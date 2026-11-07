import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/screens/sync_report_screen.dart';

class _FakeConnectivity extends ConnectivityNotifier {
  _FakeConnectivity() {
    state = ConnectivityState(isOnline: true);
  }

  @override
  Future<bool> checkConnectivity() async => true;
}

/// Màn "Báo cáo gửi dữ liệu" (07/11/2026): nhật ký mục đã gửi giữ 30 ngày, ghi lúc markDone.
void main() {
  group('Nhật ký đã gửi (SyncSentLogs)', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<int> enqueue(String uuid, {String entity = 'declaration', int? owner}) =>
        db.enqueue(SyncQueueEntriesCompanion.insert(
          entity: entity,
          op: 'create',
          clientUuid: uuid,
          payload: '{"reason_name":"Kho"}',
          createdAt: 1000,
          createdElapsed: 0,
          bootId: 'b',
          ownerUserId: owner == null ? const Value.absent() : Value(owner),
        ));

    Future<List<SyncSentLog>> logs() => db.watchSentLogs(fromMs: 0).first;

    test('markDone ghi MỘT dòng nhật ký, gọi lại không ghi trùng', () async {
      await db.setOwner(5);
      final id = await enqueue('d-1');
      expect(await db.markDone(id, serverId: 99), isTrue);
      expect(await db.markDone(id, serverId: 99), isTrue);

      final rows = await logs();
      expect(rows, hasLength(1));
      expect(rows.single.clientUuid, 'd-1');
      expect(rows.single.serverId, 99);
      expect(rows.single.ownerUserId, 5);
      expect(rows.single.createdAt, 1000);
    });

    test('chỉ thấy nhật ký của người đang đăng nhập; đăng xuất xoá dữ liệu thì xoá nhật ký của họ', () async {
      await db.setOwner(1);
      await db.markDone(await enqueue('mine'));
      await db.markDone(await enqueue('theirs', owner: 2));
      expect((await logs()).map((l) => l.clientUuid), ['mine']);

      expect(await db.clearUserData(), isTrue);
      expect(await logs(), isEmpty);
      await db.setOwner(2);
      expect((await logs()).map((l) => l.clientUuid), ['theirs'], reason: 'nhật ký người khác giữ nguyên');
    });

    test('mục done bị lùi về pending rồi gửi lại ⇒ vẫn MỘT dòng nhật ký', () async {
      await db.setOwner(5);
      final id = await enqueue('d-retry');
      await db.markDone(id);
      await db.customStatement("UPDATE sync_queue_entries SET state = 'pending' WHERE id = $id");
      await db.markDone(id);
      expect(await logs(), hasLength(1));
    });

    test('nhật ký chủ -1 (chép từ bản cũ lúc nâng cấp) giao cho người đăng nhập đầu tiên', () async {
      await db.setOwner(5);
      await db.markDone(await enqueue('legacy'));
      await db.customStatement('UPDATE sync_sent_logs SET owner_user_id = -1');
      await db.setOwner(8);
      expect((await logs()).map((l) => l.ownerUserId), [8]);
    });

    test('dọn cắt theo 0h: ngày cũ nhất màn hình cho xem còn đủ', () async {
      await db.setOwner(1);
      await db.markDone(await enqueue('early'));
      final now = DateTime(2026, 11, 7, 15);
      final oldestDay = DateTime(2026, 11, 7).subtract(AppDatabase.sentLogRetention);
      await db.customStatement(
        'UPDATE sync_sent_logs SET sent_at = ${oldestDay.add(const Duration(hours: 8)).millisecondsSinceEpoch}',
      );
      await db.purgeDoneEntries(now: now);
      expect(await logs(), hasLength(1), reason: '8h của ngày cũ nhất vẫn giữ dù lúc dọn là 15h');
    });

    test('dọn nhật ký quá 30 ngày, giữ phần còn hạn', () async {
      await db.setOwner(1);
      await db.markDone(await enqueue('old'));
      await db.markDone(await enqueue('new'));
      final now = DateTime.now();
      await db.customStatement(
        "UPDATE sync_sent_logs SET sent_at = ${now.subtract(const Duration(days: 31)).millisecondsSinceEpoch} "
        "WHERE client_uuid = 'old'",
      );

      await db.purgeDoneEntries(now: now);
      expect((await logs()).map((l) => l.clientUuid), ['new']);
    });
  });

  test('nâng cấp từ schema 6 ⇒ có bảng nhật ký, mục done còn trong hàng đợi vào nhật ký', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      raw.execute('''
        CREATE TABLE sync_queue_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT, entity TEXT NOT NULL, op TEXT NOT NULL, client_uuid TEXT NOT NULL,
          parent_uuid TEXT, payload TEXT NOT NULL, local_path TEXT, state TEXT NOT NULL DEFAULT 'pending',
          attempts INTEGER NOT NULL DEFAULT 0, next_attempt_at INTEGER, last_error TEXT, created_at INTEGER NOT NULL,
          created_elapsed INTEGER NOT NULL, boot_id TEXT NOT NULL, server_id INTEGER, owner_user_id INTEGER)
      ''');
      raw.execute('''
        CREATE TABLE local_customers (
          id INTEGER, client_uuid TEXT NOT NULL PRIMARY KEY, code TEXT NOT NULL DEFAULT '', name TEXT NOT NULL,
          name_unaccent TEXT NOT NULL, customer_type_id INTEGER, type TEXT NOT NULL DEFAULT '', channel_id INTEGER,
          channel_name TEXT, region_id INTEGER, route TEXT NOT NULL DEFAULT 'Tuyến mặc định', address TEXT NOT NULL,
          province_name TEXT, ward_name TEXT, contact_person TEXT NOT NULL, contact_title TEXT, phone TEXT NOT NULL,
          email TEXT, lat REAL, lng REAL, geofence_radius_m INTEGER, status TEXT NOT NULL DEFAULT 'active',
          approval_status TEXT NOT NULL DEFAULT 'pending', dynamic_fields_json TEXT NOT NULL DEFAULT '{}',
          sync_status TEXT NOT NULL DEFAULT 'pending', created_at TEXT, updated_at TEXT, owner_user_id INTEGER)
      ''');
      raw.execute(
        "INSERT INTO sync_queue_entries (entity, op, client_uuid, payload, state, next_attempt_at, created_at, "
        "created_elapsed, boot_id, server_id, owner_user_id) VALUES "
        "('visit', 'create', 'v-done', '{}', 'done', 5000, 1000, 0, 'b', 42, 7), "
        "('visit', 'create', 'v-pending', '{}', 'pending', NULL, 1000, 0, 'b', NULL, 7)",
      );
      raw.execute('PRAGMA user_version = 6');
    });
    final db = AppDatabase(executor, 7);
    addTearDown(db.close);

    final rows = await db.watchSentLogs(fromMs: 0).first;
    expect(rows.map((l) => l.clientUuid), ['v-done']);
    expect(rows.single.sentAt, 5000);
    expect(rows.single.serverId, 42);
  });

  group('Màn Báo cáo gửi dữ liệu', () {
    SyncSentLog sent(int id, String entity, String payload, DateTime at) => SyncSentLog(
          id: id,
          queueId: id,
          entity: entity,
          op: 'create',
          clientUuid: 'u-$id',
          payload: payload,
          createdAt: at.millisecondsSinceEpoch,
          sentAt: at.millisecondsSinceEpoch,
        );

    Future<void> pump(WidgetTester tester, {List<SyncSentLog> logs = const [], List<SyncQueueEntry> pending = const []}) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingSyncCountProvider.overrideWith((ref) => Stream.value(pending.length)),
            allPendingQueueEntriesProvider.overrideWith((ref) => Stream.value(pending)),
            deadQueueEntriesProvider.overrideWith((ref) => Stream.value(const [])),
            sentLogsProvider.overrideWith((ref) => Stream.value(logs)),
            connectivityProvider.overrideWith((ref) => _FakeConnectivity()),
          ],
          child: const MaterialApp(home: SyncReportScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('không còn hàng chờ ⇒ "Đã gửi hết"; mục gửi hôm nay hiện kèm giờ, hôm qua thì không', (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 0, 5);
      final yesterday = today.subtract(const Duration(days: 1));
      await pump(tester, logs: [
        sent(1, 'declaration', '{"reason_name":"Kho tổng"}', today),
        sent(2, 'form_submission', '{"title":"Khảo sát hôm qua"}', yesterday),
      ]);

      expect(find.text('Đã gửi hết dữ liệu'), findsOneWidget);
      expect(find.text('Khai báo vị trí: Kho tổng'), findsOneWidget);
      expect(find.text('00:05'), findsOneWidget);
      expect(find.text('Khảo sát hôm qua'), findsNothing);

      // Lùi một ngày ⇒ thấy mục hôm qua
      await tester.tap(find.byTooltip('Ngày trước'));
      await tester.pumpAndSettle();
      expect(find.text('Khảo sát hôm qua'), findsOneWidget);
      expect(find.text('Khai báo vị trí: Kho tổng'), findsNothing);
    });

    testWidgets('còn mục chờ ⇒ báo số chưa gửi + nút gửi ngay', (tester) async {
      final pending = SyncQueueEntry(
        id: 9,
        entity: 'declaration',
        op: 'create',
        clientUuid: 'p-9',
        payload: '{"reason_name":"Đại lý A"}',
        state: 'pending',
        attempts: 0,
        createdAt: 0,
        createdElapsed: 0,
        bootId: 'b',
      );
      await pump(tester, pending: [pending]);

      expect(find.text('Còn 1 mục chưa gửi'), findsOneWidget);
      expect(find.text('Gửi dữ liệu ngay'), findsOneWidget);
      expect(find.text('Khai báo vị trí: Đại lý A'), findsOneWidget);
      expect(find.text('Không có dữ liệu nào gửi lên trong ngày này.'), findsOneWidget);
    });
  });
}
