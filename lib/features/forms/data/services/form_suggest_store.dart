import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/local_history_retention.dart';
import '../../../../core/utils/account_key.dart';
import '../../domain/entities/market_form_entity.dart';
import 'forms_api_service.dart';

/// Gợi ý từ các phiếu đã nộp cho ô chữ bật `config.suggest_from_history` (chủ hệ thống chốt 20/11/2026).
///
/// Mở phiếu khi có mạng ⇒ tải danh sách từ server (`GET /dms/form-submissions/suggest`) và lưu máy; mất mạng ⇒ đọc bản lưu
/// lần cuối. Nộp phiếu ⇒ giá trị vừa nhập vào nhóm "chính máy vừa nhập" (đứng đầu, kể cả khi phiếu còn trong hàng đợi
/// ngoại tuyến), tự rời nhóm khi server đã trả về giá trị đó.
///
/// Chọn một gợi ý ⇒ tự điền cả phiếu theo phiếu cũ ([fillFor], chốt 24/11/2026): server gửi kèm câu trả lời (đã bỏ ảnh / tệp)
/// của phiếu mới nhất mỗi giá trị, lưu máy cùng lúc với danh sách ⇒ mất mạng vẫn điền được. Giá trị "chính máy vừa nhập"
/// chưa lên server thì chưa có câu trả lời để điền.
///
/// Khoá lưu theo TÀI KHOẢN và mang tiền tố `dms_market_forms_` ⇒ đăng xuất xoá theo (người dùng chung máy không thấy tên
/// / nội dung phiếu người khác nhập); dọn theo hạn cùng bản lưu biểu mẫu ([LocalHistoryRetention.touchFormsCache]).
class FormSuggestStore {
  final FormsApiService _api;

  /// Trần chờ server (cùng tham số tải biểu mẫu) — quá trần thì dùng bản lưu.
  final Duration Function() _fetchTimeout;

  FormSuggestStore(this._api, {Duration Function()? fetchTimeout})
      : _fetchTimeout = fetchTimeout ?? (() => const Duration(seconds: 5));

  /// Trần KỸ THUẬT số giá trị "chính máy vừa nhập" giữ cho mỗi ô — chờ server trả về là rời nhóm, chỉ đầy khi rất lâu
  /// không có mạng.
  static const int _maxLocal = 50;

  /// Ô có bật gợi ý không — nguồn DUY NHẤT cho cả renderer lẫn [enabledCodes] (chỉ ô chữ một dòng).
  static bool isEnabled(MarketFormBlockEntity b) =>
      b.resolved.inputType.toLowerCase() == 'text' && b.resolved.configMap?['suggest_from_history'] == true;

  /// Ô chữ bật gợi ý trong biểu mẫu.
  static Set<String> enabledCodes(List<MarketFormBlockEntity> blocks) => {
        for (final b in blocks)
          if (isEnabled(b)) b.resolved.code,
      };

  static String _key(String account, int formId) => 'dms_market_forms_suggest_${account}_$formId';
  static String _localKey(String account, int formId) => 'dms_market_forms_suggest_local_${account}_$formId';
  static String _fillKey(String account, int formId) => 'dms_market_forms_suggest_fill_${account}_$formId';

  /// Đọc / ghi bản lưu nối tiếp — [load] (tỉa nhóm máy) và [remember] (thêm vào nhóm máy) chạy chồng nhau thì bản đọc cũ
  /// ghi đè giá trị vừa nộp.
  static Future<void> _chain = Future.value();

  static Future<T> _serial<T>(Future<T> Function() run) {
    final done = _chain.then((_) => run());
    _chain = done.then((_) {}, onError: (_) {});
    return done;
  }

  /// Bản lưu trong máy — KHÔNG gọi mạng (mở phiếu dùng ngay, kể cả khi mất mạng; [load] làm mới sau).
  Future<Map<String, List<String>>> cached(int formId) => _serial(() async {
        final prefs = await SharedPreferences.getInstance();
        final account = cacheAccountKey(prefs);
        if (account == null) return {};
        return _merged(prefs, account, formId, _decode(prefs.getString(_key(account, formId))));
      });

