import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/database/app_database.dart';

/// Home đếm điểm bán + lấy điểm kế tiếp bằng SQL (29/10/2026) — phải ra Y HỆT vòng lặp cũ trên getAllLocalCustomers.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory(), 1));
  tearDown(() => db.close());

  Future<void> add(String uuid, {int? id, String status = 'synced', String? createdAt}) =>
      db.insertOrUpdateCustomer(LocalCustomersCompanion(
        id: Value(id),
        clientUuid: Value(uuid),
        name: Value('Điểm $uuid'),
        nameUnaccent: Value('diem $uuid'),
        address: const Value('A'),
        phone: const Value('0900000000'),
        contactPerson: const Value('X'),
        syncStatus: Value(status),
        createdAt: Value(createdAt),
      ));

  Future<String?> oldLoop(Set<int> visited) async {
    for (final c in await db.getAllLocalCustomers()) {
      if (!visited.contains(c.id)) return c.name;
    }
    return null;
  }

  test('đếm + điểm kế tiếp khớp vòng lặp cũ (có điểm offline chưa id, có điểm đã ghé)', () async {
    expect(await db.countLocalCustomers(), 0);
    expect(await db.firstLocalCustomerNameNotIn({}), isNull);

    await add('a', id: 1, createdAt: '2026-10-01');
    await add('b', id: 2, createdAt: '2026-10-03');
    await add('c', id: 3, createdAt: '2026-10-02');
    expect(await db.countLocalCustomers(), 3);

    for (final visited in [<int>{}, {2}, {2, 3}, {1, 2, 3}]) {
      expect(await db.firstLocalCustomerNameNotIn(visited), await oldLoop(visited), reason: '$visited');
    }

    await add('p', status: 'pending', createdAt: '2026-09-01'); // tạo offline, chưa có id ⇒ đứng đầu, chưa ghé
    expect(await db.countLocalCustomers(), 4);
    for (final visited in [<int>{}, {1, 2, 3}]) {
      expect(await db.firstLocalCustomerNameNotIn(visited), await oldLoop(visited), reason: '$visited');
    }
  });
}
