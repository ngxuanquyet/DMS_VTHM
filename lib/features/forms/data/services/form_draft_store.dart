import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/app_database.dart' show collectFilePaths, looksLikeFilePath;
import '../../../../core/utils/offline_photo_store.dart';

/// Nháp phiếu khảo sát ĐANG ĐIỀN trong lượt viếng thăm — thoát màn / tắt app / app bị đóng giữa chừng không mất phần đã
/// nhập (chủ hệ thống chốt 19/11/2026: tự lưu liên tục, lưu cả ảnh, gắn theo lượt + phiếu, nháp cũ tự dọn).
///
/// MỘT ô cho lượt đang mở (như [VisitProgressStore]): khớp id lượt hoặc `client_uuid` (lượt ngoại tuyến đổi id âm → id
/// server, uuid giữ nguyên). Tệp trên máy (ảnh / tệp đính kèm CHƯA tải lên) chép vào `Documents/[photoDir]` — ảnh chụp
/// nằm ở thư mục tạm, hệ điều hành dọn được; ảnh đã tải lên giữ token (xem [maxAge]).
/// Xoá: nộp thành công ([remove]), kết thúc lượt ([clearVisit]), lưu cho lượt khác; nháp quá [maxAge] không khôi phục.
class FormDraftStore {
  FormDraftStore._();

  static const String _key = 'form_drafts_v1';
  static const String photoDir = 'form_draft_photos';

  /// Nháp lâu hơn mức này không khôi phục — tính từ lần lưu ĐẦU (`created_at`) của phiếu, không theo ngày lịch (lượt vắt
  /// qua nửa đêm vẫn giữ). Ảnh trong nháp chỉ là token, server dọn ảnh chưa nộp sau 1 ngày tính từ lúc tải lên; mọi ảnh
  /// đều tải lên SAU lần lưu đầu ⇒ token nào cũng trẻ hơn nháp, giữ dưới 1 ngày là token còn sống.
  static const Duration maxAge = Duration(hours: 20);

  /// Ghi nối tiếp — hai lần ghi chồng nhau không được để bản cũ đè bản mới.
  static Future<void> _chain = Future.value();

  static bool _sameVisit(Map m, int visitId, String clientUuid) {
    final savedId = m['visit_id'] is num ? (m['visit_id'] as num).toInt() : 0;
    final savedUuid = m['client_uuid']?.toString() ?? '';
    return (visitId > 0 && savedId == visitId) || (clientUuid.isNotEmpty && savedUuid == clientUuid);
  }

