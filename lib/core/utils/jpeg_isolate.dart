import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Mã hoá JPEG bằng `package:image` trong ISOLATE RIÊNG — chạy trên luồng giao diện thì mỗi ảnh ~1600px đứng hình
/// 0,5–2 giây trên máy yếu (sau mỗi lần chụp, trước mỗi lần gửi ảnh).
class JpegIsolate {
  JpegIsolate._();

  /// Ảnh RGBA thô ([rgba], [width]×[height]) → JPEG. Có [maxBytes] thì giảm chất lượng dần (mỗi bước 15, tối thiểu 40)
  /// tới khi vừa ngưỡng.
  static Future<Uint8List> fromRgba(
    Uint8List rgba, {
    required int width,
    required int height,
    required int quality,
    int? maxBytes,
  }) {
    return Isolate.run(() {
      final image = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: rgba.buffer,
        order: img.ChannelOrder.rgba,
      );
      var q = quality;
      var bytes = img.encodeJpg(image, quality: q);
      while (maxBytes != null && bytes.length > maxBytes && q > 40) {
        q -= 15;
        bytes = img.encodeJpg(image, quality: q);
      }
      return bytes;
    });
  }

  /// Ảnh đã mã hoá (PNG/JPEG…) → JPEG, thu nhỏ cạnh dài về [maxDimension] nếu có. Không nhận ra định dạng ⇒ `null`;
  /// dữ liệu hỏng thì `package:image` ném lỗi (như trước khi đưa sang isolate — nơi gọi bắt lỗi để rơi sang cách khác).
  static Future<Uint8List?> fromEncoded(Uint8List encoded, {required int quality, int? maxDimension}) {
    return Isolate.run(() {
      final decoded = img.decodeImage(encoded);
      if (decoded == null) return null;
      var image = decoded;
      if (maxDimension != null && (decoded.width > maxDimension || decoded.height > maxDimension)) {
        image = decoded.width >= decoded.height
            ? img.copyResize(decoded, width: maxDimension)
            : img.copyResize(decoded, height: maxDimension);
      }
      return img.encodeJpg(image, quality: quality);
    });
  }
}
