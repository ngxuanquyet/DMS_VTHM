import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/position_declaration/domain/entities/position_declaration_entity.dart';
import '../../features/visit/domain/entities/visit_entity.dart';

/// Dọn LỊCH SỬ lưu trong máy (SharedPreferences) quá [keep] — chủ hệ thống chốt 28/10/2026 giữ 60 ngày; dữ liệu cũ
/// hơn đã nằm trên máy chủ. KHÔNG bao giờ bỏ bản ghi chưa đồng bộ (lượt còn mở / chưa có id máy chủ, khai báo đang
/// chờ gửi). Hàng đợi đồng bộ (SQLite) dọn riêng ở AppDatabase.purgeDoneEntries. KHÔNG cắt danh sách id thông báo
/// đã đọc: nó giữ cả trạng thái đọc của thông báo máy chủ (không nằm trong kho cục bộ) — cắt là hiện lại "chưa đọc".
class LocalHistoryRetention {
  LocalHistoryRetention._();

  static const keep = Duration(days: 60);

  static const _visitsKey = 'dms_visits_local_cache_v2'; // visit_repository_impl
  static const _declarationsKey = 'pos_declarations_local_list'; // position_declaration_repository_impl
  static const _throttlePrefix = 'notify_throttle_'; // app_notification_service
  static const _travelLegsPrefix = 'dms_travel_legs_cache_v1_'; // travel_repository_impl: <prefix><userId>_<yyyy-MM-dd>

  static bool _ranThisLaunch = false;

  /// Chạy một lần mỗi lần mở app — gọi và CHỜ trước lần tải dữ liệu đầu (đăng nhập/khôi phục phiên), kẻo repository
  /// đọc danh sách cũ rồi ghi đè bản vừa dọn. Lỗi thì lần mở sau thử lại.
  static Future<void> runOnce({DateTime? now}) async {
    if (_ranThisLaunch) return;
    await prune(now: now);
    _ranThisLaunch = true;
  }

  static Future<void> prune({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final cutoff = (now ?? DateTime.now()).subtract(keep);
    for (final step in <Future<void> Function()>[
      () => _pruneVisits(prefs, cutoff),
      () => _pruneDeclarations(prefs, cutoff),
      () => _pruneThrottleKeys(prefs, cutoff),
      () => _pruneTravelLegs(prefs, cutoff),
    ]) {
      try {
        await step();
      } catch (e) {
        debugPrint('[LocalHistoryRetention] Lỗi dọn lịch sử: $e');
      }
    }
  }

  static Future<void> _pruneVisits(SharedPreferences prefs, DateTime cutoff) async {
    final raw = prefs.getString(_visitsKey);
    if (raw == null || raw.isEmpty) return;
    final all = (jsonDecode(raw) as List<dynamic>).whereType<Map<String, dynamic>>().map(VisitEntity.fromJson).toList();
    final kept = all.where((v) {
      if (v.isOpen || v.id <= 0) return true; // còn mở / chưa có id máy chủ = chưa đồng bộ
      final at = v.checkinAt ?? DateTime.tryParse(v.visitDate ?? '');
      return at == null || !at.isBefore(cutoff);
    }).toList();
    if (kept.length == all.length) return;
    await prefs.setString(_visitsKey, jsonEncode(kept.map((e) => e.toJson()).toList()));
  }

  static Future<void> _pruneDeclarations(SharedPreferences prefs, DateTime cutoff) async {
    final raw = prefs.getString(_declarationsKey);
    if (raw == null || raw.isEmpty) return;
    final all = (jsonDecode(raw) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(PositionDeclarationEntity.fromJson)
        .toList();
    final kept = all.where((d) {
      if (d.syncStatus == 'pending') return true; // 'error' = máy chủ từ chối hẳn, không gửi lại — dọn theo ngày
      final at = d.createdAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(d.createdAtMs)
          : DateTime.tryParse(d.declaredDate ?? '');
      return at == null || !at.isBefore(cutoff);
    }).toList();
    if (kept.length == all.length) return;
    await prefs.setString(_declarationsKey, jsonEncode(kept.map((e) => e.toJson()).toList()));
  }

  /// Khoá chống bắn trùng thông báo mang mốc ms lần bắn gần nhất; khoảng chặn dài nhất chỉ vài giờ.
  static Future<void> _pruneThrottleKeys(SharedPreferences prefs, DateTime cutoff) async {
    final cutoffMs = cutoff.millisecondsSinceEpoch;
    for (final k in prefs.getKeys().where((k) => k.startsWith(_throttlePrefix)).toList()) {
      final v = prefs.get(k);
      if (v is! int || v < cutoffMs) await prefs.remove(k);
    }
  }

  static Future<void> _pruneTravelLegs(SharedPreferences prefs, DateTime cutoff) async {
    for (final k in prefs.getKeys().where((k) => k.startsWith(_travelLegsPrefix)).toList()) {
      final date = DateTime.tryParse(k.substring(k.lastIndexOf('_') + 1));
      if (date != null && date.isBefore(cutoff)) await prefs.remove(k);
    }
  }
}
