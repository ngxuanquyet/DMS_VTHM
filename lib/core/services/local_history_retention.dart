import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';

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
  static const _formsPrefix = 'dms_market_forms_'; // forms_repository_impl: <prefix><account>_<kind>_<customerId>
  /// Mốc lưu từng khoá cache biểu mẫu ({khoá: ms}) — cùng tiền tố nên đăng xuất (xoá `dms_market_forms_*`) xoá theo.
  static const _formsSavedAtKey = 'dms_market_forms_saved_at_v1';

  /// Ảnh tạm (ảnh chụp gốc, bản gắn watermark `wm_*`, bản nén) không ai xoá: quá hạn này và không còn mục hàng đợi
  /// nào trỏ tới thì dọn — khớp hạn giữ mục đã gửi (AppDatabase.doneRetention).
  static const photoKeep = AppDatabase.doneRetention;
  static const _offlinePhotoDirs = ['offline_visit_photos', 'offline_customer_photos', 'attendance_photos'];
  static const _imageExts = {'.jpg', '.jpeg', '.png', '.heic', '.webp'};

  /// Ghi mốc lưu cache biểu mẫu [cacheKey] (gọi khi tải biểu mẫu từ máy chủ thành công).
  static Future<void> touchFormsCache(SharedPreferences prefs, String cacheKey) async {
    final map = _readFormsSavedAt(prefs);
    map[cacheKey] = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString(_formsSavedAtKey, jsonEncode(map));
  }

  static Map<String, int> _readFormsSavedAt(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(_formsSavedAtKey);
      if (raw == null || raw.isEmpty) return {};
      return (jsonDecode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

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
      () => _pruneFormsCache(prefs, cutoff, now ?? DateTime.now()),
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

  /// Cache biểu mẫu theo điểm bán: mỗi điểm bán từng mở thêm một khoá — bỏ khoá không được tải lại quá [keep]. Khoá có
  /// từ trước khi ghi mốc thì tính từ lần dọn đầu tiên (không làm mất cache offline ngay sau nâng cấp).
  static Future<void> _pruneFormsCache(SharedPreferences prefs, DateTime cutoff, DateTime now) async {
    final savedAt = _readFormsSavedAt(prefs);
    final cutoffMs = cutoff.millisecondsSinceEpoch;
    var changed = false;
    final keys = prefs.getKeys().where((k) => k.startsWith(_formsPrefix) && k != _formsSavedAtKey).toSet();
    for (final k in keys) {
      final at = savedAt[k];
      if (at == null) {
        savedAt[k] = now.millisecondsSinceEpoch;
        changed = true;
      } else if (at < cutoffMs) {
        await prefs.remove(k);
        savedAt.remove(k);
        changed = true;
      }
    }
    final stale = savedAt.keys.where((k) => !keys.contains(k)).toList();
    for (final k in stale) {
      savedAt.remove(k);
      changed = true;
    }
    if (changed) await prefs.setString(_formsSavedAtKey, jsonEncode(savedAt));
  }

  static bool _sweptThisLaunch = false;

  /// Dọn ẢNH TẠM sửa lần cuối quá [photoKeep] — ảnh chụp gốc, `wm_*`, bản nén (ghi cạnh ảnh gốc), ảnh của mục hàng đợi
  /// đã dọn — ở: thư mục tạm của app (Android cache, iOS Library/Caches) + thư mục tạm hệ thống (iOS tmp/ — image_picker
  /// ghi ở đây), cấp ngoài cùng và thư mục con tên UUID (ảnh chọn từ thư viện trên Android: `cache/<uuid>/`) — không quét
  /// sâu hơn (cache của thư viện khác); và ba thư mục ảnh offline. TRỪ tệp bất kỳ chỗ lưu nào của app còn trỏ tới:
  /// hàng đợi, điểm bán trong máy (SQLite) và MỌI giá trị JSON trong SharedPreferences (lịch sử khai báo, lượt viếng
  /// thăm, chấm công, lượt đang mở…) — ảnh sống bằng bản ghi trỏ tới nó (lịch sử giữ [keep]). Một lần mỗi lần mở
  /// app, chạy nền. Trả số tệp đã xoá.
  static Future<int> sweepPhotoFiles(AppDatabase db, {DateTime? now, List<Directory>? roots}) async {
    if (roots == null) {
      if (_sweptThisLaunch) return 0;
      _sweptThisLaunch = true;
    }
    final cutoff = (now ?? DateTime.now()).subtract(photoKeep);

    // 1. Liệt kê ứng viên TRƯỚC, 2. tính tham chiếu SAU — tệp vừa được chép + đưa vào hàng đợi trong lúc quét (File.copy
    // giữ mốc sửa của bản gốc) đã có mặt trong tham chiếu.
    final candidates = <File>[];
    final uuidDirs = <Directory>[];
    Future<void> scan(Directory dir, {required bool intoUuidDirs}) async {
      try {
        if (!await dir.exists()) return;
        await for (final e in dir.list(followLinks: false)) {
          if (e is Directory) {
            if (intoUuidDirs && _uuidName.hasMatch(p.basename(e.path))) {
              uuidDirs.add(e);
              await scan(e, intoUuidDirs: false);
            }
            continue;
          }
          if (e is! File || !_isImage(e.path)) continue;
          try {
            if ((await e.lastModified()).isBefore(cutoff)) candidates.add(e);
          } catch (_) {}
        }
      } catch (err) {
        debugPrint('[LocalHistoryRetention] Lỗi quét ảnh tạm ${dir.path}: $err');
      }
    }

    for (final dir in roots ?? await _photoRoots()) {
      await scan(dir, intoUuidDirs: true);
    }
    if (candidates.isEmpty) return 0;

    final prefs = await SharedPreferences.getInstance();
    final prefValues = <String>[
      for (final k in prefs.getKeys())
        ...switch (prefs.get(k)) { final String s => [s], final List l => l.whereType<String>(), _ => const <String>[] },
    ];
    final dbPaths = await db.referencedFilePaths();
    // Giải mã JSON prefs (có thể vài MB) ở isolate riêng — không làm giật giao diện lúc mở app.
    final referenced = await compute(_normalizeImagePaths, [...dbPaths, ...await compute(_pathsInStrings, prefValues)]);
    // So cả TÊN tệp: đường dẫn lưu có thể khác dạng đường dẫn quét (iOS /private/var vs /var, container đổi sau nâng
    // cấp) — lệch là xoá nhầm ảnh còn dùng. Tên ảnh của app mang mốc thời gian/uuid nên gần như không trùng.
    final referencedNames = referenced.map(p.basename).toSet();

    var deleted = 0;
    for (final f in candidates) {
      if (referenced.contains(f.path) || referencedNames.contains(p.basename(f.path))) continue;
      try {
        await f.delete();
        deleted++;
      } catch (_) {}
    }
    for (final d in uuidDirs) {
      try {
        if (await d.list().isEmpty) await d.delete();
      } catch (_) {}
    }
    return deleted;
  }

  static final _uuidName = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  static bool _isImage(String path) => _imageExts.contains(p.extension(path).toLowerCase());

  /// (isolate) Đường dẫn tệp trong các chuỗi prefs — chuỗi trần '/…' / 'file://…' hoặc JSON.
  static List<String> _pathsInStrings(List<String> values) {
    final out = <String>[];
    for (final s in values) {
      if (s.startsWith('/') || s.startsWith('file://')) {
        out.add(s);
      } else if (s.startsWith('{') || s.startsWith('[')) {
        try {
          collectFilePaths(jsonDecode(s), out);
        } catch (_) {}
      }
    }
    return out;
  }

  /// (isolate) Gỡ `file://`, chỉ giữ đường dẫn ẢNH (bỏ đường dẫn API/URL tương đối của máy chủ lẫn trong cache).
  static Set<String> _normalizeImagePaths(List<String> raw) {
    final out = <String>{};
    for (final r in raw) {
      String path;
      try {
        path = r.startsWith('file://') ? Uri.parse(r).toFilePath() : r;
      } catch (_) {
        path = r;
      }
      if (_isImage(path)) out.add(path);
    }
    return out;
  }

  static Future<List<Directory>> _photoRoots() async {
    final dirs = <Directory>[];
    try {
      dirs.add(await getTemporaryDirectory());
    } catch (_) {}
    // iOS: image_picker ghi ở NSTemporaryDirectory (tmp/), khác getTemporaryDirectory (Library/Caches).
    if (!dirs.any((d) => d.path == Directory.systemTemp.path)) dirs.add(Directory.systemTemp);
    try {
      final docs = await getApplicationDocumentsDirectory();
      dirs.addAll(_offlinePhotoDirs.map((n) => Directory(p.join(docs.path, n))));
    } catch (_) {}
    return dirs;
  }
}
