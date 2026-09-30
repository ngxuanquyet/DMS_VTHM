import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Component hiển thị trạng thái danh sách/dữ liệu trống với thiết kế hiện đại,
/// bao gồm icon đại diện, tiêu đề, văn bản giải thích chi tiết và nút hành động.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionText;
  final VoidCallback? onAction;
  final String? secondaryActionText;
  final VoidCallback? onSecondaryAction;
  final double iconSize;

  const AppEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    required this.description,
    this.actionText,
    this.onAction,
    this.secondaryActionText,
    this.onSecondaryAction,
    this.iconSize = 56,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.marginMobile * 1.5,
          vertical: 40,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon container với nền tròn bo viền tinh tế
            Container(
              width: iconSize * 1.8,
              height: iconSize * 1.8,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceContainer.withValues(alpha: 0.6)
                    : AppColors.surfaceContainerHigh.withValues(alpha: 0.6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? AppColors.darkOutlineVariant.withValues(alpha: 0.5)
                      : AppColors.outlineVariant.withValues(alpha: 0.8),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: iconSize,
                  color: isDark
                      ? AppColors.darkOnSurfaceVariant
                      : AppColors.outline,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Tiêu đề giải thích
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleLarge(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            // Đoạn văn bản giải thích chi tiết
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(
                color: isDark
                    ? AppColors.darkOnSurfaceVariant
                    : AppColors.onSurfaceVariant,
              ).copyWith(height: 1.45),
            ),

            // Các nút thao tác (nếu có)
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: onAction,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(actionText!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (secondaryActionText != null && onSecondaryAction != null)
                    OutlinedButton.icon(
                      onPressed: onSecondaryAction,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(secondaryActionText!),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
