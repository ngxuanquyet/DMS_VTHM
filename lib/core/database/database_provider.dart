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

