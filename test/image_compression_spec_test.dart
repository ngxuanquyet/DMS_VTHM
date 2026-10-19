import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/utils/image_upload_helper.dart';
import 'package:vthm_dms/core/utils/photo_watermark_helper.dart';

Future<File> _createTestImage(String name, {int width = 3000, int height = 2000}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF2E7D32),
  );
  // Vẽ các chi tiết ngẫu nhiên để ảnh có dung lượng
  for (int i = 0; i < 50; i++) {
    canvas.drawLine(
      Offset(i * 40.0, 0),
      Offset(0, i * 40.0),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3,
    );
  }
  final pic = recorder.endRecording();
  final img = await pic.toImage(width, height);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  pic.dispose();

  final tempDir = Directory.systemTemp.createTempSync('img_test_');
  final file = File('${tempDir.path}/$name.png');
  await file.writeAsBytes(byteData!.buffer.asUint8List());
  return file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageUploadHelper & Compression Specification Tests', () {
    test('compressImage compresses large image to <= 1600px and under 1.5MB JPEG', () async {
      final largeFile = await _createTestImage('large_camera_photo', width: 3000, height: 2000);
      final originalSize = await largeFile.length();
      expect(originalSize, greaterThan(0));

      final compressedFile = await ImageUploadHelper.compressImage(largeFile);
      expect(compressedFile.existsSync(), isTrue);

      final compressedSize = await compressedFile.length();
      expect(compressedSize, lessThan(ImageUploadHelper.targetFileSizeBytes));
      expect(compressedSize, lessThan(ImageUploadHelper.maxFileSizeBytes));
      expect(compressedFile.path.toLowerCase().endsWith('.jpg'), isTrue);

      final codec = await ui.instantiateImageCodec(await compressedFile.readAsBytes());
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 1600);
      expect(frame.image.height, 1067);

      largeFile.parent.deleteSync(recursive: true);
    });

    test('prepareImageForUpload ensures watermark and compresses under 1.5MB', () async {
      final rawFile = await _createTestImage('clean_camera_photo', width: 2400, height: 1800);
      expect(PhotoWatermarkHelper.isWatermarked(rawFile), isFalse);

      final preparedFile = await ImageUploadHelper.prepareImageForUpload(
        rawFile,
        locationName: 'Đại lý Test',
        staffName: 'Nhân viên A',
      );

      expect(preparedFile.existsSync(), isTrue);
      expect(PhotoWatermarkHelper.isWatermarked(preparedFile), isTrue);

      final preparedSize = await preparedFile.length();
      expect(preparedSize, lessThan(ImageUploadHelper.targetFileSizeBytes));
      expect(preparedSize, lessThan(10 * 1024 * 1024)); // Tuyệt đối không quá 10MB
      expect(ImageUploadHelper.hasValidExtension(preparedFile.path), isTrue);

      rawFile.parent.deleteSync(recursive: true);
    });

    test('prepareImageForUpload leaves small watermarked JPEG untouched for speed', () async {
      final sample = await _createTestImage('wm_already_compressed', width: 800, height: 600);
      final firstPass = await ImageUploadHelper.prepareImageForUpload(sample);

      final initialLength = await firstPass.length();
      expect(initialLength, lessThan(ImageUploadHelper.targetFileSizeBytes));

      // Gọi lần 2: Không nén lại, trả về nhanh chóng
      final secondPass = await ImageUploadHelper.prepareImageForUpload(firstPass);
      expect(secondPass.path, firstPass.path);

      sample.parent.deleteSync(recursive: true);
    });
  });
}
