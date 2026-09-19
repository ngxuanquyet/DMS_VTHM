import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/utils/string_utils.dart';
import 'package:vthm_dms/features/customer/data/datasources/customer_local_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('String Unaccenting Tests (§7.4)', () {
    test('toUnaccentedLower correctly normalizes Vietnamese text with diacritics', () {
      expect(StringUtils.toUnaccentedLower('Nguyễn'), 'nguyen');
      expect(StringUtils.toUnaccentedLower('Cửa Hàng Tạp Hóa Ánh Dương'), 'cua hang tap hoa anh duong');
      expect(StringUtils.toUnaccentedLower('Đặng Văn Đạt'), 'dang van dat');
      expect(StringUtils.toUnaccentedLower('ĐỒ UỐNG & BÁNH KẸO'), 'do uong & banh keo');
      expect(StringUtils.toUnaccentedLower('123 Đường Số 5, Phường 10'), '123 duong so 5, phuong 10');
    });

    test('matchesSearch accurately matches unaccented substrings', () {
      expect(StringUtils.matchesSearch('Đại lý Nguyễn Văn A', 'nguyen'), isTrue);
      expect(StringUtils.matchesSearch('Đại lý Nguyễn Văn A', 'NGUYEN'), isTrue);
      expect(StringUtils.matchesSearch('Đại lý Nguyễn Văn A', 'van a'), isTrue);
      expect(StringUtils.matchesSearch('Đại lý Nguyễn Văn A', 'ha noi'), isFalse);
    });
  });

  group('Drift AppDatabase & Sync Queue Tests', () {
    late AppDatabase database;

    setUp(() {
      // In-memory database for testing
      database = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('BB-1 & BB-2: Enqueue sync queue entry with client_uuid', () async {
      final clientUuid = 'test-uuid-1234';
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final queueId = await database.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'customer',
          op: 'create',
          clientUuid: clientUuid,
          payload: '{"name": "Tạp hóa Test", "phone": "0987654321"}',
          createdAt: nowMs,
          createdElapsed: nowMs,
          bootId: 'boot_session_test',
        ),
      );

      expect(queueId, greaterThan(0));

      final pendingEntries = await database.getPendingQueueEntries(limit: 10);
      expect(pendingEntries.length, 1);
      expect(pendingEntries.first.clientUuid, clientUuid);
      expect(pendingEntries.first.state, 'pending');
      expect(pendingEntries.first.op, 'create');
    });

    test('Orphaned sending entries recovery on startup (§3.3 Rule 5)', () async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final id = await database.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'customer',
          op: 'create',
          clientUuid: 'test-uuid-orphaned',
          payload: '{}',
          createdAt: nowMs,
          createdElapsed: nowMs,
          bootId: 'boot_session_test',
        ),
      );

      // Simulate app crashing while sending
      await database.markSending(id);
      var entries = await database.getPendingQueueEntries(limit: 10);
      expect(entries.isEmpty, isTrue); // Not in pending anymore

      // Recover on startup
      final recovered = await database.recoverOrphanedSendingEntries();
      expect(recovered, 1);

      entries = await database.getPendingQueueEntries(limit: 10);
      expect(entries.length, 1);
      expect(entries.first.state, 'pending');
    });

    test('Sync queue state transitions: markSending -> markDone', () async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final id = await database.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'customer',
          op: 'create',
          clientUuid: 'test-uuid-done',
          payload: '{}',
          createdAt: nowMs,
          createdElapsed: nowMs,
          bootId: 'boot_session_test',
        ),
      );

      await database.markSending(id);
      await database.markDone(id);

      final entries = await database.getPendingQueueEntries(limit: 10);
      expect(entries.isEmpty, isTrue);
    });

    test('Sync queue retry exponential backoff & dead-letter (§8.2)', () async {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final id = await database.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'customer',
          op: 'create',
          clientUuid: 'test-uuid-retry',
          payload: '{}',
          createdAt: nowMs,
          createdElapsed: nowMs,
          bootId: 'boot_session_test',
        ),
      );

      // Reschedule retry
      final nextRun = DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch;
      await database.reschedule(id, nextAttemptAt: nextRun, attempts: 1, error: 'Network 500');

      // Check not immediately available if nextAttemptAt is in future
      var pending = await database.getPendingQueueEntries(limit: 10);
      expect(pending.isEmpty, isTrue);

      // Exceeded max retries -> markDead
      await database.markDead(id, 'Exceeded max retries (5)');
      pending = await database.getPendingQueueEntries(limit: 10);
      expect(pending.isEmpty, isTrue);
    });

    test('Local customer insert, unaccented search & mark synced (§7.4)', () async {
      final customer = LocalCustomersCompanion(
        id: const Value(999),
        clientUuid: const Value('uuid_999'),
        name: const Value('Đại Lý Hoàng Mai'),
        nameUnaccent: const Value('dai ly hoang mai'),
        phone: const Value('0912345678'),
        address: const Value('123 Giải Phóng, Hà Nội'),
        contactPerson: const Value('Anh Mai'),
        status: const Value('active'),
        approvalStatus: const Value('pending'),
        syncStatus: const Value('pending'),
      );

      await database.insertOrUpdateCustomer(customer);

      // Search with diacritics
      var results = await database.searchLocalCustomers('hoang mai');
      expect(results.length, 1);
      expect(results.first.clientUuid, 'uuid_999');

      // Mark synced
      await database.markCustomerSynced('uuid_999', 777);
      final updatedList = await database.searchLocalCustomers('hoang');
      expect(updatedList.first.id, 777);
      expect(updatedList.first.syncStatus, 'synced');
      expect(updatedList.first.approvalStatus, 'approved');
    });
  });

  group('CustomerLocalDataSource Integration Tests', () {
    late AppDatabase database;
    late CustomerLocalDataSource localDataSource;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      localDataSource = CustomerLocalDataSource(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('createCustomerOffline saves customer and enqueues sync item', () async {
      final entity = await localDataSource.createCustomerOffline({
        'name': 'Tiệm Tạp Hóa Bình Minh',
        'phone': '0901234567',
        'contact_person': 'Bác Bình',
        'address': '456 Lê Duẩn',
        'route': 'Tuyến 1',
        'type': 'Đại lý cấp 1',
        'dynamic_fields': {'tax_code': '0102030405'},
      });

      expect(entity.clientUuid, isNotNull);
      expect(entity.syncStatus, 'pending');
      expect(entity.approvalStatus, 'pending');
      expect(entity.name, 'Tiệm Tạp Hóa Bình Minh');

      // Verify customer exists in Drift DB
      final cached = await localDataSource.getLocalCustomers();
      expect(cached.length, 1);
      expect(cached.first.clientUuid, entity.clientUuid);
      expect(cached.first.syncStatus, 'pending');

      // Verify item enqueued in sync queue
      final pendingQueue = await database.getPendingQueueEntries();
      expect(pendingQueue.length, 1);
      expect(pendingQueue.first.clientUuid, entity.clientUuid);
      expect(pendingQueue.first.entity, 'customer');
      expect(pendingQueue.first.op, 'create');
      expect(pendingQueue.first.payload, contains('Tiệm Tạp Hóa Bình Minh'));
      expect(pendingQueue.first.payload, contains(entity.clientUuid));
      expect(pendingQueue.first.payload, contains('"region_id":'));
      expect(pendingQueue.first.payload, contains('"data":'));
      // 🔴 Xác nhận payload tuyệt đối KHÔNG chứa trường code (do server tự sinh)
      expect(pendingQueue.first.payload, isNot(contains('"code":')));
    });
  });
}
