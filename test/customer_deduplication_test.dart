import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/features/customer/data/datasources/customer_local_data_source.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Customer Deduplication Tests', () {
    test('deduplicateCustomers eliminates duplicates by id, code and clientUuid', () {
      final list = [
        const CustomerEntity(
          id: 101,
          code: 'KH101',
          name: 'Điểm bán 1',
          type: 'Đại lý',
          route: 'Tuyến 1',
          address: 'Hà Nội',
          contactPerson: 'Anh A',
          phone: '0901234567',
          clientUuid: 'uuid-1',
        ),
        // Duplicate by ID 101
        const CustomerEntity(
          id: 101,
          code: 'KH101_DUPLICATE',
          name: 'Điểm bán 1 Duplicate',
          type: 'Đại lý',
          route: 'Tuyến 1',
          address: 'Hà Nội',
          contactPerson: 'Anh A',
          phone: '0901234567',
          clientUuid: 'server_101',
        ),
        // Duplicate by Code KH102
        const CustomerEntity(
          id: 102,
          code: 'KH102',
          name: 'Điểm bán 2',
          type: 'Đại lý',
          route: 'Tuyến 1',
          address: 'Hà Nội',
          contactPerson: 'Chị B',
          phone: '0901234568',
          clientUuid: 'uuid-2',
        ),
        const CustomerEntity(
          id: 0,
          code: 'KH102',
          name: 'Điểm bán 2 Dup Code',
          type: 'Đại lý',
          route: 'Tuyến 1',
          address: 'Hà Nội',
          contactPerson: 'Chị B',
          phone: '0901234568',
          clientUuid: 'uuid-3',
        ),
        // Distinct item
        const CustomerEntity(
          id: 103,
          code: 'KH103',
          name: 'Điểm bán 3',
          type: 'Đại lý',
          route: 'Tuyến 1',
          address: 'Hà Nội',
          contactPerson: 'Anh C',
          phone: '0901234569',
          clientUuid: 'uuid-4',
        ),
      ];

      final deduplicated = CustomerLocalDataSource.deduplicateCustomers(list);
      expect(deduplicated.length, equals(3));
      expect(deduplicated.map((c) => c.id).toList(), equals([101, 102, 103]));
    });

    test('cacheRemoteCustomers updates existing offline record without creating a second row', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final dataSource = CustomerLocalDataSource(db);

      // 1. Tạo 1 khách hàng offline (clientUuid là uuid v4)
      final localCreated = await dataSource.createCustomerOffline({
        'name': 'Cửa hàng Hoàng Mai',
        'address': 'Hoàng Mai, Hà Nội',
        'phone': '0912345678',
        'route_ids': [1],
      });

      var localList = await dataSource.getLocalCustomers();
      expect(localList.length, equals(1));
      expect(localList.first.name, equals('Cửa hàng Hoàng Mai'));
      expect(localList.first.clientUuid, equals(localCreated.clientUuid));

      // 2. Giả lập sau khi đồng bộ lên server, server cấp ID 555 và code KH555
      await db.markCustomerSynced(
        localCreated.clientUuid!,
        555,
        code: 'KH555',
      );

      // 3. Giả lập GET /crm/customers/mine trả về remote customer id: 555 (chưa có clientUuid)
      final remoteEntity = CustomerEntity(
        id: 555,
        code: 'KH555',
        name: 'Cửa hàng Hoàng Mai (Updated from server)',
        type: 'Đại lý',
        route: 'Tuyến 1',
        address: 'Hoàng Mai, Hà Nội',
        contactPerson: 'Chủ cửa hàng',
        phone: '0912345678',
        // server GET response doesn't provide clientUuid
        clientUuid: null,
      );

      await dataSource.cacheRemoteCustomers([remoteEntity]);

      // 4. Kiểm tra danh sách khách hàng cục bộ: TUYỆT ĐỐI KHÔNG BỊ NHÂN ĐÔI
      localList = await dataSource.getLocalCustomers();
      expect(localList.length, equals(1), reason: 'Phải chỉ có 1 bản ghi duy nhất, không bị nhân bản thành 2');
      expect(localList.first.id, equals(555));
      expect(localList.first.code, equals('KH555'));
      expect(localList.first.name, equals('Cửa hàng Hoàng Mai (Updated from server)'));

      await db.close();
    });

    test('AppDatabase.cleanupDuplicateCustomers removes duplicate rows with same id', () async {
      final db = AppDatabase(NativeDatabase.memory());

      // Chèn thủ công 2 bản ghi có cùng id 999 nhưng clientUuid khác nhau
      await db.into(db.localCustomers).insert(
        LocalCustomersCompanion.insert(
          clientUuid: 'uuid-a',
          id: const Value(999),
          code: const Value('KH999'),
          name: 'Tiệm A',
          nameUnaccent: 'tiem a',
          address: 'Hà Nội',
          contactPerson: 'A',
          phone: '0901',
        ),
      );

      await db.into(db.localCustomers).insert(
        LocalCustomersCompanion.insert(
          clientUuid: 'server_999',
          id: const Value(999),
          code: const Value('KH999'),
          name: 'Tiệm A Duplicate',
          nameUnaccent: 'tiem a duplicate',
          address: 'Hà Nội',
          contactPerson: 'A',
          phone: '0901',
        ),
      );

      var rows = await db.getAllLocalCustomers();
      expect(rows.length, equals(2));

      // Chạy dọn dẹp trùng lặp
      await db.cleanupDuplicateCustomers();

      rows = await db.getAllLocalCustomers();
      expect(rows.length, equals(1));
      expect(rows.first.id, equals(999));

      await db.close();
    });
  });
}
