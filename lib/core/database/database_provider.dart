import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() {
    db.close();
  });
  return db;
});

final pendingSyncCountProvider = StreamProvider.autoDispose<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchPendingSyncCount();
});

final deadSyncCountProvider = StreamProvider.autoDispose<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchDeadSyncCount();
});

final formSubmissionEntriesProvider =
    StreamProvider.autoDispose<List<SyncQueueEntry>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchFormSubmissionEntries();
});

final allPendingQueueEntriesProvider =
    StreamProvider.autoDispose<List<SyncQueueEntry>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllPendingQueueEntries();
});

final deadQueueEntriesProvider =
    StreamProvider.autoDispose<List<SyncQueueEntry>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchDeadQueueEntries();
});


/// Nhật ký đã gửi của người đang đăng nhập trong [AppDatabase.sentLogRetention] gần nhất (màn Báo cáo gửi dữ liệu).
final sentLogsProvider = StreamProvider.autoDispose<List<SyncSentLog>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day).subtract(AppDatabase.sentLogRetention);
  return db.watchSentLogs(fromMs: from.millisecondsSinceEpoch);
});
