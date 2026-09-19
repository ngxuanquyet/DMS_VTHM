import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Full-screen celebration overlay shown upon successful dealer checkout.
/// Uses `assets/animations/congratulation.json` across the entire screen.
class CheckoutSuccessDialog extends StatelessWidget {
  final String dealerName;
  final VoidCallback? onConfirm;

  const CheckoutSuccessDialog({
    super.key,
    required this.dealerName,
    this.onConfirm,
  });

  /// Presents the celebration overlay covering the entire screen.
  static Future<void> show(
    BuildContext context, {
    required String dealerName,
    VoidCallback? onConfirm,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      barrierLabel: 'Checkout Success Overlay',
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, anim1, anim2) {
        return CheckoutSuccessDialog(
          dealerName: dealerName,
          onConfirm: onConfirm,
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen Lottie celebration covering the entire screen
          Positioned.fill(
            child: IgnorePointer(
              child: Lottie.asset(
                'assets/animations/congratulation.json',
                fit: BoxFit.cover,
                repeat: true,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ),

          // Foreground Centered Celebration Card
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceContainer.withValues(alpha: 0.96)
                        : Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkOutlineVariant.withValues(alpha: 0.5)
                          : AppColors.outlineVariant.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Badge icon
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Title
                      Text(
                        'Check-out thành công!',
                        textAlign: TextAlign.center,
                        style: AppTypography.titleLarge(
                          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                        ).copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Dealer Name Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.primary.withValues(alpha: 0.22)
                              : AppColors.primaryContainer.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          dealerName,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelLarge(
                            color: isDark ? AppColors.primaryFixed : AppColors.primary,
                          ).copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Description
                      Text(
                        'Bạn đã hoàn tất phiên làm việc tại điểm bán. Toàn bộ dữ liệu chuyến ghé đã được lưu vào hệ thống.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium(
                          color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                        ).copyWith(height: 1.45),
                      ),
                      const SizedBox(height: AppSpacing.stackLg),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onConfirm?.call();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'HOÀN TẤT',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
