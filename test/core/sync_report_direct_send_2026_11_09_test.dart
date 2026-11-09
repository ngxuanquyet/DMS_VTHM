import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/sync/sync_entity_group.dart';

/// 09/11/2026: nhân viên viếng thăm lúc CÓ mạng không thấy lượt trong "Báo cáo gửi dữ liệu" — nhật ký chỉ ghi ở markDone
/// (hàng đợi). Mục gửi trực tuyến nay ghi qua [AppDatabase.logDirectSend].
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<SyncSentLog>> logs() => db.watchSentLogs(fromMs: 0).first;

  test('ghi một dòng, gửi lại cùng uuid (server trả bản cũ) không ghi trùng; payload chỉ giữ trường màn đọc', () async {
    await db.setOwner(5);
    await db.logDirectSend(
      entity: 'visit',
      op: 'create',
      clientUuid: 'v-1',
      payload: {'dealer_name': 'ĐL Minh', 'lat': 21.0, 'lng': 105.8},
      serverId: 77,
    );
    await db.logDirectSend(entity: 'visit', op: 'create', clientUuid: 'v-1', serverId: 77);

    final rows = await logs();
    expect(rows, hasLength(1));
    expect(rows.single.queueId, 0);
    expect(rows.single.serverId, 77);
    expect(rows.single.ownerUserId, 5);
    expect(jsonDecode(rows.single.payload), {'dealer_name': 'ĐL Minh'});
  });

  test('cùng uuid nhưng khác op (check-in rồi check-out) ⇒ hai dòng, gom thành MỘT lượt viếng thăm "Đã check-out"', () async {
    await db.setOwner(5);
    await db.logDirectSend(entity: 'visit', op: 'create', clientUuid: 'v-2', payload: {'dealer_name': 'ĐL Hoa'});
    await db.logDirectSend(entity: 'visit_photo', op: 'upload', clientUuid: 'p-1', parentUuid: 'v-2');
    await db.logDirectSend(entity: 'visit', op: 'checkout', clientUuid: 'co-1', parentUuid: 'v-2', payload: {'visit_id': 9});

    final rows = await logs();
    expect(rows, hasLength(3));
    final groups = SyncEntityGroupHelper.groupEntries([
      for (final l in rows)
        SyncQueueEntry(
          id: -l.id,
          entity: l.entity,
          op: l.op,
          clientUuid: l.clientUuid,
          parentUuid: l.parentUuid,
          payload: l.payload,
          state: 'done',
          attempts: 0,
          createdAt: l.createdAt,
          createdElapsed: 0,
          bootId: '',
        ),
    ]);
    expect(groups, hasLength(1));
    expect(groups.single.title, 'Lượt viếng thăm: ĐL Hoa');
    expect(groups.single.subtitle, contains('Đã check-out'));
    expect(groups.single.photoCount, 1);
  });

  test('chủ = người BẤM khi người gọi biết; không biết thì người đang đăng nhập', () async {
    await db.setOwner(3);
    await db.logDirectSend(entity: 'attendance_punch', op: 'create', clientUuid: 'a-1', ownerUserId: 9);
    await db.logDirectSend(entity: 'attendance_punch', op: 'create', clientUuid: 'a-2');
    expect((await logs()).map((l) => l.clientUuid), ['a-2'], reason: 'chỉ thấy của người đang đăng nhập (3)');
    await db.setOwner(9);
    expect((await logs()).map((l) => l.clientUuid), ['a-1']);
  });

  test('đăng xuất "xoá dữ liệu" rồi lượt gửi xong muộn ⇒ không ghi lại dòng cho người đã xoá', () async {
    await db.setOwner(5);
    expect(await db.clearUserData(), isTrue);
    await db.logDirectSend(entity: 'customer', op: 'update', clientUuid: 'late', ownerUserId: 5);
    final all = await db.customSelect('SELECT COUNT(*) AS n FROM sync_sent_logs').getSingle();
    expect(all.read<int>('n'), 0);
  });

  test('lượt có dòng huỷ ⇒ nhóm ghi "Đã huỷ", không hiện như lượt thường', () async {
    await db.setOwner(5);
    await db.logDirectSend(entity: 'visit', op: 'create', clientUuid: 'v-c', payload: {'dealer_name': 'ĐL Huỷ'});
    await db.logDirectSend(entity: 'visit', op: 'cancel', clientUuid: 'x-1', parentUuid: 'v-c');
    final rows = await logs();
    final groups = SyncEntityGroupHelper.groupEntries([
      for (final l in rows)
        SyncQueueEntry(
          id: -l.id,
          entity: l.entity,
          op: l.op,
          clientUuid: l.clientUuid,
          parentUuid: l.parentUuid,
          payload: l.payload,
          state: 'done',
          attempts: 0,
          createdAt: l.createdAt,
          createdElapsed: 0,
          bootId: '',
        ),
    ]);
    expect(groups.single.title, 'Lượt viếng thăm: ĐL Huỷ');
    expect(groups.single.subtitle, contains('Đã huỷ'));
  });

  test('không biết chủ (chưa ai đăng nhập) ⇒ không ghi dòng chết; khử trùng chỉ trong cùng chủ', () async {
    await db.logDirectSend(entity: 'visit', op: 'create', clientUuid: 'orphan');
    await db.setOwner(1);
    expect(await logs(), isEmpty);
    await db.logDirectSend(entity: 'customer', op: 'update', clientUuid: 'shared-outlet');
    await db.setOwner(2);
    await db.logDirectSend(entity: 'customer', op: 'update', clientUuid: 'shared-outlet');
    expect((await logs()).map((l) => l.ownerUserId), [2], reason: 'dòng của người 1 không chặn người 2');
  });

  test('sửa điểm bán hai lần (uuid mới mỗi lần) ⇒ hai dòng; dọn hạn và xoá dữ liệu người dùng gỡ cả dòng queueId 0', () async {
    await db.setOwner(1);
    await db.logDirectSend(entity: 'customer', op: 'update', clientUuid: 'edit-1', serverId: 5);
    await db.logDirectSend(entity: 'customer', op: 'update', clientUuid: 'edit-2', serverId: 5);
    expect(await logs(), hasLength(2));

    final now = DateTime.now();
    await db.customStatement(
      "UPDATE sync_sent_logs SET sent_at = ${now.subtract(const Duration(days: 61)).millisecondsSinceEpoch} WHERE client_uuid = 'edit-1'",
    );
    await db.purgeDoneEntries(now: now);
    expect((await logs()).map((l) => l.clientUuid), ['edit-2']);

    expect(await db.clearUserData(), isTrue);
    expect(await logs(), isEmpty);
  });

  test('markDone của dòng hàng đợi sau đó không coi dòng trực tuyến (queueId 0) là đã ghi', () async {
    await db.setOwner(1);
    await db.logDirectSend(entity: 'declaration', op: 'create', clientUuid: 'd-direct');
    final id = await db.enqueue(SyncQueueEntriesCompanion.insert(
      entity: 'declaration',
      op: 'create',
      clientUuid: 'd-queue',
      payload: '{}',
      createdAt: 1,
      createdElapsed: 0,
      bootId: 'b',
    ));
    await db.markDone(id);
    expect((await logs()).map((l) => l.clientUuid).toSet(), {'d-direct', 'd-queue'});
  });
}
