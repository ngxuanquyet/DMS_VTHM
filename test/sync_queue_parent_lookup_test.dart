import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/database/app_database.dart';

/// Mục chờ gửi kẹt (#24401): tra mục cha theo clientUuid không nổ khi dòng sửa điểm bán trùng clientUuid với dòng tạo.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory(), 1));
  tearDown(() => db.close());

  Future<int> enqueue(String entity, String uuid, {String? parent, String op = 'create'}) =>
      db.enqueue(SyncQueueEntriesCompanion.insert(
        entity: entity,
        op: op,
        clientUuid: uuid,
        parentUuid: Value(parent),
        payload: '{}',
        createdAt: 0,
        createdElapsed: 0,
        bootId: 'b',
      ));

  test('getEntryByClientUuid: dòng sửa trùng clientUuid ⇒ trả dòng tạo, không ném', () async {
    final createId = await enqueue('customer', 'c1');
    await enqueue('customer', 'c1', op: 'update');

    expect((await db.getEntryByClientUuid('c1'))?.id, createId);
  });
}
