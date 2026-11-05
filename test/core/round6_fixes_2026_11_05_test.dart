// ignore_for_file: invalid_use_of_protected_member
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/core/errors/app_exceptions.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/sync/sync_service.dart';
import 'package:vthm_dms/core/utils/system_clock.dart';
import 'package:vthm_dms/features/customer/data/datasources/customer_local_data_source.dart';
import 'package:vthm_dms/features/customer/data/repositories/customer_repository_impl.dart';
import 'package:vthm_dms/features/customer/data/services/customer_api_service.dart';
import 'package:vthm_dms/features/forms/domain/usecases/get_available_forms_usecase.dart';
import 'package:vthm_dms/features/route/domain/usecases/route_usecases.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';
import 'package:vthm_dms/features/visit/data/repositories/visit_repository_impl.dart';
import 'package:vthm_dms/features/visit/data/services/visit_api_service.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_requirements_entity.dart';
import 'package:vthm_dms/features/visit/domain/usecases/visit_usecases.dart';

import '../visit/visit_closed_photo_rule_test.dart' show FakeFormsRepository, FakeRouteRepository, FakeVisitRepository;

/// Rà soát offline vòng 6 (05/11/2026, #24698) — nhóm lỗi Vừa: mỗi test tái hiện một lỗi đã vá.

typedef _Handler = (int, Object)? Function(RequestOptions o);

