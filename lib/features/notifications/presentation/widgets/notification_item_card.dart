import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/notification_entity.dart';

class NotificationItemCard extends StatelessWidget {
  final NotificationEntity notification;

  const NotificationItemCard({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    IconData icon;
    Color iconColor;
    Color iconBg;

    switch (notification.type) {
      case 'attendance':
        icon = Icons.fingerprint_rounded;
        iconColor = isDark ? AppColors.primaryFixedDim : AppColors.primary;
        iconBg = AppColors.primaryContainer.withValues(alpha: 0.2);
        break;
      case 'route':
        icon = Icons.alt_route_rounded;
        iconColor = isDark ? AppColors.tertiaryFixedDim : AppColors.tertiary;
        iconBg = AppColors.tertiaryContainer.withValues(alpha: 0.2);
        break;
      case 'form':
        icon = Icons.assignment_outlined;
        iconColor = isDark ? AppColors.secondaryFixedDim : AppColors.secondary;
        iconBg = AppColors.secondaryContainer.withValues(alpha: 0.2);
        break;
      case 'checkin':
        icon = Icons.location_on_outlined;
        iconColor = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
        iconBg = isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceVariant;
        break;
      default:
        icon = Icons.system_update_rounded;
        iconColor = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
        iconBg = isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceVariant;
        break;
    }

    final cardBg = !notification.isRead
        ? (isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLow)
        : (isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      backgroundColor: cardBg,
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: AppTypography.titleMedium(
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ).copyWith(
                        fontWeight: !notification.isRead ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.message,
                      style: AppTypography.bodyMedium(
                        color: isDark
                            ? AppColors.darkOnSurfaceVariant
                            : AppColors.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notification.timeAgo,
                      style: AppTypography.labelSmall(
                        color: !notification.isRead
                            ? (isDark ? AppColors.primaryFixedDim : AppColors.primary)
                            : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline),
                      ).copyWith(
                        fontWeight: !notification.isRead ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!notification.isRead)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
