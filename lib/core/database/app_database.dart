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
  IntColumn get nextAttemptAt => integer().nullable()(); // epoch ms; bộ gửi bỏ qua mục chưa tới hạn
  TextColumn get lastError => text().nullable()();
  IntColumn get createdAt => integer()(); // epoch ms theo ĐỒNG HỒ MÁY lúc nhập
  IntColumn get createdElapsed => integer()(); // ĐỒNG HỒ ĐƠN ĐIỆU (monotonic) lúc nhập (§6.3)
  TextColumn get bootId => text()(); // định danh lần khởi động máy
  IntColumn get serverId => integer().nullable()(); // id server trả về khi thành công
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
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

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
          ..where((tbl) => force
              ? (tbl.state.equals('pending') | tbl.state.equals('sending'))
              : (tbl.state.equals('pending') &
                  (tbl.nextAttemptAt.isNull() | tbl.nextAttemptAt.isSmallerOrEqualValue(nowMs))))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.id)])
          ..limit(limit))
        .get();
  }

  /// Thêm 1 mục vào hàng đợi đồng bộ (§3.1)
  Future<int> enqueue(SyncQueueEntriesCompanion entry) {
    return into(syncQueueEntries).insert(entry);
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
      ..where(syncQueueEntries.state.equals('pending') |
          syncQueueEntries.state.equals('sending'));
    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result ?? 0;
  }

  /// Stream theo dõi số mục đang chờ đồng bộ theo thời gian thực (chỉ pending & sending)
  Stream<int> watchPendingSyncCount() {
    final countExp = syncQueueEntries.id.count();
    final query = selectOnly(syncQueueEntries)
      ..addColumns([countExp])
      ..where(syncQueueEntries.state.equals('pending') |
          syncQueueEntries.state.equals('sending'));
    return query.map((row) => row.read(countExp) ?? 0).watchSingle();
  }

  /// Đếm số mục lỗi hỏng vĩnh viễn (dead / 4xx)
  Future<int> countDeadSync() async {
    final countExp = syncQueueEntries.id.count();
    final query = selectOnly(syncQueueEntries)
      ..addColumns([countExp])
      ..where(syncQueueEntries.state.equals('dead'));
    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result ?? 0;
  }

  /// Stream theo dõi số mục lỗi vĩnh viễn (dead / 4xx)
  Stream<int> watchDeadSyncCount() {
    final countExp = syncQueueEntries.id.count();
    final query = selectOnly(syncQueueEntries)
      ..addColumns([countExp])
      ..where(syncQueueEntries.state.equals('dead'));
    return query.map((row) => row.read(countExp) ?? 0).watchSingle();
  }

  /// Lấy danh sách các mục lỗi hỏng vĩnh viễn (dead) để thông báo chi tiết cho người dùng
  Future<List<SyncQueueEntry>> getDeadQueueEntries() {
    return (select(syncQueueEntries)
          ..where((tbl) => tbl.state.equals('dead'))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.id)]))
        .get();
  }

  /// Đăng xuất: xoá dữ liệu gắn với người vừa dùng máy — hàng đợi đồng bộ (bảng KHÔNG có cột tài khoản ⇒ để lại thì
  /// người đăng nhập sau gửi lên dưới tên mình), điểm bán lưu trong máy, và ĐÚNG các tệp ảnh chúng trỏ tới (localPath
  /// + đường dẫn trong payload của hàng đợi, ảnh `<clientUuid>_photo_*` của điểm bán) — không xoá cả thư mục: ảnh vừa chụp mà chưa kịp vào
  /// hàng đợi (lượt viếng thăm dở, lượt chấm đang lưu) nằm chung thư mục.
  /// Đếm + xoá trong CÙNG transaction: còn mục pending/sending thì KHÔNG xoá gì, trả false — trừ khi
  /// [discardPending] (người dùng đã xác nhận bỏ dữ liệu chưa gửi). Mục dead luôn bị xoá — nơi gọi phải cảnh báo trước.
  Future<bool> clearUserData({bool discardPending = false}) async {
    final queuePaths = <String>[];
    final payloads = <String>[];
    final customerUuids = <String>[];
    final cleared = await transaction(() async {
      if (!discardPending && await countPendingSync() > 0) return false;
      for (final row in await select(syncQueueEntries).get()) {
        if (row.localPath != null) queuePaths.add(row.localPath!);
        payloads.add(row.payload);
        if (row.entity == 'customer') customerUuids.add(row.clientUuid);
      }
      final c = selectOnly(localCustomers)..addColumns([localCustomers.clientUuid]);
      customerUuids.addAll((await c.map((r) => r.read(localCustomers.clientUuid)).get()).whereType<String>());
      await delete(syncQueueEntries).go();
      await delete(localCustomers).go();
      return true;
    });
    if (cleared) {
      // Ảnh chỉ ghi trong payload (biểu mẫu thị trường `_local_photo_paths`, ảnh điểm bán rơi về đường dẫn tạm) —
      // giải mã SAU transaction, không giữ khoá DB.
      for (final payload in payloads) {
        try {
          _collectPaths(jsonDecode(payload), queuePaths);
        } catch (_) {}
      }
      await _deleteUserFiles(queuePaths, customerUuids);
    }
    return cleared;
  }

  static void _collectPaths(Object? node, List<String> out) {
    if (node is String) {
      if (node.startsWith('/') || node.startsWith('file://')) out.add(node);
    } else if (node is Map) {
      for (final v in node.values) {
        _collectPaths(v, out);
      }
    } else if (node is List) {
      for (final v in node) {
        _collectPaths(v, out);
      }
    }
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
    // Ảnh điểm bán do customer_local_data_source chép vào offline_customer_photos/<clientUuid>_photo_<i>.<ext>.
    if (docs != null && customerUuids.isNotEmpty) {
      try {
        final dir = Directory(p.join(docs, 'offline_customer_photos'));
        if (await dir.exists()) {
          await for (final f in dir.list()) {
            final name = p.basename(f.path);
            if (customerUuids.any((u) => name.startsWith('${u}_photo_'))) files.add(f.path);
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

  /// Xóa các mục dead đã được xử lý hoặc dọn dẹp
  Future<int> clearDeadEntries() {
    return (delete(syncQueueEntries)..where((tbl) => tbl.state.equals('dead'))).go();
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
          ..where((tbl) => tbl.entity.equals('form_submission'))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.id)]))
        .get();
  }

  /// Stream theo dõi các phiếu biểu mẫu ngoại tuyến
  Stream<List<SyncQueueEntry>> watchFormSubmissionEntries() {
    return (select(syncQueueEntries)
          ..where((tbl) => tbl.entity.equals('form_submission'))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.id)]))
        .watch();
  }

  /// Lấy danh sách tất cả các mục đang chờ gửi hoặc đang gửi (pending & sending)
  Future<List<SyncQueueEntry>> getAllPendingQueueEntries() {
    return (select(syncQueueEntries)
          ..where((tbl) => tbl.state.equals('pending') | tbl.state.equals('sending'))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.id)]))
        .get();
  }

  /// Stream theo dõi danh sách tất cả các mục đang chờ gửi hoặc đang gửi (pending & sending)
  Stream<List<SyncQueueEntry>> watchAllPendingQueueEntries() {
    return (select(syncQueueEntries)
          ..where((tbl) => tbl.state.equals('pending') | tbl.state.equals('sending'))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.id)]))
        .watch();
  }

  /// Stream theo dõi các mục hỏng vĩnh viễn (dead / 4xx)
  Stream<List<SyncQueueEntry>> watchDeadQueueEntries() {
    return (select(syncQueueEntries)
          ..where((tbl) => tbl.state.equals('dead'))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.id)]))
        .watch();
  }

  /// Tìm mục trong hàng đợi theo clientUuid (phục vụ liên kết cha-con: visit -> photos/checkout)
  Future<SyncQueueEntry?> getEntryByClientUuid(String clientUuid) {
    return (select(syncQueueEntries)..where((tbl) => tbl.clientUuid.equals(clientUuid))).getSingleOrNull();
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

  /// Tìm kiếm điểm bán offline không dấu (§7.4)
  Future<List<LocalCustomer>> searchLocalCustomers(String unaccentedQuery) {
    if (unaccentedQuery.trim().isEmpty) {
      return getAllLocalCustomers();
    }
    final q = '%$unaccentedQuery%';
    return (select(localCustomers)
          ..where((tbl) =>
              tbl.nameUnaccent.like(q) |
              tbl.code.like(q) |
              tbl.phone.like(q) |
              tbl.address.like(q))
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

  /// Xóa 1 điểm bán theo ID khỏi SQLite
  Future<int> deleteCustomerById(int id) {
    return (delete(localCustomers)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// Xóa bản ghi điểm bán chờ đồng bộ khỏi SQLite và hủy các tác vụ sync liên quan trong sync_queue
  Future<void> deletePendingCustomer(String clientUuid) async {
    await (delete(localCustomers)..where((tbl) => tbl.clientUuid.equals(clientUuid))).go();
    await (delete(syncQueueEntries)
          ..where((tbl) => tbl.clientUuid.equals(clientUuid) | tbl.parentUuid.equals(clientUuid)))
        .go();
  }

  /// Tìm entry visit trong sync_queue theo clientUuid
  Future<SyncQueueEntry?> findVisitQueueEntry(String clientUuid) async {
    final entries = await (select(syncQueueEntries)
          ..where((tbl) => tbl.clientUuid.equals(clientUuid) & tbl.entity.equals('visit')))
        .get();
    return entries.isNotEmpty ? entries.first : null;
  }

  /// Tìm lượt chấm công đã đồng bộ gần nhất có serverId
  Future<SyncQueueEntry?> findLastSyncedPunchEntry() async {
    final entries = await (select(syncQueueEntries)
          ..where((tbl) => tbl.entity.equals('attendance_punch') & tbl.serverId.isNotNull())
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.id)])
          ..limit(1))
        .get();
    return entries.isNotEmpty ? entries.first : null;
  }

  /// Lấy danh sách đường dẫn ảnh cục bộ của lượt viếng thăm trước khi xoá queue
  Future<List<String>> getPendingVisitPhotoPaths(String clientUuid) async {
    final entries = await (select(syncQueueEntries)
          ..where((tbl) =>
              tbl.parentUuid.equals(clientUuid) &
              tbl.entity.equals('visit_photo') &
              tbl.localPath.isNotNull()))
        .get();
    return entries.map((e) => e.localPath!).toList();
  }

  /// Xoá các mục pending/sending của lượt viếng thăm (create, upload ảnh, checkout)
  Future<int> deletePendingVisitQueue(String clientUuid) async {
    return await (delete(syncQueueEntries)
          ..where((tbl) =>
              (tbl.clientUuid.equals(clientUuid) | tbl.parentUuid.equals(clientUuid)) &
              (tbl.state.equals('pending') | tbl.state.equals('sending'))))
        .go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'dms_app.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
