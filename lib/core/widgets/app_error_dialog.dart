import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../errors/app_exceptions.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Modal dialog chuẩn của ứng dụng dùng để hiển thị popup thông báo lỗi khi tải hoặc xử lý dữ liệu.
class AppErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? errorId;
  final String? errorCode;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final String retryText;
  final String dismissText;

  const AppErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.errorId,
    this.errorCode,
    this.onRetry,
    this.onDismiss,
    this.retryText = 'Thử lại',
    this.dismissText = 'Đóng',
  });

  static bool _isShowing = false;

  /// Hiển thị popup thông báo lỗi, tự động kiểm tra tránh trùng lặp dialog
  static Future<void> show(
    BuildContext context, {
    String? title,
    dynamic error,
    String? message,
    String? errorId,
    String? errorCode,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
    String retryText = 'Thử lại',
    String dismissText = 'Đóng',
  }) async {
    if (_isShowing) return;
    _isShowing = true;

    String resolvedMessage = message ?? 'Đã xảy ra lỗi. Vui lòng thử lại.';
    String? resolvedId = errorId;
    String? resolvedCode = errorCode;

    if (error is AppException) {
      resolvedMessage = message ?? error.message;
      resolvedId ??= error.errorId;
      resolvedCode ??= error.code;
      if (resolvedId == null && resolvedCode == null) {
        resolvedCode = error.displayErrorCode;
      }
    } else if (error is Exception) {
      resolvedMessage = message ?? error.toString().replaceAll('Exception: ', '');
    } else if (error != null) {
      resolvedMessage = message ?? error.toString();
    }

    try {
      await showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        builder: (ctx) => PopScope(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              _isShowing = false;
              onDismiss?.call();
            }
          },
          child: AppErrorDialog(
            title: title ?? 'Thông báo lỗi',
            message: resolvedMessage,
            errorId: resolvedId,
            errorCode: resolvedCode,
            onRetry: () {
              Navigator.of(ctx).pop();
              _isShowing = false;
              onRetry?.call();
            },
            onDismiss: () {
              Navigator.of(ctx).pop();
              _isShowing = false;
              onDismiss?.call();
            },
            retryText: retryText,
            dismissText: dismissText,
          ),
        ),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Trích xuất mã lỗi nếu truyền vào hoặc nằm trong chuỗi message
    String? resolvedErrorId = errorId;
    String? resolvedCode = errorCode;
    String displayMessage = message;

    // Trích xuất mã lỗi nếu nằm trong chuỗi message dạng (Mã lỗi: ...)
    final codeRegex = RegExp(r'\(Mã lỗi:\s*([^)]+)\)');
    final match = codeRegex.firstMatch(displayMessage);
    if (match != null) {
      final extracted = match.group(1)?.trim();
      if (extracted != null && extracted.isNotEmpty) {
        if (resolvedErrorId == null && resolvedCode == null) {
          resolvedErrorId = extracted;
        }
      }
      displayMessage = displayMessage.replaceAll(codeRegex, '').trim();
    }

    // Tách code dạng (code: 422, error_code: VALIDATION_ERROR) nếu có
    final legacyRegExp = RegExp(r'\(code:\s*(\d+),\s*error_code:\s*([^)]+)\)');
    final legacyMatch = legacyRegExp.firstMatch(displayMessage);
    if (legacyMatch != null) {
      resolvedCode ??= legacyMatch.group(2)?.trim();
      resolvedErrorId ??= 'HTTP-${legacyMatch.group(1)}';
      displayMessage = displayMessage.replaceAll(legacyRegExp, '').trim();
    }

    // Chuẩn hóa mã lỗi hiển thị
    String? finalCode;
    if (resolvedErrorId != null && resolvedErrorId.isNotEmpty) {
      if (resolvedCode != null && resolvedCode.isNotEmpty && !resolvedErrorId.contains(resolvedCode)) {
        finalCode = '$resolvedErrorId ($resolvedCode)';
      } else {
        finalCode = resolvedErrorId;
      }
    } else if (resolvedCode != null && resolvedCode.isNotEmpty) {
      finalCode = resolvedCode;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.roundedXl,
          boxShadow: AppShadows.level3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error Icon Header
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.errorContainer.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.headlineSmall(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),

            // Error Description Message
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                displayMessage,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                ).copyWith(height: 1.4),
              ),
            ),

            // Badge hiển thị Mã lỗi kèm nút Sao chép để báo admin
            if (finalCode != null && finalCode.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceContainer
                      : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tag_rounded, size: 16, color: AppColors.error),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        finalCode,
                        style: AppTypography.labelLarge(
                          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                        ).copyWith(
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: finalCode!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép mã lỗi vào bộ nhớ tạm.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(2.0),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDismiss ?? () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      dismissText,
                      style: AppTypography.labelLarge(
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ),
                    ),
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(retryText),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
