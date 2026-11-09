import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Bảng hàng đợi đồng bộ ngoại tuyến (§3.1 SPEC-DONG-BO-OFFLINE-2026-09-15.md)
class SyncQueueEntries extends Table {
  IntColumn get id => integer().autoIncrement()(); // thứ tự FIFO
  TextColumn get entity => text()(); // 'customer' | 'visit' | 'declaration' | 'form_submission' | 'photo'
  TextColumn get op => text()(); // 'create' | 'checkout' | 'attach_photo'
  TextColumn get clientUuid => text()(); // khoá chống trùng của CHÍNH mục này
  TextColumn get parentUuid => text().nullable()(); // uuid của bản ghi cha phải vào server trước
  TextColumn get payload => text()(); // JSON đóng gói SẴN lúc nhập, KHÔNG dựng lại lúc gửi
  TextColumn get localPath => text().nullable()(); // chỉ với 'photo': đường dẫn tệp trên máy
  TextColumn get state => text().withDefault(const Constant('pending'))(); // 'pending' | 'sending' | 'done' | 'dead'
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get nextAttemptAt => integer().nullable()(); // epoch ms; bộ gửi bỏ qua mục chưa tới hạn — dòng done: lúc gửi xong
  TextColumn get lastError => text().nullable()();
  IntColumn get createdAt => integer()(); // epoch ms theo ĐỒNG HỒ MÁY lúc nhập
  IntColumn get createdElapsed => integer()(); // ĐỒNG HỒ ĐƠN ĐIỆU (monotonic) lúc nhập (§6.3)
  TextColumn get bootId => text()(); // định danh lần khởi động máy
  IntColumn get serverId => integer().nullable()(); // id server trả về khi thành công
  // usr_user.id của người nhập mục (#24400) — chỉ người đó gửi/thấy/dọn mục này; máy dùng chung không gửi dữ liệu
  // người trước dưới tên người sau. -1 = dòng của bản app cũ (đánh dấu lúc nâng cấp, người đăng nhập kế tiếp nhận
  // về); NULL = nhập khi chưa ai đăng nhập trong lần chạy này (không ai gửi).
  IntColumn get ownerUserId => integer().nullable()();
}

/// Nhật ký mục ĐÃ GỬI lên máy chủ — nguồn màn "Báo cáo gửi dữ liệu" (nhân viên tự soát dữ liệu trong ngày đã lên hết
/// chưa). Hai đường ghi: dòng hàng đợi `done` (chỉ giữ [AppDatabase.doneRetention]) chép ra đây lúc [AppDatabase.markDone];
/// mục gửi TRỰC TUYẾN (không qua hàng đợi) ghi bằng [AppDatabase.logDirectSend] với `queueId = 0`. Giữ
/// [AppDatabase.sentLogRetention]. Cột trùng nghĩa cột hàng đợi để màn báo cáo gom nhóm bằng cùng
/// [SyncEntityGroupHelper]; chỉ ghi thông tin, KHÔNG giữ tệp ảnh. `payload` chỉ giữ các trường màn báo cáo đọc
/// ([AppDatabase.sentLogPayloadKeys]) — không mang toạ độ / câu trả lời biểu mẫu suốt hạn giữ.
class SyncSentLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get queueId => integer()(); // id dòng hàng đợi đã gửi (một dòng chỉ ghi một lần); 0 = gửi trực tuyến, không có dòng hàng đợi
  TextColumn get entity => text()();
  TextColumn get op => text()();
  TextColumn get clientUuid => text()();
  TextColumn get parentUuid => text().nullable()();
  TextColumn get payload => text()();
  IntColumn get createdAt => integer()(); // epoch ms lúc nhập (đồng hồ máy)
  IntColumn get sentAt => integer()(); // epoch ms lúc máy chủ nhận xong
  IntColumn get serverId => integer().nullable()();
  IntColumn get ownerUserId => integer().nullable()();
}

/// Bảng lưu trữ khách hàng ngoại tuyến trên SQLite (§7 SPEC-DONG-BO-OFFLINE-2026-09-15.md)
class LocalCustomers extends Table {
  IntColumn get id => integer().nullable()(); // ID trên server
  TextColumn get clientUuid => text()(); // UUID v4 sinh lúc nhập (BB-2)
  TextColumn get code => text().withDefault(const Constant(''))();
  TextColumn get name => text()();
  TextColumn get nameUnaccent => text()(); // Cột không dấu phục vụ tìm kiếm offline (§7.4)
  IntColumn get customerTypeId => integer().nullable()();
  TextColumn get type => text().withDefault(const Constant(''))();
  IntColumn get channelId => integer().nullable()();
  TextColumn get channelName => text().nullable()();
  IntColumn get regionId => integer().nullable()();
  TextColumn get route => text().withDefault(const Constant('Tuyến mặc định'))();
  TextColumn get address => text()();
  TextColumn get provinceName => text().nullable()();
  TextColumn get wardName => text().nullable()();
  TextColumn get contactPerson => text()();
  TextColumn get contactTitle => text().nullable()();
  TextColumn get phone => text()();
  TextColumn get email => text().nullable()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  IntColumn get geofenceRadiusM => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  TextColumn get approvalStatus => text().withDefault(const Constant('pending'))(); // §5.4: điểm bán tạo offline mang trạng thái pending
  TextColumn get dynamicFieldsJson => text().withDefault(const Constant('{}'))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))(); // 'synced' | 'pending' | 'error'
  TextColumn get createdAt => text().nullable()();
  TextColumn get updatedAt => text().nullable()();
  // Tài khoản (usr_user.id) mà dòng này thuộc về — máy dùng chung / đổi tài khoản: người sau KHÔNG thấy điểm bán (kể cả
  // điểm bán tạo ngoại tuyến chờ gửi) của người trước (#24698 vòng 2, nhóm 3). -1 = dòng của bản app cũ (người đăng nhập
  // kế tiếp nhận về, như hàng đợi).
  IntColumn get ownerUserId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {clientUuid};
}

