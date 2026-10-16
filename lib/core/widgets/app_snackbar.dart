import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../errors/app_exceptions.dart';
import '../theme/app_colors.dart';

/// Tiện ích hiển thị SnackBar thông báo chuẩn hóa toàn app, hỗ trợ hiển thị và sao chép Error ID
class AppSnackBar {
  AppSnackBar._();

  /// Hiển thị thông báo lỗi kèm Mã lỗi (nếu có) và nút sao chép
  static void showError(
    BuildContext context,
    dynamic error, {
    String? errorId,
    Duration duration = const Duration(seconds: 4),
  }) {
    String message = 'Đã xảy ra lỗi. Vui lòng thử lại.';
    String? resolvedId = errorId;

    if (error is AppException) {
      message = error.message;
      resolvedId ??= error.errorId;
    } else if (error is Exception) {
      message = error.toString().replaceAll('Exception: ', '');
    } else if (error != null) {
      message = error.toString();
    }

    // Nếu message có chứa dạng "(Mã lỗi: ERR-...)" thì tách ra
    if (resolvedId == null || resolvedId.isEmpty) {
      final regExp = RegExp(r'\(Mã lỗi:\s*(ERR-[A-Za-z0-9\-]+)\)');
      final match = regExp.firstMatch(message);
      if (match != null) {
        resolvedId = match.group(1);
        message = message.replaceAll(regExp, '').trim();
      }
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (resolvedId != null && resolvedId.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Mã lỗi: $resolvedId',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (resolvedId != null && resolvedId.isNotEmpty) ...[
              const SizedBox(width: 6),
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: resolvedId!));
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã sao chép mã lỗi vào bộ nhớ tạm.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text(
                  'Chép mã',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Hiển thị thông báo thành công
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        duration: duration,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
