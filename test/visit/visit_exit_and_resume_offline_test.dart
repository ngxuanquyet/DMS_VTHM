import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
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
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';
import 'package:vthm_dms/features/visit/data/repositories/visit_repository_impl.dart';
import 'package:vthm_dms/features/visit/data/services/visit_api_service.dart';
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

class FakeDioAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> recordedRequests = [];
  bool failNetwork = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    if (failNetwork) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'No internet connection',
      );
    }

    recordedRequests.add({
      'method': options.method,
      'path': options.path,
      'data': options.data,
    });

    if (options.path == '/dms/visits' && options.method == 'POST') {
      final res = {
        'success': true,
        'data': {
          'id': 88801,
          'customer_id': 101,
          'checkin_at': '2026-10-12 09:00:00+07',
          'visit_date': '2026-10-12',
        },
        'message': 'Check-in thành công',
      };
      return ResponseBody.fromString(
        jsonEncode(res),
        201,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    if (options.path.startsWith('/dms/visits/') && options.path.endsWith('/checkout') && options.method == 'POST') {
      final res = {
        'success': true,
        'data': {
          'id': 88801,
          'checkout_at': '2026-10-12 09:15:00+07',
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
      final res = {
        'success': true,
        'data': {
          'id': 88801,
          'cancelled_at': '2026-10-12 09:10:00+07',
        },
        'message': 'Huỷ lượt viếng thăm thành công',
      };
      return ResponseBody.fromString(
        jsonEncode(res),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': {}}),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
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

class FakeConnectivityNotifier extends ConnectivityNotifier {
  bool _mockOnline;

  FakeConnectivityNotifier([this._mockOnline = true]) {
    state = ConnectivityState(isOnline: _mockOnline);
  }

  void setOnline(bool online) {
    _mockOnline = online;
    state = state.copyWith(isOnline: online);
  }

  @override
  Future<bool> checkConnectivity() async {
    state = state.copyWith(isOnline: _mockOnline);
    return _mockOnline;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory appDocsDir;
  late AppDatabase db;
  late FakeDioAdapter fakeDioAdapter;
  late FakeConnectivityNotifier fakeConnectivity;
  late Dio dio;
  late ApiClient apiClient;
  late VisitApiService visitApiService;
  late VisitRepository visitRepository;
  late ProviderContainer container;

  final testDealer = DealerEntity(
    id: '101',
    order: '01',
    name: 'Đại lý Kim Cương',
    address: '123 Đường ABC',
    status: DealerVisitStatus.pending,
    statusLabel: 'Chưa ghé',
    isVip: false,
    lat: 10.7769,
    lng: 106.7009,
    geofenceRadiusM: 100,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('vthm_test_temp_');
    appDocsDir = await Directory.systemTemp.createTemp('vthm_test_docs_');
    PathProviderPlatform.instance = MockPathProviderPlatform(
      tempDir: tempDir,
      appDocsDir: appDocsDir,
    );

    db = AppDatabase(NativeDatabase.memory(), 1);
    fakeDioAdapter = FakeDioAdapter();
    fakeConnectivity = FakeConnectivityNotifier(true);
    dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))
      ..httpClientAdapter = fakeDioAdapter;
    apiClient = ApiClient(dio);
    visitApiService = VisitApiService(apiClient);
    visitRepository = VisitRepositoryImpl(visitApiService);

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        apiClientProvider.overrideWithValue(apiClient),
        connectivityProvider.overrideWith((ref) => fakeConnectivity),
        visitRepositoryProvider.overrideWithValue(visitRepository),
        mobileRulesProvider.overrideWith((ref) => FakeRulesNotifier(
              apiClient,
              const MobileRules(visit: VisitRules(requireGeofence: false, minDurationMinutes: 0)),
            )),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    if (appDocsDir.existsSync()) appDocsDir.deleteSync(recursive: true);
  });

  group('Màn hình Viếng Thăm: Tạm rời và Vào lại lượt (Online & Offline)', () {
    test('1. Check-in Online -> Tạm rời: Giữ nguyên lượt đang mở, không bị hủy hoặc hoàn tất', () async {
      final checkInVm = container.read(checkInViewModelProvider.notifier);

      checkInVm.initCheckinWithDealer(testDealer);
      final error = await checkInVm.performCheckin(
        customerId: 101,
        lat: 10.7769,
        lng: 106.7009,
      );

      expect(error, isNull);
      expect(container.read(checkInViewModelProvider).visitId, equals(88801));
      expect(container.read(checkInViewModelProvider).visitEntity?.isOpen, isTrue);

      // RouteViewModel cũng ghi nhận active visit
      final activeVisit = container.read(routeViewModelProvider).activeVisit;
      expect(activeVisit, isNotNull);
      expect(activeVisit?.id, equals(88801));

      // Giả lập người dùng tạm rời khỏi màn hình (vẫn lưu session, không hủy)
      checkInVm.saveCurrentActiveSession();
      checkInVm.setVisitNote('Ghi chú tạm lưu');

      // Kiểm tra storage vẫn lưu active visit
      final savedVisit = await visitRepository.getActiveVisit();
      expect(savedVisit, isNotNull);
      expect(savedVisit?.isOpen, isTrue);
      expect(savedVisit?.id, equals(88801));
    });

    test('2. Tạm rời -> Vào lại lượt: Khôi phục đúng phiên dở dang, KHÔNG tạo lượt mới', () async {
      final checkInVm = container.read(checkInViewModelProvider.notifier);

      // Check-in lần đầu
      checkInVm.initCheckinWithDealer(testDealer);
      final error = await checkInVm.performCheckin(
        customerId: 101,
        lat: 10.7769,
        lng: 106.7009,
      );
      expect(error, isNull);
      checkInVm.setVisitNote('Ghi chú phiên trước');
      final firstVisitId = container.read(checkInViewModelProvider).visitId;
      expect(firstVisitId, equals(88801));

      final requestsBefore = fakeDioAdapter.recordedRequests.length;

      // Nhân viên vào lại lượt viếng thăm từ danh sách tuyến
      checkInVm.initCheckinWithDealer(testDealer.copyWith(
        status: DealerVisitStatus.inProgress,
        visit: container.read(checkInViewModelProvider).visitEntity,
      ));

      // Đảm bảo không gửi thêm request check-in nào lên server
      expect(fakeDioAdapter.recordedRequests.length, equals(requestsBefore));

      // Trạng thái giữ nguyên phiên cũ
      expect(container.read(checkInViewModelProvider).visitId, equals(firstVisitId));
      expect(container.read(checkInViewModelProvider).visitNote, equals('Ghi chú phiên trước'));
      expect(container.read(checkInViewModelProvider).visitEntity?.isOpen, isTrue);
    });

    test('3. Check-in Offline -> Tạm rời: Phiên offline được bảo lưu nguyên vẹn trong SQLite và RAM', () async {
      fakeDioAdapter.failNetwork = true;
      final checkInVm = container.read(checkInViewModelProvider.notifier);

      checkInVm.initCheckinWithDealer(testDealer);
      final error = await checkInVm.performCheckin(
        customerId: 101,
        lat: 10.7769,
        lng: 106.7009,
      );

      expect(error, isNull);
      final offlineVisitId = container.read(checkInViewModelProvider).visitId;
      expect(offlineVisitId, lessThan(0));

      // Kiểm tra active visit trên routeViewModelProvider
      final activeVisit = container.read(routeViewModelProvider).activeVisit;
      expect(activeVisit, isNotNull);
      expect(activeVisit?.id, equals(offlineVisitId));

      // Tạm rời và lưu ghi chú
      checkInVm.setVisitNote('Ghi chú khảo sát offline');
      checkInVm.saveCurrentActiveSession();

      // Kiểm tra SQLite SyncQueueEntries chứa bản ghi create_visit
      final queueEntries = await db.select(db.syncQueueEntries).get();
      expect(queueEntries.any((e) => e.entity == 'visit' && e.op == 'create'), isTrue);

      // Kiểm tra ActiveVisit trong DB/SharedPreferences
      final localActive = await visitRepository.getActiveVisit();
      expect(localActive, isNotNull);
      expect(localActive?.id, equals(offlineVisitId));
      expect(localActive?.isOpen, isTrue);
    });

    test('4. Check-in Offline -> Có mạng lại -> SyncService đồng bộ và nâng cấp serverId -> Checkout online', () async {
      fakeDioAdapter.failNetwork = true;
      fakeConnectivity.setOnline(false);
      final checkInVm = container.read(checkInViewModelProvider.notifier);
      final syncService = container.read(syncServiceProvider);

      // Check-in offline
      checkInVm.initCheckinWithDealer(testDealer);
      final err = await checkInVm.performCheckin(
        customerId: 101,
        lat: 10.7769,
        lng: 106.7009,
      );
      expect(err, isNull);
      final offlineVisitId = container.read(checkInViewModelProvider).visitId;
      expect(offlineVisitId, lessThan(0));

      // Bật mạng lại
      fakeDioAdapter.failNetwork = false;
      fakeConnectivity.setOnline(true);

      // Đồng bộ hàng đợi
      final syncResult = await syncService.syncQueue(force: true);
      expect(syncResult.successCount, greaterThan(0));

      // Sau khi đồng bộ, visitId trên in-memory CheckInViewModel và RouteViewModel được nâng cấp lên serverId (88801)
      expect(container.read(checkInViewModelProvider).visitId, equals(88801));
      expect(container.read(routeViewModelProvider).activeVisit?.id, equals(88801));

      // Thực hiện checkout
      final (checkoutSuccess, checkoutErr) = await checkInVm.checkout(
        lat: 10.7769,
        lng: 106.7009,
      );

      expect(checkoutSuccess, isTrue);
      expect(checkoutErr, isNull);
      expect(container.read(checkInViewModelProvider).visitEntity?.isOpen, isFalse);
      expect(container.read(routeViewModelProvider).activeVisit, isNull);

      // Xác nhận request checkout đã được gửi lên server
      final checkoutRequest = fakeDioAdapter.recordedRequests.firstWhere(
        (r) => r['path'] == '/dms/visits/88801/checkout',
      );
      expect(checkoutRequest, isNotNull);
    });

    test('5. Check-in Offline -> Có mạng lại nhưng chưa kịp đồng bộ -> Bấm Checkout: Tự động sync queue lấy serverId rồi checkout trực tiếp', () async {
      fakeDioAdapter.failNetwork = true;
      fakeConnectivity.setOnline(false);
      final checkInVm = container.read(checkInViewModelProvider.notifier);

      // Check-in offline
      checkInVm.initCheckinWithDealer(testDealer);
      final err = await checkInVm.performCheckin(
        customerId: 101,
        lat: 10.7769,
        lng: 106.7009,
      );
      expect(err, isNull);
      expect(container.read(checkInViewModelProvider).visitId, lessThan(0));

      // Bật mạng lại (nhưng không gọi syncQueue thủ công)
      fakeDioAdapter.failNetwork = false;
      fakeConnectivity.setOnline(true);

      // Bấm Checkout trực tiếp
      final (checkoutSuccess, checkoutErr) = await checkInVm.checkout(
        lat: 10.7769,
        lng: 106.7009,
      );

      expect(checkoutSuccess, isTrue);
      expect(checkoutErr, isNull);
      expect(container.read(checkInViewModelProvider).visitEntity?.isOpen, isFalse);

      // Kiểm tra request checkout online với serverId 88801 đã diễn ra
      final checkoutRequest = fakeDioAdapter.recordedRequests.firstWhere(
        (r) => r['path'] == '/dms/visits/88801/checkout',
        orElse: () => {},
      );
      expect(checkoutRequest.isNotEmpty, isTrue);
    });
  });
}
