import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/utils/system_clock.dart';

/// Rà soát 19/11/2026: mục lỗi (dead) — 403 do quyền đang cấu hình, proxy chặn… — trước chỉ còn nút Xoá. "Gửi lại" đưa
/// về pending như mục mới; lệnh của lượt viếng thăm không gửi lại tay (thứ tự giữa các lượt do hàng đợi giữ).
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory(), 1));
  tearDown(() => db.close());

  Future<int> dead(String entity, String op, {String payload = '{}', String uuid = 'x'}) => db.enqueue(
        SyncQueueEntriesCompanion.insert(
          entity: entity,
          op: op,
          clientUuid: uuid,
          payload: payload,
          state: const Value('dead'),
          attempts: const Value(3),
          lastError: const Value('403'),
          createdAt: DateTime.now().millisecondsSinceEpoch,
          createdElapsed: SystemClock.nowMonotonicMs,
          bootId: SystemClock.bootId,
        ),
      );

  test('mục lỗi về pending, bỏ bộ đếm lỗi nội bộ', () async {
    final id = await dead('form_submission', 'create', payload: '{"a":1,"_server_failures":5,"_server_failure_first_ms":1}');
    expect(await db.requeueDead(id), isTrue);
    final row = (await db.getEntryById(id))!;
    expect(row.state, 'pending');
    expect(row.attempts, 0);
    expect(row.lastError, isNull);
    expect(row.payload, '{"a":1}');
  });

  test('lệnh lượt viếng thăm và mục không còn dead thì không gửi lại', () async {
    final v = await dead('visit', 'checkout', uuid: 'v');
    expect(await db.requeueDead(v), isFalse);
    expect((await db.getEntryById(v))!.state, 'dead');
    final p = await dead('visit_photo', 'upload', uuid: 'p');
    expect(await db.requeueDead(p), isTrue);
    expect(await db.requeueDead(p), isFalse, reason: 'đã là pending');
  });
}
