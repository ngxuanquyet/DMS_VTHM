import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Ảnh đại diện người dùng (bên trong khung tròn của nơi gọi): có `url` thì tải ảnh, KHÔNG có hoặc tải lỗi thì hiện chữ
/// cái đầu của tên. Không bao giờ thay bằng một ảnh mẫu — ảnh mẫu trông như ảnh thật của người khác.
class UserAvatar extends StatelessWidget {
  final String? url;

  /// Họ tên đầy đủ — hiện chữ cái đầu của TÊN (từ cuối), cùng một luật ở mọi màn.
  final String name;
  final double fontSize;
  final int? cacheWidth;

  const UserAvatar({
    super.key,
    required this.url,
    required this.name,
    this.fontSize = 16,
    this.cacheWidth,
  });

  String get _letter {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    // `characters` = trọn một ký tự hiển thị (dấu tổ hợp, emoji), không cắt nửa mã UTF-16.
    return words.isEmpty ? '?' : words.last.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: AppColors.primaryContainer.withValues(alpha: 0.3),
      child: Center(
        child: Text(
          _letter,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
      ),
    );
    final u = url?.trim() ?? '';
    if (u.isEmpty) return fallback;

    return Image.network(
      u,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
