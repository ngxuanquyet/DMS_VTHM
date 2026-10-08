import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/notification_entity.dart';

class NotificationItemCard extends StatelessWidget {
  final NotificationEntity notification;

  const NotificationItemCard({super.key, required this.notification});

  String _formatTimeAgo(DateTime? time) {
    if (time == null) return notification.timeAgo;
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    IconData icon;
    Color iconColor;
    Color iconBg;

    switch (notification.type) {
      case 'attendance_checkin':
      case 'attendance_checkout':
      case 'attendance':
        icon = Icons.fingerprint_rounded;
        iconColor = isDark ? AppColors.primaryFixedDim : AppColors.primary;
        iconBg = AppColors.primaryContainer.withValues(alpha: 0.25);
        break;
      case 'route_briefing':
      case 'route':
        icon = Icons.alt_route_rounded;
        iconColor = isDark ? AppColors.tertiaryFixedDim : AppColors.tertiary;
        iconBg = AppColors.tertiaryContainer.withValues(alpha: 0.25);
        break;
      case 'route_progress':
        icon = Icons.speed_rounded;
        iconColor = const Color(0xFFD97706);
        iconBg = const Color(0xFFFEF3C7);
        break;
      case 'forgot_checkout':
        icon = Icons.timer_outlined;
        iconColor = const Color(0xFFDC2626);
        iconBg = const Color(0xFFFEE2E2);
        break;
      case 'nearby_suggestion':
        icon = Icons.near_me_rounded;
        iconColor = const Color(0xFF059669);
        iconBg = const Color(0xFFD1FAE5);
        break;
      case 'sync_success':
        icon = Icons.cloud_done_rounded;
        iconColor = const Color(0xFF0284C7);
        iconBg = const Color(0xFFE0F2FE);
        break;
      case 'offline_queue_warning':
        icon = Icons.cloud_off_rounded;
        iconColor = const Color(0xFFEA580C);
        iconBg = const Color(0xFFFFEDD5);
        break;
      case 'form':
        icon = Icons.assignment_outlined;
        iconColor = isDark ? AppColors.secondaryFixedDim : AppColors.secondary;
        iconBg = AppColors.secondaryContainer.withValues(alpha: 0.25);
        break;
      case 'checkin':
        icon = Icons.location_on_outlined;
        iconColor = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
        iconBg = isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceVariant;
        break;
      default:
        icon = Icons.notifications_rounded;
        iconColor = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
        iconBg = isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceVariant;
        break;
    }

    final cardBg = !notification.isRead
        ? (isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLow)
        : (isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest);

    return InkWell(
      onTap: () {
        if (notification.routePath != null && notification.routePath!.isNotEmpty) {
          context.push(notification.routePath!);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: AppCard(
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
                      Row(
                        children: [
                          Text(
                            _formatTimeAgo(notification.createdAt),
                            style: AppTypography.labelSmall(
                              color: !notification.isRead
                                  ? (isDark ? AppColors.primaryFixedDim : AppColors.primary)
                                  : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline),
                            ).copyWith(
                              fontWeight: !notification.isRead ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                          if (notification.routePath != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• Nhấn để xem',
                              style: AppTypography.labelSmall(
                                color: AppColors.primary,
                              ).copyWith(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ],
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
      ),
    );
  }
}
