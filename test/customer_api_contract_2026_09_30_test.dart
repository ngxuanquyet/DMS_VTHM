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
import 'package:vthm_dms/features/customer/data/utils/customer_payload_helper.dart';

class MockContractDioAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;
  dynamic lastData;
  Map<String, dynamic>? mockResponse;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    lastOptions = options;
    lastData = options.data;

    if (options.path.contains('customers/mine')) {
      final res = {
        'success': true,
        'data': [
          {
            'id': 77540,
            'code': '08650173',
            'name': 'Tạp hoá Nghi Lộc',
            'address': 'Số 1, Nghi Lộc',
            'phone': '0912345678',
            'route': 'Tuyến thứ 2',
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

    final res = mockResponse ?? {
      'success': true,
      'message': 'Đã tạo điểm bán 08650173.',
      'data': {
        'id': 77540,
        'code': '08650173',
        'created': true,
        'route_ids': [6776, 6775],
      }
    };

    return ResponseBody.fromString(
      jsonEncode(res),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Hợp đồng hiện hành POST /crm/customers (30/09/2026)', () {
    test('§2 & §3: CustomerPayloadHelper chỉ sinh khoá trong danh sách trắng 25 keys, mw_* nằm trong data', () {
      final inputData = {
        'name': 'Tạp hoá Nghi Lộc',
        'region_id': 1,
        'phone': '0912345678',
        'address': 'Số 1, Nghi Lộc',
        'lat': '18.82',
        'lng': '105.55',
        'route_ids': [6776, 6775],
        'photo_tokens': ['ae2a1a671c3a92f23d87999741bc8986', 'bdc81d77c795e121c5dab974a7f0bf75'],
        'client_uuid': '0f2c-uuid-test',
        'is_offline_sync': true,
        // Dynamic fields MobiWork
        'mw_huyen': 'Nghi Lộc',
        'mw_khach_hang_vthm': 'KH-TEST',
        'mw_nhan_1': 'Nhãn VIP',
        // Các trường cấm TUYỆT ĐỐI không được lọt vào payload
        'client_boot_id': 'boot-should-be-removed',
        'queued_seconds': 120,
        'client_time': '2026-09-30T10:00:00+07:00',
        'code': '08650173',
        'id': 77540,
        'approval_status': 'pending',
        'custom_labels': {'dummy': 'val'},
        'customer_type_name': 'Đại lý',
        'channel_name': 'GT',
        'route': 'Tuyến thứ 2',
        'contact_person': 'Bác Minh',
      };

      final payload = CustomerPayloadHelper.buildCustomerApiPayload(
        sourceData: inputData,
        clientUuid: '0f2c-uuid-test',
        isOfflineSync: true,
      );

      // 1. Kiểm tra 100% khoá ở gốc body phải nằm trong kAllowedCustomerRootKeys
      for (final key in payload.keys) {
        expect(
          kAllowedCustomerRootKeys.contains(key),
          isTrue,
          reason: 'Khoá "$key" ở gốc body vi phạm danh sách trắng 25 keys của §2',
        );
      }

      // 2. Không chứa bất kỳ trường cấm nào
      for (final forbidden in kForbiddenCustomerKeys) {
        expect(
          payload.containsKey(forbidden),
          isFalse,
          reason: 'Khoá cấm "$forbidden" bị lọt vào gốc payload',
        );
      }

      // 3. Không có bất kỳ trường mw_* nào ở gốc body
      for (final key in payload.keys) {
        expect(
          key.startsWith('mw_'),
          isFalse,
          reason: 'Trường dynamic "$key" nằm ở gốc body sẽ bị server 422',
        );
      }

      // 4. Các trường mw_* phải nằm an toàn bên trong payload['data']
      expect(payload['data'], isA<Map<String, dynamic>>());
      final dataMap = payload['data'] as Map<String, dynamic>;
      expect(dataMap['mw_huyen'], 'Nghi Lộc');
      expect(dataMap['mw_khach_hang_vthm'], 'KH-TEST');
      expect(dataMap['mw_nhan_1'], 'Nhãn VIP');

      // Trong dataMap cũng tuyệt đối không chứa khoá cấm
      for (final forbidden in kForbiddenCustomerKeys) {
        expect(
          dataMap.containsKey(forbidden),
          isFalse,
          reason: 'Khoá cấm "$forbidden" bị lọt vào map data',
        );
      }

      // 5. Kiểm tra đúng định dạng theo curl §6
      expect(payload['name'], 'Tạp hoá Nghi Lộc');
      expect(payload['region_id'], 1);
      expect(payload['phone'], '0912345678');
      expect(payload['address'], 'Số 1, Nghi Lộc');
      expect(payload['lat'], 18.82);
      expect(payload['lng'], 105.55);
      expect(payload['route_ids'], [6776, 6775]);
      expect(payload['photo_tokens'], ['ae2a1a671c3a92f23d87999741bc8986', 'bdc81d77c795e121c5dab974a7f0bf75']);
      expect(payload['photo_token'], 'ae2a1a671c3a92f23d87999741bc8986');
      expect(payload['client_uuid'], '0f2c-uuid-test');
      expect(payload['is_offline_sync'], isTrue);
    });

    test('§2 & §6: GPS lat/lng phải đi thành cặp (nếu thiếu 1 thì không gửi cả 2)', () {
      final payloadOnlyLat = CustomerPayloadHelper.buildCustomerApiPayload(
        sourceData: {
          'name': 'Điểm test',
          'region_id': 1,
          'lat': 18.82,
        },
      );
      expect(payloadOnlyLat.containsKey('lat'), isFalse);
      expect(payloadOnlyLat.containsKey('lng'), isFalse);

      final payloadBoth = CustomerPayloadHelper.buildCustomerApiPayload(
        sourceData: {
          'name': 'Điểm test',
          'region_id': 1,
          'lat': 18.82,
          'lng': 105.55,
        },
      );
      expect(payloadBoth['lat'], 18.82);
      expect(payloadBoth['lng'], 105.55);
    });

    test('§7: Idempotency - server trả về 200 kèm created: false được coi là THÀNH CÔNG và xoá hàng đợi', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final adapter = MockContractDioAdapter();
      // Giả lập server trả về created: false do trùng client_uuid
      adapter.mockResponse = {
        'success': true,
        'message': 'Điểm bán đã tồn tại trên hệ thống.',
        'data': {
          'id': 77540,
          'code': '08650173',
          'created': false,
          'route_ids': [6776, 6775],
        },
      };

      final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = adapter;
      final apiClient = ApiClient(dio);
      final localDataSource = CustomerLocalDataSource(db);
      final apiService = CustomerApiService(apiClient);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          apiClientProvider.overrideWithValue(apiClient),
          connectivityProvider.overrideWith((ref) => ConnectivityNotifier()),
          customerRepositoryProvider.overrideWith((ref) => CustomerRepositoryImpl(
            apiService,
            localDataSource,
            ref.read(syncServiceProvider),
            null,
            () => true,
          )),
        ],
      );

      final syncService = container.read(syncServiceProvider);

      // Tạo khách hàng offline có trường mw_*
      final offlineEntity = await localDataSource.createCustomerOffline({
        'name': 'Tạp hoá Nghi Lộc',
        'region_id': 1,
        'route_ids': [6776, 6775],
        'route': 'Tuyến thứ 2',
        'phone': '0912345678',
        'mw_huyen': 'Nghi Lộc',
        'mw_khach_hang_vthm': 'KH-TEST',
        'photo_tokens': ['ae2a1a671c3a92f23d87999741bc8986'],
      });

      expect(offlineEntity.syncStatus, 'pending');

      final countBefore = await db.countPendingSync();
      expect(countBefore, 1);

      final beforeSyncList = await db.getAllLocalCustomers();
      expect(beforeSyncList.length, 1);

      // Chạy đồng bộ
      await syncService.syncQueue(force: true);

      // Xác nhận hàng đợi đã được dọn sạch (0 pending)
      final countAfter = await db.countPendingSync();
      expect(countAfter, 0);

      // Xác nhận SQLite đã được cập nhật sang synced với mã do server cấp
      final localList = await db.getAllLocalCustomers();
      expect(localList.first.syncStatus, 'synced');
      expect(localList.first.id, 77540);
      expect(localList.first.code, '08650173');

      // Xác nhận payload gửi lên đúng chuẩn §6
      final sentData = adapter.lastData as Map<String, dynamic>;
      expect(sentData['name'], 'Tạp hoá Nghi Lộc');
      expect(sentData['region_id'], 1);
      expect(sentData['route_ids'], [6776, 6775]);
      expect(sentData['data'], isA<Map<String, dynamic>>());
      expect((sentData['data'] as Map)['mw_huyen'], 'Nghi Lộc');
      expect((sentData['data'] as Map)['mw_khach_hang_vthm'], 'KH-TEST');
      expect(sentData.containsKey('client_boot_id'), isFalse);
      expect(sentData.containsKey('queued_seconds'), isFalse);

      await db.close();
      container.dispose();
    });
  });
}
