import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
}
