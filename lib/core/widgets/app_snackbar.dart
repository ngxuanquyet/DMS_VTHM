import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../errors/app_exceptions.dart';
import '../theme/app_colors.dart';

/// Tiện ích hiển thị SnackBar thông báo chuẩn hóa toàn app, hỗ trợ hiển thị và sao chép Error ID
class AppSnackBar {
  AppSnackBar._();

  /// Hiển thị thông báo lỗi kèm Mã lỗi (nếu có) và nút sao chép để báo admin
  static void showError(
    BuildContext context,
    dynamic error, {
    String? errorId,
    String? errorCode,
    Duration duration = const Duration(seconds: 4),
  }) {
    String message = 'Đã xảy ra lỗi. Vui lòng thử lại.';
    String? resolvedId = errorId;
    String? resolvedCode = errorCode;

    if (error is AppException) {
      message = error.message;
      resolvedId ??= error.errorId;
      resolvedCode ??= error.code;
      if (resolvedId == null && resolvedCode == null) {
        resolvedCode = error.displayErrorCode;
      }
    } else if (error is Exception) {
      message = error.toString().replaceAll('Exception: ', '');
    } else if (error != null) {
      message = error.toString();
    }

    // Nếu message có chứa dạng "(Mã lỗi: ...)" thì tách ra
    final codeRegex = RegExp(r'\(Mã lỗi:\s*([^)]+)\)');
    final match = codeRegex.firstMatch(message);
    if (match != null) {
      final extracted = match.group(1)?.trim();
      if (extracted != null && extracted.isNotEmpty) {
        if (resolvedId == null && resolvedCode == null) {
          resolvedCode = extracted;
        }
      }
      message = message.replaceAll(codeRegex, '').trim();
    }

    // Tách code dạng (code: 422, error_code: VALIDATION_ERROR) nếu có
    final legacyRegex = RegExp(r'\(code:\s*(\d+),\s*error_code:\s*([^)]+)\)');
    final legacyMatch = legacyRegex.firstMatch(message);
    if (legacyMatch != null) {
      resolvedCode ??= legacyMatch.group(2)?.trim();
      resolvedId ??= 'HTTP-${legacyMatch.group(1)}';
      message = message.replaceAll(legacyRegex, '').trim();
    }

    // Chuẩn hóa mã lỗi hiển thị (displayCode)
    String? displayCode;
    if (resolvedId != null && resolvedId.isNotEmpty) {
      if (resolvedCode != null &&
          resolvedCode.isNotEmpty &&
          !resolvedId.contains(resolvedCode)) {
        displayCode = '$resolvedId ($resolvedCode)';
      } else {
        displayCode = resolvedId;
      }
    } else if (resolvedCode != null && resolvedCode.isNotEmpty) {
      displayCode = resolvedCode;
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
                  if (displayCode != null && displayCode.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Mã lỗi: $displayCode',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (displayCode != null && displayCode.isNotEmpty) ...[
              const SizedBox(width: 6),
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: displayCode!));
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
    showSuccessOn(ScaffoldMessenger.of(context), message, duration: duration);
  }

  /// Như [showSuccess] nhưng nhận sẵn [messenger] — dùng khi phải lấy messenger TRƯỚC một lượt `await` (widget gọi có thể
  /// đã bị gỡ khỏi cây khi lượt chờ xong, vd màn đổi sang vòng tải trong lúc làm mới).
  static void showSuccessOn(
    ScaffoldMessengerState messenger,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showOn(messenger, message, const Color(0xFF10B981), Icons.check_circle_rounded, duration);
  }

  /// Thông báo cảnh báo nhẹ (màu cam) — vd làm mới không tới được server, đang hiện dữ liệu trên máy.
  static void showWarningOn(
    ScaffoldMessengerState messenger,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _showOn(messenger, message, const Color(0xFFF59E0B), Icons.cloud_off_rounded, duration);
  }

  static void _showOn(
    ScaffoldMessengerState messenger,
    String message,
    Color background,
    IconData icon,
    Duration duration,
  ) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
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