@DriftDatabase(tables: [SyncQueueEntries, LocalCustomers, SyncSentLogs])
class AppDatabase extends _$AppDatabase {
  /// [ownerUserId]: người đang đăng nhập ban đầu (test dựng DB trong bộ nhớ); app đặt qua [setOwner].
  AppDatabase([QueryExecutor? e, int? ownerUserId])
      : _ownerUserId = ownerUserId,
        super(e ?? _openConnection());

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createCustomerIndexes();
          await _createQueueIndexes();
          await _createCustomerOwnerIndex();
          await _createSentLogIndex();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(syncQueueEntries, syncQueueEntries.ownerUserId);
            await customStatement('UPDATE sync_queue_entries SET owner_user_id = $_legacyOwner');
          }
          if (from < 3) {
            await _createCustomerIndexes();
          }
          if (from < 4) {
            await _createQueueIndexes();
          }
          if (from < 5) {
            // Kiểm trước: bản dựng thử (và máy hạ cấp rồi nâng lại) có thể đã có cột — thêm lại là "duplicate column".
            final cols = await customSelect("SELECT name FROM pragma_table_info('local_customers')").get();
            if (!cols.any((r) => r.read<String>('name') == 'owner_user_id')) {
              await m.addColumn(localCustomers, localCustomers.ownerUserId);
              await customStatement('UPDATE local_customers SET owner_user_id = $_legacyOwner');
            }
            await _createCustomerOwnerIndex();
          }
          if (from < 6) {
            // Bản cũ gán nhầm "bị từ chối duyệt" cho điểm bán gửi lỗi (tạo hoặc sửa bị 4xx). "Từ chối" thật chỉ đến từ dữ
            // liệu máy chủ, dòng khi đó là 'synced' — dòng 'error' mang 'rejected' đều do app gán ⇒ trả về chờ duyệt.
            // Chưa từng lên máy chủ (id NULL) ⇒ chờ duyệt; đã có trên máy chủ (lỗi khi SỬA) ⇒ trạng thái gốc không còn, lấy
            // "đã duyệt" — gần đúng nhất cho điểm bán đang dùng; lần tải danh sách sau máy chủ ghi lại đúng.
            await customStatement(
              "UPDATE local_customers SET approval_status = CASE WHEN id IS NULL THEN 'pending' ELSE 'approved' END "
              "WHERE sync_status = 'error' AND approval_status = 'rejected'",
            );
          }
          if (from < 7) {
            await m.createTable(syncSentLogs);
            await _createSentLogIndex();
            // Mục đã gửi còn trong hàng đợi (≤ doneRetention) vào nhật ký luôn — báo cáo hôm nay/hôm qua không trống sau nâng cấp.
            // customSelect chọn ĐÚNG cột của schema 7 — select typed dùng định nghĩa bảng MỚI NHẤT, schema sau thêm cột hàng
            // đợi thì máy nâng thẳng từ < 7 vỡ "no such column" ở bước này.
            final done = await customSelect(
              'SELECT id, entity, op, client_uuid, parent_uuid, payload, next_attempt_at, created_at, server_id, '
              "owner_user_id FROM sync_queue_entries WHERE state = 'done'",
            ).get();
            for (final r in done) {
              final createdAt = r.read<int>('created_at');
              await into(syncSentLogs).insert(_sentLogOf(
                SyncQueueEntry(
                  id: r.read<int>('id'),
                  entity: r.read<String>('entity'),
                  op: r.read<String>('op'),
                  clientUuid: r.read<String>('client_uuid'),
                  parentUuid: r.readNullable<String>('parent_uuid'),
                  payload: r.read<String>('payload'),
                  state: 'done',
                  attempts: 0,
                  createdAt: createdAt,
                  createdElapsed: 0,
                  bootId: '',
                  serverId: r.readNullable<int>('server_id'),
                  ownerUserId: r.readNullable<int>('owner_user_id'),
                ),
                sentAt: r.readNullable<int>('next_attempt_at') ?? createdAt,
              ));
            }
          }
        },
      );

  /// Index tra điểm bán theo id máy chủ / mã khi ghi cache — khoá chính chỉ là `client_uuid`, thiếu hai index này
  /// thì mỗi dòng trong lượt đồng bộ quét cả bảng (2.000 điểm bán ⇒ hàng triệu lượt so).
  Future<void> _createCustomerIndexes() async {
    await customStatement('CREATE INDEX IF NOT EXISTS idx_local_customers_id ON local_customers (id)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_local_customers_code ON local_customers (code)');
  }

  /// Index lọc điểm bán theo chủ ([isMyCustomer]) — schema 5.
  Future<void> _createCustomerOwnerIndex() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_local_customers_owner ON local_customers (owner_user_id, sync_status)',
    );
  }

  /// Index hàng đợi: mọi truy vấn theo tập lọc `owner_user_id` + `state` (đếm/liệt kê/gửi — badge trên thanh trên cùng
  /// đếm lại sau MỖI lần ghi hàng đợi); liên kết cha–con tra theo `client_uuid` / `parent_uuid`. Thiếu index thì mỗi
  /// lượt quét cả bảng, kể cả dòng `done` chưa tới hạn dọn.
  Future<void> _createQueueIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_owner_state ON sync_queue_entries (owner_user_id, state, id)',
    );
    await customStatement('CREATE INDEX IF NOT EXISTS idx_sync_queue_client_uuid ON sync_queue_entries (client_uuid)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_sync_queue_parent_uuid ON sync_queue_entries (parent_uuid)');
  }

  /// Index nhật ký đã gửi: màn báo cáo lọc theo chủ + khoảng ngày gửi — schema 7.
  Future<void> _createSentLogIndex() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_sent_logs_owner_sent ON sync_sent_logs (owner_user_id, sent_at)',
    );
  }

  /// Người đang đăng nhập (usr_user.id) — AuthViewModel đặt lúc đăng nhập/khôi phục phiên, xoá lúc đăng xuất.
  /// Hàng đợi chỉ gửi/đếm/liệt kê/dọn dòng của người này; chưa đăng nhập thì không thấy dòng nào.
  int? _ownerUserId;

  /// Người đăng nhập gần nhất trong lần chạy này — mục nhập MUỘN ngay sau đăng xuất (ảnh đang nén, lượt chấm đang lưu)
  /// vẫn là của người vừa đăng xuất, không thành "vô chủ".
  int? _lastOwnerUserId;

  /// Dấu dòng của bản app cũ (trước khi có cột chủ) — đặt lúc nâng cấp schema 1 → 2.
  static const _legacyOwner = -1;

  int? get ownerUserId => _ownerUserId;

  /// Người đang đăng nhập, hoặc — trong lúc đăng xuất — người vừa đăng nhập gần nhất (chủ mặc định của [enqueue]).
  int? get ownerOrLastUserId => _ownerUserId ?? _lastOwnerUserId;

  /// Người dùng đã TỰ đăng xuất kèm xoá dữ liệu của họ ([clearUserData]) kể từ lần đăng nhập gần nhất — lượt chấm công về
  /// muộn không được xếp lại vào máy (#24698 vòng 3). Đăng nhập lại ([setOwner]) thì về false.
  bool get userDataClearedSinceLogin => _userDataCleared;
  bool _userDataCleared = false;

  /// Đặt người đang đăng nhập; dòng của bản app cũ ([_legacyOwner]) giao cho người đăng nhập đầu tiên sau nâng cấp
  /// (bản cũ vốn gửi chúng bằng token của bất kỳ ai — không tệ hơn).
  Future<void> setOwner(int? userId) async {
    _ownerUserId = userId;
    if (userId != null) {
      _lastOwnerUserId = userId;
      _userDataCleared = false;
      await transaction(() async {
        await (update(syncQueueEntries)..where((t) => t.ownerUserId.equals(_legacyOwner)))
            .write(SyncQueueEntriesCompanion(ownerUserId: Value(userId)));
        // Nhật ký đã gửi chép từ dòng bản cũ lúc nâng cấp schema 7 cũng mang -1 ⇒ giao cùng người.
        await (update(syncSentLogs)..where((t) => t.ownerUserId.equals(_legacyOwner)))
            .write(SyncSentLogsCompanion(ownerUserId: Value(userId)));
        // Điểm bán: dòng bản cũ (-1) như hàng đợi; dòng vô chủ (NULL — ghi khi chưa ai đăng nhập trong lần chạy) chỉ nhận
        // phần ĐÃ đồng bộ (bộ đệm): dòng chờ gửi vô chủ đi cùng dòng hàng đợi vô chủ, hàng đợi không giao nó cho ai.
        await (update(localCustomers)
              ..where((t) =>
                  t.ownerUserId.equals(_legacyOwner) | (t.ownerUserId.isNull() & t.syncStatus.equals('synced'))))
            .write(LocalCustomersCompanion(ownerUserId: Value(userId)));
        // MỘT chủ một lúc (chủ hệ thống chốt 03/11/2026, #24698 nhóm 3): bộ đệm điểm bán đã đồng bộ của tài khoản khác bỏ
        // hẳn (họ vào lại thì tải lại); điểm bán họ tạo / sửa ngoại tuyến còn chờ gửi GIỮ, ẩn qua [isMyCustomer].
        await (delete(localCustomers)
              ..where((t) => t.syncStatus.equals('synced') & t.ownerUserId.equals(userId).not()))
            .go();
      });
      // Chạy nền: lần đầu sau nâng cấp có thể dọn hàng trăm tệp — đừng bắt đăng nhập chờ.
      unawaited(purgeDoneEntries().catchError((Object e) {
        debugPrint('[AppDatabase] Lỗi dọn mục đã gửi: $e');
        return 0;
      }));
    }
  }

  /// Vế lọc "dòng của người đang đăng nhập" — MỌI truy vấn hàng đợi theo tập (gửi, đếm, liệt kê, dọn, gộp) phải đi qua
  /// đây. Chưa đăng nhập ⇒ không dòng nào.
  Expression<bool> isMine(SyncQueueEntries t) => _ownedByMe(t.ownerUserId);

  /// Vế lọc "điểm bán trong máy của người đang đăng nhập" — mọi truy vấn điểm bán theo TẬP (liệt kê, tìm, đếm, đối chiếu,
  /// dọn) phải đi qua đây. Chưa đăng nhập ⇒ không dòng nào.
  Expression<bool> isMyCustomer(LocalCustomers t) => _ownedByMe(t.ownerUserId);

  /// Dòng điểm bán của [owner] khi nơi gọi đã chốt chủ, không thì của người đang đăng nhập.
  Expression<bool> _ownedBy(LocalCustomers t, int? owner) =>
      owner == null ? isMyCustomer(t) : t.ownerUserId.equals(owner);

  Expression<bool> _ownedByMe(Expression<int> ownerColumn) {
    final owner = _ownerUserId;
    return owner == null ? const Constant(false) : ownerColumn.equals(owner);
  }

  // ===========================================================================
  // SYNC QUEUE OPERATIONS (§3 & §8 SPEC-DONG-BO-OFFLINE)
  // ===========================================================================

  /// Hồi phục các mục 'sending' mồ côi về 'pending' khi khởi động hoặc cưỡng chế đồng bộ (§3.3 Luật 5)
  /// TUYỆT ĐỐI không hồi phục các mục 'dead' (lỗi 4xx) vì đó là lỗi hỏng vĩnh viễn (§3.2, §3.3 Luật 1).
  Future<int> recoverOrphanedSendingEntries({bool resetPendingBackoff = false}) {
    final query = update(syncQueueEntries);
    if (resetPendingBackoff) {
      query.where((tbl) => tbl.state.equals('sending') | tbl.state.equals('pending'));
    } else {
      query.where((tbl) => tbl.state.equals('sending'));
    }
    return query.write(const SyncQueueEntriesCompanion(
      state: Value('pending'),
      attempts: Value(0),
      nextAttemptAt: Value(null),
    ));
  }

  /// Lấy các mục pending có thể gửi theo thứ tự FIFO (§3.3 Luật 1 & 6)
  /// TUYỆT ĐỐI KHÔNG lấy các mục 'dead' (lỗi 4xx là hỏng vĩnh viễn, không retry).
  /// Nếu [force] = true: lấy tất cả các mục pending/sending mà không cần đợi nextAttemptAt (người dùng bấm đồng bộ thủ công).
  /// [afterId]: trang kế — chỉ lấy mục có id lớn hơn (lô bỏ qua mục đang bị hoãn thì đọc tiếp, không để chúng chiếm chỗ).
  Future<List<SyncQueueEntry>> getPendingQueueEntries({int limit = 50, bool force = false, int? afterId}) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return (select(syncQueueEntries)
          ..where((tbl) =>
              isMine(tbl) &
              (afterId != null ? tbl.id.isBiggerThanValue(afterId) : const Constant(true)) &
              (force
                  ? (tbl.state.equals('pending') | tbl.state.equals('sending'))
                  : (tbl.state.equals('pending') &
                      (tbl.nextAttemptAt.isNull() | tbl.nextAttemptAt.isSmallerOrEqualValue(nowMs)))))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.id)])
          ..limit(limit))
        .get();
  }

  /// Thêm 1 mục vào hàng đợi đồng bộ (§3.1) — tự gắn người đang đăng nhập nếu nơi gọi không ghi.
  Future<int> enqueue(SyncQueueEntriesCompanion entry) {
    final owned =
        entry.ownerUserId.present ? entry : entry.copyWith(ownerUserId: Value(_ownerUserId ?? _lastOwnerUserId));
    return into(syncQueueEntries).insert(owned);
  }

  /// Ghi lại payload của một mục (vd bộ đếm lỗi máy chủ của thao tác vật tư).
  Future<void> updatePayload(int id, String payload) async {
    await (update(syncQueueEntries)..where((tbl) => tbl.id.equals(id)))
        .write(SyncQueueEntriesCompanion(payload: Value(payload)));
  }

  /// Dòng TẠO điểm bán [clientUuid] trong hàng đợi (mọi trạng thái), null nếu không có.
  Future<SyncQueueEntry?> findCustomerCreateRow(String clientUuid) {
    return (select(syncQueueEntries)
          ..where((tbl) => tbl.entity.equals('customer') & tbl.op.equals('create') & tbl.clientUuid.equals(clientUuid))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.id)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Đánh dấu mục đang gửi — CHỈ khi dòng còn chờ gửi (pending, hoặc sending mồ côi lúc cưỡng chế). Trả false khi dòng
  /// đã bị xoá / đổi trạng thái sau lúc lô nạp vào RAM (vd người dùng huỷ lượt chưa gửi) ⇒ nơi gọi KHÔNG được gửi nó.
  Future<bool> markSending(int id) async {
    final updated = await (update(syncQueueEntries)
          ..where((tbl) => tbl.id.equals(id) & (tbl.state.equals('pending') | tbl.state.equals('sending'))))
        .write(const SyncQueueEntriesCompanion(state: Value('sending')));
    return updated > 0;
  }

  /// Đánh dấu mục đã gửi thành công (§3.2, §4.3)
  /// Lần đầu chuyển sang done thì chép vào nhật ký đã gửi ([SyncSentLogs]) trong CÙNG transaction.
  Future<bool> markDone(int id, {int? serverId}) => transaction(() async {
        final row = await getEntryById(id);
        if (row == null) return false;
        final sentAt = DateTime.now().millisecondsSinceEpoch;
        final updated = await (update(syncQueueEntries)..where((tbl) => tbl.id.equals(id))).write(
          SyncQueueEntriesCompanion(
            state: const Value('done'),
            serverId: Value(serverId),
            // Dòng done không còn lịch thử lại ⇒ dùng cột này ghi LÚC GỬI XONG cho [purgeDoneEntries].
            nextAttemptAt: Value(sentAt),
          ),
        );
        // Chặn trùng theo queue_id (không chỉ theo state): mục đã done mà bị lùi về pending (lỗi SAU markDone) gửi lại thì
        // vẫn chỉ một dòng nhật ký.
        final logged = await (select(syncSentLogs)
          ..where((t) => t.queueId.equals(id))
          ..limit(1)).getSingleOrNull();
        if (updated > 0 && logged == null) {
          await into(syncSentLogs).insert(_sentLogOf(row, sentAt: sentAt, serverId: serverId));
        }
        return updated > 0;
      });

  /// Ghi nhật ký đã gửi cho mục gửi TRỰC TUYẾN (không qua hàng đợi). Màn "Báo cáo gửi dữ liệu" phải hiện MỌI thứ đã
  /// lên máy chủ trong ngày — trước 09/11/2026 chỉ ghi ở [markDone] nên lượt viếng thăm / chấm công / phiếu / điểm bán
  /// gửi lúc có mạng không bao giờ xuất hiện, nhân viên tưởng dữ liệu chưa lên. `queueId = 0` (không có dòng hàng đợi).
  /// Khử trùng theo (chủ, entity, op, clientUuid): gửi lại cùng lượt (server trả bản cũ) không thêm dòng — người gọi
  /// muốn mỗi lần gửi là một dòng (sửa điểm bán nhiều lần) thì truyền uuid MỚI mỗi lần. Lỗi ghi nhật ký KHÔNG được làm
  /// hỏng nghiệp vụ đã gửi xong ⇒ nuốt lỗi, chỉ log. [ownerUserId] = người BẤM khi người gọi biết (lượt chấm công có thể
  /// xong sau khi đổi tài khoản), mặc định người đang/vừa đăng nhập; không biết ai ⇒ KHÔNG ghi (dòng chủ NULL không ai
  /// thấy, nằm chết tới hạn dọn).
  Future<void> logDirectSend({
    required String entity,
    required String op,
    required String clientUuid,
    String? parentUuid,
    Map<String, dynamic> payload = const {},
    int? serverId,
    int? ownerUserId,
  }) async {
    try {
      final owner = ownerUserId ?? ownerOrLastUserId;
      // Không biết ai, hoặc người đó vừa đăng xuất "xoá dữ liệu" (lượt gửi xong muộn) ⇒ không ghi: dòng sẽ không ai thấy /
      // là dữ liệu của người đã xoá.
      if (owner == null || _userDataCleared) return;
      await transaction(() async {
        final dup = await (select(syncSentLogs)
              ..where((t) =>
                  t.ownerUserId.equals(owner) &
                  t.entity.equals(entity) &
                  t.op.equals(op) &
                  t.clientUuid.equals(clientUuid))
              ..limit(1))
            .getSingleOrNull();
        if (dup != null) return;
        final now = DateTime.now().millisecondsSinceEpoch;
        await into(syncSentLogs).insert(SyncSentLogsCompanion.insert(
          queueId: 0,
          entity: entity,
          op: op,
          clientUuid: clientUuid,
          parentUuid: Value(parentUuid),
          payload: jsonEncode({
            for (final e in payload.entries)
              if (sentLogPayloadKeys.contains(e.key) && e.value != null) e.key: e.value,
          }),
          createdAt: now,
          sentAt: now,
          serverId: Value(serverId),
          ownerUserId: Value(owner),
        ));
      });
    } catch (e) {
      debugPrint('[AppDatabase] Không ghi được nhật ký đã gửi ($entity/$op): $e');
    }
  }

  /// Đánh dấu mục bị lỗi vĩnh viễn (4xx, 403, 422, INVALID) -> chuyển sang 'dead' (§3.2, §3.3 Luật 1)
  Future<bool> markDead(int id, String error) async {
    final updated = await (update(syncQueueEntries)..where((tbl) => tbl.id.equals(id))).write(
      SyncQueueEntriesCompanion(
        state: const Value('dead'),
        lastError: Value(error),
        nextAttemptAt: const Value(null),
      ),
    );
    return updated > 0;
  }

  /// Lùi lịch thử lại khi lỗi mạng / 5xx theo backoff (§8.2)
  Future<bool> reschedule(int id, {required int nextAttemptAt, required int attempts, String? error}) async {
    final updated = await (update(syncQueueEntries)..where((tbl) => tbl.id.equals(id))).write(
      SyncQueueEntriesCompanion(
        state: const Value('pending'),
        attempts: Value(attempts),
        nextAttemptAt: Value(nextAttemptAt),
        lastError: Value(error),
      ),
    );
    return updated > 0;
  }

  /// Đếm số mục đang chờ đồng bộ hoặc đang gửi (KHÔNG bao gồm các mục dead đã hỏng vĩnh viễn)
  Future<int> countPendingSync() async {
    final countExp = syncQueueEntries.id.count();
    final query = selectOnly(syncQueueEntries)
      ..addColumns([countExp])
      ..where(isMine(syncQueueEntries) &
          (syncQueueEntries.state.equals('pending') | syncQueueEntries.state.equals('sending')));
    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result ?? 0;
  }

  /// Stream theo dõi số mục đang chờ đồng bộ theo thời gian thực (chỉ pending & sending)
  Stream<int> watchPendingSyncCount() {
    final countExp = syncQueueEntries.id.count();
    final query = selectOnly(syncQueueEntries)
      ..addColumns([countExp])
      ..where(isMine(syncQueueEntries) &
          (syncQueueEntries.state.equals('pending') | syncQueueEntries.state.equals('sending')));
    return query.map((row) => row.read(countExp) ?? 0).watchSingle();
  }

  /// Đếm số mục lỗi hỏng vĩnh viễn (dead / 4xx)
  Future<int> countDeadSync() async {
    final countExp = syncQueueEntries.id.count();
    final query = selectOnly(syncQueueEntries)
      ..addColumns([countExp])
      ..where(isMine(syncQueueEntries) & syncQueueEntries.state.equals('dead'));
    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result ?? 0;
  }

  /// Stream theo dõi số mục lỗi vĩnh viễn (dead / 4xx)
  Stream<int> watchDeadSyncCount() {
    final countExp = syncQueueEntries.id.count();
    final query = selectOnly(syncQueueEntries)
      ..addColumns([countExp])
      ..where(isMine(syncQueueEntries) & syncQueueEntries.state.equals('dead'));
    return query.map((row) => row.read(countExp) ?? 0).watchSingle();
  }

  /// Lấy danh sách các mục lỗi hỏng vĩnh viễn (dead) để thông báo chi tiết cho người dùng
  Future<List<SyncQueueEntry>> getDeadQueueEntries() {
    return (select(syncQueueEntries)
          ..where((tbl) => isMine(tbl) & tbl.state.equals('dead'))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.id)]))
        .get();
  }

  /// Đăng xuất: xoá dữ liệu gắn với người vừa dùng máy — dòng hàng đợi CỦA NGƯỜI NÀY (dòng người khác để lại, vd đăng
  /// xuất cưỡng bức, giữ nguyên chờ đúng chủ đăng nhập lại — máy dùng chung hiếm, không xử lý thêm), điểm bán lưu
  /// trong máy, và ĐÚNG các tệp ảnh chúng trỏ tới (localPath
  /// + đường dẫn trong payload của hàng đợi, ảnh `<clientUuid>_photo_*` của điểm bán) — không xoá cả thư mục: ảnh vừa chụp mà chưa kịp vào
  /// hàng đợi (lượt viếng thăm dở, lượt chấm đang lưu) nằm chung thư mục.
  /// Đếm + xoá trong CÙNG transaction: còn mục pending/sending của người này thì KHÔNG xoá gì, trả false. Mục dead bị
  /// xoá — nơi gọi phải cảnh báo người dùng trước. Chưa đăng nhập (không rõ chủ) thì không xoá gì.
  Future<bool> clearUserData() async {
    final rows = <SyncQueueEntry>[];
    final customerUuids = <String>[];
    if (_ownerUserId == null) return false;
    final cleared = await transaction(() async {
      if (await countPendingSync() > 0) return false;
      rows.addAll(await (select(syncQueueEntries)..where(isMine)).get());
      customerUuids.addAll(rows.where((r) => r.entity == 'customer').map((r) => r.clientUuid));
      final c = selectOnly(localCustomers)
        ..addColumns([localCustomers.clientUuid])
        ..where(isMyCustomer(localCustomers));
      customerUuids.addAll((await c.map((r) => r.read(localCustomers.clientUuid)).get()).whereType<String>());
      await (delete(syncQueueEntries)..where(isMine)).go();
      await (delete(localCustomers)..where(isMyCustomer)).go();
      await (delete(syncSentLogs)..where((t) => _ownedByMe(t.ownerUserId))).go();
      return true;
    });
    if (cleared) {
      _userDataCleared = true;
      await _deleteRowFiles(rows, customerUuids);
    }
    return cleared;
  }

  /// Mọi tệp mà SQLite còn trỏ tới — hàng đợi (mọi trạng thái, mọi chủ: localPath + payload) và điểm bán trong máy
  /// (dynamicFieldsJson). Quét dọn ảnh tạm KHÔNG được xoá các tệp này.
  ///
  /// [unfinishedOnly]: chỉ dòng hàng đợi CHƯA xong, bỏ dòng [exceptId] — tệp còn CẦN sau khi dòng đó gửi xong / bị xoá
  /// (lệnh đứng sau có thể trỏ CÙNG tệp: OfflinePhotoStore.persist giữ nguyên tệp đã nằm trong thư mục lưu ⇒ xoá là 410,
  /// mất cả lần sửa — #24698 vòng 4, C2).
  Future<List<String>> referencedFilePaths({bool unfinishedOnly = false, int? exceptId}) async {
    final paths = <String>[];
    final rows = select(syncQueueEntries)
      ..where((tbl) =>
          (unfinishedOnly ? tbl.state.equals('done').not() : const Constant(true)) &
          (exceptId == null ? const Constant(true) : tbl.id.equals(exceptId).not()));
    for (final row in await rows.get()) {
      if (row.localPath != null) paths.add(row.localPath!);
      try {
        collectFilePaths(jsonDecode(row.payload), paths);
      } catch (_) {}
    }
    for (final c in await select(localCustomers).get()) {
      try {
        collectFilePaths(jsonDecode(c.dynamicFieldsJson), paths);
      } catch (_) {}
    }
    return paths;
  }

  /// Ảnh của các dòng hàng đợi đã xoá: localPath + đường dẫn chỉ ghi trong payload (biểu mẫu thị trường
  /// `_local_photo_paths`, ảnh điểm bán rơi về đường dẫn tạm). Giải mã payload NGOÀI transaction — không giữ khoá DB.
  /// [keep]: tệp chỗ khác còn trỏ tới — không xoá.
  static Future<void> _deleteRowFiles(List<SyncQueueEntry> rows, List<String> customerUuids,
      {Set<String> keep = const {}}) async {
    final paths = <String>[];
    for (final row in rows) {
      if (row.localPath != null) paths.add(row.localPath!);
      try {
        collectFilePaths(jsonDecode(row.payload), paths);
      } catch (_) {}
    }
    // So theo TÊN tệp (cùng luật quét dọn ảnh tạm): một tệp có thể ghi dạng `file://…` ở dòng này, đường dẫn trần ở dòng khác.
    final keepNames = keep.map(p.basename).toSet();
    paths.removeWhere((x) => keepNames.contains(p.basename(x)));
    await _deleteUserFiles(paths, customerUuids);
  }

  static Future<void> _deleteUserFiles(List<String> queuePaths, List<String> customerUuids) async {
    final roots = <String>[];
    String? docs;
    for (final dir in [getApplicationDocumentsDirectory, getApplicationSupportDirectory, getTemporaryDirectory]) {
      try {
        final path = (await dir()).path;
        roots.add(path);
        if (dir == getApplicationDocumentsDirectory) docs = path;
      } catch (e) {
        debugPrint('[AppDatabase] Không lấy được thư mục app khi dọn ảnh: $e');
      }
    }
    final files = <String>{};
    // localPath của hàng đợi — chỉ nhận tệp trong vùng riêng của app.
    for (final raw in queuePaths) {
      try {
        final path = raw.startsWith('file://') ? Uri.parse(raw).toFilePath() : raw;
        if (roots.any((r) => p.isWithin(r, path))) files.add(path);
      } catch (_) {}
    }
    // Ảnh điểm bán do customer_local_data_source chép vào offline_customer_photos/<clientUuid>_photo_<i>.<ext> — có thể
    // mang tiền tố `wm_` (PhotoWatermarkHelper.keepMarkerName giữ dấu đã đóng watermark); bỏ sót là ảnh ở lại máy.
    if (docs != null && customerUuids.isNotEmpty) {
      try {
        final dir = Directory(p.join(docs, 'offline_customer_photos'));
        if (await dir.exists()) {
          await for (final f in dir.list()) {
            final name = p.basename(f.path);
            final bare = name.startsWith('wm_') ? name.substring(3) : name;
            if (customerUuids.any((u) => bare.startsWith('${u}_photo_') || bare.startsWith('${u}_material_'))) {
              files.add(f.path);
            }
          }
        }
      } catch (e) {
        debugPrint('[AppDatabase] Không duyệt được offline_customer_photos: $e');
      }
    }
    for (final path in files) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  /// Xóa các mục dead đã được xử lý hoặc dọn dẹp — kèm tệp ảnh của chúng. Trả số mục GIỮ LẠI vì đang giữ lượt sau
  /// ([isHoldingLaterVisit]).
  Future<int> clearDeadEntries() async {
    final rows = await (select(syncQueueEntries)..where((tbl) => isMine(tbl) & tbl.state.equals('dead'))).get();
    final held = [for (final r in rows) if (await isHoldingLaterVisit(r)) r.id];
    rows.removeWhere((r) => held.contains(r.id));
    if (rows.isEmpty) return held.length;
    await (delete(syncQueueEntries)..where((tbl) => tbl.id.isIn(rows.map((r) => r.id)))).go();
    // Lệnh sửa điểm bán đứng sau có thể trỏ CÙNG tệp ảnh (#24698 vòng 4, C2) ⇒ giữ tệp còn được tham chiếu.
    await _deleteRowFiles(rows, const [], keep: (await referencedFilePaths(unfinishedOnly: true)).toSet());
    return held.length;
  }

  /// Xoá một mục hàng đợi (người dùng bấm xoá mục lỗi) — kèm tệp ảnh của nó. `false` = không xoá (lệnh đóng lượt đang
  /// giữ lượt sau, [isHoldingLaterVisit]).
  Future<bool> deleteEntry(int id) async {
    final row = await (select(syncQueueEntries)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (row == null) return true;
    if (await isHoldingLaterVisit(row)) return false;
    await (delete(syncQueueEntries)..where((tbl) => tbl.id.equals(id))).go();
    await _deleteRowFiles([row], const [], keep: (await referencedFilePaths(unfinishedOnly: true)).toSet());
    return true;
  }

  /// Lệnh check-out / huỷ bị từ chối (dead) [row] đang cho một dòng tạo lượt SAU nó chờ không đếm trần
  /// ([hasDeadVisitCloseBefore]) ⇒ KHÔNG cho xoá: xoá đi thì lượt sau đếm trần rồi chết sau ~2 giờ, mất trọn lượt (#24698
  /// vòng 4, V3). Nhân viên đóng lại lượt cũ (lượt đang mở trên tuyến) hoặc qua ngày thì dòng hết giữ, xoá được.
  Future<bool> isHoldingLaterVisit(SyncQueueEntry row) async {
    if (row.state != 'dead' || row.entity != 'visit' || (row.op != 'checkout' && row.op != 'cancel')) return false;
    final creates = await (select(syncQueueEntries)
          ..where((t) =>
              isMine(t) &
              t.id.isBiggerThanValue(row.id) &
              t.entity.equals('visit') &
              t.op.equals('create') &
              (t.state.equals('pending') | t.state.equals('sending'))))
        .get();
    for (final c in creates) {
      if (await hasDeadVisitCloseBefore(c, onlyCloseId: row.id)) return true;
    }
    return false;
  }

  /// Giữ mục đã gửi bao lâu trước khi dọn: dòng done là nguồn tra clientUuid → serverId cho việc làm MUỘN sau khi gửi
  /// (ảnh chấm công bổ sung, huỷ lượt đã đồng bộ, check-out ngay sau đồng bộ); ảnh vừa gửi còn được lịch sử offline
  /// hiển thị tới khi tải lại từ máy chủ.
  static const doneRetention = Duration(days: 2);

  /// Giữ nhật ký đã gửi ([SyncSentLogs]) bao lâu — màn "Báo cáo gửi dữ liệu" xem lại được chừng ấy ngày (chủ hệ thống
  /// chốt 60 ngày, 07/11/2026). Chỉ là thông tin chữ, không giữ tệp ảnh; quá hạn tự xoá ở [purgeDoneEntries].
  static const sentLogRetention = Duration(days: 60);

  /// Trường payload mà [SyncEntityGroupHelper] đọc để đặt tên nhóm — nhật ký chỉ giữ chừng này.
  static const sentLogPayloadKeys = {'dealer_name', 'visit_id', 'name', 'address', 'route', 'title', 'form_code', 'reason_name'};

  /// Dòng nhật ký đã gửi của một dòng hàng đợi: payload gọt còn [sentLogPayloadKeys] (hỏng JSON ⇒ `{}`).
  static SyncSentLogsCompanion _sentLogOf(SyncQueueEntry row, {required int sentAt, int? serverId}) {
    var payload = '{}';
    try {
      final decoded = jsonDecode(row.payload);
      if (decoded is Map<String, dynamic>) {
        payload = jsonEncode({
          for (final e in decoded.entries)
            if (sentLogPayloadKeys.contains(e.key) && e.value != null) e.key: e.value,
        });
      }
    } catch (_) {}
    return SyncSentLogsCompanion.insert(
      queueId: row.id,
      entity: row.entity,
      op: row.op,
      clientUuid: row.clientUuid,
      parentUuid: Value(row.parentUuid),
      payload: payload,
      createdAt: row.createdAt,
      sentAt: sentAt,
      serverId: Value(serverId ?? row.serverId),
      ownerUserId: Value(row.ownerUserId),
    );
  }

  /// Dọn mục ĐÃ GỬI XONG (done) của người đang đăng nhập quá [doneRetention] — hàng đợi không phình mãi. CHỈ xoá dòng:
  /// tệp ảnh của chúng có thể còn được lịch sử trong máy hiển thị (lịch sử chấm công trỏ url = đường dẫn máy) — để
  /// LocalHistoryRetention.sweepPhotoFiles dọn khi không còn chỗ lưu nào trỏ tới. Giữ dòng cha còn mục con chưa xong (chờ/đang gửi/lỗi):
  /// con tra serverId của cha qua dòng này. Dòng done của bản cũ (chưa ghi lúc gửi xong) tính theo lúc nhập.
  /// Gọi cuối mỗi lượt đồng bộ và lúc đặt chủ (dọn dồn từ bản cũ).
  Future<int> purgeDoneEntries({DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).subtract(doneRetention).millisecondsSinceEpoch;
    final rows = <SyncQueueEntry>[];
    await transaction(() async {
      final unfinishedParents = selectOnly(syncQueueEntries)
        ..addColumns([syncQueueEntries.parentUuid])
        ..where(syncQueueEntries.parentUuid.isNotNull() & syncQueueEntries.state.equals('done').not());
      rows.addAll(await (select(syncQueueEntries)
            ..where((t) =>
                isMine(t) &
                t.state.equals('done') &
                coalesce([t.nextAttemptAt, t.createdAt]).isSmallerThanValue(cutoff) &
                t.clientUuid.isNotInQuery(unfinishedParents)))
          .get());
      if (rows.isNotEmpty) await (delete(syncQueueEntries)..where((t) => t.id.isIn(rows.map((r) => r.id)))).go();
      // Nhật ký đã gửi quá hạn: dọn của MỌI tài khoản theo thời gian — người lâu không đăng nhập lại cũng không phình mãi.
      // Cắt theo 0h — màn báo cáo cho lùi tới đúng ngày này, cắt giữa ngày thì ngày cũ nhất hiện thiếu (tưởng chưa gửi).
      final n = now ?? DateTime.now();
      final logCutoff = DateTime(n.year, n.month, n.day).subtract(sentLogRetention).millisecondsSinceEpoch;
      await (delete(syncSentLogs)..where((t) => t.sentAt.isSmallerThanValue(logCutoff))).go();
    });
    return rows.length;
  }

  /// Khoá (mã server, client_uuid) của các điểm bán còn lệnh SỬA chưa gửi xong của [owner] — lần tải danh sách không đè
  /// các dòng này bằng bản server cũ hơn phần sửa (#24698 vòng 3). Một truy vấn cho cả lô.
  Future<({Set<int> ids, Set<String> uuids})> unsentCustomerUpdateKeys(int owner) async {
    final rows = await (select(syncQueueEntries)
          ..where((tbl) => tbl.ownerUserId.equals(owner) & _unsentCustomerUpdate(tbl)))
        .get();
    return (
      ids: {for (final r in rows) if ((r.serverId ?? 0) > 0) r.serverId!},
      uuids: {for (final r in rows) if (r.clientUuid.isNotEmpty) r.clientUuid},
    );
  }

  /// Đánh dấu điểm bán bị lỗi đồng bộ vĩnh viễn (4xx)
  /// Máy chủ từ chối DỮ LIỆU điểm bán (4xx khi gửi) ⇒ chỉ đánh dấu lỗi đồng bộ. KHÔNG đặt "bị từ chối duyệt": đó là
  /// quyết định của người duyệt trên máy chủ, gán nhầm thì điểm bán biến khỏi tuyến, mất nút Sửa (không sửa để gửi lại
  /// được) và hiện banner "bị từ chối" oan (#24698 nhóm 4).
  Future<void> markCustomerSyncError(String clientUuid, String error) async {
    await (update(localCustomers)..where((tbl) => tbl.clientUuid.equals(clientUuid))).write(
      const LocalCustomersCompanion(syncStatus: Value('error')),
    );
  }

  /// Lấy danh sách các phiếu biểu mẫu đã nộp ngoại tuyến (SyncQueue form_submission)
  Future<List<SyncQueueEntry>> getFormSubmissionEntries() {
    return (select(syncQueueEntries)
          ..where((tbl) => isMine(tbl) & tbl.entity.equals('form_submission'))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.id)]))
        .get();
  }

  /// Stream theo dõi các phiếu biểu mẫu ngoại tuyến
  Stream<List<SyncQueueEntry>> watchFormSubmissionEntries() {
    return (select(syncQueueEntries)
          ..where((tbl) => isMine(tbl) & tbl.entity.equals('form_submission'))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.id)]))
        .watch();
  }

  /// Thao tác vật tư (#24522) của một lượt viếng thăm ([visitClientUuid] = clientUuid phiên lượt), theo thứ tự bấm —
  /// để màn Vật tư và cổng check-out ngoại tuyến thấy thao tác còn nằm trên máy.
  Future<List<SyncQueueEntry>> getVisitMaterialEntries(String visitClientUuid) {
    return (select(syncQueueEntries)
          ..where((tbl) =>
              isMine(tbl) & tbl.entity.equals('visit_material') & tbl.parentUuid.equals(visitClientUuid))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.id)]))
        .get();
  }

  /// clientUuid các thao tác vật tư server đã từ chối (dead) — mọi lượt; để cache không tính chúng là "đã kiểm".
  Future<Set<String>> getDeadVisitMaterialUuids() => _visitMaterialUuidsInStates(const ['dead']);

  /// clientUuid các thao tác vật tư CHƯA lên server (pending/sending) — mọi lượt; mục Vật tư ở chi tiết điểm bán (#24707)
  /// gắn nhãn "chờ đồng bộ".
  Future<Set<String>> getOpenVisitMaterialUuids() => _visitMaterialUuidsInStates(const ['pending', 'sending']);

  /// clientUuid thao tác vật tư của người đang dùng máy có trạng thái thuộc [states] — mọi lượt.
  Future<Set<String>> _visitMaterialUuidsInStates(List<String> states) async {
    final rows = await (select(syncQueueEntries)
          ..where((tbl) => isMine(tbl) & tbl.entity.equals('visit_material') & tbl.state.isIn(states)))
        .get();
    return rows.map((r) => r.clientUuid).toSet();
  }

  /// Còn lệnh lượt viếng thăm (check-in / check-out / huỷ) CHƯA lên server (pending/sending) mà CÒN ĐI TIẾP được. Check-in
  /// trực tuyến phải chờ chúng (#24698 vòng 2): lượt trước chưa đóng trên server ⇒ lượt mới mở trước khiến lệnh của lượt
  /// trước bị từ chối "còn lượt mở" rồi chết. Bỏ qua chuỗi lượt kẹt vĩnh viễn ([_stuckVisitUuids]).
  Future<bool> hasOpenVisitLifecycleEntries() async {
    final rows = await (select(syncQueueEntries)
          ..where((tbl) =>
              isMine(tbl) & tbl.entity.equals('visit') & (tbl.state.equals('pending') | tbl.state.equals('sending'))))
        .get();
    if (rows.isEmpty) return false;
    final stuck = await _stuckVisitUuids();
    return rows.any((r) => !stuck.contains(_visitUuidOf(r)));
  }

  /// clientUuid lượt mà một dòng lệnh lượt thuộc về: dòng tạo = chính nó, check-out / huỷ = lượt cha.
  static String? _visitUuidOf(SyncQueueEntry r) => r.op == 'create' ? r.clientUuid : r.parentUuid;

  /// Lượt (clientUuid) KẸT VĨNH VIỄN: dòng tạo lượt ở điểm bán tạo ngoại tuyến mà dòng TẠO điểm bán đó đã bị server từ
  /// chối (dead) — lượt không bao giờ lên được. Hai cổng chờ (check-in trực tuyến [hasOpenVisitLifecycleEntries], dòng tạo
  /// lượt trong hàng đợi [isVisitCreateHeld]) bỏ qua chúng — không thì một điểm bán bị từ chối chặn mọi lượt về sau.
  /// Chỉ xét dòng `create` dead của điểm bán: lệnh SỬA bị từ chối (cùng clientUuid) không làm điểm bán mất id server.
  Future<Set<String>> _stuckVisitUuids() async {
    final deadCustomers = (await (select(syncQueueEntries)
              ..where((tbl) =>
                  isMine(tbl) & tbl.entity.equals('customer') & tbl.op.equals('create') & tbl.state.equals('dead')))
            .get())
        .map((r) => r.clientUuid)
        .toSet();
    if (deadCustomers.isEmpty) return const {};
    final creates = await (select(syncQueueEntries)
          ..where((tbl) =>
              isMine(tbl) &
              tbl.entity.equals('visit') &
              tbl.op.equals('create') &
              (tbl.state.equals('pending') | tbl.state.equals('sending'))))
        .get();
    return {
      for (final r in creates)
        if (deadCustomers.contains(_offlineCustomerUuidOfVisitCreate(r))) r.clientUuid,
    };
  }

  /// Mục `pending` ĐÃ TỚI LƯỢT THỬ (qua lịch thử lại) của các lượt viếng thăm (lệnh lượt + ảnh / phiếu / vật tư — mục
  /// con check-out chờ), theo thứ tự nhập. Tôn trọng lịch thử lại: đẩy ngay trước MỌI check-in trực tuyến, bỏ lịch là dội
  /// máy chủ đang lỗi + nút check-in quay tới trần chờ; mục chưa tới lượt ⇒ check-in mới đi hàng đợi (an toàn).
  /// Kèm dòng TẠO điểm bán ngoại tuyến mà dòng tạo lượt còn chờ đứng sau (không có id server thì lượt không lên được).
  /// Dòng tạo điểm bán cha được đưa vào bất kể lịch thử lại — đứng sau nó là dòng tạo lượt đã tới lượt.
  Future<List<SyncQueueEntry>> getPendingVisitLifecycleEntries() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final rows = await (select(syncQueueEntries)
          ..where((tbl) =>
              isMine(tbl) &
              (tbl.entity.equals('visit') | tbl.entity.isIn(checkoutGatedEntities)) &
              tbl.state.equals('pending') &
              (tbl.nextAttemptAt.isNull() | tbl.nextAttemptAt.isSmallerOrEqualValue(nowMs))))
        .get();
    final parents = {
      for (final r in rows.where((r) => r.entity == 'visit' && r.op == 'create')) ?_offlineCustomerUuidOfVisitCreate(r),
    };
    final customers = parents.isEmpty
        ? const <SyncQueueEntry>[]
        : await (select(syncQueueEntries)
              ..where((tbl) =>
                  isMine(tbl) &
                  tbl.entity.equals('customer') &
                  tbl.op.equals('create') &
                  tbl.state.equals('pending') &
                  tbl.clientUuid.isIn(parents)))
            .get();
    return [...rows, ...customers]..sort((a, b) => a.id.compareTo(b.id));
  }

  /// `client_uuid` điểm bán (tạo ngoại tuyến) mà một dòng tạo lượt đứng sau: `customer_client_uuid` trong payload, hoặc
  /// `parentUuid` (bản cũ).
  static String? _offlineCustomerUuidOfVisitCreate(SyncQueueEntry r) {
    try {
      final p = jsonDecode(r.payload);
      if (p is Map && p['customer_client_uuid'] != null) return p['customer_client_uuid'].toString();
    } catch (_) {}
    return r.parentUuid;
  }

  /// Mục con chặn check-out (ảnh / phiếu / vật tư — [checkoutGatedEntities]) của lượt [visitClientUuid] còn CHƯA lên
  /// server (pending/sending). Check-out trực tuyến phải đẩy chúng trước (#24698 vòng 2): gửi check-out trước thì server
  /// trả 422 thiếu ảnh/phiếu, còn bản chờ tới sau thành dead.
  Future<List<SyncQueueEntry>> getOpenCheckoutChildren(String visitClientUuid) =>
      _checkoutChildrenInStates(visitClientUuid, const ['pending', 'sending']);

  /// Mục con chặn check-out của lượt [visitClientUuid] đang `pending`, theo thứ tự nhập.
  Future<List<SyncQueueEntry>> getPendingCheckoutChildren(String visitClientUuid) =>
      _checkoutChildrenInStates(visitClientUuid, const ['pending']);

  Future<List<SyncQueueEntry>> _checkoutChildrenInStates(String visitClientUuid, List<String> states) {
    return (select(syncQueueEntries)
          ..where((tbl) =>
              isMine(tbl) &
              tbl.entity.isIn(checkoutGatedEntities) &
              tbl.parentUuid.equals(visitClientUuid) &
              tbl.state.isIn(states))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.id)]))
        .get();
  }

  /// Loại mục con mà server đếm ở cổng check-out (VisitCheckoutGuard): ảnh ③, phiếu khảo sát ②, vật tư ④.
  static const checkoutGatedEntities = ['visit_photo', 'form_submission', 'visit_material'];

  /// Mục check-out phải nhường cho ảnh / phiếu / thao tác vật tư chưa gửi của CÙNG lượt (thứ tự FIFO + lịch thử lại có
  /// thể cho check-out vượt lên ⇒ 422 thiếu ảnh/phiếu/vật tư ⇒ dead, lượt treo). Mục con đã dead không giữ; mục con
  /// [released] trả true cũng thôi giữ (SyncService: ảnh/phiếu bị máy chủ lỗi lặp quá trần — chống giữ mãi, chặn đăng xuất).
  Future<bool> isCheckoutHeld(SyncQueueEntry entry, {bool Function(SyncQueueEntry child)? released}) async {
    if (entry.entity != 'visit' || entry.op != 'checkout' || entry.parentUuid == null) return false;
    final rows = await (select(syncQueueEntries)
          ..where((tbl) =>
              isMine(tbl) &
              tbl.entity.isIn(checkoutGatedEntities) &
              tbl.parentUuid.equals(entry.parentUuid!) &
              (tbl.state.equals('pending') | tbl.state.equals('sending'))))
        .get();
    return rows.any((c) => released == null || !released(c));
  }

  /// Dòng TẠO lượt viếng thăm phải đứng sau check-out / huỷ còn chờ của lượt KHÁC nhập trước nó: server không mở lượt
  /// mới khi lượt trước còn mở (422 DMS_VISIT_STILL_OPEN). Chỉ xét `pending`: trong một lô các mục đi lần lượt nên lúc
  /// tới dòng tạo, dòng 'sending' của lượt trước chỉ có thể là mồ côi (app bị tắt giữa chừng) — giữ theo nó là kẹt tới
  /// lần khởi động sau.
  Future<bool> isVisitCreateHeld(SyncQueueEntry entry) async {
    if (entry.entity != 'visit' || entry.op != 'create') return false;
    final rows = await _otherVisitClosesBefore(entry, 'pending');
    if (rows.isEmpty) return false;
    // Lệnh của lượt kẹt vĩnh viễn (điểm bán ngoại tuyến bị từ chối) không giữ — cùng luật cổng check-in trực tuyến.
    final stuck = await _stuckVisitUuids();
    return rows.any((r) => !stuck.contains(r.parentUuid));
  }

  /// Lệnh SỬA điểm bán [entry] nhường lệnh sửa NHẬP TRƯỚC của cùng điểm bán còn chờ / đang gửi: lệnh trước bị lùi lịch
  /// (lỗi tạm) mà lệnh sau gửi trước thì lệnh trước gửi sau ĐÈ giá trị mới bằng giá trị cũ (rà soát #24698 vòng 3).
  Future<bool> isCustomerUpdateHeld(SyncQueueEntry entry) async {
    if (entry.entity != 'customer' || entry.op != 'update') return false;
    return await latestUnsentCustomerUpdate(entry.serverId ?? 0, entry.clientUuid, beforeId: entry.id) != null;
  }

  /// Lệnh SỬA điểm bán [serverId] / [clientUuid] MỚI NHẤT chưa gửi xong (chờ / đang gửi) của người đang đăng nhập;
  /// [beforeId]: chỉ xét lệnh nhập trước dòng đó. serverId 0 / mã rỗng không phải khoá (khớp nhầm điểm bán khác).
  Future<SyncQueueEntry?> latestUnsentCustomerUpdate(int serverId, String? clientUuid, {int? beforeId}) {
    return (select(syncQueueEntries)
          ..where((tbl) =>
              isMine(tbl) &
              (beforeId != null ? tbl.id.isSmallerThanValue(beforeId) : const Constant(true)) &
              _unsentCustomerUpdate(tbl) &
              ((serverId > 0 ? tbl.serverId.equals(serverId) : const Constant(false)) |
                  (clientUuid != null && clientUuid.isNotEmpty ? tbl.clientUuid.equals(clientUuid) : const Constant(false))))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.id)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Vế lọc "lệnh SỬA điểm bán chưa gửi xong" — dùng chung [latestUnsentCustomerUpdate] và [unsentCustomerUpdateKeys].
  Expression<bool> _unsentCustomerUpdate(SyncQueueEntries tbl) =>
      tbl.entity.equals('customer') &
      tbl.op.equals('update') &
      (tbl.state.equals('pending') | tbl.state.equals('sending'));

  /// Lệnh check-out / huỷ ở trạng thái [state] của lượt KHÁC, nhập trước dòng tạo lượt [entry]; [createdFromMs]: chỉ dòng
  /// tạo từ mốc đó trở đi.
  Future<List<SyncQueueEntry>> _otherVisitClosesBefore(SyncQueueEntry entry, String state, {int? createdFromMs}) {
    return (select(syncQueueEntries)
          ..where((tbl) =>
              isMine(tbl) &
              tbl.id.isSmallerThanValue(entry.id) &
              tbl.entity.equals('visit') &
              (tbl.op.equals('checkout') | tbl.op.equals('cancel')) &
              tbl.parentUuid.equals(entry.clientUuid).not() &
              tbl.state.equals(state) &
              (createdFromMs == null ? const Constant(true) : tbl.createdAt.isBiggerOrEqualValue(createdFromMs))))
        .get();
  }

  /// Có check-out / huỷ của lượt KHÁC (nhập trước dòng tạo lượt [entry]) bị server từ chối (dead) mà lượt đó ĐÃ lên server,
  /// check-in CÙNG NGÀY với [entry] và chưa được đóng lại bằng một lệnh check-out / huỷ khác trong hàng đợi — tức lượt đó
  /// còn mở trên server, [entry] nhận DMS_VISIT_STILL_OPEN cho tới khi nhân viên đóng lại nó (màn tuyến đưa nó lên làm lượt
  /// đang mở) hoặc cron đầu ngày đánh dấu "Chưa check-out". Khi đó dòng tạo CHỜ, không đếm vào trần — đếm thì một
  /// check-out hỏng kéo chết mọi lượt sau trong ngày (#24698 vòng 2).
  /// Chỉ miễn trong CHÍNH ngày đó ([nowMs]): qua ngày thì cron đã đánh dấu lượt kia, còn STILL_OPEN là do lượt khác ⇒ đếm
  /// trần như thường (chặn trên thời gian miễn, kể cả khi lượt kia đã được đóng trực tuyến mà dòng dead còn nằm lại).
  /// Ngày so theo giờ máy (máy ở VN ⇒ trùng ngày server); lượt check-in trực tuyến không có dòng tạo ⇒ lấy ngày của lệnh đóng.
  /// [onlyCloseId]: chỉ xét đúng lệnh đóng đó ([isHoldingLaterVisit]).
  Future<bool> hasDeadVisitCloseBefore(SyncQueueEntry entry, {int? nowMs, int? onlyCloseId}) async {
    if (entry.entity != 'visit' || entry.op != 'create') return false;
    DateTime dayOf(int ms) {
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      return DateTime(d.year, d.month, d.day);
    }

    final day = dayOf(entry.createdAt);
    if (dayOf(nowMs ?? DateTime.now().millisecondsSinceEpoch) != day) return false;
    // Lệnh đóng đứng sau check-in của lượt đó ⇒ lượt check-in trong ngày [day] có lệnh đóng tạo từ đầu ngày [day].
    final closes = await _otherVisitClosesBefore(entry, 'dead', createdFromMs: day.millisecondsSinceEpoch);
    for (final r in closes) {
      final visitUuid = r.parentUuid;
      if (visitUuid == null || (onlyCloseId != null && r.id != onlyCloseId)) continue;
      final create = await (select(syncQueueEntries)
            ..where((t) => isMine(t) & t.entity.equals('visit') & t.op.equals('create') & t.clientUuid.equals(visitUuid))
            ..limit(1))
          .getSingleOrNull();
      // Dòng tạo chưa lên server (chờ / chết / kẹt) ⇒ lượt không mở trên server, không phải nó chặn [entry].
      if (create != null && create.state != 'done') continue;
      if (dayOf(create?.createdAt ?? r.createdAt) != day) continue;
      final reclosed = await (select(syncQueueEntries)
            ..where((t) =>
                isMine(t) &
                t.entity.equals('visit') &
                (t.op.equals('checkout') | t.op.equals('cancel')) &
                t.parentUuid.equals(visitUuid) &
                t.state.equals('done'))
            ..limit(1))
          .getSingleOrNull();
      if (reclosed == null) return true;
    }
    return false;
  }

  /// Lấy danh sách tất cả các mục đang chờ gửi hoặc đang gửi (pending & sending)
  Future<List<SyncQueueEntry>> getAllPendingQueueEntries() {
    return (select(syncQueueEntries)
          ..where((tbl) => isMine(tbl) & (tbl.state.equals('pending') | tbl.state.equals('sending')))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.id)]))
        .get();
  }

  /// Stream theo dõi danh sách tất cả các mục đang chờ gửi hoặc đang gửi (pending & sending)
  Stream<List<SyncQueueEntry>> watchAllPendingQueueEntries() {
    return (select(syncQueueEntries)
          ..where((tbl) => isMine(tbl) & (tbl.state.equals('pending') | tbl.state.equals('sending')))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.id)]))
        .watch();
  }

  /// Stream nhật ký đã gửi của người đang đăng nhập từ [fromMs] (epoch ms) — mới nhất trước.
  Stream<List<SyncSentLog>> watchSentLogs({required int fromMs}) {
    return (select(syncSentLogs)
          ..where((t) => _ownedByMe(t.ownerUserId) & t.sentAt.isBiggerOrEqualValue(fromMs))
          ..orderBy([(t) => OrderingTerm.desc(t.sentAt), (t) => OrderingTerm.desc(t.id)]))
        .watch();
  }

  /// Stream theo dõi các mục hỏng vĩnh viễn (dead / 4xx)
  Stream<List<SyncQueueEntry>> watchDeadQueueEntries() {
    return (select(syncQueueEntries)
          ..where((tbl) => isMine(tbl) & tbl.state.equals('dead'))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.id)]))
        .watch();
  }

  /// Một dòng hàng đợi theo id (đọc lại bản mới nhất ngay trước khi gửi).
  Future<SyncQueueEntry?> getEntryById(int id) =>
      (select(syncQueueEntries)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  /// Tìm mục trong hàng đợi theo clientUuid (phục vụ liên kết cha-con: visit -> photos/checkout)
  /// Dòng ĐẦU TIÊN (dòng tạo) mang [clientUuid] — dòng sửa điểm bán (`update`) dùng chung clientUuid với dòng tạo, nên
  /// không dùng getSingleOrNull (ném StateError ⇒ mục con thử lại mãi).
  Future<SyncQueueEntry?> getEntryByClientUuid(String clientUuid) {
    return (select(syncQueueEntries)
          ..where((tbl) => tbl.clientUuid.equals(clientUuid))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.id)])
          ..limit(1))
        .getSingleOrNull();
  }

  // ===========================================================================
  // LOCAL CUSTOMER OPERATIONS (§7 SPEC-DONG-BO-OFFLINE)
  // ===========================================================================

  /// Thêm mới hoặc cập nhật thông tin điểm bán cục bộ
  /// Tự gắn người đang đăng nhập nếu nơi gọi không ghi (như [enqueue]). Khoá trùng dòng CHỜ GỬI của tài khoản khác
  /// (điểm bán chung tuyến họ sửa ngoại tuyến, điểm bán họ tạo) ⇒ KHÔNG ghi: ghi đè là mất phần chờ gửi của họ — người này
  /// thiếu điểm bán đó trong máy tới khi họ gửi xong (chủ hệ thống chấp nhận, "một chủ một lúc" 03/11/2026, #24698 nhóm 3).
  /// Chưa rõ chủ (chưa ai đăng nhập trong lần chạy) ⇒ chỉ ghi đè dòng đã đồng bộ / vô chủ, GIỮ chủ cũ của dòng.
  /// Giá trị trả về là của câu INSERT — lượt bị bỏ qua vẫn trả số khác 0, đừng dùng nó để biết đã ghi hay chưa.
  /// Điều kiện nằm trong chính câu upsert (`ON CONFLICT … DO UPDATE … WHERE`) — kiểm rồi ghi riêng là hở giữa hai bước.
  Future<int> insertOrUpdateCustomer(LocalCustomersCompanion customer) {
    final owner = customer.ownerUserId.present ? customer.ownerUserId.value : (_ownerUserId ?? _lastOwnerUserId);
    // Chưa rõ chủ ⇒ BỎ cột chủ khỏi câu ghi (kể cả nơi gọi truyền `Value(null)`) để dòng có sẵn giữ chủ của nó.
    final row = customer.copyWith(ownerUserId: owner == null ? const Value.absent() : Value(owner));
    return into(localCustomers).insert(
      row,
      onConflict: DoUpdate(
        (_) => row,
        where: (old) =>
            old.syncStatus.equals('synced') |
            old.ownerUserId.isNull() |
            (owner == null ? const Constant(false) : old.ownerUserId.equals(owner)),
      ),
    );
  }

  /// Lấy toàn bộ danh sách khách hàng cục bộ (ưu tiên bản ghi pending/error lên đầu, sau đó theo thời gian tạo mới nhất)
  Future<List<LocalCustomer>> getAllLocalCustomers() {
    return (select(localCustomers)
          ..where(isMyCustomer)
          ..orderBy([
            (tbl) => OrderingTerm(
                  expression: tbl.syncStatus.equals('synced'),
                  mode: OrderingMode.asc,
                ),
            (tbl) => OrderingTerm.desc(tbl.createdAt),
          ]))
        .get();
  }

  /// Số điểm bán trong máy — đếm bằng SQL, không nạp cả bảng (1.000+ dòng đủ cột) chỉ để lấy `length`.
  Future<int> countLocalCustomers() async {
    final count = localCustomers.clientUuid.count();
    final row = await (selectOnly(localCustomers)
          ..addColumns([count])
          ..where(isMyCustomer(localCustomers)))
        .getSingle();
    return row.read(count) ?? 0;
  }

  /// Tên điểm bán ĐẦU TIÊN (cùng thứ tự với [getAllLocalCustomers]) chưa có trong [visitedIds] — điểm chưa có id máy
  /// chủ (tạo offline) tính là chưa ghé, như vòng lặp cũ.
  Future<String?> firstLocalCustomerNameNotIn(Set<int> visitedIds) async {
    final query = selectOnly(localCustomers)
      ..addColumns([localCustomers.name])
      ..where(isMyCustomer(localCustomers))
      ..orderBy([
        OrderingTerm(expression: localCustomers.syncStatus.equals('synced'), mode: OrderingMode.asc),
        OrderingTerm.desc(localCustomers.createdAt),
      ])
      ..limit(1);
    if (visitedIds.isNotEmpty) {
      query.where(localCustomers.id.isNull() | localCustomers.id.isNotIn(visitedIds));
    }
    final row = await query.getSingleOrNull();
    return row?.read(localCustomers.name);
  }

  /// Tìm kiếm điểm bán offline không dấu (§7.4)
  Future<List<LocalCustomer>> searchLocalCustomers(String unaccentedQuery) {
    if (unaccentedQuery.trim().isEmpty) {
      return getAllLocalCustomers();
    }
    final q = '%$unaccentedQuery%';
    return (select(localCustomers)
          ..where((tbl) =>
              isMyCustomer(tbl) &
              (tbl.nameUnaccent.like(q) | tbl.code.like(q) | tbl.phone.like(q) | tbl.address.like(q)))
          ..orderBy([
            (tbl) => OrderingTerm(
                  expression: tbl.syncStatus.equals('synced'),
                  mode: OrderingMode.asc,
                ),
            (tbl) => OrderingTerm.desc(tbl.createdAt),
          ]))
        .get();
  }

  /// Cập nhật trạng thái đồng bộ và server ID sau khi push thành công
  Future<void> markCustomerSynced(
    String clientUuid,
    int serverId, {
    String? code,
    String? type,
    String? dynamicFieldsJson,
  }) async {
    await (update(localCustomers)..where((tbl) => tbl.clientUuid.equals(clientUuid))).write(
      LocalCustomersCompanion(
        id: Value(serverId),
        code: code != null ? Value(code) : const Value.absent(),
        type: type != null && type.isNotEmpty ? Value(type) : const Value.absent(),
        dynamicFieldsJson: dynamicFieldsJson != null ? Value(dynamicFieldsJson) : const Value.absent(),
        syncStatus: const Value('synced'),
        approvalStatus: const Value('approved'),
      ),
    );
  }

  /// Dọn dẹp các bản ghi khách hàng bị trùng lặp trên SQLite (theo id hoặc code)
  /// [owner]: chủ mà nơi gọi đã chốt từ đầu lượt ghi (mặc định: người đang đăng nhập).
  Future<void> cleanupDuplicateCustomers({int? owner}) async {
    try {
      final all = await (select(localCustomers)..where((t) => _ownedBy(t, owner))).get();
      final seenIds = <int, String>{};
      final seenCodes = <String, String>{};
      final toDelete = <String>[];

      for (final row in all) {
        bool isDup = false;
        if (row.id != null && row.id! > 0) {
          if (seenIds.containsKey(row.id!)) {
            isDup = true;
          } else {
            seenIds[row.id!] = row.clientUuid;
          }
        }

        if (!isDup && row.code.isNotEmpty && !row.code.startsWith('PENDING_')) {
          if (seenCodes.containsKey(row.code)) {
            isDup = true;
          } else {
            seenCodes[row.code] = row.clientUuid;
          }
        }

        if (isDup) {
          toDelete.add(row.clientUuid);
        }
      }

      if (toDelete.isNotEmpty) {
        await (delete(localCustomers)..where((tbl) => tbl.clientUuid.isIn(toDelete))).go();
      }
    } catch (_) {}
  }

  /// Xóa các điểm bán đã đồng bộ trên SQLite nhưng không còn trong danh sách ID từ máy chủ (§7 reconcile)
  Future<int> deleteSyncedCustomersNotIn(List<int> activeServerIds, {int? owner}) {
    if (activeServerIds.isEmpty) {
      return (delete(localCustomers)..where((tbl) => _ownedBy(tbl, owner) & tbl.syncStatus.equals('synced'))).go();
    }
    return (delete(localCustomers)
          ..where((tbl) =>
              _ownedBy(tbl, owner) &
              tbl.syncStatus.equals('synced') &
              (tbl.id.isNotNull() & tbl.id.isNotIn(activeServerIds))))
        .go();
  }

  /// Tập ID máy chủ của các điểm bán đang ở trạng thái đã đồng bộ — chụp TRƯỚC khi tải danh sách để reconcile.
  Future<Set<int>> syncedCustomerIds() async {
    final rows = await (selectOnly(localCustomers)
          ..addColumns([localCustomers.id])
          ..where(isMyCustomer(localCustomers) &
              localCustomers.syncStatus.equals('synced') &
              localCustomers.id.isNotNull()))
        .get();
    return {for (final r in rows) r.read(localCustomers.id)!};
  }

  /// Xóa các điểm bán đã đồng bộ có ID trong [serverIds] (reconcile theo ảnh chụp — xem [syncedCustomerIds]).
  Future<int> deleteSyncedCustomersIn(Iterable<int> serverIds, {int? owner}) {
    if (serverIds.isEmpty) return Future.value(0);
    return (delete(localCustomers)
          ..where((tbl) => _ownedBy(tbl, owner) & tbl.syncStatus.equals('synced') & tbl.id.isIn(serverIds)))
        .go();
  }

  /// Xóa 1 điểm bán theo ID khỏi SQLite
  Future<int> deleteCustomerById(int id) {
    return (delete(localCustomers)..where((tbl) => isMyCustomer(tbl) & tbl.id.equals(id))).go();
  }

  /// Xóa bản ghi điểm bán chờ đồng bộ khỏi SQLite và hủy các tác vụ sync liên quan trong sync_queue. Trả `false` (không
  /// xoá gì) khi điểm bán đã / đang lên server: dòng tạo đang gửi / đã gửi, hoặc bản trong máy đã có id server — xoá lúc
  /// đó thì server vẫn tạo điểm bán (kèm lượt "Tạo điểm bán") mà máy quên, điểm bán "sống lại" ở lần tải sau (#24698).
  /// Kiểm và xoá trong CÙNG transaction để lô đồng bộ không giành dòng tạo giữa chừng.
  Future<bool> deletePendingCustomer(String clientUuid) async {
    final rows = await transaction(() async {
      final create = await findCustomerCreateRow(clientUuid);
      // Đang gửi / đã gửi / CÓ THỂ đã tới server (lần gửi trước hỏng giữa chừng — dấu [queueMaybeOnServerKey]) ⇒ từ chối:
      // xoá thì server vẫn giữ điểm bán, lần tải sau nó quay lại.
      if (create != null &&
          (create.state == 'sending' ||
              create.state == 'done' ||
              (create.state == 'pending' && queueMaybeOnServer(create.payload)))) {
        return null;
      }
      final local = await (select(localCustomers)..where((tbl) => tbl.clientUuid.equals(clientUuid))).get();
      if (local.any((r) => (r.id ?? 0) > 0)) return null;

      // 1. Tìm các lượt viếng thăm của điểm bán này (liên kết qua parentUuid hoặc customer_client_uuid trong payload)
      final allVisits = await (select(syncQueueEntries)
            ..where((tbl) =>
                tbl.entity.equals('visit') &
                (tbl.parentUuid.equals(clientUuid) | tbl.payload.like('%"$clientUuid"%'))))
          .get();

      // Xoá dòng trong transaction, TỆP ảnh xoá sau khi commit (rollback giữa chừng không được để dòng quay lại mà ảnh mất).
      final visitRows = <SyncQueueEntry>[];
      for (final v in allVisits) {
        visitRows.addAll(await _deleteRows(await _pendingVisitRows(v.clientUuid)));
      }

      final rows = await (select(syncQueueEntries)
            ..where((tbl) => tbl.clientUuid.equals(clientUuid) | tbl.parentUuid.equals(clientUuid)))
          .get();
      await (delete(localCustomers)..where((tbl) => tbl.clientUuid.equals(clientUuid))).go();
      await (delete(syncQueueEntries)
            ..where((tbl) => tbl.clientUuid.equals(clientUuid) | tbl.parentUuid.equals(clientUuid)))
          .go();
      return [...visitRows, ...rows];
    });
    if (rows == null) return false;
    await _deleteRowFiles(rows, [clientUuid]);
    return true;
  }

  /// Tìm entry visit trong sync_queue theo clientUuid
  Future<SyncQueueEntry?> findVisitQueueEntry(String clientUuid) async {
    final entries = await (select(syncQueueEntries)
          ..where((tbl) => tbl.clientUuid.equals(clientUuid) & tbl.entity.equals('visit')))
        .get();
    return entries.isNotEmpty ? entries.first : null;
  }

  /// Lượt chấm công của người đang đăng nhập còn CHỜ GỬI (pending/sending), mới → cũ — để màn hình vẫn coi là đã chấm.
  Future<List<SyncQueueEntry>> getQueuedAttendancePunches() {
    return (select(syncQueueEntries)
          ..where((tbl) =>
              isMine(tbl) &
              tbl.entity.equals('attendance_punch') &
              (tbl.state.equals('pending') | tbl.state.equals('sending')))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.id)]))
        .get();
  }

  /// Ảnh chấm công của người đang đăng nhập còn chờ gửi (`parentUuid` = lượt chấm cha).
  Future<List<SyncQueueEntry>> getQueuedAttendancePhotos() {
    return (select(syncQueueEntries)
          ..where((tbl) =>
              isMine(tbl) &
              tbl.entity.equals('attendance_photo') &
              (tbl.state.equals('pending') | tbl.state.equals('sending'))))
        .get();
  }

  /// Tìm lượt chấm công đã đồng bộ gần nhất có serverId
  Future<SyncQueueEntry?> findLastSyncedPunchEntry() async {
    final entries = await (select(syncQueueEntries)
          ..where((tbl) => isMine(tbl) & tbl.entity.equals('attendance_punch') & tbl.serverId.isNotNull())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.id)])
          ..limit(1))
        .get();
    return entries.isNotEmpty ? entries.first : null;
  }

  /// Huỷ lượt CHƯA lên server: xoá dòng tạo + mục con chờ gửi ([deletePendingVisitQueue]) — trong một transaction,
  /// và TỪ CHỐI (trả false, không xoá gì) khi dòng tạo đang được gửi: xoá lúc đó thì check-in vẫn lên server và lượt
  /// treo mãi. Cùng với [markSending] có điều kiện, hai phía không giẫm nhau: xoá trước ⇒ lô bỏ qua; gửi trước ⇒ ở đây
  /// thấy 'sending' ⇒ nơi gọi xếp lệnh huỷ chờ check-in.
  Future<bool> deleteUnsentVisit(String clientUuid) async {
    final deleted = await transaction<List<SyncQueueEntry>?>(() async {
      final create = await (select(syncQueueEntries)
            ..where((tbl) => tbl.clientUuid.equals(clientUuid) & tbl.entity.equals('visit') & tbl.op.equals('create'))
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.id)])
            ..limit(1))
          .getSingleOrNull();
      if (create?.state == 'sending') return null;
      // Dòng tạo 'pending' nhưng ĐÃ TỪNG gửi đi (lần trước hỏng giữa chừng / lượt trực tuyến quá giờ rồi rơi về hàng đợi):
      // server có thể đã mở lượt ⇒ coi như đang gửi, để nơi gọi xếp lệnh huỷ chờ check-in có mã rồi huỷ. Xoá thì lượt treo
      // trên server mà app không còn gì để gỡ (#24698 lỗi 6).
      if (create != null && create.state == 'pending' && queueMaybeOnServer(create.payload)) return null;
      if (create?.state == 'dead') {
        // Check-in bị server TỪ CHỐI: lượt không hề có trên server ⇒ xoá trọn (cả dòng tạo dead, phiếu, mục con đã dead)
        // — để lại thì phiếu của lượt đã huỷ nổi lên "Lỗi đồng bộ" (cha dead = hết hy vọng ⇒ 410).
        final rows = await (select(syncQueueEntries)
              ..where((tbl) => tbl.clientUuid.equals(clientUuid) | tbl.parentUuid.equals(clientUuid)))
            .get();
        rows.removeWhere((r) => r.state == 'done');
        return _deleteRows(rows);
      }
      return _deleteRows(await _pendingVisitRows(clientUuid));
    });
    if (deleted == null) return false;
    // Xoá tệp SAU khi transaction xong — không giữ khoá DB (lô đồng bộ chờ) trong lúc chạm đĩa.
    await _deleteRowFiles(deleted, const []);
    return true;
  }

  /// Xoá các mục pending/sending của lượt viếng thăm (create, upload ảnh, checkout)
  ///
  /// [keepVisitCreate]: GIỮ dòng tạo lượt (đang gửi dở, chưa biết đã lên server chưa) — lệnh huỷ xếp sau sẽ chờ nó có
  /// mã server rồi huỷ. Khi đó coi như lượt đã lên server: phiếu đã nộp cũng giữ.
  Future<int> deletePendingVisitQueue(String clientUuid, {bool keepVisitCreate = false}) async {
    final rows = await _deleteRows(await _pendingVisitRows(clientUuid, keepVisitCreate: keepVisitCreate));
    await _deleteRowFiles(rows, const []);
    return rows.length;
  }

  /// Dòng chờ gửi (pending/sending) của lượt [clientUuid] mà [deletePendingVisitQueue] xoá.
  Future<List<SyncQueueEntry>> _pendingVisitRows(String clientUuid, {bool keepVisitCreate = false}) async {
    // Lượt ĐÃ lên server (không còn dòng tạo chờ gửi): giữ phiếu khảo sát người dùng đã nộp (con theo parentUuid) — vẫn
    // gửi; server từ chối thì hiện ở "Lỗi đồng bộ" thay vì mất im lặng cùng ảnh. Lượt CHƯA lên server: không có gì để
    // phiếu gắn vào ⇒ xoá cùng lượt.
    final visitNeverSent = keepVisitCreate
        ? null
        : await (select(syncQueueEntries)
              ..where((tbl) =>
                  tbl.clientUuid.equals(clientUuid) &
                  tbl.entity.equals('visit') &
                  tbl.op.equals('create') &
                  (tbl.state.equals('pending') | tbl.state.equals('sending')))
              ..limit(1))
            .getSingleOrNull();
    return (select(syncQueueEntries)
          ..where((tbl) =>
              (tbl.clientUuid.equals(clientUuid) | tbl.parentUuid.equals(clientUuid)) &
              (visitNeverSent != null ? const Constant(true) : tbl.entity.equals('form_submission').not()) &
              (keepVisitCreate
                  ? (tbl.entity.equals('visit') & tbl.op.equals('create')).not()
                  : const Constant(true)) &
              (tbl.state.equals('pending') | tbl.state.equals('sending'))))
        .get();
  }

  /// Xoá các dòng [rows] khỏi hàng đợi (KHÔNG xoá tệp — nơi gọi xoá sau, ngoài transaction); trả lại chính danh sách đó.
  Future<List<SyncQueueEntry>> _deleteRows(List<SyncQueueEntry> rows) async {
    if (rows.isNotEmpty) await (delete(syncQueueEntries)..where((tbl) => tbl.id.isIn(rows.map((r) => r.id)))).go();
    return rows;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'dms_app.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// Gom mọi chuỗi trông như đường dẫn tệp trên máy ([looksLikeFilePath]) trong một cây JSON đã giải mã — dùng chung
/// cho dọn tệp của dòng hàng đợi và tìm tệp còn được tham chiếu (quét ảnh tạm).
void collectFilePaths(Object? node, List<String> out) {
  if (node is String) {
    if (looksLikeFilePath(node)) out.add(node);
  } else if (node is Map) {
    for (final v in node.values) {
      collectFilePaths(v, out);
    }
  } else if (node is List) {
    for (final v in node) {
      collectFilePaths(v, out);
    }
  }
}

/// Khoá NỘI BỘ trong payload dòng TẠO của hàng đợi (lượt viếng thăm, điểm bán): có thể ĐÃ tới server (đã gửi ít nhất một lần, hoặc lượt
/// gửi trực tuyến quá giờ). Không dùng `attempts` — "Đồng bộ ngay" đặt lại nó. Bỏ khỏi payload trước khi gửi.
const String queueMaybeOnServerKey = '_maybe_on_server';

/// Dòng tạo lượt có dấu [queueMaybeOnServerKey] không.
bool queueMaybeOnServer(String payload) {
  try {
    final map = jsonDecode(payload);
    return map is Map && map[queueMaybeOnServerKey] == true;
  } catch (_) {
    return false;
  }
}

final _windowsAbsolutePath = RegExp(r'^[A-Za-z]:[\\/]');

/// Đường dẫn tuyệt đối trên máy: '/...' (Android/iOS), 'file://...', hoặc 'C:\...' (Windows — máy chạy test/desktop).
bool looksLikeFilePath(String s) => s.startsWith('/') || s.startsWith('file://') || _windowsAbsolutePath.hasMatch(s);
