import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/sync/sync_service.dart';

class ConfigurableDioAdapter implements HttpClientAdapter {
  int statusCode = 200;
  String responseBody = '{"success":true}';
  bool throwNetworkError = false;
  int callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    if (throwNetworkError) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'Không thể kết nối đến máy chủ',
      );
    }

    if (statusCode >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: statusCode,
          data: jsonDecode(responseBody),
        ),
        type: DioExceptionType.badResponse,
      );
    }

    return ResponseBody.fromString(
      responseBody,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late ConfigurableDioAdapter adapter;
  late ProviderContainer container;
  late SyncService syncService;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    adapter = ConfigurableDioAdapter();

    final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = adapter;
    final apiClient = ApiClient(dio);

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        apiClientProvider.overrideWithValue(apiClient),
        connectivityProvider.overrideWith((ref) => ConnectivityNotifier()),
      ],
    );

    syncService = container.read(syncServiceProvider);
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  group('Database Queue 4xx (Dead) vs 5xx/Pending Tests', () {
    test('Dead items are NEVER returned by getPendingQueueEntries even with force=true', () async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final deadId = await database.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'customer',
          op: 'create',
          clientUuid: 'uuid-dead-test',
          payload: '{"name": "Dead Customer"}',
          createdAt: nowMs,
          createdElapsed: nowMs,
          bootId: 'test_boot',
        ),
      );

      await database.markDead(deadId, 'Lỗi 422: Cột không hợp lệ');

      // Normal getPendingQueueEntries should be empty
      final normalPending = await database.getPendingQueueEntries(limit: 10, force: false);
      expect(normalPending.isEmpty, isTrue);

      // force=true MUST NOT return dead entries!
      final forcePending = await database.getPendingQueueEntries(limit: 10, force: true);
      expect(forcePending.isEmpty, isTrue);

      // Verify dead count and retrieval
      final deadCount = await database.countDeadSync();
      expect(deadCount, 1);

      final deadEntries = await database.getDeadQueueEntries();
      expect(deadEntries.length, 1);
      expect(deadEntries.first.state, 'dead');
      expect(deadEntries.first.lastError, 'Lỗi 422: Cột không hợp lệ');
    });

    test('recoverOrphanedSendingEntries NEVER recovers dead items back to pending', () async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final deadId = await database.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'customer',
          op: 'create',
          clientUuid: 'uuid-dead-recovery',
          payload: '{}',
          createdAt: nowMs,
          createdElapsed: nowMs,
          bootId: 'test_boot',
        ),
      );

      await database.markDead(deadId, 'Lỗi 403: Không có quyền');

      // Call recover with resetPendingBackoff = true
      final recovered = await database.recoverOrphanedSendingEntries(resetPendingBackoff: true);
      expect(recovered, 0); // Did not touch dead item

      final deadEntries = await database.getDeadQueueEntries();
      expect(deadEntries.length, 1);
      expect(deadEntries.first.state, 'dead');

      final pending = await database.getPendingQueueEntries(force: true);
      expect(pending.isEmpty, isTrue);
    });

    test('markCustomerSyncError sets syncStatus to error and approvalStatus to rejected', () async {
      const clientUuid = 'customer-err-uuid';
      await database.insertOrUpdateCustomer(
        const LocalCustomersCompanion(
          clientUuid: Value(clientUuid),
          name: Value('Điểm bán lỗi 4xx'),
          nameUnaccent: Value('diem ban loi 4xx'),
          phone: Value('0909000111'),
          address: Value('Hà Nội'),
          contactPerson: Value('Người liên hệ'),
          syncStatus: Value('pending'),
          approvalStatus: Value('pending'),
        ),
      );

      await database.markCustomerSyncError(clientUuid, 'Lỗi 422');

      final customers = await database.getAllLocalCustomers();
      expect(customers.length, 1);
      expect(customers.first.clientUuid, clientUuid);
      expect(customers.first.syncStatus, 'error');
      expect(customers.first.approvalStatus, 'rejected');
    });
  });

  group('SyncService 4xx (Dead / Permanent) vs 500 (Retry) Classification Tests', () {
    test('422 / 4xx error is classified as permanent dead -> NO RETRY, customer marked error', () async {
      const clientUuid = 'uuid-422-test';
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // Seed local customer
      await database.insertOrUpdateCustomer(
        const LocalCustomersCompanion(
          clientUuid: Value(clientUuid),
          name: Value('Điểm bán 422'),
          nameUnaccent: Value('diem ban 422'),
          phone: Value('0909000222'),
          address: Value('Hà Nội'),
          contactPerson: Value('Chủ quán'),
          syncStatus: Value('pending'),
        ),
      );

      // Enqueue sync task
      await database.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'customer',
          op: 'create',
          clientUuid: clientUuid,
          payload: '{"name": "Điểm bán 422", "route_ids": [5]}',
          createdAt: nowMs,
          createdElapsed: nowMs,
          bootId: 'test_boot',
        ),
      );

      // Configure adapter to return 422 Unprocessable Entity
      adapter.statusCode = 422;
      adapter.responseBody = jsonEncode({
        'status': false,
        'message': 'Biểu mẫu điểm bán không có trường nào tên queued_seconds.',
      });

      // Trigger sync
      final result = await syncService.syncQueue(force: true);

      // 1. Result should report dead error
      expect(result.hasDeadErrors, isTrue);
      expect(result.deadErrors.length, 1);
      expect(result.deadErrors.first.statusCode, 422);
      expect(result.deadErrors.first.message, contains('queued_seconds'));
      expect(result.retryableCount, 0);

      // 2. Queue entry in DB must be 'dead'
      final deadEntries = await database.getDeadQueueEntries();
      expect(deadEntries.length, 1);
      expect(deadEntries.first.state, 'dead');
      expect(deadEntries.first.attempts, 0); // No backoff attempt counter incremented

      // 3. Customer in DB must have syncStatus = 'error'
      final customer = (await database.getAllLocalCustomers()).first;
      expect(customer.syncStatus, 'error');

      // 4. Pending sync count must be 0 (no items waiting to retry)
      final pendingCount = await database.countPendingSync();
      expect(pendingCount, 0);

      // 5. Subsequent syncQueue call MUST NOT retry this dead item
      final subsequentResult = await syncService.syncQueue(force: true);
      expect(subsequentResult.totalEntries, 0);
      expect(adapter.callCount, 1); // exactly 1 time, never retried!
    });

    test('400 Bad Request error is classified as permanent dead -> NO RETRY', () async {
      const clientUuid = 'uuid-400-test';
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      await database.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'customer',
          op: 'create',
          clientUuid: clientUuid,
          payload: '{"name": "Bad Request Customer"}',
          createdAt: nowMs,
          createdElapsed: nowMs,
          bootId: 'test_boot',
        ),
      );

      adapter.statusCode = 400;
      adapter.responseBody = jsonEncode({
        'status': false,
        'message': 'Dữ liệu không đúng định dạng',
      });

      final result = await syncService.syncQueue(force: true);
      expect(result.hasDeadErrors, isTrue);
      expect(result.deadErrors.first.statusCode, 400);

      final deadEntries = await database.getDeadQueueEntries();
      expect(deadEntries.first.state, 'dead');
    });

    test('500 Server Error is classified as temporary network error -> RETRY with backoff', () async {
      const clientUuid = 'uuid-500-test';
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      await database.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'customer',
          op: 'create',
          clientUuid: clientUuid,
          payload: '{"name": "Customer 500"}',
          createdAt: nowMs,
          createdElapsed: nowMs,
          bootId: 'test_boot',
        ),
      );

      adapter.statusCode = 500;
      adapter.responseBody = jsonEncode({
        'status': false,
        'message': '500 Internal Server Error',
      });

      final result = await syncService.syncQueue(force: true);

      // Result should report retryable error, NOT dead error
      expect(result.hasDeadErrors, isFalse);
      expect(result.retryableCount, 1);

      // Queue entry in DB must REMAIN 'pending' with attempts = 1 and nextAttemptAt set
      final deadEntries = await database.getDeadQueueEntries();
      expect(deadEntries.isEmpty, isTrue);

      final pendingEntries = await database.getPendingQueueEntries(force: true);
      expect(pendingEntries.length, 1);
      expect(pendingEntries.first.state, 'pending');
      expect(pendingEntries.first.attempts, 1);
      expect(pendingEntries.first.nextAttemptAt, isNotNull);
    });

    test('NetworkException (no internet / connection error) -> RETRY with backoff', () async {
      const clientUuid = 'uuid-network-test';
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      await database.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'customer',
          op: 'create',
          clientUuid: clientUuid,
          payload: '{"name": "Customer Network Error"}',
          createdAt: nowMs,
          createdElapsed: nowMs,
          bootId: 'test_boot',
        ),
      );

      adapter.throwNetworkError = true;

      final result = await syncService.syncQueue(force: true);
      expect(result.hasDeadErrors, isFalse);
      expect(result.retryableCount, 1);

      final pendingEntries = await database.getPendingQueueEntries(force: true);
      expect(pendingEntries.first.state, 'pending');
      expect(pendingEntries.first.attempts, 1);
    });

    test('409 Conflict is treated as success (Idempotency Rule)', () async {
      const clientUuid = 'uuid-409-test';
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      await database.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'customer',
          op: 'create',
          clientUuid: clientUuid,
          payload: '{"name": "Existing Customer"}',
          createdAt: nowMs,
          createdElapsed: nowMs,
          bootId: 'test_boot',
        ),
      );

      adapter.statusCode = 409;
      adapter.responseBody = jsonEncode({
        'status': false,
        'message': 'ALREADY_EXISTS',
      });

      final result = await syncService.syncQueue(force: true);
      expect(result.hasDeadErrors, isFalse);
      expect(result.retryableCount, 0);

      // Entry marked done
      final deadEntries = await database.getDeadQueueEntries();
      expect(deadEntries.isEmpty, isTrue);

      final pendingEntries = await database.getPendingQueueEntries(force: true);
      expect(pendingEntries.isEmpty, isTrue);
    });
  });
}
