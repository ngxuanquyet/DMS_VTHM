import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:vthm_dms/core/utils/jpeg_isolate.dart';

/// Nén JPEG trong isolate riêng (29/10/2026) — cùng kết quả như nén trên luồng giao diện trước đây.
void main() {
  Uint8List noisyRgba(int w, int h) {
    final r = Random(1);
    return Uint8List.fromList(List.generate(w * h * 4, (i) => i % 4 == 3 ? 255 : r.nextInt(256)));
  }

  bool isJpeg(List<int> b) => b.length > 2 && b[0] == 0xFF && b[1] == 0xD8;

  test('RGBA → JPEG hợp lệ, đúng kích thước', () async {
    final out = await JpegIsolate.fromRgba(noisyRgba(120, 80), width: 120, height: 80, quality: 78);
    expect(isJpeg(out), isTrue);
    final back = img.decodeJpg(out)!;
    expect((back.width, back.height), (120, 80));
  });

  test('vượt maxBytes ⇒ giảm chất lượng, nhỏ hơn bản chất lượng gốc', () async {
    final rgba = noisyRgba(300, 300);
    final full = await JpegIsolate.fromRgba(rgba, width: 300, height: 300, quality: 90);
    final capped = await JpegIsolate.fromRgba(rgba, width: 300, height: 300, quality: 90, maxBytes: full.length ~/ 2);
    expect(capped.length, lessThan(full.length));
  });

  test('ảnh đã mã hoá → thu nhỏ cạnh dài về maxDimension; dữ liệu hỏng ⇒ báo lỗi cho nơi gọi', () async {
    final png = Uint8List.fromList(img.encodePng(img.Image(width: 400, height: 200)));
    final out = await JpegIsolate.fromEncoded(png, quality: 80, maxDimension: 100);
    final back = img.decodeJpg(out!)!;
    expect((back.width, back.height), (100, 50));
    await expectLater(JpegIsolate.fromEncoded(Uint8List.fromList([1, 2, 3]), quality: 80), throwsA(anything));
  });
}
