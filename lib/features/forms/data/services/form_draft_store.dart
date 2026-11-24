import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/app_database.dart' show collectFilePaths, looksLikeFilePath;
import '../../../../core/services/local_history_retention.dart';
import '../../../../core/utils/offline_photo_store.dart';

/// Nháp phiếu khảo sát ĐANG ĐIỀN trong lượt viếng thăm — thoát màn / tắt app / app bị đóng giữa chừng không mất phần đã
/// nhập (chủ hệ thống chốt 19/11/2026: tự lưu liên tục, lưu cả ảnh, gắn theo lượt + phiếu, nháp cũ tự dọn).
///
/// MỘT ô cho lượt đang mở (như [VisitProgressStore]): khớp id lượt hoặc `client_uuid` (lượt ngoại tuyến đổi id âm → id
/// server, uuid giữ nguyên). Tệp trên máy (ảnh / tệp đính kèm CHƯA tải lên) chép vào `Documents/[photoDir]` — ảnh chụp
/// nằm ở thư mục tạm, hệ điều hành dọn được; ảnh đã tải lên giữ token trong câu trả lời, tệp gốc của nó chép vào
/// `token_files` (token → tệp) — phiếu nộp muộn khi token đã hết hạn trên server thì tải lại từ tệp này.
/// Xoá: nộp thành công ([remove]), kết thúc lượt ([clearVisit]), lưu cho lượt khác; nháp quá [maxAge] không khôi phục.
///
/// Phiếu THU THẬP (không gắn lượt, chủ hệ thống chốt 20/11/2026): mỗi biểu mẫu một nháp, cùng luật lưu / hạn, ở ngăn RIÊNG
/// của từng tài khoản ([collectSlot]) với lượt giả [collectVisitId] / [collectUuid] — không đụng ngăn của lượt viếng thăm.
///
/// Màn "Thêm mới điểm bán" (chủ hệ thống chốt 24/11/2026): MỘT nháp mỗi tài khoản, cùng luật lưu / hạn, ở ngăn [customerSlot]
/// (lượt giả [collectVisitId] / [customerUuid], phiếu [customerConfigId]).
class FormDraftStore {
  FormDraftStore._();

  static const String _key = 'form_drafts_v1';

  /// Ngăn nháp của lượt viếng thăm (phiếu khảo sát).
  static const String visitSlot = _key;

  /// Ngăn nháp phiếu thu thập của [account] — tiền tố `dms_market_forms_` ⇒ đăng xuất xoá theo (máy dùng chung).
  static String collectSlot(String account) => 'dms_market_forms_draft_collect_v1_$account';

  /// Ngăn nháp màn "Thêm mới điểm bán" của [account] — cùng tiền tố [_accountDraftPrefix] ⇒ đăng xuất xoá theo.
  static String customerSlot(String account) => 'dms_market_forms_draft_customer_v1_$account';

  /// Tiền tố chung của mọi ngăn nháp theo tài khoản ([collectSlot], [customerSlot]) — [clearAccountDrafts] dọn theo nó.
  static const String _accountDraftPrefix = 'dms_market_forms_draft_';

  /// "Lượt" của ngăn thu thập — ngăn chỉ chứa phiếu thu thập, khoá lượt chỉ để dùng chung luật khớp ô.
  static const int collectVisitId = 0;
  static const String collectUuid = 'collect';

  /// "Lượt" + "phiếu" của ngăn điểm bán — ngăn chỉ chứa một nháp.
  static const String customerUuid = 'customer';
  static const int customerConfigId = 0;
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

