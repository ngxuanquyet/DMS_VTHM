import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/sync/sync_service.dart';
import 'package:vthm_dms/features/customer/data/datasources/customer_local_data_source.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';

class MockPhotoSyncDioAdapter implements HttpClientAdapter {
  final List<String> pathsHit = [];
  Map<String, dynamic>? lastCustomerPayload;
  bool failPhotoUpload = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    pathsHit.add(options.path);

    if (options.path == '/crm/customer-photos') {
      if (failPhotoUpload) {
        return ResponseBody.fromString(
          jsonEncode({'message': 'Network error uploading photo'}),
          500,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      }
      final res = {
        'success': true,
        'data': {
          'token': 'a1b2c3d4e5f60718293a4b5c6d7e8f90',
          'url': 'https://api-app.vthmgroup.vn/crm/customer-photos/public/a1b2c3d4e5f60718293a4b5c6d7e8f90',
        },
      };
      return ResponseBody.fromString(
        jsonEncode(res),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    if (options.path == '/crm/customers') {
      lastCustomerPayload = options.data is Map<String, dynamic>
          ? options.data as Map<String, dynamic>
          : (options.data is String ? jsonDecode(options.data as String) : null);

      final res = {
        'success': true,
        'data': {
          'id': 9999,
          'code': 'KH_TEST_9999',
          'created': true,
          'route_ids': [1],
        },
        'message': 'Đã tạo điểm bán thành công.'
      };
      return ResponseBody.fromString(
        jsonEncode(res),
        201,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': []}),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MockPhotoSyncDioAdapter adapter;
  late ProviderContainer container;
  late CustomerLocalDataSource localDataSource;
  late SyncService syncService;
  late Directory tempDir;
  late File tempPhotoFile;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    adapter = MockPhotoSyncDioAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = adapter;
    final apiClient = ApiClient(dio);

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        apiClientProvider.overrideWithValue(apiClient),
        connectivityProvider.overrideWith((ref) => ConnectivityNotifier()),
      ],
    );

    localDataSource = CustomerLocalDataSource(db);
    syncService = container.read(syncServiceProvider);

    tempDir = Directory.systemTemp.createTempSync('offline_photo_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );
    tempPhotoFile = File('${tempDir.path}/test_customer_photo.jpg');
    tempPhotoFile.writeAsBytesSync([1, 2, 3, 4, 5, 6, 7, 8]);
  });

  tearDown(() async {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
    await db.close();
    container.dispose();
  });

  test('createCustomerOffline preserves photo paths in entity, SQLite and sync queue', () async {
    final inputData = {
      'name': 'Đại lý Bia Ngoại Tuyến',
      'region_id': 10,
      'route_ids': [1],
      'phone': '0912345678',
      'address': 'Số 1 Đường Hoa Ban',
      'photo_tokens': [tempPhotoFile.path],
    };

    final createdEntity = await localDataSource.createCustomerOffline(inputData);

    // 1. Entity returned has photoUrl & photoUrls
    expect(createdEntity.photoUrl, isNotNull);
    expect(createdEntity.photoUrls.isNotEmpty, isTrue);
    expect(CustomerEntity.isLocalFilePath(createdEntity.photoUrl!), isTrue);

    // 2. LocalCustomers in SQLite has dynamicFieldsJson with photo
    final localCustomers = await db.getAllLocalCustomers();
    expect(localCustomers.length, 1);
    final row = localCustomers.first;
    expect(row.syncStatus, 'pending');

    final dyn = jsonDecode(row.dynamicFieldsJson) as Map<String, dynamic>;
    expect(dyn['photo_tokens'], isNotNull);
    expect((dyn['photo_tokens'] as List).isNotEmpty, isTrue);
    expect(dyn['photo_url'], isNotNull);

    // 3. Sync queue entry has local photo paths in payload
    final queueEntries = await db.getPendingQueueEntries(limit: 10, force: true);
    expect(queueEntries.length, 1);
    final queuePayload = jsonDecode(queueEntries.first.payload) as Map<String, dynamic>;
    expect(queuePayload['photo_tokens'], isNotNull);
    expect((queuePayload['photo_tokens'] as List).isNotEmpty, isTrue);
  });

  test('SyncService uploads offline customer photo to /crm/customer-photos, receives token, and syncs to /crm/customers', () async {
    final inputData = {
      'name': 'Tạp hóa Bình Minh Offline',
      'region_id': 5,
      'route_ids': [1],
      'address': '456 Phố Huế',
      'photo': tempPhotoFile.path,
    };

    final createdEntity = await localDataSource.createCustomerOffline(inputData);
    expect(createdEntity.syncStatus, 'pending');

    // Tiến hành đồng bộ qua SyncService
    final result = await syncService.syncQueue(force: true);

    expect(result.successCount, 1);
    expect(result.deadErrors, isEmpty);

    // Kiểm tra /crm/customer-photos được gọi upload ảnh
    expect(adapter.pathsHit.contains('/crm/customer-photos'), isTrue);

    // Kiểm tra /crm/customers được gọi với photo_tokens là token 32-hex
    expect(adapter.pathsHit.contains('/crm/customers'), isTrue);
    final payload = adapter.lastCustomerPayload;
    expect(payload, isNotNull);
    expect(payload!['photo_tokens'], ['a1b2c3d4e5f60718293a4b5c6d7e8f90']);
    expect(payload['photo_token'], 'a1b2c3d4e5f60718293a4b5c6d7e8f90');
    expect(payload['name'], 'Tạp hóa Bình Minh Offline');
    expect(payload['client_uuid'], createdEntity.clientUuid);

    // Kiểm tra tuyệt đối KHÔNG có local_photo_paths ở root hay trong 'data'
    expect(payload.containsKey('local_photo_paths'), isFalse);
    if (payload.containsKey('data') && payload['data'] is Map) {
      final dataMap = payload['data'] as Map<String, dynamic>;
      expect(dataMap.containsKey('local_photo_paths'), isFalse);
    }

    // Kiểm tra SQLite đã cập nhật sang 'synced' và dynamicFieldsJson có token 32-hex
    final localCustomers = await db.getAllLocalCustomers();
    expect(localCustomers.first.syncStatus, 'synced');
    expect(localCustomers.first.id, 9999);
    expect(localCustomers.first.code, 'KH_TEST_9999');

    final dyn = jsonDecode(localCustomers.first.dynamicFieldsJson) as Map<String, dynamic>;
    expect(dyn['photo_tokens'], ['a1b2c3d4e5f60718293a4b5c6d7e8f90']);
  });

  test('SyncService does NOT send customer payload with missing photos if photo upload fails with 500', () async {
    adapter.failPhotoUpload = true;

    final inputData = {
      'name': 'Cửa hàng Lỗi Mạng Ảnh',
      'region_id': 5,
      'route_ids': [1],
      'address': '789 Giải Phóng',
      'photo': tempPhotoFile.path,
    };

    await localDataSource.createCustomerOffline(inputData);

    // Tiến hành đồng bộ - photo upload sẽ fail 500
    final result = await syncService.syncQueue(force: true);

    // Phải là retryable, KHÔNG được là dead error và KHÔNG được gọi /crm/customers khi thiếu ảnh
    expect(result.retryableCount, 1);
    expect(result.deadErrors, isEmpty);
    expect(adapter.pathsHit.contains('/crm/customer-photos'), isTrue);
    expect(adapter.pathsHit.contains('/crm/customers'), isFalse);

    // Hàng đợi vẫn còn mục chờ đồng bộ (không bị mất)
    final pendingCount = await db.countPendingSync();
    expect(pendingCount, 1);
  });
}