  /// Gợi ý theo mã ô, tải mới từ server (quá trần chờ / lỗi ⇒ bản lưu). Lỗi / chưa có gì ⇒ map rỗng.
  Future<Map<String, List<String>>> load(int formId) async {
    final prefs = await SharedPreferences.getInstance();
    final account = cacheAccountKey(prefs);
    if (account == null) return {};

    FormSuggestions? server;
    try {
      server = await _api.getSuggestions(formId).timeout(_fetchTimeout());
    } catch (e) {
      debugPrint('[FormSuggestStore] Không tải được gợi ý, dùng bản lưu: $e');
    }
    return _serial(() async {
      // Đổi tài khoản trong lúc chờ mạng ⇒ đây là gợi ý của người CŨ, không lưu, không dùng.
      if (cacheAccountKey(prefs) != account) return {};
      final got = server;
      if (got != null) {
        await prefs.setString(_key(account, formId), jsonEncode(got.fields));
        await LocalHistoryRetention.touchFormsCache(prefs, _key(account, formId));
        await prefs.setString(_fillKey(account, formId), jsonEncode(got.fills));
        await LocalHistoryRetention.touchFormsCache(prefs, _fillKey(account, formId));
      }
      return _merged(prefs, account, formId, got?.fields ?? _decode(prefs.getString(_key(account, formId))));
    });
  }

  /// Ghép nhóm "chính máy vừa nhập" (đứng đầu) với danh sách server; giá trị server đã có thì rời nhóm máy (đã đồng bộ).
  Future<Map<String, List<String>>> _merged(
    SharedPreferences prefs,
    String account,
    int formId,
    Map<String, List<String>> server,
  ) async {
    final local = _decode(prefs.getString(_localKey(account, formId)));
    final con = <String, List<String>>{};
    for (final e in local.entries) {
      final daCo = {for (final v in server[e.key] ?? const <String>[]) _fold(v)};
      final giu = e.value.where((v) => !daCo.contains(_fold(v))).toList();
      if (giu.isNotEmpty) con[e.key] = giu;
    }
    if (!mapEquals(con.map((k, v) => MapEntry(k, v.join('\n'))), local.map((k, v) => MapEntry(k, v.join('\n'))))) {
      await prefs.setString(_localKey(account, formId), jsonEncode(con));
    }

    return {
      for (final code in {...server.keys, ...con.keys}) code: merge(con[code] ?? const [], server[code] ?? const []),
    };
  }

  /// Ghi giá trị vừa nộp của các ô bật gợi ý — gọi sau khi nộp thành công (trực tiếp hoặc vào hàng đợi).
  Future<void> remember(int formId, Map<String, dynamic> answers, Set<String> codes) {
    if (codes.isEmpty) return Future.value();
    return _serial(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final account = cacheAccountKey(prefs);
        if (account == null) return;
        final local = _decode(prefs.getString(_localKey(account, formId)));
        var doi = false;
        for (final code in codes) {
          final v = answers[code];
          if (v is! String || v.trim().isEmpty) continue;
          local[code] = merge([v.trim()], local[code] ?? const []).take(_maxLocal).toList();
          doi = true;
        }
        if (!doi) return;
        await prefs.setString(_localKey(account, formId), jsonEncode(local));
        await LocalHistoryRetention.touchFormsCache(prefs, _localKey(account, formId));
      } catch (e) {
        debugPrint('[FormSuggestStore] Không ghi được giá trị vừa nộp: $e');
      }
    });
  }

  /// Câu trả lời để tự điền khi chọn gợi ý [value] của ô [code] (bản lưu lần tải gần nhất, không gọi mạng) — so cùng khoá
  /// gộp với danh sách gợi ý; không có ⇒ null (chỉ điền chữ vào ô như cũ).
  Future<Map<String, dynamic>?> fillFor(int formId, String code, String value) => _serial(() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final account = cacheAccountKey(prefs);
          final raw = account == null ? null : prefs.getString(_fillKey(account, formId));
          if (raw == null) return null;
          final all = jsonDecode(raw);
          final byValue = all is Map ? all[code] : null;
          if (byValue is! Map) return null;
          final key = _fold(value);
          for (final e in byValue.entries) {
            if (_fold('${e.key}') == key && e.value is Map) return Map<String, dynamic>.from(e.value as Map);
          }
        } catch (e) {
          debugPrint('[FormSuggestStore] Không đọc được câu trả lời tự điền: $e');
        }
        return null;
      });

  /// Ghép hai danh sách giữ thứ tự, bỏ trùng theo cùng khoá gộp với server (chữ thường, khoảng trắng liền gộp một).
  @visibleForTesting
  static List<String> merge(List<String> first, List<String> second) {
    final seen = <String>{};
    return [
      for (final v in [...first, ...second])
        if (seen.add(_fold(v))) v,
    ];
  }

  static String _fold(String v) => v.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  static Map<String, List<String>> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return {};
      return {
        for (final e in m.entries)
          if (e.value is List) '${e.key}': [for (final v in e.value as List) if (v is String) v],
      };
    } catch (_) {
      return {};
    }
  }
}
