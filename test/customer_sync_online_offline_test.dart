import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/sync/sync_service.dart';
import 'package:vthm_dms/features/customer/data/datasources/customer_local_data_source.dart';
import 'package:vthm_dms/features/customer/data/repositories/customer_repository_impl.dart';
import 'package:vthm_dms/features/customer/data/services/customer_api_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/features/route/data/services/route_api_service.dart';

class MockSyncDioAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;
  dynamic lastData;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    lastOptions = options;
    lastData = options.data;
    if (options.path == '/crm/customers') {
      final res = {
        'success': true,
        'data': {
          'id': 8888,
          'code': '08190163',
          'created': true,
          'route_ids': [5],
        },
        'message': 'Đã tạo điểm bán 08190163.'
      };
      return ResponseBody.fromString(
        jsonEncode(res),
        201,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }
    if (options.path.contains('customers/mine')) {
      final res = {
        'success': true,
        'data': [
          {
            'id': 8888,
            'code': '08190163',
            'name': 'Cửa hàng Test',
            'address': 'Hà Nội',
            'phone': '0988888888',
            'route': 'Tuyến 1',
            'status': 'active',
          }
        ],
      };
      return ResponseBody.fromString(
        jsonEncode(res),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }
    if (options.path == '/dms/routes/mine') {
      final res = {
        'success': true,
        'data': [
          {'id': 1, 'name': 'Tuyến Hà Nội - Đông Anh', 'code': 'ROUTE_01'},
          {'id': 2, 'name': 'Tuyến Sóc Sơn', 'code': 'ROUTE_02'},
        ],
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

  late AppDatabase db;
  late MockSyncDioAdapter adapter;
  late ProviderContainer container;
  late CustomerRepositoryImpl repo;
  late SyncService syncService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    adapter = MockSyncDioAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = adapter;
    final apiClient = ApiClient(dio);

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        apiClientProvider.overrideWithValue(apiClient),
        connectivityProvider.overrideWith((ref) => ConnectivityNotifier()),
      ],
    );

    final localDataSource = CustomerLocalDataSource(db);
    final apiService = CustomerApiService(apiClient);
    syncService = container.read(syncServiceProvider);
    repo = CustomerRepositoryImpl(apiService, localDataSource, syncService, null, () => true);
  });

  tearDown(() async {
    await db.close();
    container.dispose();
  });

  test('createCustomer online calls API directly and does NOT enqueue into sync_queue', () async {
    final inputData = {
      'name': 'Cửa hàng Online Test',
      'region_id': 12,
      'route_ids': [5],
      'phone': '0988888888',
      'address': '123 Đường Láng',
      'customer_type_id': 2,
    };

    final created = await repo.createCustomer(inputData);

    expect(created.id, 8888);
    expect(created.code, '08190163');
    expect(created.syncStatus, 'synced');
    expect(created.name, 'Cửa hàng Online Test');

    // Verify adapter received request and has NO forbidden root keys
    expect(adapter.lastOptions?.path, '/crm/customers');
    final sentData = adapter.lastData as Map<String, dynamic>;
    expect(sentData.containsKey('queued_seconds'), isFalse);
    expect(sentData.containsKey('client_boot_id'), isFalse);
    expect(sentData.containsKey('photo_tokens'), isFalse);
    expect(sentData.containsKey('code'), isFalse);
    expect(sentData.containsKey('status'), isFalse);
    expect(sentData['route_ids'], [5]);

    // Verify sync_queue is EMPTY!
    final pendingCount = await db.countPendingSync();
    expect(pendingCount, 0);

    // Verify SQLite local_customers has synced record
    final localList = await db.getAllLocalCustomers();
    expect(localList.length, 1);
    expect(localList.first.id, 8888);
    expect(localList.first.code, '08190163');
    expect(localList.first.syncStatus, 'synced');
  });

  test('offline syncQueue pushes pending customer with clean payload and marks synced', () async {
    final localDataSource = CustomerLocalDataSource(db);

    // Simulate an offline created customer in SQLite
    final inputData = {
      'name': 'Cửa hàng Ngoại Tuyến',
      'region_id': 4,
      'route_ids': [54],
      'route': 'Tuyến thứ 2 - thứ 6',
      'phone': '0911223344',
      'photo_tokens': ['9a8e3cf14b7ad4f6d13d4988ae2f484c'],
    };

    final offlineEntity = await localDataSource.createCustomerOffline(inputData);
    expect(offlineEntity.code.startsWith('PENDING_'), isTrue);
    expect(offlineEntity.syncStatus, 'pending');

    final countBefore = await db.countPendingSync();
    expect(countBefore, 1);

    // Force sync queue
    await syncService.syncQueue(force: true);

    expect(adapter.lastOptions?.path, '/crm/customers');
    final sentData = adapter.lastData as Map<String, dynamic>;
    expect(sentData.containsKey('queued_seconds'), isFalse);
    expect(sentData.containsKey('client_boot_id'), isFalse);
    // Theo spec 30/09 §2 & §6: photo_tokens và photo_token đều nằm trong 25 khoá gốc được nhận
    expect(sentData['photo_tokens'], ['9a8e3cf14b7ad4f6d13d4988ae2f484c']);
    expect(sentData['photo_token'], '9a8e3cf14b7ad4f6d13d4988ae2f484c');
    expect(sentData['is_offline_sync'], isTrue);

    final countAfter = await db.countPendingSync();
    expect(countAfter, 0);

    final localList = await db.getAllLocalCustomers();
    expect(localList.first.id, 8888);
    expect(localList.first.code, '08190163');
    expect(localList.first.syncStatus, 'synced');
  });

  test('getCustomers offline seamlessly returns cached SQLite data without errors', () async {
    final localDataSource = CustomerLocalDataSource(db);
    final apiService = CustomerApiService(ApiClient(Dio()));

    // 1. First, populate SQLite with 1 cached customer (as if synced earlier)
    await repo.getCustomers(forceRefresh: true);
    final countBefore = (await db.getAllLocalCustomers()).length;
    expect(countBefore, 1);

    // 2. Create an offline repository instance (_isOnlineChecker returns false)
    final offlineRepo = CustomerRepositoryImpl(
      apiService,
      localDataSource,
      syncService,
      null,
      () => false,
    );

    // 3. getCustomers() offline must return the cached customers without throwing
    final offlineCustomers = await offlineRepo.getCustomers();
    expect(offlineCustomers.isNotEmpty, isTrue);
    expect(offlineCustomers.first.name, 'Cửa hàng Test');
    expect(offlineCustomers.first.route, 'Tuyến 1');
  });

  test('RouteApiService caches getMyRoutes into SharedPreferences and returns them offline', () async {
    SharedPreferences.setMockInitialValues({});
    final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = adapter;
    final apiClient = ApiClient(dio);
    final routeApiService = RouteApiService(apiClient);

    // 1. Online: fetch from server
    final routes = await routeApiService.getMyRoutes(forceRefresh: true);
    expect(routes.length, 2);
    expect(routes.first.name, 'Tuyến Hà Nội - Đông Anh');
    expect(routes.last.name, 'Tuyến Sóc Sơn');

    // 2. Offline simulation: RouteApiService with a failing Dio client
    final failingDio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))
      ..httpClientAdapter = MockFailingDioAdapter();
    final offlineRouteApiService = RouteApiService(ApiClient(failingDio));

    // Must return the cached routes from SharedPreferences!
    final cachedRoutes = await offlineRouteApiService.getMyRoutes();
    expect(cachedRoutes.length, 2);
    expect(cachedRoutes.first.name, 'Tuyến Hà Nội - Đông Anh');
    expect(cachedRoutes.last.name, 'Tuyến Sóc Sơn');
  });
}

class MockFailingDioAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      error: 'No internet connection',
    );
  }

  @override
  void close({bool force = false}) {}
}
