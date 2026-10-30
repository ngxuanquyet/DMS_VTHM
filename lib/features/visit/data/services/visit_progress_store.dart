import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/visit_photo_entity.dart';

/// Tiến độ của lượt viếng thăm ĐANG MỞ lưu trên máy: ảnh ĐÃ tải lên + biểu mẫu khảo sát đã nộp.
///
/// Tắt hẳn app rồi vào lại lượt thì màn lượt vẫn hiện đúng số ảnh / biểu mẫu (chủ hệ thống chốt 30/10/2026: lưu trên máy,
/// không gọi thêm server). Ảnh CHƯA tải lên đã có hàng đợi đồng bộ giữ riêng — ở đây chỉ giữ ảnh có id server (> 0).
/// MỘT ô duy nhất (mỗi lúc chỉ một lượt mở); đọc chỉ nhận khi khớp id lượt hoặc `client_uuid` (lượt ngoại tuyến đổi
/// id âm → id server sau đồng bộ, uuid thì giữ nguyên).
class VisitProgressStore {
  VisitProgressStore._();

  static const String _key = 'visit_progress_v1';

  /// Ghi nối tiếp — hai lần ghi chồng nhau không được để bản cũ đè bản mới.
  static Future<void> _chain = Future.value();

  static Future<void> save({
    required int visitId,
    required String clientUuid,
    required List<VisitPhotoEntity> photos,
    required Set<int> submittedConfigIds,
  }) {
    final payload = jsonEncode({
      'visit_id': visitId,
      'client_uuid': clientUuid,
      'photos': photos.where((p) => p.id > 0).map((p) => p.toJson()).toList(),
      'submitted_config_ids': submittedConfigIds.toList(),
    });
    return _chain = _chain.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_key, payload);
      } catch (_) {}
    });
  }

  /// Tiến độ đã lưu của đúng lượt này; null khi không có / của lượt khác / hỏng.
  static Future<({List<VisitPhotoEntity> photos, Set<int> submittedConfigIds})?> load({
    required int visitId,
    required String clientUuid,
  }) async {
    await _chain;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final savedId = m['visit_id'] is num ? (m['visit_id'] as num).toInt() : 0;
      final savedUuid = m['client_uuid']?.toString() ?? '';
      final sameVisit = (visitId > 0 && savedId == visitId) || (clientUuid.isNotEmpty && savedUuid == clientUuid);
      if (!sameVisit) return null;
      final photos = (m['photos'] is List ? m['photos'] as List : const [])
          .whereType<Map>()
          .map((p) => VisitPhotoEntity.fromJson(Map<String, dynamic>.from(p)))
          .where((p) => p.id > 0)
          .toList();
      final submitted = (m['submitted_config_ids'] is List ? m['submitted_config_ids'] as List : const [])
          .map((e) => e is num ? e.toInt() : int.tryParse('$e'))
          .whereType<int>()
          .toSet();
      return (photos: photos, submittedConfigIds: submitted);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() {
    return _chain = _chain.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_key);
      } catch (_) {}
    });
  }
}
