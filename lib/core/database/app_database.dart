import 'dart:io';
import 'package:drift/drift.dart';
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

  /// Hồi phục các mục 'sending' mồ côi về 'pending' khi app khởi động (§3.3 Luật 5)
  Future<int> recoverOrphanedSendingEntries() {
    return (update(syncQueueEntries)..where((tbl) => tbl.state.equals('sending')))
        .write(const SyncQueueEntriesCompanion(state: Value('pending')));
  }

  /// Lấy các mục pending có thể gửi (đã tới hạn nextAttemptAt) theo thứ tự FIFO (§3.3 Luật 1 & 6)
  Future<List<SyncQueueEntry>> getPendingQueueEntries({int limit = 50}) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return (select(syncQueueEntries)
          ..where((tbl) =>
              tbl.state.equals('pending') &
              (tbl.nextAttemptAt.isNull() | tbl.nextAttemptAt.isSmallerOrEqualValue(nowMs)))
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

  /// Đánh dấu mục bị lỗi vĩnh viễn (403, 422, INVALID) -> chuyển sang 'dead' (§3.2, §3.3 Luật 1)
  Future<bool> markDead(int id, String error) async {
    final updated = await (update(syncQueueEntries)..where((tbl) => tbl.id.equals(id))).write(
      SyncQueueEntriesCompanion(
        state: const Value('dead'),
        lastError: Value(error),
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

  /// Đếm số mục đang chờ đồng bộ
  Future<int> countPendingSync() async {
    final countExp = syncQueueEntries.id.count();
    final query = selectOnly(syncQueueEntries)
      ..addColumns([countExp])
      ..where(syncQueueEntries.state.equals('pending') | syncQueueEntries.state.equals('sending'));
    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result ?? 0;
  }

  /// Stream theo dõi số mục đang chờ đồng bộ theo thời gian thực
  Stream<int> watchPendingSyncCount() {
    final countExp = syncQueueEntries.id.count();
    final query = selectOnly(syncQueueEntries)
      ..addColumns([countExp])
      ..where(syncQueueEntries.state.equals('pending') | syncQueueEntries.state.equals('sending'));
    return query.map((row) => row.read(countExp) ?? 0).watchSingle();
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

  // ===========================================================================
  // LOCAL CUSTOMER OPERATIONS (§7 SPEC-DONG-BO-OFFLINE)
  // ===========================================================================

  /// Thêm mới hoặc cập nhật thông tin điểm bán cục bộ
  Future<int> insertOrUpdateCustomer(LocalCustomersCompanion customer) {
    return into(localCustomers).insertOnConflictUpdate(customer);
  }

  /// Lấy toàn bộ danh sách khách hàng cục bộ
  Future<List<LocalCustomer>> getAllLocalCustomers() {
    return select(localCustomers).get();
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
              tbl.address.like(q)))
        .get();
  }

  /// Cập nhật trạng thái đồng bộ và server ID sau khi push thành công
  Future<void> markCustomerSynced(String clientUuid, int serverId, {String? code, String? type}) async {
    await (update(localCustomers)..where((tbl) => tbl.clientUuid.equals(clientUuid))).write(
      LocalCustomersCompanion(
        id: Value(serverId),
        code: code != null ? Value(code) : const Value.absent(),
        type: type != null && type.isNotEmpty ? Value(type) : const Value.absent(),
        syncStatus: const Value('synced'),
        approvalStatus: const Value('approved'),
      ),
    );
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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'dms_app.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
