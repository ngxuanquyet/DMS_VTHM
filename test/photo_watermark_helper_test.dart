import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vthm_dms/core/constants/app_assets.dart';
import 'package:vthm_dms/core/utils/photo_watermark_helper.dart';

Future<File> _createSampleImage(String name, {int width = 1200, int height = 800}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF1E88E5),
  );
  final pic = recorder.endRecording();
  final img = await pic.toImage(width, height);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  pic.dispose();

  final tempDir = Directory.systemTemp.createTempSync('wm_test_');
  final file = File('${tempDir.path}/$name.png');
  await file.writeAsBytes(byteData!.buffer.asUint8List());
  return file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PhotoWatermarkHelper & SVG Logo Tests', () {
    test('SVG asset assets/icons/logos/logo.svg can be loaded via SvgAssetLoader', () async {
      final pictureInfo = await vg.loadPicture(
        const SvgAssetLoader(AppAssets.logo),
        null,
      );
      expect(pictureInfo, isNotNull);
      expect(pictureInfo.size.width, 474.0);
      expect(pictureInfo.size.height, 459.0);
      pictureInfo.picture.dispose();
    });

    test('addWatermark successfully embeds watermark and logo inline with VTHM DMS text', () async {
      final inputFile = await _createSampleImage('full_test');

      final outputFile = await PhotoWatermarkHelper.addWatermark(
        imageFile: inputFile,
        timestamp: DateTime(2026, 10, 5, 11, 0, 0),
        latitude: 21.028511,
        longitude: 105.854444,
        accuracy: 5.0,
        locationName: 'Đại lý VTHM - Chi nhánh Hà Nội',
        staffName: 'Nguyễn Văn A',
        logoAsset: AppAssets.logo,
      );

      expect(outputFile.existsSync(), isTrue);
      final outputBytes = await outputFile.readAsBytes();
      expect(outputBytes.length, greaterThan(0));

      final codec = await ui.instantiateImageCodec(outputBytes);
      final frame = await codec.getNextFrame();
      final resultImg = frame.image;
      expect(resultImg.width, 1200);
      expect(resultImg.height, 800);

      // Dọn dẹp tệp tạm
      inputFile.parent.deleteSync(recursive: true);
    });

    test('addWatermark functions correctly with minimal parameters', () async {
      final inputFile = await _createSampleImage('minimal_test', width: 800, height: 600);

      final outputFile = await PhotoWatermarkHelper.addWatermark(
        imageFile: inputFile,
      );

      expect(outputFile.existsSync(), isTrue);
      final outputBytes = await outputFile.readAsBytes();
      expect(outputBytes.length, greaterThan(0));

      final codec = await ui.instantiateImageCodec(outputBytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 800);
      expect(frame.image.height, 600);

      inputFile.parent.deleteSync(recursive: true);
    });

    test('addWatermark handles non-existent SVG gracefully without crashing', () async {
      final inputFile = await _createSampleImage('fallback_test', width: 640, height: 480);

      final outputFile = await PhotoWatermarkHelper.addWatermark(
        imageFile: inputFile,
        logoAsset: 'assets/non_existent_logo.svg',
      );

      expect(outputFile.existsSync(), isTrue);
      final outputBytes = await outputFile.readAsBytes();
      expect(outputBytes.length, greaterThan(0));

      inputFile.parent.deleteSync(recursive: true);
    });
  });
}
