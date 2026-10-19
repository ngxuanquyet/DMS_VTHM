import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
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

  static const int targetFileSizeBytes = 1572864; // 1.5 MB mục tiêu cho ảnh DMS

  /// Nén và chuẩn hoá ảnh về định dạng JPEG với kích thước <= maxDimension (mặc định 1600px)
  /// và dung lượng <= maxBytes (mặc định 1.5 MB, bảo đảm tuyệt đối không vượt trần 10 MB của server).
  static Future<File> compressImage(
    File file, {
    int maxDimension = 1600,
    int quality = 78,
    int maxBytes = targetFileSizeBytes,
  }) async {
    try {
      final currentSize = await file.length();
      final lower = file.path.toLowerCase();
      final isJpeg = lower.endsWith('.jpg') || lower.endsWith('.jpeg');

      // Nếu ảnh đã là JPEG và đã nhỏ hơn ngưỡng mong muốn, không cần nén lại
      if (isJpeg && currentSize <= maxBytes) {
        return file;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return file;

      // 1. Sử dụng Flutter native codec (hỗ trợ JPG, PNG, WEBP, HEIC bằng C++ phần cứng cực nhanh)
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final decodedImage = frame.image;

        final origW = decodedImage.width.toDouble();
        final origH = decodedImage.height.toDouble();

        double targetW = origW;
        double targetH = origH;
        final maxDim = maxDimension.toDouble();

        if (targetW > maxDim || targetH > maxDim) {
          if (targetW >= targetH) {
            targetH = (targetH * maxDim / targetW).roundToDouble();
            targetW = maxDim;
          } else {
            targetW = (targetW * maxDim / targetH).roundToDouble();
            targetH = maxDim;
          }
        }

        // Vẽ ảnh lên canvas với kích thước chuẩn targetW x targetH
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, targetW, targetH));
        canvas.drawImageRect(
          decodedImage,
          Rect.fromLTWH(0, 0, origW, origH),
          Rect.fromLTWH(0, 0, targetW, targetH),
          Paint()..filterQuality = FilterQuality.medium,
        );

        final pic = recorder.endRecording();
        final targetImg = await pic.toImage(targetW.toInt(), targetH.toInt());
        final rawRgba = await targetImg.toByteData(format: ui.ImageByteFormat.rawRgba);

        decodedImage.dispose();
        targetImg.dispose();
        pic.dispose();

        if (rawRgba != null) {
          final dartImg = img.Image.fromBytes(
            width: targetW.toInt(),
            height: targetH.toInt(),
            bytes: rawRgba.buffer,
            order: img.ChannelOrder.rgba,
          );

          int currentQuality = quality;
          List<int> jpgBytes = img.encodeJpg(dartImg, quality: currentQuality);

          // Nếu ảnh có nhiều chi tiết phức tạp vẫn vượt ngưỡng maxBytes, giảm dần chất lượng
          while (jpgBytes.length > maxBytes && currentQuality > 40) {
            currentQuality -= 15;
            jpgBytes = img.encodeJpg(dartImg, quality: currentQuality);
          }

          final isWm = PhotoWatermarkHelper.isWatermarked(file);
          final prefix = isWm ? 'wm_compressed_' : 'compressed_';
          final dir = file.parent;
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final compressedFile =
              File('${dir.path}${Platform.pathSeparator}$prefix$timestamp.jpg');
          await compressedFile.writeAsBytes(jpgBytes);
          return compressedFile;
        }
      } catch (e) {
        debugPrint('[ImageUploadHelper] Không thể nén qua native codec: $e');
      }

      // 2. Fallback thuần bằng package:image nếu native codec gặp lỗi (ví dụ trong môi trường test)
      try {
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          img.Image resized = decoded;
          if (decoded.width > maxDimension || decoded.height > maxDimension) {
            if (decoded.width >= decoded.height) {
              resized = img.copyResize(decoded, width: maxDimension);
            } else {
              resized = img.copyResize(decoded, height: maxDimension);
            }
          }
          final jpgBytes = img.encodeJpg(resized, quality: quality);
          final isWm = PhotoWatermarkHelper.isWatermarked(file);
          final prefix = isWm ? 'wm_compressed_' : 'compressed_';
          final dir = file.parent;
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final compressedFile =
              File('${dir.path}${Platform.pathSeparator}$prefix$timestamp.jpg');
          await compressedFile.writeAsBytes(jpgBytes);
          return compressedFile;
        }
      } catch (e) {
        debugPrint('[ImageUploadHelper] Không thể nén bằng package:image: $e');
      }
    } catch (e) {
      debugPrint('[ImageUploadHelper] Lỗi khi xử lý nén ảnh: $e');
    }

    return file;
  }

  /// Chuẩn bị tệp ảnh trước khi tải lên:
  /// 1. Tự động kiểm tra & đóng dấu Watermark (GPS, thời gian, nhân sự) nếu chưa có
  /// 2. Tự động nén dung lượng về <= 1.5MB (JPEG, max 1600px), đảm bảo tuyệt đối không vượt 10MB
  static Future<File> prepareImageForUpload(
    File file, {
    double? latitude,
    double? longitude,
    String? locationName,
    String? staffName,
  }) async {
    File targetFile = file;

    // 0. Nếu ảnh đã có watermark, đã là JPEG và đã <= 1.5MB: trả về ngay lập tức
    final isWm = PhotoWatermarkHelper.isWatermarked(targetFile);
    final lower = targetFile.path.toLowerCase();
    final isJpeg = lower.endsWith('.jpg') || lower.endsWith('.jpeg');
    if (isWm && isJpeg) {
      final size = await targetFile.length();
      if (size <= targetFileSizeBytes) {
        return targetFile;
      }
    }

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

    // 2. Tự động nén và chuẩn hoá dung lượng đảm bảo <= 1.5MB (và tuyệt đối < 10MB)
    try {
      targetFile = await compressImage(
        targetFile,
        maxDimension: 1600,
        quality: 78,
        maxBytes: targetFileSizeBytes,
      );
    } catch (e) {
      debugPrint('[ImageUploadHelper] Lỗi khi nén ảnh: $e');
    }

    // 3. Kiểm tra trần cứng cuối cùng: nếu vẫn vượt 10MB (ví dụ tệp nhị phân hỏng), ép nén khẩn cấp
    try {
      final finalSize = await targetFile.length();
      if (finalSize > maxFileSizeBytes) {
        debugPrint('[ImageUploadHelper] CẢNH BÁO: Tệp ảnh ($finalSize bytes) vượt trần 10MB! Tiến hành nén khẩn cấp.');
        targetFile = await compressImage(
          targetFile,
          maxDimension: 1280,
          quality: 50,
          maxBytes: 1024 * 1024, // Ép về <= 1MB
        );
      }
    } catch (e) {
      debugPrint('[ImageUploadHelper] Lỗi khi kiểm tra trần kích thước ảnh: $e');
    }

    return targetFile;
  }
}
