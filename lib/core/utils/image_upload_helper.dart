import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'photo_watermark_helper.dart';

/// Helper chuẩn hoá và kiểm soát ảnh trước khi tải lên máy chủ
/// Tuân thủ quy chuẩn §1.1 & §3 API-THAY-DOI-CHO-MOBILE-2026-10-01.md:
/// - Server chỉ nhận: jpg, jpeg, png, gif, webp, bmp (KHÔNG nhận heic/heif)
/// - Trần kích thước: 10 MB (10240 KB)
/// - Bắt buộc xử lý/convert sang JPEG/PNG trước khi tải lên để không bị chặn trên iOS
/// - Bắt buộc có Watermark (Toạ độ GPS, Thời gian, Tên nhân sự) trước khi upload
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
  /// 1. Tự động kiểm tra & đóng dấu Watermark (GPS, thời gian, nhân sự) nếu chưa có
  /// 2. Chuyển đổi HEIC/HEIF sang PNG/JPEG và nén nếu kích thước vượt trần 10MB
  static Future<File> prepareImageForUpload(
    File file, {
    double? latitude,
    double? longitude,
    String? locationName,
    String? staffName,
  }) async {
    File targetFile = file;

    // 1. Đảm bảo toàn bộ ảnh tải lên qua API đều có Watermark
    try {
      if (!PhotoWatermarkHelper.isWatermarked(targetFile)) {
        targetFile = await PhotoWatermarkHelper.addWatermark(
          imageFile: targetFile,
          latitude: latitude,
          longitude: longitude,
          locationName: locationName,
          staffName: staffName,
        );
      }
    } catch (e) {
      debugPrint('[ImageUploadHelper] Lỗi khi gắn watermark tự động: $e');
    }

    // 2. Kiểm tra định dạng & dung lượng
    try {
      final path = targetFile.path;
      final lower = path.toLowerCase();
      final isHeic = lower.endsWith('.heic') || lower.endsWith('.heif');
      final fileSize = await targetFile.length();

      // Nếu ảnh hợp lệ và <= 10MB, trả về ngay
      if (!isHeic && fileSize <= maxFileSizeBytes && hasValidExtension(path)) {
        return targetFile;
      }

      // Cần decode và re-encode
      final bytes = await targetFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final byteData =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final dir = targetFile.parent;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final convertedPath =
            '${dir.path}${Platform.pathSeparator}wm_converted_$timestamp.png';
        final convertedFile = File(convertedPath);
        await convertedFile.writeAsBytes(byteData.buffer.asUint8List());
        return convertedFile;
      }
    } catch (e) {
      debugPrint('[ImageUploadHelper] Không thể convert ảnh: $e');
    }
    return targetFile;
  }
}
