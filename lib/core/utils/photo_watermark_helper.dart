import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../constants/app_assets.dart';

/// Tiện ích đóng dấu toạ độ GPS, thời gian và thông tin điểm bán lên ảnh chụp thực địa
/// Đảm bảo tính minh bạch, chuyên nghiệp và chống gian lận ảnh cho đội ngũ thị trường
class PhotoWatermarkHelper {
  PhotoWatermarkHelper._();

  /// Đóng dấu toạ độ, thời gian và thông tin điểm bán lên tệp ảnh [imageFile]
  /// Ở góc dưới bên phải hiển thị logo xác thực thương hiệu từ [logoAsset]
  static Future<File> addWatermark({
    required File imageFile,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? locationName,
    String? staffName,
    String logoAsset = AppAssets.logo,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      if (bytes.isEmpty) return imageFile;

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final width = image.width.toDouble();
      final height = image.height.toDouble();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

      // 1. Vẽ ảnh gốc
      canvas.drawImage(image, Offset.zero, Paint());

      // 2. Chuẩn bị nội dung đóng dấu
      final timeStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(timestamp ?? DateTime.now());
      final List<String> watermarkLines = [];

      watermarkLines.add('🕒 $timeStr${staffName != null && staffName.isNotEmpty ? '  •  👤 $staffName' : ''}');

      if (latitude != null && longitude != null) {
        watermarkLines.add('📍 GPS: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}');
      }

      if (locationName != null && locationName.isNotEmpty) {
        watermarkLines.add('🏪 $locationName');
      }

      // 3. Tải logo SVG (mặc định assets/icons/logos/logo.svg)
      PictureInfo? logoInfo;
      try {
        logoInfo = await vg.loadPicture(
          SvgAssetLoader(logoAsset),
          null,
        );
      } catch (e) {
        debugPrint('[PhotoWatermarkHelper] Không thể tải logo SVG ($logoAsset): $e');
      }

      // 4. Tính toán kích thước banner watermark theo tỉ lệ ảnh
      // Tỉ lệ scale font chữ theo chiều rộng ảnh (để ảnh 1000px hay 4000px đều vừa mắt)
      final baseFontSize = (width / 50).clamp(12.0, 36.0);
      final padding = baseFontSize * 0.8;
      final lineHeight = baseFontSize * 1.35;
      final totalLines = watermarkLines.length + 1; // + 1 cho dòng thương hiệu VTHM DMS
      final bannerHeight = (totalLines * lineHeight) + (padding * 2);

      // 5. Vẽ nền banner mờ màu đen bán trong suốt ở góc dưới ảnh
      final bannerRect = Rect.fromLTWH(0, height - bannerHeight, width, bannerHeight);
      final bannerPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, height - bannerHeight),
          Offset(0, height),
          [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.78),
            Colors.black.withValues(alpha: 0.88),
          ],
          [0.0, 0.35, 1.0],
        );
      canvas.drawRect(bannerRect, bannerPaint);

      // 6. Vẽ từng dòng chữ watermark ở góc dưới bên trái
      double currentY = height - bannerHeight + padding;
      final maxTextWidth = width - (padding * 2);

      for (int i = 0; i < watermarkLines.length; i++) {
        final isPrimary = i == 0 || i == 1;
        final textSpan = TextSpan(
          text: watermarkLines[i],
          style: TextStyle(
            color: isPrimary ? Colors.white : Colors.white70,
            fontSize: isPrimary ? baseFontSize : baseFontSize * 0.85,
            fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
            ],
          ),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: ui.TextDirection.ltr,
          maxLines: 1,
        );
        textPainter.layout(maxWidth: maxTextWidth);
        textPainter.paint(canvas, Offset(padding, currentY));
        currentY += lineHeight;
      }

      // 7. Vẽ dòng thương hiệu: Logo SVG ở bên trái text 'VTHM DMS'
      if (logoInfo != null) {
        final svgSize = logoInfo.size;
        final svgAspect = svgSize.width / (svgSize.height > 0 ? svgSize.height : 1.0);

        final logoBoxHeight = baseFontSize * 1.1;
        final logoBoxWidth = logoBoxHeight * svgAspect;
        final logoBoxY = currentY + (lineHeight - logoBoxHeight) / 2;
        final innerPad = logoBoxHeight * 0.08;

        // Thẻ nền trắng bo góc nhẹ làm nổi bật màu xanh dương & xanh lá của logo VTHM
        final badgeRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(padding, logoBoxY, logoBoxWidth, logoBoxHeight),
          Radius.circular(baseFontSize * 0.2),
        );
        canvas.drawRRect(
          badgeRect,
          Paint()..color = Colors.white.withValues(alpha: 0.95),
        );

        // Vẽ logo SVG
        canvas.save();
        canvas.translate(padding + innerPad, logoBoxY + innerPad);
        canvas.scale(
          (logoBoxWidth - (innerPad * 2)) / svgSize.width,
          (logoBoxHeight - (innerPad * 2)) / svgSize.height,
        );
        canvas.drawPicture(logoInfo.picture);
        canvas.restore();

        logoInfo.picture.dispose();

        // Vẽ chữ 'VTHM DMS' ngay bên phải logo
        final brandSpan = TextSpan(
          text: 'VTHM DMS',
          style: TextStyle(
            color: Colors.white,
            fontSize: baseFontSize * 0.88,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
            ],
          ),
        );
        final brandPainter = TextPainter(
          text: brandSpan,
          textDirection: ui.TextDirection.ltr,
          maxLines: 1,
        );
        final gap = baseFontSize * 0.35;
        brandPainter.layout(maxWidth: maxTextWidth - logoBoxWidth - gap);
        final textY = currentY + (lineHeight - brandPainter.height) / 2;
        brandPainter.paint(canvas, Offset(padding + logoBoxWidth + gap, textY));
      } else {
        // Fallback nếu không tải được logo SVG: dùng biểu tượng text
        final fallbackSpan = TextSpan(
          text: '🛡️ VTHM DMS',
          style: TextStyle(
            color: Colors.white,
            fontSize: baseFontSize * 0.88,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
            ],
          ),
        );
        final fallbackPainter = TextPainter(
          text: fallbackSpan,
          textDirection: ui.TextDirection.ltr,
          maxLines: 1,
        );
        fallbackPainter.layout(maxWidth: maxTextWidth);
        final textY = currentY + (lineHeight - fallbackPainter.height) / 2;
        fallbackPainter.paint(canvas, Offset(padding, textY));
      }

      // 8. Xuất ảnh đã đóng dấu
      final picture = recorder.endRecording();
      final watermarkedImage = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await watermarkedImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final parentDir = imageFile.parent;
        final fileName = 'wm_${DateTime.now().millisecondsSinceEpoch}.png';
        final outputFile = File('${parentDir.path}${Platform.pathSeparator}$fileName');
        await outputFile.writeAsBytes(byteData.buffer.asUint8List());
        return outputFile;
      }
    } catch (e) {
      debugPrint('[PhotoWatermarkHelper] Lỗi khi đóng dấu ảnh (dùng ảnh gốc): $e');
    }
    return imageFile;
  }
}

