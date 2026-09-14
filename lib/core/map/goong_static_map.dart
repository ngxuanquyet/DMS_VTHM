import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'goong_api_service.dart';
import 'goong_models.dart';

/// Ảnh bản đồ tĩnh của Goong — dùng cho thẻ xem trước, nơi không cần kéo/phóng.
///
/// Nhẹ hơn hẳn [GoongMapView]: chỉ là một `Image.network`, không dựng máy vẽ bản đồ, không cần quyền gì.
/// Đổi lại thì **không tương tác được** và mỗi lần hiện là một lượt gọi Goong.
///
/// Truyền [destination] để vẽ tuyến từ [center] tới đó; bỏ trống thì ra bản đồ một điểm có ghim đỏ.
class GoongStaticMap extends StatelessWidget {
  final GoongLatLng center;
  final GoongLatLng? destination;
  final int? width;
  final int? height;
  final BoxFit fit;

  /// Hiện khi chưa có toạ độ, hoặc khi tải ảnh hỏng (mất mạng, hết hạn mức).
  /// Bản đồ chỉ là thứ trang trí cho thao tác chính — hỏng ảnh **không được** chặn nghiệp vụ.
  final Widget? placeholder;

  const GoongStaticMap({
    super.key,
    required this.center,
    this.destination,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final url = GoongApiService().staticMapUrl(
      center,
      to: destination,
      width: width,
      height: height,
    );

    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _fallback(const CircularProgressIndicator(strokeWidth: 2)),
      errorBuilder: (_, __, ___) => placeholder ?? _fallback(null),
    );
  }

  Widget _fallback(Widget? child) => Container(
        color: AppColors.surfaceContainerHigh,
        alignment: Alignment.center,
        child: child,
      );
}
