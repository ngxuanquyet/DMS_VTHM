import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/services/local_history_retention.dart';

/// Dọn lịch sử lưu trong máy quá 60 ngày (chủ hệ thống chốt 28/10/2026) — không bao giờ bỏ bản ghi chưa đồng bộ.
void main() {
  final now = DateTime(2026, 10, 28, 9);
  final old = now.subtract(const Duration(days: 61));
  final recent = now.subtract(const Duration(days: 5));
  String iso(DateTime d) => d.toIso8601String();

  test('dọn lượt viếng thăm, khai báo, khoá chặn thông báo, cache công tác quá hạn', () async {
    SharedPreferences.setMockInitialValues({
      'dms_visits_local_cache_v2': jsonEncode([
        {'id': 1, 'customer_id': 10, 'checkin_at': iso(old), 'checkout_at': iso(old)}, // cũ, đã đóng ⇒ bỏ
        {'id': 2, 'customer_id': 10, 'checkin_at': iso(recent), 'checkout_at': iso(recent)}, // mới ⇒ giữ
        {'id': -3, 'customer_id': 10, 'checkin_at': iso(old), 'checkout_at': iso(old)}, // chưa đồng bộ ⇒ giữ
        {'id': 4, 'customer_id': 10, 'checkin_at': iso(old)}, // còn mở ⇒ giữ
      ]),
      'pos_declarations_local_list': jsonEncode([
        {'client_uuid': 'd-old', 'sync_status': 'synced', 'created_at_ms': old.millisecondsSinceEpoch},
        {'client_uuid': 'd-new', 'sync_status': 'synced', 'created_at_ms': recent.millisecondsSinceEpoch},
        {'client_uuid': 'd-pending', 'sync_status': 'pending', 'created_at_ms': old.millisecondsSinceEpoch},
        {'client_uuid': 'd-error-old', 'sync_status': 'error', 'created_at_ms': old.millisecondsSinceEpoch},
      ]),
      'notify_throttle_route_brief_2026-08-01': old.millisecondsSinceEpoch,
      'notify_throttle_queue_pending': recent.millisecondsSinceEpoch,
      'dms_travel_legs_cache_v1_7_2026-08-01': '[]',
      'dms_travel_legs_cache_v1_7_2026-10-20': '[]',
      'local_notifications_store_v1': jsonEncode({
        'today': [
          {'id': 'n1', 'title': 't', 'message': 'm', 'time': '09:00', 'type': 'x'},
        ],
        'earlier': [],
      }),
      'local_notifications_read_ids_v1': ['n1', 'server-noti'],
    });

    await LocalHistoryRetention.prune(now: now);
    final prefs = await SharedPreferences.getInstance();

    final visits = (jsonDecode(prefs.getString('dms_visits_local_cache_v2')!) as List).map((e) => e['id']);
    expect(visits, unorderedEquals([2, -3, 4]));
    final decls =
        (jsonDecode(prefs.getString('pos_declarations_local_list')!) as List).map((e) => e['client_uuid']);
    expect(decls, unorderedEquals(['d-new', 'd-pending']));
    expect(prefs.containsKey('notify_throttle_route_brief_2026-08-01'), isFalse);
    expect(prefs.containsKey('notify_throttle_queue_pending'), isTrue);
    expect(prefs.containsKey('dms_travel_legs_cache_v1_7_2026-08-01'), isFalse);
    expect(prefs.containsKey('dms_travel_legs_cache_v1_7_2026-10-20'), isTrue);
    expect(prefs.getStringList('local_notifications_read_ids_v1'), ['n1', 'server-noti'],
        reason: 'id đã đọc gồm cả thông báo máy chủ — không cắt');
  });

  test('cache biểu mẫu: bỏ khoá quá 60 ngày, khoá cũ chưa có mốc thì bắt đầu tính từ lần dọn đầu', () async {
    SharedPreferences.setMockInitialValues({
      'dms_market_forms_u1_visit_10': '[]',
      'dms_market_forms_u1_visit_11': '[]',
      'dms_market_forms_u1_visit_12': '[]', // khoá có từ trước, chưa có mốc
      'dms_market_forms_saved_at_v1': jsonEncode({
        'dms_market_forms_u1_visit_10': old.millisecondsSinceEpoch,
        'dms_market_forms_u1_visit_11': recent.millisecondsSinceEpoch,
        'dms_market_forms_u1_visit_99': old.millisecondsSinceEpoch, // khoá đã mất
      }),
    });

    await LocalHistoryRetention.prune(now: now);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('dms_market_forms_u1_visit_10'), isFalse);
    expect(prefs.containsKey('dms_market_forms_u1_visit_11'), isTrue);
    expect(prefs.containsKey('dms_market_forms_u1_visit_12'), isTrue);
    final savedAt = jsonDecode(prefs.getString('dms_market_forms_saved_at_v1')!) as Map<String, dynamic>;
    expect(savedAt.keys, unorderedEquals(['dms_market_forms_u1_visit_11', 'dms_market_forms_u1_visit_12']));
    expect(savedAt['dms_market_forms_u1_visit_12'], now.millisecondsSinceEpoch);
  });

  test('quét ảnh tạm: xoá ảnh cũ không ai trỏ tới; giữ ảnh mới, ảnh hàng đợi/lịch sử còn trỏ (kể cả khác dạng đường dẫn)',
      () async {
    final root = await Directory.systemTemp.createTemp('dms_sweep');
    addTearDown(() => root.delete(recursive: true));
    final sub = Directory('${root.path}/offline_visit_photos')..createSync();
    File mk(String path, DateTime at) => File(path)
      ..writeAsBytesSync([1])
      ..setLastModifiedSync(at);
    final oldOrphan = mk('${root.path}/image_picker_1.jpg', old);
    final oldWm = mk('${sub.path}/wm_1.jpg', old);
    final oldReferenced = mk('${sub.path}/photo_ref.jpg', old);
    final oldRefOtherForm = mk('${root.path}/att_front_x.jpg', old);
    final fresh = mk('${root.path}/image_picker_2.jpg', now.subtract(const Duration(days: 1)));
    final oldNotImage = mk('${root.path}/cache.bin', old);
    final oldInHistory = mk('${root.path}/image_picker_decl.jpg', old);
    final nested = Directory('${root.path}/lib_cache')..createSync();
    final oldNested = mk('${nested.path}/tile.png', old);
    final picked = Directory('${root.path}/0f8fad5b-d9cb-469f-a165-70867728950e')..createSync();
    final oldPicked = mk('${picked.path}/IMG_1.jpg', old);
    final oldFileUri = mk('${root.path}/image_picker_uri.jpg', old);
    final oldInList = mk('${root.path}/image_picker_list.jpg', old);
    SharedPreferences.setMockInitialValues({
      'pos_declarations_local_list': jsonEncode([
        {'client_uuid': 'd1', 'local_photo_paths': [oldInHistory.path]},
      ]),
      'dms_active_visit_session_v1': jsonEncode({'photos': ['file://${oldFileUri.path}']}),
      'some_list': [oldInList.path],
    });

    final db = AppDatabase(NativeDatabase.memory(), 1);
    addTearDown(db.close);
    await db.enqueue(SyncQueueEntriesCompanion.insert(
      entity: 'visit_photo',
      op: 'upload',
      clientUuid: 'p1',
      payload: jsonEncode({'local_path': '/private/var/some/other/att_front_x.jpg'}),
      localPath: Value(oldReferenced.path),
      createdAt: 0,
      createdElapsed: 0,
      bootId: 'b',
    ));

    final n = await LocalHistoryRetention.sweepPhotoFiles(db, now: now, roots: [root, sub]);
    expect(n, 3);
    expect(oldPicked.existsSync(), isFalse, reason: 'ảnh chọn từ thư viện (cache/<uuid>/) cũng được dọn');
    expect(picked.existsSync(), isFalse, reason: 'thư mục <uuid> rỗng bị xoá');
    expect(oldFileUri.existsSync(), isTrue, reason: 'tham chiếu dạng file://');
    expect(oldInList.existsSync(), isTrue, reason: 'tham chiếu trong StringList');
    expect(oldInHistory.existsSync(), isTrue, reason: 'lịch sử khai báo còn trỏ tới');
    expect(oldNested.existsSync(), isTrue, reason: 'không quét sâu thư mục con (cache thư viện khác)');
    expect(oldOrphan.existsSync(), isFalse);
    expect(oldWm.existsSync(), isFalse);
    expect(oldReferenced.existsSync(), isTrue);
    expect(oldRefOtherForm.existsSync(), isTrue);
    expect(fresh.existsSync(), isTrue);
    expect(oldNotImage.existsSync(), isTrue);
  });
}