  static Map? _read(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw);
      return m is Map ? m : null;
    } catch (_) {
      return null;
    }
  }

  /// Chép tệp trên máy trong [v] (ô ảnh, `photos` của ô ma trận, ô tệp, nhóm lặp…) vào thư mục nháp; token / chữ giữ
  /// nguyên ([OfflinePhotoStore.persist] trả nguyên chuỗi không phải tệp đang có). [memo] (tệp gốc → bản chép) giữ qua các
  /// lần lưu của một màn — không chép lại cùng một tệp.
  static Future<dynamic> _persistFiles(dynamic v, Map<String, String> memo, String prefix) async {
    if (v is String) {
      final t = v.trim();
      return looksLikeFilePath(t)
          ? OfflinePhotoStore.persistOnce(memo, OfflinePhotoStore.toFilePath(t), dirName: photoDir, prefix: prefix)
          : v;
    }
    if (v is List) return [for (final x in v) await _persistFiles(x, memo, prefix)];
    if (v is Map) return {for (final e in v.entries) '${e.key}': await _persistFiles(e.value, memo, prefix)};
    return v;
  }

  /// Tệp nằm trong thư mục nháp mà [v] trỏ tới.
  static Set<String> _draftFiles(Object? v) {
    final all = <String>[];
    collectFilePaths(v, all);
    return all.where((x) => x.contains('/$photoDir/')).toSet();
  }

  static Future<void> _deleteFiles(Iterable<String> files) async {
    for (final f in files) {
      try {
        await File(f).delete();
      } catch (_) {}
    }
  }

  /// [answers] PHẢI là bản chụp độc lập (không dùng chung map lồng với biểu mẫu đang sửa — lượt chờ chép tệp đọc nó).
  /// false = không ghi được (nơi gọi không được coi là đã lưu).
  static Future<bool> save({
    required int visitId,
    required String clientUuid,
    required int configId,
    required Map<String, dynamic> answers,
    required Map<String, String> photoMemo,
  }) {
    final done = _chain.then((_) async {
      try {
        final prefix = '${clientUuid}_$configId';
        final now = DateTime.now().millisecondsSinceEpoch;
        final draft = <String, dynamic>{'saved_at': now, 'answers': await _persistFiles(answers, photoMemo, prefix)};
        final prefs = await SharedPreferences.getInstance();
        final slot = _read(prefs);
        final old = slot?['drafts'] is Map ? slot!['drafts'] as Map : const {};
        final cu = slot != null && _sameVisit(slot, visitId, clientUuid) ? old['$configId'] : null;
        // Giữ mốc lần lưu đầu — trừ khi bản cũ đã quá [maxAge] (load không khôi phục nó): bắt đầu nháp mới, không thì
        // mọi lần lưu sau đều "sinh ra đã quá hạn".
        final createdAt = cu is Map && cu['created_at'] is num ? (cu['created_at'] as num).toInt() : now;
        draft['created_at'] = now - createdAt > maxAge.inMilliseconds ? now : createdAt;
        final drafts = <String, dynamic>{
          // Nháp của lượt khác: bỏ cả ô.
          if (slot != null && _sameVisit(slot, visitId, clientUuid)) ...Map<String, dynamic>.from(old),
          '$configId': draft,
        };
        await prefs.setString(_key, jsonEncode({'visit_id': visitId, 'client_uuid': clientUuid, 'drafts': drafts}));
        // Tệp không còn nháp nào trỏ tới (ô bỏ đi / lượt cũ). Nháp mới có thể trỏ CHÍNH tệp của bản cũ (nháp khôi phục
        // đã nằm trong thư mục nháp) ⇒ chỉ xoá phần chênh.
        await _deleteFiles(_draftFiles(old).difference(_draftFiles(drafts)));
        return true;
      } catch (_) {
        return false;
      }
    });
    _chain = done;
    return done;
  }

  /// Nháp của phiếu [configId] trong đúng lượt này; null khi không có / của lượt khác / quá [maxAge] / hỏng.
  static Future<({Map<String, dynamic> answers, DateTime savedAt})?> load({
    required int visitId,
    required String clientUuid,
    required int configId,
  }) async {
    await _chain;
    try {
      final prefs = await SharedPreferences.getInstance();
      final slot = _read(prefs);
      if (slot == null || !_sameVisit(slot, visitId, clientUuid)) return null;
      final d = slot['drafts'] is Map ? (slot['drafts'] as Map)['$configId'] : null;
      if (d is! Map || d['answers'] is! Map) return null;
      final savedAt = DateTime.fromMillisecondsSinceEpoch(d['saved_at'] is num ? (d['saved_at'] as num).toInt() : 0);
      final createdAt = d['created_at'] is num ? (d['created_at'] as num).toInt() : 0;
      if (DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(createdAt)) > maxAge) return null;
      return (answers: Map<String, dynamic>.from(d['answers'] as Map), savedAt: savedAt);
    } catch (_) {
      return null;
    }
  }

  /// Bỏ nháp của MỘT phiếu (đã nộp / người dùng chọn làm lại) cùng tệp của nó.
  static Future<void> remove({required int visitId, required String clientUuid, required int configId}) {
    return _chain = _chain.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final slot = _read(prefs);
        if (slot == null || !_sameVisit(slot, visitId, clientUuid) || slot['drafts'] is! Map) return;
        final drafts = Map<String, dynamic>.from(slot['drafts'] as Map);
        final removed = drafts.remove('$configId');
        if (removed == null) return;
        await prefs.setString(_key, jsonEncode({...slot, 'drafts': drafts}));
        await _deleteFiles(_draftFiles(removed).difference(_draftFiles(drafts)));
      } catch (_) {}
    });
  }

  /// Kết thúc lượt [visitId] / [clientUuid] (check-out / huỷ / bỏ phiên): xoá mọi nháp của ĐÚNG lượt đó cùng tệp của
  /// chúng. `resetSession` còn chạy ở đường không đóng lượt đang mở (state không phải lượt đó) ⇒ không khớp thì giữ nguyên.
  static Future<void> clearVisit({required int visitId, required String clientUuid}) {
    return _chain = _chain.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final slot = _read(prefs);
        if (slot == null || !_sameVisit(slot, visitId, clientUuid)) return;
        await prefs.remove(_key);
        await _deleteFiles(_draftFiles(slot['drafts']));
      } catch (_) {}
    });
  }
}
