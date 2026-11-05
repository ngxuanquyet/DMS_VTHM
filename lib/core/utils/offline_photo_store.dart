import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'photo_watermark_helper.dart';

/// Chép ảnh chờ gửi vào thư mục lưu lâu dài trong Documents của app (#24698).
///
/// Ảnh chụp nằm ở thư mục tạm / cache của camera (image_picker): hệ điều hành dọn trước khi có mạng là mục hàng đợi
/// chết vì "mất tệp". Gọi TRƯỚC khi xếp hàng. Dọn: theo dòng hàng đợi đã gửi (AppDatabase dọn tệp trong payload) + quét
/// mồ côi (LocalHistoryRetention — thêm [dirName] vào danh sách thư mục của nó).
class OfflinePhotoStore {
  OfflinePhotoStore._();

  /// Chuẩn hoá `file://…` ⇒ đường dẫn tệp.
  static String toFilePath(String raw) {
    if (!raw.startsWith('file://')) return raw;
    try {
      return Uri.parse(raw).toFilePath();
    } catch (_) {
      return raw.replaceFirst('file://', '');
    }
  }

  /// Tệp ảnh của mục hàng đợi còn trên máy không: đường dẫn đã lưu, hoặc — iOS đổi UUID thư mục app sau cập nhật/khôi phục —
  /// dựng lại theo thư mục Documents hiện tại. null = mất thật (#24698: trước đây chỉ ảnh điểm bán dựng lại, ảnh viếng
  /// thăm / phiếu / chấm công thành "mất tệp" dù tệp vẫn còn).
  static Future<File?> existingFile(String? path) async {
    if (path == null || path.isEmpty) return null;
    final clean = toFilePath(path);
    final file = File(clean);
    if (await file.exists()) return file;
    return rebaseToCurrentDocuments(clean);
  }

  /// Đường dẫn cũ `…/Documents/<phần sau>` dựng lại theo thư mục Documents HIỆN TẠI (null nếu không áp dụng / không có).
  static Future<File?> rebaseToCurrentDocuments(String path) async {
    const marker = '/Documents/';
    final i = path.indexOf(marker);
    if (i < 0) return null;
    try {
      final docs = (await getApplicationDocumentsDirectory()).path;
      final candidate = File(p.join(docs, path.substring(i + marker.length)));
      return candidate.path != path && await candidate.exists() ? candidate : null;
    } catch (_) {
      return null;
    }
  }

  /// Như [persist] cho MỘT ảnh, nhớ bản chép trong [memo] (ảnh gốc → bản chép): form lưu lại sau lỗi không chép thêm bản
  /// mới; chép hỏng (trả nguyên) không nhớ để lần sau thử lại.
  static int _dem = 0;

  static Future<String> persistOnce(Map<String, String> memo, String path,
      {required String dirName, required String prefix}) async {
    final daChep = memo[path];
    if (daChep != null && File(daChep).existsSync()) return daChep;
    final out = (await persist([path], dirName: dirName, prefix: prefix)).first;
    if (out != path) memo[path] = out;
    return out;
  }

  /// Bản lưu lâu dài của từng ảnh trong [paths], cùng thứ tự: token ảnh (32 hex), tệp đã nằm trong [dirName], tệp không
  /// còn ⇒ giữ nguyên; tệp khác ⇒ chép vào `Documents/<dirName>/<prefix>_<mốc>_<i>.<ext>` (giữ dấu "đã đóng watermark"
  /// — [PhotoWatermarkHelper.keepMarkerName] — không thì lúc gửi bị đóng thêm lớp thứ hai). Lỗi ⇒ trả nguyên [paths].
  static Future<List<String>> persist(List<String> paths, {required String dirName, required String prefix}) async {
    if (paths.isEmpty) return paths;
    try {
      final docs = (await getApplicationDocumentsDirectory()).path;
      final dir = Directory(p.join(docs, dirName));
      if (!await dir.exists()) await dir.create(recursive: true);
      // Mốc + số đếm trong phiên: nhiều lần gọi một ảnh ([persistOnce]) trùng mốc micro giây không được đè tệp của nhau.
      final stamp = '${DateTime.now().microsecondsSinceEpoch}${_dem++}';
      final out = <String>[];
      for (var i = 0; i < paths.length; i++) {
        final raw = paths[i];
        if (raw.length == 32 && !raw.contains('/') && !raw.contains(r'\')) {
          out.add(raw);
          continue;
        }
        final path = toFilePath(raw);
        if (p.isWithin(dir.path, path)) {
          out.add(path);
          continue;
        }
        final src = File(path);
        if (!await src.exists()) {
          out.add(raw);
          continue;
        }
        final ext = p.extension(path).isNotEmpty ? p.extension(path) : '.jpg';
        final name = PhotoWatermarkHelper.keepMarkerName(src, '${prefix}_${stamp}_$i$ext');
        out.add((await src.copy(p.join(dir.path, name))).path);
      }
      return out;
    } catch (e) {
      debugPrint('[OfflinePhotoStore] Không chép được ảnh vào $dirName: $e');
      return [...paths];
    }
  }
}
