import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/features/customer/data/datasources/customer_local_data_source.dart';
import 'package:vthm_dms/features/customer/presentation/widgets/pending_sync_dismissible.dart';

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

    testWidgets('Pending item has Dismissible and swiping shows confirmation popup', (tester) async {
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
      expect(find.text('Xóa bản ghi chờ đồng bộ?'), findsOneWidget);
      expect(find.text('Hủy'), findsOneWidget);
      expect(find.text('Xóa'), findsOneWidget);

      // Click "Hủy"
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      // Dialog closed, item is not deleted
      expect(find.text('Xóa bản ghi chờ đồng bộ?'), findsNothing);
      expect(find.text('Điểm Bán Chờ Gửi'), findsOneWidget);
      expect(deleteCalled, isFalse);

      // Swipe from right to left to trigger dismiss again
      await tester.drag(find.text('Điểm Bán Chờ Gửi'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Popup dialog appears again
      expect(find.text('Xóa bản ghi chờ đồng bộ?'), findsOneWidget);

      // Click "Xóa" to confirm deletion
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();

      // Deletion callback was invoked
      expect(deleteCalled, isTrue);
      // SnackBar with confirmation message is displayed
      expect(find.textContaining('Đã xóa bản ghi chờ'), findsOneWidget);
    });
  });
}
