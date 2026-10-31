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

  @override
  Set<Column> get primaryKey => {clientUuid};
}

@DriftDatabase(tables: [SyncQueueEntries, LocalCustomers])
class AppDatabase extends _$AppDatabase {
  /// [ownerUserId]: người đang đăng nhập ban đầu (test dựng DB trong bộ nhớ); app đặt qua [setOwner].
  AppDatabase([QueryExecutor? e, int? ownerUserId])
      : _ownerUserId = ownerUserId,
        super(e ?? _openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createCustomerIndexes();
          await _createQueueIndexes();
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
        },
      );

  /// Index tra điểm bán theo id máy chủ / mã khi ghi cache — khoá chính chỉ là `client_uuid`, thiếu hai index này
  /// thì mỗi dòng trong lượt đồng bộ quét cả bảng (2.000 điểm bán ⇒ hàng triệu lượt so).
  Future<void> _createCustomerIndexes() async {
    await customStatement('CREATE INDEX IF NOT EXISTS idx_local_customers_id ON local_customers (id)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_local_customers_code ON local_customers (code)');
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

  /// Người đang đăng nhập (usr_user.id) — AuthViewModel đặt lúc đăng nhập/khôi phục phiên, xoá lúc đăng xuất.
  /// Hàng đợi chỉ gửi/đếm/liệt kê/dọn dòng của người này; chưa đăng nhập thì không thấy dòng nào.
  int? _ownerUserId;

  /// Người đăng nhập gần nhất trong lần chạy này — mục nhập MUỘN ngay sau đăng xuất (ảnh đang nén, lượt chấm đang lưu)
  /// vẫn là của người vừa đăng xuất, không thành "vô chủ".
  int? _lastOwnerUserId;

  /// Dấu dòng của bản app cũ (trước khi có cột chủ) — đặt lúc nâng cấp schema 1 → 2.
  static const _legacyOwner = -1;

  int? get ownerUserId => _ownerUserId;

  /// Đặt người đang đăng nhập; dòng của bản app cũ ([_legacyOwner]) giao cho người đăng nhập đầu tiên sau nâng cấp
  /// (bản cũ vốn gửi chúng bằng token của bất kỳ ai — không tệ hơn).
  Future<void> setOwner(int? userId) async {
    _ownerUserId = userId;
    if (userId != null) {
      _lastOwnerUserId = userId;
      await (update(syncQueueEntries)..where((t) => t.ownerUserId.equals(_legacyOwner)))
          .write(SyncQueueEntriesCompanion(ownerUserId: Value(userId)));
      // Chạy nền: lần đầu sau nâng cấp có thể dọn hàng trăm tệp — đừng bắt đăng nhập chờ.
      unawaited(purgeDoneEntries().catchError((Object e) {
        debugPrint('[AppDatabase] Lỗi dọn mục đã gửi: $e');
        return 0;
      }));
    }
  }

  /// Vế lọc "dòng của người đang đăng nhập" — MỌI truy vấn hàng đợi theo tập (gửi, đếm, liệt kê, dọn, gộp) phải đi qua
  /// đây. Chưa đăng nhập ⇒ không dòng nào.
  Expression<bool> isMine(SyncQueueEntries t) {
    final owner = _ownerUserId;
    return owner == null ? const Constant(false) : t.ownerUserId.equals(owner);
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
  Future<List<SyncQueueEntry>> getPendingQueueEntries({int limit = 50, bool force = false}) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return (select(syncQueueEntries)
          ..where((tbl) =>
              isMine(tbl) &
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

  /// Đánh dấu mục đang gửi
  Future<bool> markSending(int id) async {
    final updated = await (update(syncQueueEntries)..where((tbl) => tbl.id.equals(id)))
        .write(const SyncQueueEntriesCompanion(state: Value('sending')));
    return updated > 0;
  }

  /// Đánh dấu mục đã gửi thành công (§3.2, §4.3)
  Future<bool> markDone(int id, {int? serverId}) async {
    final updated = await (update(syncQueueEntries)..where((tbl) => tbl.id.equals(id))).write(
      SyncQueueEntriesCompanion(
        state: const Value('done'),
        serverId: Value(serverId),
        // Dòng done không còn lịch thử lại ⇒ dùng cột này ghi LÚC GỬI XONG cho [purgeDoneEntries].
        nextAttemptAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    return updated > 0;
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
      final c = selectOnly(localCustomers)..addColumns([localCustomers.clientUuid]);
      customerUuids.addAll((await c.map((r) => r.read(localCustomers.clientUuid)).get()).whereType<String>());
      await (delete(syncQueueEntries)..where(isMine)).go();
      await delete(localCustomers).go();
      return true;
    });
    if (cleared) await _deleteRowFiles(rows, customerUuids);
    return cleared;
  }

  /// Mọi tệp mà SQLite còn trỏ tới — hàng đợi (mọi trạng thái, mọi chủ: localPath + payload) và điểm bán trong máy
  /// (dynamicFieldsJson). Quét dọn ảnh tạm KHÔNG được xoá các tệp này.
  Future<List<String>> referencedFilePaths() async {
    final paths = <String>[];
    for (final row in await select(syncQueueEntries).get()) {
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
  static Future<void> _deleteRowFiles(List<SyncQueueEntry> rows, List<String> customerUuids) async {
    final paths = <String>[];
    for (final row in rows) {
      if (row.localPath != null) paths.add(row.localPath!);
      try {
        collectFilePaths(jsonDecode(row.payload), paths);
      } catch (_) {}
    }
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
            if (customerUuids.any((u) => bare.startsWith('${u}_photo_'))) files.add(f.path);
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

  /// Xóa các mục dead đã được xử lý hoặc dọn dẹp — kèm tệp ảnh của chúng.
  Future<int> clearDeadEntries() async {
    final rows = await (select(syncQueueEntries)..where((tbl) => isMine(tbl) & tbl.state.equals('dead'))).get();
    if (rows.isEmpty) return 0;
    final n = await (delete(syncQueueEntries)..where((tbl) => tbl.id.isIn(rows.map((r) => r.id)))).go();
    await _deleteRowFiles(rows, const []);
    return n;
  }

  /// Xoá một mục hàng đợi (người dùng bấm xoá mục lỗi) — kèm tệp ảnh của nó.
  Future<void> deleteEntry(int id) async {
    final row = await (select(syncQueueEntries)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await (delete(syncQueueEntries)..where((tbl) => tbl.id.equals(id))).go();
    await _deleteRowFiles([row], const []);
  }

  /// Giữ mục đã gửi bao lâu trước khi dọn: dòng done là nguồn tra clientUuid → serverId cho việc làm MUỘN sau khi gửi
  /// (ảnh chấm công bổ sung, huỷ lượt đã đồng bộ, check-out ngay sau đồng bộ); ảnh vừa gửi còn được lịch sử offline
  /// hiển thị tới khi tải lại từ máy chủ.
  static const doneRetention = Duration(days: 2);

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
    });
    return rows.length;
  }

  /// Đánh dấu điểm bán bị lỗi đồng bộ vĩnh viễn (4xx)
  Future<void> markCustomerSyncError(String clientUuid, String error) async {
    await (update(localCustomers)..where((tbl) => tbl.clientUuid.equals(clientUuid))).write(
      const LocalCustomersCompanion(
        syncStatus: Value('error'),
        approvalStatus: Value('rejected'),
      ),
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

  /// Lượt [visitClientUuid] còn thao tác vật tư CHƯA lên server (pending — kể cả đang chờ thử lại — hoặc sending).
  /// Server chỉ nhận thao tác vật tư trước giờ check-out và cổng ④ đòi chúng ⇒ check-out của lượt phải đứng chờ.
  Future<bool> hasOpenVisitMaterials(String visitClientUuid) async {
    final row = await (select(syncQueueEntries)
          ..where((tbl) =>
              isMine(tbl) &
              tbl.entity.equals('visit_material') &
              tbl.parentUuid.equals(visitClientUuid) &
              (tbl.state.equals('pending') | tbl.state.equals('sending')))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  /// clientUuid các thao tác vật tư server đã từ chối (dead) — mọi lượt; để cache không tính chúng là "đã kiểm".
  Future<Set<String>> getDeadVisitMaterialUuids() async {
    final rows = await (select(syncQueueEntries)
          ..where((tbl) => isMine(tbl) & tbl.entity.equals('visit_material') & tbl.state.equals('dead')))
        .get();
    return rows.map((r) => r.clientUuid).toSet();
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

  /// Stream theo dõi các mục hỏng vĩnh viễn (dead / 4xx)
  Stream<List<SyncQueueEntry>> watchDeadQueueEntries() {
    return (select(syncQueueEntries)
          ..where((tbl) => isMine(tbl) & tbl.state.equals('dead'))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.id)]))
        .watch();
  }

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
  Future<int> insertOrUpdateCustomer(LocalCustomersCompanion customer) {
    return into(localCustomers).insertOnConflictUpdate(customer);
  }

  /// Lấy toàn bộ danh sách khách hàng cục bộ (ưu tiên bản ghi pending/error lên đầu, sau đó theo thời gian tạo mới nhất)
  Future<List<LocalCustomer>> getAllLocalCustomers() {
    return (select(localCustomers)
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
    final row = await (selectOnly(localCustomers)..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  /// Tên điểm bán ĐẦU TIÊN (cùng thứ tự với [getAllLocalCustomers]) chưa có trong [visitedIds] — điểm chưa có id máy
  /// chủ (tạo offline) tính là chưa ghé, như vòng lặp cũ.
  Future<String?> firstLocalCustomerNameNotIn(Set<int> visitedIds) async {
    final query = selectOnly(localCustomers)
      ..addColumns([localCustomers.name])
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
              tbl.nameUnaccent.like(q) | tbl.code.like(q) | tbl.phone.like(q) | tbl.address.like(q))
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
  Future<void> cleanupDuplicateCustomers() async {
    try {
      final all = await select(localCustomers).get();
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
  Future<int> deleteSyncedCustomersNotIn(List<int> activeServerIds) {
    if (activeServerIds.isEmpty) {
      return (delete(localCustomers)..where((tbl) => tbl.syncStatus.equals('synced'))).go();
    }
    return (delete(localCustomers)
          ..where((tbl) =>
              tbl.syncStatus.equals('synced') &
              (tbl.id.isNotNull() & tbl.id.isNotIn(activeServerIds))))
        .go();
  }

  /// Tập ID máy chủ của các điểm bán đang ở trạng thái đã đồng bộ — chụp TRƯỚC khi tải danh sách để reconcile.
  Future<Set<int>> syncedCustomerIds() async {
    final rows = await (selectOnly(localCustomers)
          ..addColumns([localCustomers.id])
          ..where(localCustomers.syncStatus.equals('synced') & localCustomers.id.isNotNull()))
        .get();
    return {for (final r in rows) r.read(localCustomers.id)!};
  }

  /// Xóa các điểm bán đã đồng bộ có ID trong [serverIds] (reconcile theo ảnh chụp — xem [syncedCustomerIds]).
  Future<int> deleteSyncedCustomersIn(Iterable<int> serverIds) {
    if (serverIds.isEmpty) return Future.value(0);
    return (delete(localCustomers)
          ..where((tbl) => tbl.syncStatus.equals('synced') & tbl.id.isIn(serverIds)))
        .go();
  }

  /// Xóa 1 điểm bán theo ID khỏi SQLite
  Future<int> deleteCustomerById(int id) {
    return (delete(localCustomers)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// Xóa bản ghi điểm bán chờ đồng bộ khỏi SQLite và hủy các tác vụ sync liên quan trong sync_queue
  Future<void> deletePendingCustomer(String clientUuid) async {
    final rows = await (select(syncQueueEntries)
          ..where((tbl) => tbl.clientUuid.equals(clientUuid) | tbl.parentUuid.equals(clientUuid)))
        .get();
    await (delete(localCustomers)..where((tbl) => tbl.clientUuid.equals(clientUuid))).go();
    await (delete(syncQueueEntries)
          ..where((tbl) => tbl.clientUuid.equals(clientUuid) | tbl.parentUuid.equals(clientUuid)))
        .go();
    await _deleteRowFiles(rows, [clientUuid]);
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

  /// Xoá các mục pending/sending của lượt viếng thăm (create, upload ảnh, checkout)
  Future<int> deletePendingVisitQueue(String clientUuid) async {
    // Lượt ĐÃ lên server (không còn dòng tạo chờ gửi): giữ phiếu khảo sát người dùng đã nộp (con theo parentUuid) — vẫn
    // gửi; server từ chối thì hiện ở "Lỗi đồng bộ" thay vì mất im lặng cùng ảnh. Lượt CHƯA lên server: không có gì để
    // phiếu gắn vào ⇒ xoá cùng lượt.
    final visitNeverSent = await (select(syncQueueEntries)
          ..where((tbl) =>
              tbl.clientUuid.equals(clientUuid) &
              tbl.entity.equals('visit') &
              tbl.op.equals('create') &
              (tbl.state.equals('pending') | tbl.state.equals('sending')))
          ..limit(1))
        .getSingleOrNull();
    final rows = await (select(syncQueueEntries)
          ..where((tbl) =>
              (tbl.clientUuid.equals(clientUuid) | tbl.parentUuid.equals(clientUuid)) &
              (visitNeverSent != null ? const Constant(true) : tbl.entity.equals('form_submission').not()) &
              (tbl.state.equals('pending') | tbl.state.equals('sending'))))
        .get();
    if (rows.isEmpty) return 0;
    final n = await (delete(syncQueueEntries)..where((tbl) => tbl.id.isIn(rows.map((r) => r.id)))).go();
    await _deleteRowFiles(rows, const []);
    return n;
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

final _windowsAbsolutePath = RegExp(r'^[A-Za-z]:[\\/]');

/// Đường dẫn tuyệt đối trên máy: '/...' (Android/iOS), 'file://...', hoặc 'C:\...' (Windows — máy chạy test/desktop).
bool looksLikeFilePath(String s) => s.startsWith('/') || s.startsWith('file://') || _windowsAbsolutePath.hasMatch(s);
