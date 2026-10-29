import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/database/app_database.dart';

/// Hàng đợi đồng bộ có index (Đợt 3 hiệu năng, P3.6) — cả máy cài mới lẫn máy nâng cấp từ schema 3.
Future<Set<String>> _queueIndexes(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'sync_queue_entries'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

const _expected = {'idx_sync_queue_owner_state', 'idx_sync_queue_client_uuid', 'idx_sync_queue_parent_uuid'};

void main() {
  test('cài mới ⇒ có đủ index hàng đợi', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await _queueIndexes(db), containsAll(_expected));
  });

  test('nâng cấp từ schema 3 ⇒ thêm index, giữ dữ liệu', () async {
    final executor = NativeDatabase.memory(setup: (raw) {
      // Dựng bảng schema 3 (đủ cột) rồi đánh dấu user_version = 3 như máy đang chạy bản cũ.
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
          sync_status TEXT NOT NULL DEFAULT 'pending', created_at TEXT, updated_at TEXT)
      ''');
      raw.execute(
        "INSERT INTO sync_queue_entries (entity, op, client_uuid, payload, created_at, created_elapsed, boot_id, "
        "owner_user_id) VALUES ('visit', 'create', 'u-1', '{}', 0, 0, 'b', 7)",
      );
      raw.execute('PRAGMA user_version = 3');
    });
    final db = AppDatabase(executor, 7);
    addTearDown(db.close);
    expect(await _queueIndexes(db), containsAll(_expected));
    expect(await db.countPendingSync(), 1);
  });
}
