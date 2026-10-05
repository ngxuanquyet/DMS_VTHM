import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/features/customer/data/datasources/customer_local_data_source.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_dynamic_column.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_meta_entity.dart';
import 'package:vthm_dms/features/customer/domain/repositories/customer_repository.dart';
import 'package:vthm_dms/features/customer/presentation/viewmodels/customer_view_model.dart';
import 'package:vthm_dms/features/customer/presentation/widgets/pending_sync_dismissible.dart';

class _MockCustomerRepository implements CustomerRepository {
  final List<CustomerEntity> customers = [];

  @override
  Future<List<CustomerEntity>> getCustomers({
    int page = 1,
    int perPage = 200,
    String? query,
    bool forceRefresh = false,
  }) async =>
      customers;

  @override
  Future<List<CustomerDynamicColumn>> getDynamicColumns({bool forceRefresh = false}) async =>
      [];

  @override
  Future<CustomerMetaData> getCustomerMeta({bool forceRefresh = false}) async =>
      const CustomerMetaData();

  @override
  Future<CustomerEntity> updateCustomer({
    required int id,
    required Map<String, dynamic> changes,
    String? clientUuid,
  }) async =>
      customers.first;

  @override
  Future<CustomerEntity> getCustomerDetail(int id) async => customers.first;

  @override
  Future<CustomerEntity> createCustomer(Map<String, dynamic> data) async {
    final entity = CustomerEntity(
      id: 0,
      code: 'PENDING_TEST',
      name: data['name']?.toString() ?? 'Khách hàng mới',
      type: 'Đại lý',
      route: 'Tuyến 1',
      address: 'Hà Nội',
      contactPerson: 'Anh Nam',
      phone: '0987654321',
      syncStatus: 'pending',
      clientUuid: 'uuid-mock-123',
    );
    customers.insert(0, entity);
    return entity;
  }

  @override
  Future<Map<String, dynamic>> uploadCustomerPhoto(String filePath) async =>
      {'token': 'test_token'};

  @override
  Future<Map<String, dynamic>> getCustomerFormSchema({bool forceRefresh = false}) async => {};

  @override
  Future<bool> deleteCustomer(int id) async => true;

  @override
  Future<bool> deletePendingCustomer(String clientUuid) async {
    customers.removeWhere((c) => c.clientUuid == clientUuid);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Delete Pending Customer Database Tests', () {
    late AppDatabase database;
    late CustomerLocalDataSource localDataSource;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      localDataSource = CustomerLocalDataSource(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('deletePendingCustomer deletes both local_customers and sync_queue entries (including photo parentUuid)', () async {
      const clientUuid = 'test-client-uuid-999';
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // 1. Insert local customer
      await database.insertOrUpdateCustomer(
        LocalCustomersCompanion.insert(
          clientUuid: clientUuid,
          name: 'Điểm Bán Chờ Xóa',
          nameUnaccent: 'diem ban cho xoa',
          address: 'Hà Nội',
          contactPerson: 'Anh Nam',
          phone: '0912345678',
          syncStatus: const Value('pending'),
        ),
      );

      // 2. Enqueue create customer
      await database.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'customer',
          op: 'create',
          clientUuid: clientUuid,
          payload: '{"name": "Điểm Bán Chờ Xóa"}',
          createdAt: nowMs,
          createdElapsed: nowMs,
          bootId: 'boot_session_test',
        ),
      );

      // 3. Enqueue photo with parentUuid = clientUuid
      await database.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: 'photo',
          op: 'attach_photo',
          clientUuid: 'photo-uuid-111',
          parentUuid: const Value(clientUuid),
          payload: '{"photo": "photo.jpg"}',
          createdAt: nowMs,
          createdElapsed: nowMs,
          bootId: 'boot_session_test',
        ),
      );

      // Verify before deletion
      var customers = await database.getAllLocalCustomers();
      var queue = await database.getPendingQueueEntries(limit: 10);
      expect(customers.length, 1);
      expect(queue.length, 2);

      // 4. Delete pending customer
      await database.deletePendingCustomer(clientUuid);

