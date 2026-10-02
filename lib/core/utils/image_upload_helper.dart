import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

/// Helper chuẩn hoá và kiểm soát ảnh trước khi tải lên máy chủ
/// Tuân thủ quy chuẩn §1.1 & §3 API-THAY-DOI-CHO-MOBILE-2026-10-01.md:
/// - Server chỉ nhận: jpg, jpeg, png, gif, webp, bmp (KHÔNG nhận heic/heif)
/// - Trần kích thước: 10 MB (10240 KB)
/// - Bắt buộc xử lý/convert sang JPEG/PNG trước khi tải lên để không bị chặn trên iOS
class ImageUploadHelper {
  ImageUploadHelper._();

  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

  static const Set<String> allowedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
  };

  /// Kiểm tra xem tệp có đuôi mở rộng hợp lệ hay không
  static bool hasValidExtension(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return allowedExtensions.contains(ext);
  }

  /// Chuẩn hoá tên tệp khi gửi qua MultipartFile (đảm bảo đuôi hợp lệ)
  static String getValidFileName(String filePath) {
    final rawName =
        filePath.split(Platform.pathSeparator).last.split('/').last;
    final dotIndex = rawName.lastIndexOf('.');
    if (dotIndex == -1) {
      return '$rawName.jpg';
    }
    final ext = rawName.substring(dotIndex + 1).toLowerCase();
    if (!allowedExtensions.contains(ext)) {
      return '${rawName.substring(0, dotIndex)}.jpg';
    }
    return rawName;
  }

  /// Chuẩn bị tệp ảnh trước khi tải lên:
  /// - Nếu là HEIC/HEIF hoặc dung lượng > 10MB hoặc đuôi không hợp lệ:
  ///   Tự động giải mã bằng Flutter engine và xuất sang PNG/JPEG
  static Future<File> prepareImageForUpload(File file) async {
    try {
      final path = file.path;
      final lower = path.toLowerCase();
      final isHeic = lower.endsWith('.heic') || lower.endsWith('.heif');
      final fileSize = await file.length();

      // Nếu ảnh hợp lệ và <= 10MB, trả về ngay
      if (!isHeic && fileSize <= maxFileSizeBytes && hasValidExtension(path)) {
        return file;
      }

      // Cần decode và re-encode
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final byteData =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final dir = file.parent;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final convertedPath =
            '${dir.path}${Platform.pathSeparator}converted_$timestamp.png';
        final convertedFile = File(convertedPath);
        await convertedFile.writeAsBytes(byteData.buffer.asUint8List());
        return convertedFile;
      }
    } catch (e) {
      debugPrint('[ImageUploadHelper] Không thể convert ảnh: $e');
    }
    return file;
  }
}
