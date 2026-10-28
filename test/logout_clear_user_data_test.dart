import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/database/app_database.dart';

/// Đăng xuất xoá hàng đợi đồng bộ + điểm bán lưu trong máy — kẻo người đăng nhập sau gửi dữ liệu người trước
/// dưới tên mình (bảng hàng đợi không có cột tài khoản). Còn mục chờ gửi thì KHÔNG xoá gì (mất dữ liệu).
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> enqueue(String uuid) => db.enqueue(SyncQueueEntriesCompanion.insert(
        entity: 'visit',
        op: 'create',
        clientUuid: uuid,
        payload: '{}',
        createdAt: 0,
        createdElapsed: 0,
        bootId: 'b',
      ));

  Future<void> addCustomer() => db.insertOrUpdateCustomer(LocalCustomersCompanion.insert(
        clientUuid: 'c-1',
        name: 'Điểm bán A',
        nameUnaccent: 'diem ban a',
        address: 'HN',
        contactPerson: 'A',
        phone: '0900000000',
      ));

  test('không còn mục chờ gửi: xoá sạch hàng đợi (done + dead) và điểm bán trong máy', () async {
    await db.markDone(await enqueue('u-done'));
    await db.markDead(await enqueue('u-dead'), 'x');
    await addCustomer();

    expect(await db.clearUserData(), isTrue);
    expect(await db.select(db.syncQueueEntries).get(), isEmpty);
    expect(await db.getAllLocalCustomers(), isEmpty);
  });

  for (final st in ['pending', 'sending']) {
    test('còn mục $st: không xoá gì, trả false', () async {
      final id = await enqueue('u-$st');
      if (st == 'sending') await db.markSending(id);
      await db.markDead(await enqueue('u-dead'), 'x');
      await addCustomer();

      expect(await db.clearUserData(), isFalse);
      expect(await db.select(db.syncQueueEntries).get(), hasLength(2));
      expect(await db.getAllLocalCustomers(), hasLength(1));
    });
  }

  test('discardPending: người dùng xác nhận bỏ dữ liệu chưa gửi ⇒ xoá cả mục pending', () async {
    await enqueue('u-pending');
    await addCustomer();

    expect(await db.clearUserData(discardPending: true), isTrue);
    expect(await db.select(db.syncQueueEntries).get(), isEmpty);
    expect(await db.getAllLocalCustomers(), isEmpty);
  });
}
