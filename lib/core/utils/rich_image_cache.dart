import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../errors/app_exceptions.dart';
import '../network/api_client.dart';

/// Tải ảnh rich-image (`GET /rich-image/serve?token=…`, Bearer qua [ApiClient]) và lưu bộ đệm ra tệp trong thư mục
/// app (`rich_images/<token>`) để xem lại khi mất mạng. Lỗi ⇒ ô xám nhỏ, không sập.
class RichImageCache {
  final ApiClient _api;
  final Future<Directory> Function() _dir;

  RichImageCache(this._api, {Future<Directory> Function()? baseDir})
      : _dir = baseDir ?? getApplicationSupportDirectory;

  static final RegExp _safeToken = RegExp(r'^[A-Za-z0-9_-]{8,128}$');

  /// Lượt tải đang chạy theo token — cùng ảnh hiện hai chỗ / mở-thu khi đang tải dùng chung một lượt (ghi chung một tệp
  /// tạm thì hỏng tệp).
  static final Map<String, Future<File?>> _inflight = {};

  /// Thư mục bộ đệm — đăng xuất xoá cả thư mục (máy dùng chung, #24753).
  static Future<void> clear({Future<Directory> Function()? baseDir}) async {
    // Lượt tải đang bay lúc đăng xuất không được ghi lại ảnh vào thư mục vừa xoá (người sau trên máy dùng chung).
    _generation++;
    _failed.clear();
    _inflight.clear();
    try {
      final dir = Directory(p.join((await (baseDir ?? getApplicationSupportDirectory)()).path, 'rich_images'));
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  /// Đổi mỗi lần [clear] — lượt tải bắt đầu trước đó bỏ kết quả.
  static int _generation = 0;

  /// Token máy chủ TỪ CHỐI HẲN (4xx: ảnh đã xoá, không có quyền) trong lần chạy này — mở/thu ô không gửi lại yêu cầu hỏng
  /// mãi. Lỗi tạm (mất mạng, quá giờ, 401 trước khi làm mới phiên, 5xx) KHÔNG nhớ — lần mở sau thử lại.
  static final Set<String> _failed = {};

  Future<File?> load(String token) {
    if (_failed.contains(token)) return Future.value(null);
    final running = _inflight[token];
    if (running != null) return running;
    final run = _load(token).catchError((Object e, StackTrace st) {
      if (isPermanentRejection(e)) _failed.add(token);
      Error.throwWithStackTrace(e, st);
    });
    _inflight[token] = run;
    // Thân khối (không trả Future) — trả lại chính Future đang chờ là tự chờ mình, treo vĩnh viễn.
    run.whenComplete(() {
      _inflight.remove(token);
    }).ignore();
    return run;
  }

  Future<File?> _load(String token) async {
    // Chốt thế hệ NGAY đầu — đăng xuất trong lúc đang tải (phần chậm) cũng bị nhận ra.
    final generation = _generation;
    if (!_safeToken.hasMatch(token)) return null;
    final dir = Directory(p.join((await _dir()).path, 'rich_images'));
    final file = File(p.join(dir.path, token));
    if (await file.exists() && await file.length() > 0) return file;
    final data = await _api.get(
      '/rich-image/serve',
      queryParameters: {'token': token},
      options: Options(responseType: ResponseType.bytes),
    );
    // CHỈ lưu khi đúng là ảnh (JPEG/PNG/GIF/WebP) — trang HTML của mạng có cổng đăng nhập (200) lưu vào là hỏng mãi.
    if (data is! List<int> || !_looksLikeImage(data)) return null;
    await dir.create(recursive: true);
    final tmp = File('${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
    try {
      await tmp.writeAsBytes(data, flush: true);
      if (generation != _generation) {
        await tmp.delete();
        return null;
      }
      await tmp.rename(file.path);
      // Đăng xuất chen vào giữa lúc kiểm và lúc đổi tên ⇒ bỏ tệp vừa đặt.
      if (generation != _generation) {
        if (await file.exists()) await file.delete();
        return null;
      }
    } catch (_) {
      // Đầy bộ nhớ / thư mục bị xoá giữa chừng (đăng xuất): không để tệp tạm nằm lại.
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      rethrow;
    }
    return file;
  }

  static bool _looksLikeImage(List<int> b) {
    bool at(int i, List<int> sig) {
      if (b.length < i + sig.length) return false;
      for (var k = 0; k < sig.length; k++) {
        if (b[i + k] != sig[k]) return false;
      }
      return true;
    }

    return at(0, [0xFF, 0xD8, 0xFF]) ||
        at(0, [0x89, 0x50, 0x4E, 0x47]) ||
        at(0, [0x47, 0x49, 0x46, 0x38]) ||
        (at(0, [0x52, 0x49, 0x46, 0x46]) && at(8, [0x57, 0x45, 0x42, 0x50]));
  }
}

final richImageCacheProvider = Provider<RichImageCache>((ref) => RichImageCache(ref.read(apiClientProvider)));
