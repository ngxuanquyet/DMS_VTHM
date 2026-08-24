import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum StatusBadgeType { success, warning, error, info, neutral }

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusBadgeType type;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    this.type = StatusBadgeType.success,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;

    switch (type) {
      case StatusBadgeType.success:
        bg = AppColors.primaryContainer.withValues(alpha: 0.12);
        fg = AppColors.primary;
        border = AppColors.primaryContainer.withValues(alpha: 0.25);
        break;
      case StatusBadgeType.warning:
        bg = const Color(0xFFFFF4E5);
        fg = const Color(0xFFB76E00);
        border = const Color(0xFFFFD180);
        break;
      case StatusBadgeType.error:
        bg = AppColors.errorContainer.withValues(alpha: 0.3);
        fg = AppColors.error;
        border = AppColors.errorContainer;
        break;
      case StatusBadgeType.info:
        bg = AppColors.secondaryContainer.withValues(alpha: 0.2);
        fg = AppColors.secondary;
        border = AppColors.secondaryContainer.withValues(alpha: 0.4);
        break;
      case StatusBadgeType.neutral:
        bg = AppColors.surfaceContainerHigh;
        fg = AppColors.onSurfaceVariant;
        border = AppColors.outlineVariant;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.roundedSm,
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.labelSmall(color: fg).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
