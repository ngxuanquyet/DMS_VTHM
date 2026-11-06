import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/sync/sync_service.dart';
import 'package:vthm_dms/core/utils/system_clock.dart';
import 'package:vthm_dms/features/customer/data/datasources/customer_local_data_source.dart';
import 'package:vthm_dms/features/forms/domain/usecases/get_available_forms_usecase.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';
import 'package:vthm_dms/features/route/domain/usecases/route_usecases.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';
import 'package:vthm_dms/features/visit/data/repositories/visit_repository_impl.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';
import 'package:vthm_dms/features/visit/domain/usecases/visit_usecases.dart';

import '../visit/visit_closed_photo_rule_test.dart' show FakeFormsRepository, FakeRouteRepository, FakeVisitRepository;

/// Rà soát offline vòng 8 (06/11/2026, #24698) — mỗi test tái hiện một lỗi đã vá: lượt ngày cũ mở lại qua nút Check-in
/// Trang chủ (V1), bộ đệm lượt dùng chung mọi tài khoản (V3), lệnh sửa ma trận SOS không mang giờ bấm (S1), làm mới phiên
/// hết giờ chờ phản hồi làm mất token đã xoay (Nhẹ).

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

class _Online extends ConnectivityNotifier {
  _Online() {
    state = const ConnectivityState(isOnline: true);
  }

  @override
  Future<bool> checkConnectivity() async {
    state = const ConnectivityState(isOnline: true);
    return true;
  }

  @override
  void handleNetworkDisconnection() {}
}

