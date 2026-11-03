import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/rules/mobile_rules_model.dart';
import 'package:vthm_dms/core/rules/mobile_rules_service.dart';
import 'package:vthm_dms/core/sync/sync_service.dart';
import 'package:vthm_dms/core/utils/system_clock.dart';
import 'package:vthm_dms/features/customer/data/datasources/customer_local_data_source.dart';
import 'package:vthm_dms/features/customer/data/utils/customer_payload_helper.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';
import 'package:vthm_dms/features/visit/data/repositories/visit_repository_impl.dart';
import 'package:vthm_dms/features/visit/data/services/visit_api_service.dart';

/// Rà soát #24698 nhóm 3: lỗi 3 (lượt ngoại tuyến không biết biểu mẫu bắt buộc), 4 (máy khởi động lại ⇒ queued rỗng),
/// 6 (huỷ lượt xoá dòng tạo mà server có thể đã nhận), 10 (sửa toạ độ điểm bán ngoại tuyến chưa gửi).

class _Paths extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  final Directory dir;
  _Paths(this.dir);

  @override
  Future<String?> getTemporaryPath() async => dir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;
}

/// Biểu mẫu: một phiếu khảo sát BẮT BUỘC. Check-in: hỏng mạng theo [checkinError].
class _Adapter implements HttpClientAdapter {
  DioExceptionType checkinError = DioExceptionType.connectionError;
  Object checkinCause = const SocketException('Failed host lookup');

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    if (o.path.startsWith('/dms/forms/available')) {
      return _json({
        'success': true,
        'data': [
          {
            'config_id': 9,
            'form_id': 55,
            'code': 'KS1',
            'name': 'Khảo sát trưng bày',
            'kind': 'survey',
            'is_required': true,
            'visit_scope': 'all',
            'sort_order': 1,
            'schema': {'blocks': []},
          },
          {
            'config_id': 10,
            'form_id': 56,
            'code': 'KS2',
            'name': 'Khảo sát tuỳ chọn',
            'kind': 'survey',
            'is_required': false,
            'visit_scope': 'all',
            'sort_order': 2,
            'schema': {'blocks': []},
          },
        ],
      });
    }
    if (o.path == '/dms/visits' && o.method == 'POST') {
      throw DioException(
        requestOptions: o,
        type: checkinError,
        error: checkinCause,
      );
    }
    return _json({'success': true, 'data': <String, dynamic>{}});
  }

  ResponseBody _json(Object body) => ResponseBody.fromString(jsonEncode(body), 200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

  @override
  void close({bool force = false}) {}
}

class _Online extends ConnectivityNotifier {
  _Online() {
    state = const ConnectivityState(isOnline: true);
  }

  @override
  Future<bool> checkConnectivity() async => true;

  @override
  void handleNetworkDisconnection() {}
}

class _Rules extends MobileRulesNotifier {
  _Rules(super.apiClient) {
    state = const MobileRules(visit: VisitRules(requireGeofence: false, minDurationMinutes: 0, minPhotos: 0));
  }

