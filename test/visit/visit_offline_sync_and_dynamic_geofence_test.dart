import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
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
import 'package:vthm_dms/core/rules/geofence_rule_helper.dart';
import 'package:vthm_dms/core/rules/mobile_rules_model.dart';
import 'package:vthm_dms/core/rules/mobile_rules_service.dart';
import 'package:vthm_dms/core/sync/sync_service.dart';
import 'package:vthm_dms/core/utils/system_clock.dart';
import 'package:vthm_dms/features/forms/data/models/route_customer_model.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';
import 'package:vthm_dms/features/route/presentation/states/route_state.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';
import 'package:vthm_dms/features/visit/data/repositories/visit_repository_impl.dart';
import 'package:vthm_dms/features/visit/data/services/visit_api_service.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';
import 'package:vthm_dms/features/visit/domain/repositories/visit_repository.dart';

class MockPathProviderPlatform extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  final Directory tempDir;
  final Directory appDocsDir;
  MockPathProviderPlatform({required this.tempDir, required this.appDocsDir});

  @override
  Future<String?> getTemporaryPath() async => tempDir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => appDocsDir.path;
}

class FailingNetworkDioAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'No internet connection',
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeRulesNotifier extends MobileRulesNotifier {
  FakeRulesNotifier(super.apiClient, [MobileRules rules = const MobileRules()]) {
    state = rules;
  }
  @override
  Future<MobileRules> fetchRules({bool forceRefresh = false}) async => state;
}

class FakeDioAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> recordedRequests = [];
  bool return422OnCheckout = false;
  bool return422OnCancel = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    recordedRequests.add({
      'method': options.method,
      'path': options.path,
      'data': options.data,
    });

    if (options.path == '/dms/visits' && options.method == 'POST') {
      final res = {
        'success': true,
        'data': {
          'id': 99901,
          'customer_id': 101,
          'checkin_at': '2026-10-03 14:00:00+07',
          'visit_date': '2026-10-03',
        },
        'message': 'Check-in thành công',
      };
      return ResponseBody.fromString(
        jsonEncode(res),
        201,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    if (options.path.startsWith('/dms/visits/') && options.path.endsWith('/photos') && options.method == 'POST') {
      final res = {
        'success': true,
        'data': {
          'id': 701,
          'file_id': 12345,
          'token': 'photo_token_abc',
          'url': '/dms/visit-photos/public/photo_token_abc',
          'photo_type': 'display',
        },
        'message': 'Tải ảnh thành công',
      };
      return ResponseBody.fromString(
        jsonEncode(res),
        201,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    if (options.path.startsWith('/dms/visits/') && options.path.endsWith('/checkout') && options.method == 'POST') {
      if (return422OnCheckout) {
        final errRes = {
          'success': false,
          'message': 'Lượt viếng thăm này đã check-out rồi',
        };
        return ResponseBody.fromString(
          jsonEncode(errRes),
          422,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      }
      final res = {
        'success': true,
        'data': {
          'id': 99901,
          'checkout_at': '2026-10-03 14:15:00+07',
        },
        'message': 'Check-out thành công',
      };
      return ResponseBody.fromString(
        jsonEncode(res),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    if (options.path.startsWith('/dms/visits/') && options.path.endsWith('/cancel') && options.method == 'POST') {
      if (return422OnCancel) {
        final errRes = {
          'success': false,
          'message': 'Lượt viếng thăm này đã bị huỷ rồi',
        };
        return ResponseBody.fromString(
          jsonEncode(errRes),
          422,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      }
      final res = {
        'success': true,
        'data': {
          'id': 99901,
          'cancelled_at': '2026-10-03 14:10:00+07',
        },
        'message': 'Huỷ lượt viếng thăm thành công',
      };
      return ResponseBody.fromString(
        jsonEncode(res),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    return ResponseBody.fromString('{"success":true}', 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory docsDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('vthm_test_temp_');
    docsDir = await Directory.systemTemp.createTemp('vthm_test_docs_');
    PathProviderPlatform.instance = MockPathProviderPlatform(
      tempDir: tempDir,
      appDocsDir: docsDir,
    );
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
      if (await docsDir.exists()) await docsDir.delete(recursive: true);
    } catch (_) {}
  });

  group('GeofenceRuleHelper Dynamic Geofence Resolution Tests', () {
    test('DealerEntity with custom geofenceRadiusM overrides default rules', () {
      const dealer = DealerEntity(
        id: '1',
        order: '01',
        name: 'Đại lý A',
        address: 'Hà Nội',
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
        lat: 21.0,
        lng: 105.0,
        geofenceRadiusM: 250,
      );

      const rules = MobileRules(
        visit: VisitRules(requireGeofence: true, defaultRadiusM: 100),
      );

      final radius = GeofenceRuleHelper.resolveAllowedRadius(dealer: dealer, rules: rules);
      expect(radius, 250);
    });

    test('CheckinDealerEntity with custom geofenceRadiusM overrides default rules', () {
      const checkinDealer = CheckinDealerEntity(
        id: '2',
        name: 'Đại lý B',
        address: 'Đà Nẵng',
        isVip: false,
        distanceMeters: 50,
        visitDuration: '00:00:00',
        lat: 16.0,
        lng: 108.0,
        geofenceRadiusM: 180,
      );

      const rules = MobileRules(
        visit: VisitRules(requireGeofence: true, defaultRadiusM: 80),
      );

      final radius = GeofenceRuleHelper.resolveAllowedRadius(dealer: checkinDealer, rules: rules);
      expect(radius, 180);
    });

    test('RouteCustomerItem with custom geofenceRadiusM overrides rules', () {
      final customerItem = RouteCustomerItem(
        id: 3,
        code: 'KH03',
        name: 'Đại lý C',
        address: 'Cần Thơ',
        lat: 10.0,
        lng: 105.7,
        geofenceRadiusM: 350,
      );

      const rules = MobileRules(
        visit: VisitRules(requireGeofence: true, defaultRadiusM: 100),
      );

      final radius = GeofenceRuleHelper.resolveAllowedRadius(dealer: customerItem, rules: rules);
      expect(radius, 350);
    });

    test('Falls back to rules.visit.defaultRadiusM when dealer has null geofenceRadiusM', () {
      const dealer = DealerEntity(
        id: '4',
        order: '04',
        name: 'Đại lý D',
        address: 'Hà Nội',
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
        lat: 21.0,
        lng: 105.0,
        geofenceRadiusM: null,
      );

      const rules = MobileRules(
        visit: VisitRules(requireGeofence: true, defaultRadiusM: 120),
      );

      final radius = GeofenceRuleHelper.resolveAllowedRadius(dealer: dealer, rules: rules);
      expect(radius, 120);
    });

    test('Falls back to 100 when both dealer and rules are null', () {
      final radius = GeofenceRuleHelper.resolveAllowedRadius(dealer: null, rules: null);
      expect(radius, 100);
    });

    test('isGeofenceRequired respects rules configuration', () {
      const rulesEnabled = MobileRules(visit: VisitRules(requireGeofence: true));
      const rulesDisabled = MobileRules(visit: VisitRules(requireGeofence: false));

      expect(GeofenceRuleHelper.isGeofenceRequired(rulesEnabled), isTrue);
      expect(GeofenceRuleHelper.isGeofenceRequired(rulesDisabled), isFalse);
      expect(GeofenceRuleHelper.isGeofenceRequired(null), isTrue);
    });
  });

  group('RouteViewModel Dynamic Geofence & Offline Visits Flow', () {
    late AppDatabase db;
    late VisitRepository visitRepo;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());

      // Create a VisitRepositoryImpl with failing network adapter to force offline behavior
      final failingDio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))
        ..httpClientAdapter = FailingNetworkDioAdapter();
      final apiClient = ApiClient(failingDio);
      final apiService = VisitApiService(apiClient);
      visitRepo = VisitRepositoryImpl(apiService);

      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          apiClientProvider.overrideWithValue(apiClient),
          connectivityProvider.overrideWith((ref) => ConnectivityNotifier()),
          visitRepositoryProvider.overrideWithValue(visitRepo),
          mobileRulesProvider.overrideWith((ref) => FakeRulesNotifier(
                apiClient,
                const MobileRules(visit: VisitRules(requireGeofence: true, defaultRadiusM: 100)),
              )),
        ],
      );
    });

    tearDown(() async {
      await db.close();
      container.dispose();
    });

    test('Offline checkin creates negative visitId and queues in SyncQueueEntries', () async {
      final vm = container.read(checkInViewModelProvider.notifier);

      const dealer = DealerEntity(
        id: '101',
        order: '01',
        name: 'Cửa hàng Hoàng Gia',
        address: 'Hà Nội',
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
        lat: 21.028511,
        lng: 105.854444,
        geofenceRadiusM: 200,
      );

      vm.initCheckinWithDealer(dealer);

      // Check-in cách ~10m (nằm trong bán kính 200m)
      final error = await vm.performCheckin(
        customerId: 101,
        lat: 21.028600,
        lng: 105.854444,
      );

      // Offline check-in thành công (error is null)
      expect(error, isNull);
      expect(vm.state.visitId, lessThan(0));
      expect(vm.state.status, CheckInStatus.loaded);

      // Đã lưu vào SyncQueueEntries
      final pending = await db.getPendingQueueEntries();
      expect(pending.length, 1);
      final entry = pending.first;
      expect(entry.entity, 'visit');
      expect(entry.op, 'create');
      expect(entry.clientUuid, isNotNull);

      final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
      expect(payload['customer_id'], 101);
      expect(payload['lat'], 21.028600);

      // Đã lưu vào active visit trong local DB
      final active = await visitRepo.getActiveVisit();
      expect(active, isNotNull);
      expect(active!.id, vm.state.visitId);
      expect(active.clientUuid, entry.clientUuid);
    });

    test('Offline checkin strictly respects min_duration_minutes from cached rules (1 minute instead of hardcoded 5)', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        MobileRulesNotifier.cacheKey,
        jsonEncode({
          'visit': {
            'require_geofence': true,
            'default_radius_m': 100,
            'min_duration_minutes': 1,
            'min_photos': 1,
          },
        }),
      );

      final vm = container.read(checkInViewModelProvider.notifier);

      const dealer = DealerEntity(
        id: '101',
        order: '01',
        name: 'Cửa hàng Hoàng Gia',
        address: 'Hà Nội',
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
        lat: 21.028511,
        lng: 105.854444,
      );

      vm.initCheckinWithDealer(dealer);
      final error = await vm.performCheckin(
        customerId: 101,
        lat: 21.028511,
        lng: 105.854444,
      );

      expect(error, isNull);
      expect(vm.state.visitId, lessThan(0));
      // Kiểm tra chính xác thời gian tối thiểu theo luật đã lưu trong cache (1 phút = 60s, KHÔNG phải 5 phút = 300s)
      expect(vm.state.requirements?.secondsRemaining, 60);
      expect(vm.state.requirements?.blockers, contains('Bạn cần ở lại thêm 1 phút nữa mới check-out được.'));
      expect(vm.state.requirements?.blockers.any((b) => b.contains('5 phút')), isFalse);
    });

    test('Check-in blocks when outside dynamic allowedRadiusMeters', () async {
      final vm = container.read(checkInViewModelProvider.notifier);

      const dealer = DealerEntity(
        id: '101',
        order: '01',
        name: 'Cửa hàng Hoàng Gia',
        address: 'Hà Nội',
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
        lat: 21.028511,
        lng: 105.854444,
        geofenceRadiusM: 150,
      );

      vm.initCheckinWithDealer(dealer);

      // Check-in ở xa (cách 5km)
      final error = await vm.performCheckin(
        customerId: 101,
        lat: 21.060000,
        lng: 105.854444,
      );

      expect(error, contains('Bạn đang cách điểm bán'));
      expect(error, contains('tối đa 150m'));
      expect(vm.state.visitId, 0);

      final pending = await db.getPendingQueueEntries();
      expect(pending.isEmpty, isTrue);
    });

    test('Offline photo upload copies file to offline dir and enqueues sync entry', () async {
      final vm = container.read(checkInViewModelProvider.notifier);

      const dealer = DealerEntity(
        id: '101',
        order: '01',
        name: 'Cửa hàng Hoàng Gia',
        address: 'Hà Nội',
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
      );

      vm.initCheckinWithDealer(dealer);
      await vm.performCheckin(customerId: 101);
      final parentClientUuid = vm.state.visitEntity?.clientUuid;
      expect(parentClientUuid, isNotNull);

      // Tạo một file ảnh tạm
      final tempPhoto = File('${tempDir.path}/test_capture.jpg');
      await tempPhoto.writeAsString('sample image data');

      final (uploadSuccess, uploadError) = await vm.uploadPhoto(
        tempPhoto,
        photoType: 'display',
      );

      expect(uploadSuccess, isTrue);
      expect(uploadError, contains('Đã lưu ảnh ngoại tuyến'));
      expect(vm.state.photos.length, 1);
      expect(vm.state.photos.first.photoType, 'display');

      // Kiểm tra sync queue đã có entry upload ảnh với parentUuid
      final pending = await db.getPendingQueueEntries();
      expect(pending.length, 2); // 1 checkin + 1 photo

      final photoEntry = pending.firstWhere((e) => e.entity == 'visit_photo');
      expect(photoEntry.op, 'upload');
      expect(photoEntry.parentUuid, parentClientUuid);
      expect(photoEntry.localPath, isNotNull);
      expect(File(photoEntry.localPath!).existsSync(), isTrue);
    });

    test('Offline checkout enqueues checkout entry with parentUuid and marks completed', () async {
      final vm = container.read(checkInViewModelProvider.notifier);

      const dealer = DealerEntity(
        id: '101',
        order: '01',
        name: 'Cửa hàng Hoàng Gia',
        address: 'Hà Nội',
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
        lat: 21.028511,
        lng: 105.854444,
        geofenceRadiusM: 200,
      );

      vm.initCheckinWithDealer(dealer);
      await vm.performCheckin(
        customerId: 101,
        lat: 21.028511,
        lng: 105.854444,
      );
      final parentClientUuid = vm.state.visitEntity?.clientUuid;

      final (success, errorMsg) = await vm.checkout(
        lat: 21.028520,
        lng: 105.854444,
      );

      expect(success, isTrue);
      expect(errorMsg, isNull);
      expect(vm.state.status, CheckInStatus.checkedOut);

      // Active visit đã được dọn sạch
      final active = await visitRepo.getActiveVisit();
      expect(active, isNull);

      // Lượt viếng thăm trong local repo đã được đánh dấu hoàn thành
      final allLocal = await visitRepo.getAllLocalVisits();
      expect(allLocal.first.isCompleted, isTrue);
      expect(allLocal.first.checkoutAt, isNotNull);

      // Kiểm tra sync queue có entry checkout
      final pending = await db.getPendingQueueEntries();
      expect(pending.length, 2); // 1 checkin + 1 checkout

      final checkoutEntry = pending.firstWhere((e) => e.entity == 'visit' && e.op == 'checkout');
      expect(checkoutEntry.parentUuid, parentClientUuid);
    });

    test('Offline checkin cancellation deletes pending queue entries, photos, and clears active visit', () async {
      final vm = container.read(checkInViewModelProvider.notifier);

      const dealer = DealerEntity(
        id: '101',
        order: '01',
        name: 'Cửa hàng Hoàng Gia',
        address: 'Hà Nội',
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
      );

      vm.initCheckinWithDealer(dealer);
      await vm.performCheckin(customerId: 101);
      final clientUuid = vm.state.visitEntity?.clientUuid;
      expect(clientUuid, isNotNull);
      expect(vm.state.visitId, lessThan(0));

      // Chụp 1 ảnh offline
      final tempPhoto = File('${tempDir.path}/test_cancel_photo.jpg');
      await tempPhoto.writeAsString('sample photo content');
      await vm.uploadPhoto(tempPhoto, photoType: 'display');

      var pending = await db.getPendingQueueEntries();
      expect(pending.length, 2); // 1 checkin + 1 photo

      final photoLocalPath = pending.firstWhere((e) => e.entity == 'visit_photo').localPath;
      expect(photoLocalPath, isNotNull);
      expect(File(photoLocalPath!).existsSync(), isTrue);

      // Người dùng bấm Huỷ check-in
      final (cancelSuccess, cancelError) = await vm.cancelVisit();
      expect(cancelSuccess, isTrue);
      expect(cancelError, isNull);

      // Queue đồng bộ đã được xoá sạch (không để lại entry mồ côi)
      pending = await db.getPendingQueueEntries();
      expect(pending.isEmpty, isTrue);

      // Ảnh offline trên ổ đĩa đã được dọn dẹp
      expect(File(photoLocalPath).existsSync(), isFalse);

      // Active visit đã được dọn sạch
      final active = await visitRepo.getActiveVisit();
      expect(active, isNull);

      // Session đã reset
      expect(vm.state.visitId, 0);
    });

    test('Offline cancellation of a server visit enqueues op cancel in SyncQueueEntries', () async {
      final vm = container.read(checkInViewModelProvider.notifier);

      final existingVisit = VisitEntity(
        id: 99901,
        customerId: 101,
        customerName: 'Cửa hàng Hoàng Gia',
        checkinAtRaw: '2026-10-03 14:00:00+07',
      );

      final dealer = DealerEntity(
        id: '101',
        order: '01',
        name: 'Cửa hàng Hoàng Gia',
        address: 'Hà Nội',
        status: DealerVisitStatus.inProgress,
        statusLabel: 'Đang ghé',
        isVip: false,
        visit: existingVisit,
      );

      vm.initCheckinWithDealer(dealer);
      expect(vm.state.visitId, 99901);

      // Giả lập mạng bị lỗi (failing network adapter) khi bấm huỷ lượt server
      final (cancelSuccess, cancelError) = await vm.cancelVisit();
      expect(cancelSuccess, isTrue);
      expect(cancelError, isNull);

      // Vì offline, hệ thống phải enqueue op 'cancel' vào hàng đợi đồng bộ
      final pending = await db.getPendingQueueEntries();
      expect(pending.length, 1);
      final cancelEntry = pending.first;
      expect(cancelEntry.entity, 'visit');
      expect(cancelEntry.op, 'cancel');

      final payload = jsonDecode(cancelEntry.payload) as Map<String, dynamic>;
      expect(payload['visit_id'], 99901);

      // Active visit cục bộ đã được dọn sạch
      final active = await visitRepo.getActiveVisit();
      expect(active, isNull);
    });
  });

  group('SyncService Offline Visit Sync Flow with Parent-Child Resolution', () {
    late AppDatabase db;
    late FakeDioAdapter dioAdapter;
    late ProviderContainer container;
    late SyncService syncService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      dioAdapter = FakeDioAdapter();

      final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = dioAdapter;
      final apiClient = ApiClient(dio);

      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          apiClientProvider.overrideWithValue(apiClient),
          connectivityProvider.overrideWith((ref) => ConnectivityNotifier()),
        ],
      );

      syncService = container.read(syncServiceProvider);
    });

    tearDown(() async {
      await db.close();
      container.dispose();
    });

    test('Syncs check-in, photo, and checkout sequentially with parent serverId propagation', () async {
      const visitClientUuid = 'visit-offline-uuid-999';
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final bootId = SystemClock.bootId;
      final elapsedMs = SystemClock.nowMonotonicMs;

      // 1. Enqueue Visit Check-in
      await db.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'visit',
          op: 'create',
          clientUuid: visitClientUuid,
          payload: jsonEncode({
            'customer_id': 101,
            'lat': 21.028511,
            'lng': 105.854444,
            'accuracy_m': 10.0,
            'is_mock_location': false,
          }),
          createdAt: nowMs,
          createdElapsed: elapsedMs,
          bootId: bootId,
        ),
      );

      // 2. Tạo file ảnh offline
      final offlinePhotoFile = File('${docsDir.path}/offline_visit_photos/test_p1.jpg');
      await offlinePhotoFile.parent.create(recursive: true);
      await offlinePhotoFile.writeAsString('sample image file binary');

      // Enqueue Visit Photo with parentUuid
      await db.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'visit_photo',
          op: 'upload',
          clientUuid: 'photo-offline-uuid-888',
          parentUuid: Value(visitClientUuid),
          localPath: Value(offlinePhotoFile.path),
          payload: jsonEncode({
            'photo_type': 'display',
            'lat': 21.028511,
            'lng': 105.854444,
          }),
          createdAt: nowMs + 1000,
          createdElapsed: elapsedMs + 1000,
          bootId: bootId,
        ),
      );

      // 3. Enqueue Visit Checkout with parentUuid
      await db.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'visit',
          op: 'checkout',
          clientUuid: 'checkout-offline-uuid-777',
          parentUuid: Value(visitClientUuid),
          payload: jsonEncode({
            'visit_id': -1,
            'lat': 21.028520,
            'lng': 105.854444,
          }),
          createdAt: nowMs + 2000,
          createdElapsed: elapsedMs + 2000,
          bootId: bootId,
        ),
      );

      var pendingCount = await db.countPendingSync();
      expect(pendingCount, 3);

      // Run sync!
      final syncResult = await syncService.syncQueue(force: true);
      expect(syncResult.successCount, 3);

      // Hàng đợi đồng bộ đã xử lý sạch 3 mục
      pendingCount = await db.countPendingSync();
      expect(pendingCount, 0);

      // Verify requests were made in order
      expect(dioAdapter.recordedRequests.length, 3);

      // 1st request: POST /dms/visits
      final r1 = dioAdapter.recordedRequests[0];
      expect(r1['path'], '/dms/visits');
      final r1Data = r1['data'] as Map<String, dynamic>;
      expect(r1Data['client_uuid'], visitClientUuid);
      expect(r1Data['is_offline_sync'], isTrue);
      expect(r1Data.containsKey('queued_seconds'), isTrue);
      expect(r1Data['client_boot_id'], bootId);

      // 2nd request: POST /dms/visits/99901/photos (serverId 99901 resolved from parent!)
      final r2 = dioAdapter.recordedRequests[1];
      expect(r2['path'], '/dms/visits/99901/photos');

      // Ảnh cục bộ đã được xóa sau khi tải lên thành công (§9)
      expect(await offlinePhotoFile.exists(), isFalse);

      // 3rd request: POST /dms/visits/99901/checkout (serverId 99901 resolved from parent!)
      final r3 = dioAdapter.recordedRequests[2];
      expect(r3['path'], '/dms/visits/99901/checkout');
      final r3Data = r3['data'] as Map<String, dynamic>;
      expect(r3Data['is_offline_sync'], isTrue);
      expect(r3Data.containsKey('queued_seconds'), isTrue);
      expect(r3Data['client_boot_id'], bootId);
    });

    test('SyncService handles 422 idempotent error on checkout gracefully', () async {
      dioAdapter.return422OnCheckout = true;
      const visitClientUuid = 'visit-offline-uuid-idempotent';
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final bootId = SystemClock.bootId;
      final elapsedMs = SystemClock.nowMonotonicMs;

      // 1. Visit Checkin
      await db.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'visit',
          op: 'create',
          clientUuid: visitClientUuid,
          payload: jsonEncode({'customer_id': 101}),
          createdAt: nowMs,
          createdElapsed: elapsedMs,
          bootId: bootId,
        ),
      );

      // 2. Checkout
      await db.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'visit',
          op: 'checkout',
          clientUuid: 'checkout-uuid-idempotent',
          parentUuid: Value(visitClientUuid),
          payload: jsonEncode({'visit_id': -1}),
          createdAt: nowMs + 1000,
          createdElapsed: elapsedMs + 1000,
          bootId: bootId,
        ),
      );

      final syncResult = await syncService.syncQueue(force: true);
      expect(syncResult.successCount, 2);

      // Phải hoàn tất cả 2 mà không ném exception / bị kẹt
      final pendingCount = await db.countPendingSync();
      expect(pendingCount, 0);
    });

    test('SyncService processes op cancel and calls /dms/visits/{id}/cancel', () async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final bootId = SystemClock.bootId;
      final elapsedMs = SystemClock.nowMonotonicMs;

      await db.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'visit',
          op: 'cancel',
          clientUuid: 'cancel-visit-uuid-123',
          payload: jsonEncode({'visit_id': 99901}),
          createdAt: nowMs,
          createdElapsed: elapsedMs,
          bootId: bootId,
        ),
      );

      final syncResult = await syncService.syncQueue(force: true);
      expect(syncResult.successCount, 1);

      final pendingCount = await db.countPendingSync();
      expect(pendingCount, 0);

      // Verify POST /dms/visits/99901/cancel was called
      expect(dioAdapter.recordedRequests.any((r) =>
          r['path'] == '/dms/visits/99901/cancel' && r['method'] == 'POST'), isTrue);
    });

    test('SyncService handles 422 idempotent error on cancel gracefully', () async {
      dioAdapter.return422OnCancel = true;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final bootId = SystemClock.bootId;
      final elapsedMs = SystemClock.nowMonotonicMs;

      await db.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'visit',
          op: 'cancel',
          clientUuid: 'cancel-visit-uuid-422',
          payload: jsonEncode({'visit_id': 99901}),
          createdAt: nowMs,
          createdElapsed: elapsedMs,
          bootId: bootId,
        ),
      );

      final syncResult = await syncService.syncQueue(force: true);
      expect(syncResult.successCount, 1);

      final pendingCount = await db.countPendingSync();
      expect(pendingCount, 0);
    });

    test('Offline checkin cancelled locally does NOT sync when network is restored', () async {
      const visitClientUuid = 'cancelled-offline-visit-uuid';
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final bootId = SystemClock.bootId;
      final elapsedMs = SystemClock.nowMonotonicMs;

      // 1. Enqueue Visit Checkin & Photo
      await db.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'visit',
          op: 'create',
          clientUuid: visitClientUuid,
          payload: jsonEncode({'customer_id': 101}),
          createdAt: nowMs,
          createdElapsed: elapsedMs,
          bootId: bootId,
        ),
      );

      await db.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'visit_photo',
          op: 'upload',
          clientUuid: 'photo-offline-uuid',
          parentUuid: const Value(visitClientUuid),
          payload: jsonEncode({'photo_type': 'display'}),
          createdAt: nowMs + 500,
          createdElapsed: elapsedMs + 500,
          bootId: bootId,
        ),
      );

      expect(await db.countPendingSync(), 2);

      // 2. User cancels offline checkin
      await db.deletePendingVisitQueue(visitClientUuid);
      expect(await db.countPendingSync(), 0);

      // 3. Network reconnects and syncQueue runs
      final syncResult = await syncService.syncQueue(force: true);
      expect(syncResult.successCount, 0);
      expect(dioAdapter.recordedRequests.where((r) => r['path'] == '/dms/visits'), isEmpty);
    });

    test('Online check-in then offline cancel: when reconnected, syncs /dms/visits/{id}/cancel to server and dealer is not visited', () async {
      const serverVisitId = 88801;
      const visitClientUuid = 'online-checkin-offline-cancel-uuid';
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final bootId = SystemClock.bootId;
      final elapsedMs = SystemClock.nowMonotonicMs;

      // 1. Lượt đã tạo online trên server có serverId = 88801
      // Khi offline, người dùng huỷ lượt -> enqueue op 'cancel' với visit_id: 88801
      await db.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'visit',
          op: 'cancel',
          clientUuid: 'cancel-uuid-88801',
          parentUuid: const Value(visitClientUuid),
          payload: jsonEncode({'visit_id': serverVisitId}),
          createdAt: nowMs,
          createdElapsed: elapsedMs,
          bootId: bootId,
        ),
      );

      expect(await db.countPendingSync(), 1);

      // 2. Có mạng trở lại: syncQueue chạy và gửi POST /dms/visits/88801/cancel lên server
      final syncResult = await syncService.syncQueue(force: true);
      expect(syncResult.successCount, 1);
      expect(await db.countPendingSync(), 0);

      // Verify request được gửi đến endpoint huỷ lượt của máy chủ
      expect(
        dioAdapter.recordedRequests.any((r) =>
            r['path'] == '/dms/visits/$serverVisitId/cancel' && r['method'] == 'POST'),
        isTrue,
      );
    });
  });
}

