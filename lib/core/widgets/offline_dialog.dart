import 'package:flutter/material.dart';
import '../localization/app_language.dart';
import '../localization/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

class OfflineDisconnectDialog extends StatelessWidget {
  final VoidCallback? onDismiss;
  final AppStrings? strings;

  const OfflineDisconnectDialog({
    super.key,
    this.onDismiss,
    this.strings,
  });

  static bool isShowing = false;
  static BuildContext? _activeDialogContext;

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onDismiss,
    AppStrings? strings,
  }) {
    if (isShowing) return Future.value();
    isShowing = true;

    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) {
        _activeDialogContext = ctx;
        return PopScope(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              isShowing = false;
              _activeDialogContext = null;
              onDismiss?.call();
            }
          },
          child: OfflineDisconnectDialog(
            strings: strings,
            onDismiss: () {
              isShowing = false;
              _activeDialogContext = null;
              onDismiss?.call();
            },
          ),
        );
      },
    ).then((_) {
      isShowing = false;
      _activeDialogContext = null;
    });
  }

  static void dismiss() {
    if (isShowing && _activeDialogContext != null) {
      try {
        if (_activeDialogContext!.mounted) {
          Navigator.of(_activeDialogContext!).pop();
        }
      } catch (_) {}
      isShowing = false;
      _activeDialogContext = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = strings ?? const AppStrings(AppLanguage.vi);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.roundedXl,
          boxShadow: AppShadows.level3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Disconnect Icon Header
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.errorContainer.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.wifi_off_rounded,
                  color: AppColors.error,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              s.offlineTitle,
              style: AppTypography.headlineSmall(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                s.offlineDesc,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                ).copyWith(height: 1.4),
              ),
            ),
            const SizedBox(height: 24),

            // CTA Button "ĐÃ HIỂU"
            AppButton(
              text: s.understood,
              width: double.infinity,
              height: 48,
              onPressed: () {
                Navigator.of(context).pop();
                onDismiss?.call();
              },
            ),
            const SizedBox(height: 8),

            // Secondary "Đóng" button
            SizedBox(
              width: double.infinity,
              height: 40,
              child: TextButton(
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.roundedMd,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  onDismiss?.call();
                },
                child: Text(
                  s.close,
                  style: AppTypography.labelLarge(
                    color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