  @override
  Future<MobileRules> fetchRules({bool forceRefresh = false}) async => state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'account_key': 'u7'}));

  group('lỗi 4 — máy khởi động lại', () {
    test('check-in/out viếng thăm tính theo GIỜ MÁY; nơi không truyền giờ máy vẫn rỗng như cũ', () {
      final tapMs = DateTime.now().subtract(const Duration(minutes: 20)).millisecondsSinceEpoch;
      expect(
        SystemClock.calculateQueuedSeconds(createdElapsedMs: 0, entryBootId: 'boot:khac', wallFallbackCreatedAtMs: tapMs),
        closeTo(1200, 2),
        reason: 'lỗi cũ: rỗng ⇒ server ghi giờ vào/ra = lúc nhận ⇒ check-out kẹt cổng 5 phút',
      );
      expect(SystemClock.calculateQueuedSeconds(createdElapsedMs: 0, entryBootId: 'boot:khac'), isNull);
    });

    test('giờ máy lùi sau lúc bấm ⇒ 0, không âm', () {
      final future = DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch;
      expect(
        SystemClock.calculateQueuedSeconds(createdElapsedMs: 0, entryBootId: 'boot:khac', wallFallbackCreatedAtMs: future),
        0,
      );
    });
  });

  group('lỗi 6 — huỷ lượt chưa gửi', () {
    late AppDatabase db;
    setUp(() async {
      db = AppDatabase(NativeDatabase.memory(), 1);
      await db.setOwner(7);
    });
    tearDown(() => db.close());

    Future<void> create(Map<String, dynamic> payload) => db.enqueue(SyncQueueEntriesCompanion.insert(
          entity: 'visit',
          op: 'create',
          clientUuid: 'v1',
          payload: jsonEncode(payload),
          createdAt: DateTime.now().millisecondsSinceEpoch,
          createdElapsed: SystemClock.nowMonotonicMs,
          bootId: SystemClock.bootId,
        ));

    test('dòng tạo CHƯA từng gửi ⇒ xoá thẳng', () async {
      await create({'customer_id': 1});
      expect(await db.deleteUnsentVisit('v1'), isTrue);
      expect(await db.select(db.syncQueueEntries).get(), isEmpty);
    });

    test('dòng tạo đã từng gửi (có thể đã lên server) ⇒ KHÔNG xoá, để xếp lệnh huỷ chờ check-in', () async {
      await create({'customer_id': 1, queueMaybeOnServerKey: true});
      expect(await db.deleteUnsentVisit('v1'), isFalse, reason: 'lỗi cũ: xoá ⇒ lượt treo trên server');
      expect(await db.select(db.syncQueueEntries).get(), hasLength(1));
    });
  });

  group('lỗi 3 + 6 — check-in rơi về ngoại tuyến', () {
    late AppDatabase db;
    late ProviderContainer container;
    late _Adapter adapter;
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('vthm_g3_');
      PathProviderPlatform.instance = _Paths(dir);
      db = AppDatabase(NativeDatabase.memory(), 1);
      await db.setOwner(7);
      adapter = _Adapter();
      final api = ApiClient(Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = adapter);
      container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        apiClientProvider.overrideWithValue(api),
        connectivityProvider.overrideWith((ref) => _Online()),
        visitRepositoryProvider.overrideWithValue(VisitRepositoryImpl(VisitApiService(api))),
        mobileRulesProvider.overrideWith((ref) => _Rules(api)),
      ]);
    });
    tearDown(() async {
      container.dispose();
      await db.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    const dealer = DealerEntity(
      id: '101',
      order: '01',
      name: 'Đại lý A',
      address: 'Hà Nội',
      status: DealerVisitStatus.pending,
      statusLabel: 'Chưa ghé',
      isVip: false,
      lat: 10.7769,
      lng: 106.7009,
      geofenceRadiusM: 100,
    );

    Future<CheckInViewModel> checkinOffline() async {
      final vm = container.read(checkInViewModelProvider.notifier);
      vm.initCheckinWithDealer(dealer);
      await vm.loadSurveyForms(101);
      expect(await vm.performCheckin(customerId: 101, lat: 10.7769, lng: 106.7009), isNull);
      expect(container.read(checkInViewModelProvider).visitId, lessThan(0));
      return vm;
    }

    test('lỗi 3: cổng biểu mẫu của lượt ngoại tuyến lấy phiếu BẮT BUỘC đã lưu; nộp xong thì mở', () async {
      final vm = await checkinOffline();
      final req = container.read(checkInViewModelProvider).requirements!;
      expect(req.missingForms.map((f) => f.formId), [55], reason: 'lỗi cũ: rỗng ⇒ check-out bị server từ chối 422');
      expect(req.satisfied, isFalse);

      vm.markSurveySubmitted(9, 55);
      final after = container.read(checkInViewModelProvider).requirements!;
      expect(after.missingForms, isEmpty);
      expect(after.satisfied, isTrue);
    });

    test('lỗi 6: không có mạng ⇒ dòng tạo KHÔNG mang dấu "có thể đã lên server"', () async {
      await checkinOffline();
      final row = (await db.select(db.syncQueueEntries).get()).single;
      expect(queueMaybeOnServer(row.payload), isFalse);
    });

    test('lỗi 6: đã gửi trọn request rồi đứt trước khi có phản hồi ⇒ dòng tạo mang dấu', () async {
      adapter.checkinCause = const HttpException('Connection closed before full header was received');
      await checkinOffline();
      final row = (await db.select(db.syncQueueEntries).get()).single;
      expect(queueMaybeOnServer(row.payload), isTrue);
    });

    test('lỗi 6: quá giờ chờ phản hồi ⇒ dòng tạo mang dấu, huỷ lượt không xoá thẳng', () async {
      adapter.checkinError = DioExceptionType.receiveTimeout;
      adapter.checkinCause = 'timed out';
      await checkinOffline();
      final row = (await db.select(db.syncQueueEntries).get()).single;
      expect(queueMaybeOnServer(row.payload), isTrue);
      expect(await db.deleteUnsentVisit(row.clientUuid), isFalse);
    });
  });

  test('lỗi 6: lượt chờ điểm bán cha (chưa gửi gì) KHÔNG bị đóng dấu "có thể đã lên server"', () async {
    final db = AppDatabase(NativeDatabase.memory(), 1);
    await db.setOwner(7);
    final api = ApiClient(Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = _Adapter());
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      apiClientProvider.overrideWithValue(api),
      connectivityProvider.overrideWith((ref) => _Online()),
    ]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    Future<int> add(String entity, String uuid, Map<String, dynamic> payload, {String? parent}) =>
        db.enqueue(SyncQueueEntriesCompanion.insert(
          entity: entity,
          op: 'create',
          clientUuid: uuid,
          parentUuid: Value(parent),
          payload: jsonEncode(payload),
          createdAt: DateTime.now().millisecondsSinceEpoch,
          createdElapsed: SystemClock.nowMonotonicMs,
          bootId: SystemClock.bootId,
          // Điểm bán cha chưa tới lượt gửi.
          nextAttemptAt: Value(entity == 'customer' ? DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch : 0),
        ));
    await add('customer', 'c-new', {'name': 'Điểm bán mới'});
    final visitId = await add('visit', 'v-new', {'customer_client_uuid': 'c-new'}, parent: 'c-new');

    await container.read(syncServiceProvider).syncQueue();

    final row = await db.getEntryById(visitId);
    expect(row!.lastError, isNotNull, reason: 'lô phải ĐÃ xử lý dòng lượt (dừng vì chờ cha)');
    expect(queueMaybeOnServer(row.payload), isFalse, reason: 'chưa gửi request nào ⇒ huỷ lượt phải xoá thẳng được');
  });

  group('lỗi 10 — sửa toạ độ điểm bán ngoại tuyến chưa gửi', () {
    late AppDatabase db;
    setUp(() async {
      db = AppDatabase(NativeDatabase.memory(), 1);
      await db.setOwner(7);
    });
    tearDown(() => db.close());

    test('toạ độ mới thay `coords` của dòng tạo ⇒ lúc đồng bộ gửi toạ độ MỚI', () async {
      final ds = CustomerLocalDataSource(db);
      final e = await ds.createCustomerOffline({
        'name': 'Điểm bán A',
        'phone': '0909000111',
        'address': 'Hà Nội',
        'coords': {'lat': 21.0, 'lng': 105.8, 'accuracy': 5.0, 'mock': false},
      });
      await ds.updateCustomerOffline(e.clientUuid!, {
        'coords': {'lat': 21.5, 'lng': 105.9, 'accuracy': 3.0, 'mock': false},
      });

      final row = (await db.select(db.syncQueueEntries).get()).single;
      final payload = jsonDecode(row.payload) as Map<String, dynamic>;
      final sent = CustomerPayloadHelper.buildCustomerApiPayload(sourceData: payload, clientUuid: row.clientUuid);
      expect((sent['coords'] as Map)['lat'], 21.5, reason: 'lỗi cũ: chỉ ghi lat/lng, gửi coords cũ 21.0');
      expect((sent['coords'] as Map)['lng'], 105.9);
    });
  });
}