class _Adapter implements HttpClientAdapter {
  final _Handler handler;
  final List<RequestOptions> calls = [];
  _Adapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    calls.add(o);
    final r = handler(o) ?? (200, {'success': true, 'data': <String, dynamic>{}});
    return ResponseBody.fromString(jsonEncode(r.$2), r.$1,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

/// Server báo thiếu loại vật tư bắt buộc #3 — chưa thấy thao tác vật tư đang nằm hàng đợi.
class _MaterialReq extends FakeVisitRepository {
  _MaterialReq() : super([]);

  @override
  Future<VisitRequirementsEntity> getRequirements(int visitId, {String? visitResult}) async =>
      const VisitRequirementsEntity(
        satisfied: false,
        missingMaterials: [MissingMaterialEntity(materialTypeId: 3, name: 'Kệ trưng bày')],
        blockers: ['Chưa kiểm vật tư bắt buộc: Kệ trưng bày'],
      );
}

/// Huỷ lượt: server trả [error]; ghi lại lần gọi API huỷ và lần ghi "đã huỷ" trong máy.
class _CancelRepo extends FakeVisitRepository {
  final Object error;
  int apiCancels = 0;
  int localMarks = 0;
  _CancelRepo(this.error) : super([]);

  @override
  Future<void> cancelVisit(int visitId, {String? clientUuid}) async {
    apiCancels++;
    throw error;
  }

  @override
  Future<void> markVisitCancelledLocally(int visitId, {String? clientUuid}) async {
    localMarks++;
    activeVisit = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  late Ref testRef;

  setUp(() async {
    SharedPreferences.setMockInitialValues({AppConstants.keyUserData: jsonEncode({'id': 7})});
    db = AppDatabase(NativeDatabase.memory(), 1);
    await db.setOwner(7);
    container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
    container.read(Provider((ref) => testRef = ref));
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  CheckInViewModel vm(FakeVisitRepository visitRepo, {Ref? ref}) => CheckInViewModel(
        getDealerCheckinUseCase: GetDealerCheckinUseCase(FakeRouteRepository()),
        checkoutDealerUseCase: CheckoutDealerUseCase(FakeRouteRepository()),
        getAvailableFormsUseCase: GetAvailableFormsUseCase(FakeFormsRepository()),
        checkinUseCase: CheckinUseCase(visitRepo),
        checkoutUseCase: CheckoutUseCase(visitRepo),
        getVisitRequirementsUseCase: GetVisitRequirementsUseCase(visitRepo),
        uploadVisitPhotoUseCase: UploadVisitPhotoUseCase(visitRepo),
        deleteVisitPhotoUseCase: DeleteVisitPhotoUseCase(visitRepo),
        cancelVisitUseCase: CancelVisitUseCase(visitRepo),
        visitRepository: visitRepo,
        ref: ref,
      );

  Future<void> enqueueMaterial(String parent, String state, int typeId) => db.enqueue(SyncQueueEntriesCompanion.insert(
        entity: 'visit_material',
        op: 'create',
        clientUuid: 'mat-$state-$typeId',
        parentUuid: Value(parent),
        payload: jsonEncode({
          'visit_id': 5,
          'op': {'client_uuid': 'op-$state-$typeId', 'material_type_id': typeId, 'action': 'confirm'},
        }),
        state: Value(state),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        createdElapsed: SystemClock.nowMonotonicMs,
        bootId: SystemClock.bootId,
      ));

  group('V1 cổng vật tư ④ cộng thao tác vật tư còn chờ gửi', () {
    test('thao tác vật tư chờ gửi ⇒ làm mới điều kiện từ server KHÔNG đóng lại cổng ④', () async {
      final m = vm(_MaterialReq(), ref: testRef);
      await enqueueMaterial(m.sessionClientUuid, 'pending', 3);
      m.state = m.state.copyWith(visitId: 5);

      await m.refreshRequirements();

      final req = m.state.requirements!;
      expect(req.missingMaterials, isEmpty, reason: 'lỗi cũ: nút Check-out báo "chưa kiểm vật tư" dù đã kiểm');
      expect(req.blockers, isEmpty);
      expect(req.satisfied, isTrue);
    });

    test('thao tác vật tư đã chết ⇒ vẫn thiếu', () async {
      final m = vm(_MaterialReq(), ref: testRef);
      await enqueueMaterial(m.sessionClientUuid, 'dead', 3);
      m.state = m.state.copyWith(visitId: 5);

      await m.refreshRequirements();

      expect(m.state.requirements!.missingMaterials.single.materialTypeId, 3);
      expect(m.state.requirements!.satisfied, isFalse);
    });
  });

  group('V2 huỷ lượt KHÔNG gọi API huỷ lần hai', () {
    test('server báo 404 ⇒ chỉ ghi "đã huỷ" trong máy, không ném ra (hộp xoay không kẹt)', () async {
      final repo = _CancelRepo(const ServerException('Không tìm thấy lượt', 404));
      final m = vm(repo, ref: testRef);
      m.state = m.state.copyWith(visitId: 5);

      final (ok, _) = await m.cancelVisit();

      expect(ok, isTrue);
      expect(repo.apiCancels, 1, reason: 'lỗi cũ: gọi lại API huỷ trong catch ⇒ 404 lần hai ném ra ngoài');
      expect(repo.localMarks, 1);
    });
  });

  group('V3 huỷ lượt bị server từ chối KHÔNG ghi "đã huỷ" trong máy', () {
    test('500 ⇒ ném lỗi, lượt vẫn đang mở + không gắn cancelledAt', () async {
      final adapter = _Adapter((o) => o.path.endsWith('/cancel') ? (500, {'success': false, 'message': 'lỗi lưu'}) : null);
      final repo = VisitRepositoryImpl(VisitApiService(ApiClient(Dio()..httpClientAdapter = adapter)));
      final now = DateTime.now();
      final visit = VisitEntity(
          id: 55, customerId: 1, checkinAt: now, checkinAtRaw: now.toIso8601String(), clientUuid: 'v-55');
      await repo.saveActiveVisit(visit);
      await repo.saveLocalVisit(visit);

      await expectLater(repo.cancelVisit(55, clientUuid: 'v-55'), throwsA(isA<AppException>()));

      expect((await repo.getActiveVisit())?.id, 55, reason: 'lỗi cũ: finally dọn lượt đang mở kể cả khi server từ chối');
      expect((await repo.getAllLocalVisits()).single.cancelledAt, isNull);
    });

    test('ghi huỷ lượt A trong máy KHÔNG xoá lượt B đang mở; id 0 / uuid rỗng không khớp nhầm', () async {
      final repo = VisitRepositoryImpl(VisitApiService(ApiClient(Dio())));
      final now = DateTime.now();
      VisitEntity v(int id, String uuid) =>
          VisitEntity(id: id, customerId: 1, checkinAt: now, checkinAtRaw: now.toIso8601String(), clientUuid: uuid);
      await repo.saveActiveVisit(v(66, 'v-b'));
      await repo.saveLocalVisit(v(0, ''));
      await repo.saveLocalVisit(v(66, 'v-b'));

      await repo.markVisitCancelledLocally(0, clientUuid: '');
      await repo.markVisitCancelledLocally(55, clientUuid: 'v-a');

      expect((await repo.getActiveVisit())?.id, 66);
      expect((await repo.getAllLocalVisits()).every((x) => x.cancelledAt == null), isTrue);
    });
  });

  group('C1 ảnh mặt tiền đi hàng đợi giữ ĐƯỜNG DẪN, không token đã tải', () {
    late Directory tmp;
    late CustomerRepositoryImpl repo;
    var postFails = false;
    var uploadFails = false;
    Map? patched;

    setUp(() async {
      postFails = false;
      uploadFails = false;
      patched = null;
      tmp = await Directory.systemTemp.createTemp('front_');
      final adapter = _Adapter((o) {
        if (o.path == '/crm/customer-photos') {
          return uploadFails ? (500, {'success': false}) : (200, {'success': true, 'data': {'token': 'f' * 32}});
        }
        if (o.path == '/crm/customers' && o.method == 'POST') {
          return postFails
              ? (500, {'success': false, 'message': 'lỗi CSDL tạm'})
              : (201, {'success': true, 'data': {'id': 9001, 'code': 'DMS0001', 'created': true}});
        }
        if (o.path.startsWith('/crm/customers/') && o.method == 'PATCH') {
          patched = o.data is Map ? o.data as Map : null;
          return (200, {'success': true, 'data': {'id': 9001}});
        }
        return (200, {'success': true, 'data': []});
      });
      final apiClient = ApiClient(Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = adapter);
      final c = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        apiClientProvider.overrideWithValue(apiClient),
        connectivityProvider.overrideWith((ref) => ConnectivityNotifier()),
      ]);
      addTearDown(c.dispose);
      repo = CustomerRepositoryImpl(
        CustomerApiService(apiClient),
        CustomerLocalDataSource(db),
        c.read(syncServiceProvider),
        null,
        () => true,
      );
    });
    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    File anh() => File('${tmp.path}/mat_tien_${DateTime.now().microsecondsSinceEpoch}.jpg')..writeAsBytesSync([1, 2, 3]);

    Map<String, dynamic> input(String path) =>
        {'name': 'Điểm bán ảnh', 'region_id': 1, 'route_ids': [1], 'photo_tokens': [path]};

    test('TẠO: ảnh đã tải được nhưng POST lỗi tạm ⇒ hàng đợi giữ đường dẫn ảnh', () async {
      postFails = true;
      await repo.createCustomer(input(anh().path));

      final row = (await db.getAllPendingQueueEntries()).singleWhere((r) => r.entity == 'customer');
      final photos = (jsonDecode(row.payload)['photo_tokens'] as List).cast<String>();
      expect(photos, isNot(contains('f' * 32)), reason: 'lỗi cũ: token đã tải bị server dọn sau 1 ngày ⇒ dead');
      expect(photos.single, endsWith('.jpg'));
    });

    test('SỬA có mạng: ảnh mặt tiền là đường dẫn ⇒ tải ngay trước PATCH; tải lỗi ⇒ hàng đợi giữ đường dẫn', () async {
      await repo.createCustomer({'name': 'Điểm bán ảnh', 'region_id': 1, 'route_ids': [1]});

      await repo.updateCustomer(id: 9001, changes: {'photo_tokens': [anh().path]});
      expect(patched?['photo_tokens'], ['f' * 32]);

      patched = null;
      uploadFails = true;
      await repo.updateCustomer(id: 9001, changes: {'photo_tokens': [anh().path]});
      expect(patched, isNull, reason: 'lỗi cũ: PATCH mang đường dẫn máy ⇒ 4xx, mất lần sửa');
      final row = (await (db.select(db.syncQueueEntries)..where((t) => t.op.equals('update'))).get()).single;
      expect((jsonDecode(row.payload)['photo_tokens'] as List).single, endsWith('.jpg'));
    });
  });

  group('A1 bị thu quyền app lúc làm mới token ⇒ về đăng nhập kèm đúng lý do', () {
    test('/auth/refresh 403 DMS_APP_FORBIDDEN ⇒ báo phiên bị từ chối với câu của server', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyAccessToken, 'old');
      await prefs.setString(AppConstants.keyRefreshToken, 'refresh-old');
      String? lyDo;
      var goi = 0;
      AuthInterceptor.onSessionRejected = ([m]) {
        goi++;
        lyDo = m;
      };
      addTearDown(() => AuthInterceptor.onSessionRejected = null);
      final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))
        ..httpClientAdapter = _Adapter((_) => (401, {'success': false}));
      dio.interceptors.add(AuthInterceptor(dio,
          refreshDio: () => Dio()
            ..httpClientAdapter = _Adapter(
                (_) => (403, {'success': false, 'code': 'DMS_APP_FORBIDDEN', 'message': 'Đã bị thu quyền app'}))));

      await expectLater(ApiClient(dio).post('/dms/attendance/punch', data: {}), throwsA(isA<AppException>()));

      expect(goi, 1, reason: 'lỗi cũ: phiên bị xoá mà app ở lại, chấm công sau đó 401 xếp hàng và báo "Đã ghi nhận"');
      expect(lyDo, 'Đã bị thu quyền app');
      expect(prefs.getString(AppConstants.keyRefreshToken), isNull);
    });

    test('403 không mang mã/câu thu quyền (trang chặn proxy) ⇒ về đăng nhập câu "hết phiên", không phải thu quyền',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyAccessToken, 'old');
      await prefs.setString(AppConstants.keyRefreshToken, 'refresh-old');
      var goi = 0;
      String? lyDo = 'chưa gọi';
      AuthInterceptor.onSessionRejected = ([m]) {
        goi++;
        lyDo = m;
      };
      addTearDown(() => AuthInterceptor.onSessionRejected = null);
      final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))
        ..httpClientAdapter = _Adapter((_) => (401, {'success': false}));
      dio.interceptors.add(AuthInterceptor(dio, refreshDio: () => Dio()..httpClientAdapter = _Adapter((_) => (403, 'blocked'))));

      await expectLater(ApiClient(dio).post('/dms/attendance/punch', data: {}),
          throwsA(allOf(isA<AppException>(), isNot(isA<DmsAppForbiddenException>()))),
          reason: 'không phải bị thu quyền ⇒ chấm công vẫn xếp hàng');

      expect(goi, 1);
      expect(lyDo, isNull);
    });
  });
}