      // Verify after deletion: both customer and its queue entries are gone
      customers = await database.getAllLocalCustomers();
      queue = await database.getPendingQueueEntries(limit: 10);
      expect(customers.isEmpty, isTrue);
      expect(queue.isEmpty, isTrue);
    });

    test('CustomerLocalDataSource.deletePendingCustomer successfully deletes offline created customer', () async {
      final customer = await localDataSource.createCustomerOffline({
        'name': 'Đại lý Chờ Xóa',
        'phone': '0901234567',
        'address': 'Số 10 Nguyễn Trãi',
        'contact_name': 'Chị Lan',
        'route_ids': [1],
      });

      expect(customer.clientUuid, isNotNull);
      final uuid = customer.clientUuid!;

      var list = await localDataSource.getLocalCustomers();
      expect(list.any((c) => c.clientUuid == uuid), isTrue);

      await localDataSource.deletePendingCustomer(uuid);

      list = await localDataSource.getLocalCustomers();
      expect(list.any((c) => c.clientUuid == uuid), isFalse);
    });

    test('Offline created customer is sorted to top ahead of synced customers in getLocalCustomers', () async {
      // 1. Insert 2 synced customers
      await database.insertOrUpdateCustomer(
        LocalCustomersCompanion.insert(
          clientUuid: 'synced-uuid-1',
          name: 'Đại lý Synced 1',
          nameUnaccent: 'dai ly synced 1',
          address: 'Hà Nội',
          contactPerson: 'Anh A',
          phone: '0911111111',
          syncStatus: const Value('synced'),
          createdAt: const Value('2026-10-01T08:00:00+07:00'),
        ),
      );
      await database.insertOrUpdateCustomer(
        LocalCustomersCompanion.insert(
          clientUuid: 'synced-uuid-2',
          name: 'Đại lý Synced 2',
          nameUnaccent: 'dai ly synced 2',
          address: 'Hà Nội',
          contactPerson: 'Anh B',
          phone: '0922222222',
          syncStatus: const Value('synced'),
          createdAt: const Value('2026-10-02T08:00:00+07:00'),
        ),
      );

      // 2. Insert offline customer (pending)
      final offlineCustomer = await localDataSource.createCustomerOffline({
        'name': 'Đại lý Offline Mới Tạo',
        'phone': '0987654321',
        'address': 'Hà Nội',
        'contact_name': 'Anh Nam',
        'route_ids': [1],
      });

      // 3. Query getLocalCustomers
      final list = await localDataSource.getLocalCustomers();
      expect(list.length, 3);
      // The offline customer must be at index 0 (pinned to top)
      expect(list.first.clientUuid, offlineCustomer.clientUuid);
      expect(list.first.name, 'Đại lý Offline Mới Tạo');
      expect(list.first.syncStatus, 'pending');
    });

    test('CustomerViewModel.createCustomer prepends offline customer and deletePendingCustomer removes it', () async {
      final mockRepo = _MockCustomerRepository();
      final vm = CustomerViewModel(mockRepo);

      final newCustomer = await vm.createCustomer({
        'name': 'Khách hàng Offline ViewModel',
      });

      expect(vm.state.allCustomers.first.name, 'Khách hàng Offline ViewModel');
      expect(vm.state.allCustomers.first.syncStatus, 'pending');

      final deleteSuccess = await vm.deletePendingCustomer(newCustomer.clientUuid!);
      expect(deleteSuccess, isTrue);
      expect(vm.state.allCustomers.any((c) => c.clientUuid == newCustomer.clientUuid), isFalse);
    });

    test('CustomerLocalDataSource.updateCustomerOffline successfully recovers error record back to pending', () async {
      // 1. Tạo khách hàng offline
      final customer = await localDataSource.createCustomerOffline({
        'name': 'Đại lý Bị Lỗi 4xx',
        'phone': '0901234567',
        'address': 'Số 5 Phố Huế',
        'contact_name': 'Anh Tuấn',
      });
      final uuid = customer.clientUuid!;

      // 2. Giả lập SyncService gặp lỗi 4xx -> markCustomerSyncError & markDead
      await database.markCustomerSyncError(uuid, '422: Số điện thoại không hợp lệ');
      final entries = await (database.select(database.syncQueueEntries)
            ..where((tbl) => tbl.clientUuid.equals(uuid)))
          .get();
      expect(entries.isNotEmpty, isTrue);
      await database.markDead(entries.first.id, '422: Số điện thoại không hợp lệ');

      // Kiểm tra trạng thái đang là error/dead
      var currentList = await localDataSource.getLocalCustomers();
      var curCustomer = currentList.firstWhere((c) => c.clientUuid == uuid);
      expect(curCustomer.syncStatus, 'error');
      expect(curCustomer.approvalStatus, 'rejected');

      var curEntries = await (database.select(database.syncQueueEntries)
            ..where((tbl) => tbl.clientUuid.equals(uuid)))
          .get();
      expect(curEntries.first.state, 'dead');
      expect(curEntries.first.lastError, contains('422'));

      // 3. User thực hiện sửa thông tin qua updateCustomerOffline
      final updated = await localDataSource.updateCustomerOffline(uuid, {
        'name': 'Đại lý Đã Được Sửa Lại',
        'phone': '0988776655',
        'contact_name': 'Anh Tuấn Sửa',
      });

      // Kiểm tra trạng thái đã được phục hồi về 'pending'
      expect(updated.syncStatus, 'pending');
      expect(updated.approvalStatus, 'pending');
      expect(updated.name, 'Đại lý Đã Được Sửa Lại');
      expect(updated.phone, '0988776655');
      expect(updated.contactPerson, 'Anh Tuấn Sửa');

      // Kiểm tra trong database SQLite LocalCustomers
      currentList = await localDataSource.getLocalCustomers();
      curCustomer = currentList.firstWhere((c) => c.clientUuid == uuid);
      expect(curCustomer.syncStatus, 'pending');
      expect(curCustomer.approvalStatus, 'pending');
      expect(curCustomer.name, 'Đại lý Đã Được Sửa Lại');

      // Kiểm tra trong SyncQueueEntries: state = pending, attempts = 0, lastError = null
      curEntries = await (database.select(database.syncQueueEntries)
            ..where((tbl) => tbl.clientUuid.equals(uuid)))
          .get();
      expect(curEntries.first.state, 'pending');
      expect(curEntries.first.attempts, 0);
      expect(curEntries.first.lastError, isNull);
      expect(curEntries.first.payload, contains('0988776655'));
    });
  });

  group('PendingSyncDismissible Widget Tests', () {
    testWidgets('Non-pending item cannot be dismissed / has no Dismissible', (tester) async {
      bool deleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PendingSyncDismissible(
              itemKey: 'test_1',
              title: 'Điểm Bán Đã Đồng Bộ',
              isPending: false,
              onConfirmDelete: () async {
                deleted = true;
                return true;
              },
              child: const ListTile(title: Text('Điểm Bán Đã Đồng Bộ')),
            ),
          ),
        ),
      );

      expect(find.byType(Dismissible), findsNothing);
      expect(find.text('Điểm Bán Đã Đồng Bộ'), findsOneWidget);
      expect(deleted, isFalse);
    });

    testWidgets('Pending or Error item has Dismissible and swiping shows confirmation popup', (tester) async {
      bool deleteCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PendingSyncDismissible(
              itemKey: 'test_pending_1',
              title: 'Điểm Bán Chờ Gửi',
              isPending: true,
              onConfirmDelete: () async {
                deleteCalled = true;
                return true;
              },
              child: const SizedBox(
                height: 80,
                width: 400,
                child: Text('Điểm Bán Chờ Gửi'),
              ),
            ),
          ),
        ),
      );

      // Verify Dismissible is present
      expect(find.byType(Dismissible), findsOneWidget);

      // Swipe from left to right to trigger dismiss confirmation
      await tester.drag(find.text('Điểm Bán Chờ Gửi'), const Offset(500, 0));
      await tester.pumpAndSettle();

      // Popup dialog should appear
      expect(find.text('Xóa bản ghi chưa đồng bộ?'), findsOneWidget);
      expect(find.text('Hủy'), findsOneWidget);
      expect(find.text('Xóa'), findsOneWidget);

      // Click "Hủy"
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      // Dialog closed, item is not deleted
      expect(find.text('Xóa bản ghi chưa đồng bộ?'), findsNothing);
      expect(find.text('Điểm Bán Chờ Gửi'), findsOneWidget);
      expect(deleteCalled, isFalse);

      // Swipe from right to left to trigger dismiss again
      await tester.drag(find.text('Điểm Bán Chờ Gửi'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Popup dialog appears again
      expect(find.text('Xóa bản ghi chưa đồng bộ?'), findsOneWidget);

      // Click "Xóa" to confirm deletion
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();

      // Deletion callback was invoked
      expect(deleteCalled, isTrue);
      // SnackBar with confirmation message is displayed
      expect(find.textContaining('Đã xóa bản ghi'), findsOneWidget);
    });
  });
}