  static Map? _read(SharedPreferences prefs, [String slotKey = _key]) {
    final raw = prefs.getString(slotKey);
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
    Map<String, String> tokenFiles = const {},
    String slotKey = _key,
  }) {
    final done = _chain.then((_) async {
      try {
        final prefix = '${clientUuid}_$configId';
        final now = DateTime.now().millisecondsSinceEpoch;
        final draft = <String, dynamic>{'saved_at': now, 'answers': await _persistFiles(answers, photoMemo, prefix)};
        // Tệp gốc của ảnh đã có token, chỉ giữ token còn trong câu trả lời (ảnh đã xoá thì bỏ tệp).
        final encoded = jsonEncode(answers);
        final keep = {for (final e in tokenFiles.entries) if (encoded.contains('"${e.key}"')) e.key: e.value};
        if (keep.isNotEmpty) draft['token_files'] = await _persistFiles(keep, photoMemo, prefix);
        final prefs = await SharedPreferences.getInstance();
        final slot = _read(prefs, slotKey);
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
        await prefs.setString(slotKey, jsonEncode({'visit_id': visitId, 'client_uuid': clientUuid, 'drafts': drafts}));
        // Ngăn thu thập mang tiền tố bản lưu biểu mẫu ⇒ đóng mốc mỗi lần lưu, kẻo bị dọn như bản lưu biểu mẫu quá hạn.
        if (slotKey != _key) await LocalHistoryRetention.touchFormsCache(prefs, slotKey);
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
  static Future<({Map<String, dynamic> answers, DateTime savedAt, Map<String, String> tokenFiles})?> load({
    required int visitId,
    required String clientUuid,
    required int configId,
    String slotKey = _key,
  }) async {
    await _chain;
    try {
      final prefs = await SharedPreferences.getInstance();
      final slot = _read(prefs, slotKey);
      if (slot == null || !_sameVisit(slot, visitId, clientUuid)) return null;
      final d = slot['drafts'] is Map ? (slot['drafts'] as Map)['$configId'] : null;
      if (d is! Map || d['answers'] is! Map) return null;
      final savedAt = DateTime.fromMillisecondsSinceEpoch(d['saved_at'] is num ? (d['saved_at'] as num).toInt() : 0);
      final createdAt = d['created_at'] is num ? (d['created_at'] as num).toInt() : 0;
      if (DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(createdAt)) > maxAge) return null;
      final tf = d['token_files'] is Map ? d['token_files'] as Map : const {};
      return (
        answers: Map<String, dynamic>.from(d['answers'] as Map),
        savedAt: savedAt,
        tokenFiles: {for (final e in tf.entries) '${e.key}': '${e.value}'},
      );
    } catch (_) {
      return null;
    }
  }

  /// Bỏ nháp của MỘT phiếu (đã nộp / người dùng chọn làm lại) cùng tệp của nó.
  static Future<void> remove({
    required int visitId,
    required String clientUuid,
    required int configId,
    String slotKey = _key,
  }) {
    return _chain = _chain.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final slot = _read(prefs, slotKey);
        if (slot == null || !_sameVisit(slot, visitId, clientUuid) || slot['drafts'] is! Map) return;
        final drafts = Map<String, dynamic>.from(slot['drafts'] as Map);
        final removed = drafts.remove('$configId');
        if (removed == null) return;
        await prefs.setString(slotKey, jsonEncode({...slot, 'drafts': drafts}));
        await _deleteFiles(_draftFiles(removed).difference(_draftFiles(drafts)));
      } catch (_) {}
    });
  }

  /// Đăng xuất: xoá ngăn nháp theo tài khoản (phiếu thu thập + điểm bán) của MỌI tài khoản cùng ảnh nháp của chúng — máy
  /// dùng chung không giữ ảnh của người trước (khoá ngăn cũng bị đăng xuất xoá theo tiền tố `dms_market_forms_`, nhưng tệp
  /// ảnh thì không).
  static Future<void> clearAccountDrafts() {
    return _chain = _chain.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        for (final k in prefs.getKeys().where((k) => k.startsWith(_accountDraftPrefix))) {
          final slot = _read(prefs, k);
          await prefs.remove(k);
          await _deleteFiles(_draftFiles(slot?['drafts']));
        }
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
