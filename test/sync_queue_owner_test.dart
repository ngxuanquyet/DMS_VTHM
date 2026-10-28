import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/database/app_database.dart';

/// Hàng đợi đồng bộ gắn chủ (#24400): máy dùng chung không gửi/hiện/dọn dữ liệu người trước dưới tên người sau.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> enqueue(String uuid, {int? owner, bool setOwner = false}) => db.enqueue(SyncQueueEntriesCompanion.insert(
        entity: 'visit',
        op: 'create',
        clientUuid: uuid,
        payload: '{}',
        createdAt: 0,
        createdElapsed: 0,
        bootId: 'b',
        ownerUserId: setOwner ? Value(owner) : const Value.absent(),
      ));

  Future<List<String>> pendingUuids() async => (await db.getPendingQueueEntries()).map((e) => e.clientUuid).toList();

  test('enqueue tự gắn người đang đăng nhập', () async {
    await db.setOwner(7);
    await enqueue('a');
    expect((await db.getEntryByClientUuid('a'))?.ownerUserId, 7);
  });

  test('chỉ gửi/đếm/liệt kê dòng của người đang đăng nhập', () async {
    await db.setOwner(1);
    await enqueue('mine');
    await enqueue('theirs', owner: 2, setOwner: true);
    final deadId = await enqueue('theirs-dead', owner: 2, setOwner: true);
    await db.markDead(deadId, 'x');

    expect(await pendingUuids(), ['mine']);
    expect(await db.countPendingSync(), 1);
    expect(await db.countDeadSync(), 0);
    expect((await db.getAllPendingQueueEntries()).map((e) => e.clientUuid), ['mine']);

    await db.clearDeadEntries();
    expect(await db.getEntryByClientUuid('theirs-dead'), isNotNull, reason: 'không dọn mục lỗi của người khác');

    await db.setOwner(2);
    expect(await pendingUuids(), ['theirs']);
  });

  test('chưa đăng nhập ⇒ không thấy dòng nào (không gửi)', () async {
    await db.setOwner(1);
    await enqueue('mine');
    await db.setOwner(null);
    expect(await pendingUuids(), isEmpty);
    expect(await db.countPendingSync(), 0);
    expect(await db.clearUserData(), isFalse);
    expect(await db.getEntryByClientUuid('mine'), isNotNull);
  });

  test('mục nhập muộn ngay sau đăng xuất vẫn của người vừa đăng xuất, không giao cho người sau', () async {
    await db.setOwner(3);
    await db.setOwner(null);
    await enqueue('late');
    await db.setOwner(4);
    expect((await db.getEntryByClientUuid('late'))?.ownerUserId, 3);
    expect(await pendingUuids(), isEmpty);
  });

  test('mục vô chủ (nhập khi chưa ai đăng nhập trong lần chạy) không bị giao cho ai', () async {
    await db.setOwner(null);
    await enqueue('orphan');
    await db.setOwner(5);
    expect((await db.getEntryByClientUuid('orphan'))?.ownerUserId, isNull);
    expect(await pendingUuids(), isEmpty);
  });

  test('clearUserData chỉ xoá dòng hàng đợi của mình', () async {
    await db.setOwner(1);
    await db.markDone(await enqueue('mine-done'));
    await enqueue('theirs', owner: 2, setOwner: true);

    expect(await db.clearUserData(), isTrue);
    expect(await db.getEntryByClientUuid('mine-done'), isNull);
    expect(await db.getEntryByClientUuid('theirs'), isNotNull);
  });

  test('nâng cấp từ schema 1 (chưa có cột chủ): thêm cột, giữ dữ liệu, giao dòng cũ cho người đăng nhập', () async {
    final dir = await Directory.systemTemp.createTemp('dms_owner_mig');
    addTearDown(() => dir.delete(recursive: true));

    // Lấy DDL hiện hành rồi bỏ cột owner_user_id ⇒ dựng lại đúng bảng của schema 1.
    final probe = AppDatabase(NativeDatabase.memory());
    final ddl = (await probe.customSelect("SELECT sql FROM sqlite_master WHERE type = 'table' AND sql IS NOT NULL AND name NOT LIKE 'sqlite_%'").get())
        .map((r) => r.read<String>('sql'))
        .toList();
    await probe.close();
    final v1 = ddl.map((sql) => sql.replaceAll(RegExp(r',\s*"owner_user_id" INTEGER NULL'), '')).toList();
    expect(v1.any((sql) => sql.contains('owner_user_id')), isFalse);

    final file = File('${dir.path}/v1.sqlite');
    final old = AppDatabase(NativeDatabase(file, setup: (raw) {
      if (raw.userVersion != 0) return;
      for (final sql in v1) {
        raw.execute(sql);
      }
      raw.execute("INSERT INTO sync_queue_entries (entity, op, client_uuid, payload, created_at, created_elapsed, boot_id) "
          "VALUES ('visit', 'create', 'old-row', '{}', 0, 0, 'b')");
      raw.userVersion = 1;
    }));
    await old.setOwner(9);
    expect((await old.getEntryByClientUuid('old-row'))?.ownerUserId, 9);
    expect((await old.getPendingQueueEntries()).map((e) => e.clientUuid), ['old-row']);
    await old.close();
  });
}