VisitEntity _visit(int id, DateTime checkinAt) =>
    VisitEntity(id: id, customerId: 3, customerName: 'Điểm bán 3', checkinAt: checkinAt, clientUuid: 'v$id');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final homQua = DateTime.now().subtract(const Duration(days: 1));

  group('V1 lượt ngày cũ đã có mã không còn là lượt đang mở', () {
    late AppDatabase db;
    late ProviderContainer container;
    late Ref testRef;

    setUp(() async {
      SharedPreferences.setMockInitialValues({AppConstants.keyUserData: jsonEncode({'id': 7})});
      db = AppDatabase(NativeDatabase.memory(), 7);
      container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
      container.read(Provider((ref) => testRef = ref));
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    CheckInViewModel vm(FakeVisitRepository repo) => CheckInViewModel(
          getDealerCheckinUseCase: GetDealerCheckinUseCase(FakeRouteRepository()),
          checkoutDealerUseCase: CheckoutDealerUseCase(FakeRouteRepository()),
          getAvailableFormsUseCase: GetAvailableFormsUseCase(FakeFormsRepository()),
          checkinUseCase: CheckinUseCase(repo),
          checkoutUseCase: CheckoutUseCase(repo),
          getVisitRequirementsUseCase: GetVisitRequirementsUseCase(repo),
          uploadVisitPhotoUseCase: UploadVisitPhotoUseCase(repo),
          deleteVisitPhotoUseCase: DeleteVisitPhotoUseCase(repo),
          cancelVisitUseCase: CancelVisitUseCase(repo),
          visitRepository: repo,
          ref: testRef,
        );

    test('isPastDayServerVisit: chỉ lượt NGÀY CŨ đã có mã server', () {
      expect(_visit(9, homQua).isPastDayServerVisit, isTrue);
      expect(_visit(-2, homQua).isPastDayServerVisit, isFalse, reason: 'lượt chưa có mã vẫn chặn (chốt 06/11/2026)');
      expect(_visit(9, DateTime.now()).isPastDayServerVisit, isFalse);
    });

    test('nút Check-in Trang chủ (không điểm bán) KHÔNG khôi phục lượt hôm qua đã có mã', () async {
      final v = vm(FakeVisitRepository([], activeVisit: _visit(9, homQua)));
      addTearDown(v.dispose);

      expect(await v.restoreActiveVisitIfAvailable(), isFalse,
          reason: 'lỗi cũ: mở lại lượt hôm qua, check-out sáng nay xoá dấu "Chưa check-out", thời lượng hàng chục giờ');
      expect(v.state.visitId, 0);
    });

    test('VM sống qua đêm còn giữ lượt hôm qua ⇒ check-in điểm bán khác dựng phiên MỚI', () async {
      final v = vm(FakeVisitRepository([]));
      addTearDown(v.dispose);
      // ignore: invalid_use_of_protected_member
      v.state = v.state.copyWith(visitId: 9, visitEntity: _visit(9, homQua));

      v.initCheckinWithDealer(const DealerEntity(
          id: '5', order: '01', name: 'B', address: '', status: DealerVisitStatus.pending, statusLabel: '', isVip: false));

      expect(v.state.visitId, 0,
          reason: 'lỗi cũ: bỏ qua init, check-in gửi uuid lượt hôm qua ⇒ server trả lại chính lượt đó (chống gửi trùng)');
      expect(v.state.checkinData?.dealer.id, '5');
    });

    test('tuyến sống qua đêm gắn lượt hôm qua vào CÙNG điểm bán ⇒ bấm lại dựng phiên mới, không nhận lượt cũ', () async {
      final v = vm(FakeVisitRepository([]));
      addTearDown(v.dispose);
      final cu = _visit(9, homQua);
      // ignore: invalid_use_of_protected_member
      v.state = v.state.copyWith(visitId: 9, visitEntity: cu);

      v.initCheckinWithDealer(DealerEntity(
          id: '3', order: '01', name: 'Điểm bán 3', address: '', status: DealerVisitStatus.inProgress, statusLabel: '',
          isVip: false, visit: cu));

      expect(v.state.visitId, 0, reason: 'lỗi cũ: dựng lại phiên bằng lượt hôm qua ⇒ check-in gửi uuid cũ, server trả lượt đó');
      expect(v.state.visitEntity, isNull);
    });

    test('lượt hôm qua CHƯA có mã (id âm) vẫn khôi phục như cũ', () async {
      final v = vm(FakeVisitRepository([], activeVisit: _visit(-2, homQua)));
      addTearDown(v.dispose);

      expect(await v.restoreActiveVisitIfAvailable(), isTrue);
      expect(v.state.visitId, -2);
    });
  });

  group('V3 bộ đệm lượt viếng thăm theo tài khoản', () {
    const active = 'dms_active_visit_session_v1';
    const list = 'dms_visits_local_cache_v2';

    test('tài khoản khác đăng nhập ⇒ cất bản của người trước; người trước vào lại thì lấy lại', () async {
      SharedPreferences.setMockInitialValues({
        'dms_visits_local_owner': 7,
        active: '{"id":-2}',
        list: '[{"id":-2}]',
      });
      final prefs = await SharedPreferences.getInstance();

      await VisitRepositoryImpl.switchLocalOwner(8);
      expect(prefs.getString(active), isNull, reason: 'lỗi cũ: B thấy và bị chặn bởi lượt đang mở của A');
      expect(prefs.getString(list), isNull);

      await prefs.setString(active, '{"id":55}');
      await VisitRepositoryImpl.switchLocalOwner(7);
      expect(prefs.getString(active), '{"id":-2}', reason: 'lượt ngoại tuyến chưa gửi của A còn nguyên');
      expect(prefs.getString(list), '[{"id":-2}]');

      await VisitRepositoryImpl.switchLocalOwner(8);
      expect(prefs.getString(active), '{"id":55}');
    });

    test('máy chưa ghi chủ (bản app cũ) / cùng người đăng nhập lại ⇒ giữ nguyên', () async {
      SharedPreferences.setMockInitialValues({active: '{"id":-2}'});
      final prefs = await SharedPreferences.getInstance();

      await VisitRepositoryImpl.switchLocalOwner(7);
      await VisitRepositoryImpl.switchLocalOwner(7);
      expect(prefs.getString(active), '{"id":-2}');
    });
  });

  group('S1 lệnh sửa điểm bán từ hàng đợi mang giờ bấm thật', () {
    late AppDatabase db;
    late _Adapter adapter;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory(), 7);
      adapter = _Adapter((_) => null);
      final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = adapter;
      container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        apiClientProvider.overrideWithValue(ApiClient(dio)),
        connectivityProvider.overrideWith((ref) => _Online()),
      ]);
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('lệnh sửa có ô ma trận KHÔNG gộp — mỗi lệnh giữ giờ bấm riêng; lệnh thường vẫn gộp', () async {
      final local = CustomerLocalDataSource(db);
      final t0 = DateTime.now().millisecondsSinceEpoch;
      Future<void> sua(Map<String, dynamic> c, int t) =>
          local.enqueueCustomerUpdate(serverId: 77, clientUuid: 'server_77', changes: c, nowMs: t);
      await sua({'data': {'sos': {'counts': {'vthm': {'ke': 2}}}}}, t0);
      await sua({'phone': '1'}, t0 + 1000);
      await sua({'name': 'B'}, t0 + 2000);

      final rows = await db.getAllPendingQueueEntries();
      expect(rows, hasLength(2),
          reason: 'lỗi: gộp chung một mốc ⇒ phiếu khảo sát nộp giữa hai lần sửa bị số cũ đè hoặc đè mất số mới');
      expect(jsonDecode(rows.firstWhere((r) => r.payload.contains('sos')).payload).containsKey('phone'), isFalse);
      expect(jsonDecode(rows.firstWhere((r) => r.payload.contains('phone')).payload)['name'], 'B');
    });

    test('PATCH mang client_time + queued_seconds, không mang client_boot_id (form sửa từ chối khoá lạ)', () async {
      final bam = DateTime.now().subtract(const Duration(minutes: 30)).millisecondsSinceEpoch;
      await db.enqueue(SyncQueueEntriesCompanion.insert(
        entity: 'customer',
        op: 'update',
        clientUuid: 'server_77',
        serverId: const Value(77),
        payload: jsonEncode({'phone': '0901234567'}),
        createdAt: bam,
        createdElapsed: SystemClock.nowMonotonicMs - 30 * 60 * 1000,
        bootId: SystemClock.bootId,
      ));

      await container.read(syncServiceProvider).syncQueue(force: true);

      final body = adapter.calls.singleWhere((c) => c.path == '/crm/customers/77').data as Map;
      expect(body['offline_queue'], isTrue);
      expect(body['client_time'], DateTime.fromMillisecondsSinceEpoch(bam).toIso8601String());
      expect(body['queued_seconds'], greaterThanOrEqualTo(30 * 60 - 1),
          reason: 'lỗi cũ: server đóng dấu giờ nhận ⇒ phiếu đo trước đó, gửi sau bị coi là "đến muộn"');
      expect(body.containsKey('client_boot_id'), isFalse);
    });
  });

  group('Làm mới phiên hết giờ chờ phản hồi', () {
    test('receiveTimeout ⇒ gửi lại /auth/refresh NGAY một lần, nhận token đã xoay, không bị đăng xuất', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyAccessToken, 'old');
      await prefs.setString(AppConstants.keyRefreshToken, 'refresh-old');
      var rejected = 0;
      AuthInterceptor.onSessionRejected = ([_]) => rejected++;
      addTearDown(() => AuthInterceptor.onSessionRejected = null);

      var refreshCalls = 0;
      final refreshAdapter = _Adapter((o) {
        refreshCalls++;
        if (refreshCalls == 1) {
          throw DioException(requestOptions: o, type: DioExceptionType.receiveTimeout);
        }
        return (200, {
          'success': true,
          'data': {'access_token': 'new', 'refresh_token': 'refresh-new'},
        });
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))
        ..httpClientAdapter = _Adapter((o) => o.headers['Authorization'] == 'Bearer new'
            ? (200, {'success': true, 'data': <String, dynamic>{}})
            : (401, {'success': false}));
      dio.interceptors.add(AuthInterceptor(dio, refreshDio: () => Dio()..httpClientAdapter = refreshAdapter));

      await ApiClient(dio).get('/dms/attendance/config');

      expect(refreshCalls, 2,
          reason: 'lỗi cũ: giữ refresh token cũ, lần sau quá cửa replay 60 s ⇒ 401 ⇒ bị đăng xuất cưỡng bức');
      expect(prefs.getString(AppConstants.keyRefreshToken), 'refresh-new');
      expect(rejected, 0);
    });
  });
}
