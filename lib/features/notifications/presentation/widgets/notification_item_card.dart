import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/sync/sync_entity_group.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/offline_sync_badge.dart';
import '../../domain/entities/notification_entity.dart';
import '../viewmodels/notifications_view_model.dart';

class NotificationItemCard extends ConsumerWidget {
  final NotificationEntity notification;
  final VoidCallback? onTap;

  const NotificationItemCard({
    super.key,
    required this.notification,
    this.onTap,
  });

  /// Kiểm tra xem thông báo có phải là thông báo đồng bộ ngoại tuyến thành công không
  static bool isOfflineSyncSuccessNotification(NotificationEntity notification) {
    final type = notification.type.toLowerCase();
    final title = notification.title.toLowerCase();
    return type == 'sync_success' ||
        title.contains('đồng bộ ngoại tuyến thành công') ||
        title.contains('đồng bộ thành công');
  }

  /// Kiểm tra xem thông báo có phải là cảnh báo hàng đợi ngoại tuyến tồn đọng không
  static bool isOfflineQueueWarningNotification(NotificationEntity notification) {
    final type = notification.type.toLowerCase();
    final title = notification.title.toLowerCase();
    final message = notification.message.toLowerCase();
    return type == 'offline_queue_warning' ||
        title.contains('chưa đồng bộ') ||
        title.contains('tồn đọng hàng đợi') ||
        message.contains('bản ghi ngoại tuyến chưa được gửi');
  }

  /// Tự động xác định màn hình đích tương ứng với từng loại thông báo
  static String? resolveNotificationRoute(NotificationEntity notification) {
    final type = notification.type.toLowerCase();
    final title = notification.title.toLowerCase();
    final message = notification.message.toLowerCase();
    final combined = '$type $title $message';

    // 0. Ưu tiên hàng đầu: Thông báo điểm bán bị từ chối duyệt -> luôn điều hướng về /customers/rejected
    if (type == 'crm.customer_rejected' ||
        (combined.contains('từ chối') &&
            (combined.contains('điểm bán') ||
                combined.contains('khách hàng') ||
                type.contains('customer')))) {
      return '/customers/rejected';
    }

    final explicitPath = notification.routePath?.trim();
    if (explicitPath != null && explicitPath.isNotEmpty && explicitPath != '/notifications') {
      if (explicitPath == '/route' || explicitPath == '/route/check-in') {
        return '/routes';
      }
      return explicitPath;
    }

    // Các thông báo ngoại tuyến được xử lý riêng bằng Modal BottomSheet (tránh nhảy lung tung hoặc đè stack)
    if (isOfflineSyncSuccessNotification(notification) ||
        isOfflineQueueWarningNotification(notification)) {
      return null;
    }

    // 1. Thông báo Tuyến bán hàng / Lộ trình (Ưu tiên theo yêu cầu người dùng)
    if (type.contains('route') ||
        combined.contains('tuyến') ||
        combined.contains('lộ trình') ||
        combined.contains('tiến độ tuyến') ||
        combined.contains('lân cận') ||
        type == 'nearby_suggestion') {
      return '/routes';
    }

    // 2. Thông báo Chấm công (Vào ca, Ra ca)
    if (type.contains('attendance') ||
        combined.contains('chấm công') ||
        combined.contains('vào ca') ||
        combined.contains('ra ca')) {
      return '/attendance';
    }

    // 3. Thông báo Check-in / Viếng thăm
    if (type.contains('checkin') ||
        type.contains('check_in') ||
        type == 'forgot_checkout' ||
        combined.contains('kết thúc viếng thăm')) {
      return '/routes';
    }

    // 4. Thông báo Biểu mẫu khảo sát thị trường
    if (type.contains('form') ||
        combined.contains('biểu mẫu') ||
        combined.contains('khảo sát')) {
      return '/forms';
    }

    // 5. Thông báo Điểm bán / Khách hàng
    if (type.contains('customer') ||
        combined.contains('khách hàng') ||
        combined.contains('điểm bán mới')) {
      return '/customers';
    }

    // 6. Khai báo vị trí
    if (type.contains('position') ||
        combined.contains('khai báo vị trí')) {
      return '/position-declaration';
    }

    // 7. Báo cáo ngày
    if (type.contains('report') || combined.contains('báo cáo ngày')) {
      return '/daily-report';
    }

    // 8. Nhật ký di chuyển / Hành trình
    if (type.contains('travel') ||
        combined.contains('hành trình') ||
        combined.contains('di chuyển')) {
      return '/travel';
    }

    return null;
  }

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

  /// Hiển thị Modal chi tiết kết quả đồng bộ ngoại tuyến
  void _showSyncSuccessModal(BuildContext context, WidgetRef ref, bool isDark) {
    final pendingEntries = ref.read(allPendingQueueEntriesProvider).value ?? [];
    final groupedPending = SyncEntityGroupHelper.groupEntries(pendingEntries);
    final displayPendingCount = groupedPending.isNotEmpty
        ? groupedPending.length
        : (ref.read(pendingSyncCountProvider).value ?? 0);
    final deadCount = ref.read(deadSyncCountProvider).value ?? 0;
    final isOnline = ref.read(connectivityProvider).isOnline;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.cloud_done_rounded,
                          color: Color(0xFF10B981),
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Đã tải lên máy chủ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatTimeAgo(notification.createdAt),
                                style: AppTypography.labelSmall(
                                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.title,
                            style: AppTypography.titleMedium(
                              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Hộp nội dung chi tiết
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF262D28) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          notification.message,
                          style: AppTypography.bodyMedium(
                            color: isDark ? AppColors.darkOnSurface : const Color(0xFF166534),
                          ).copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Trạng thái mạng & Hàng đợi hiện tại
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                        size: 18,
                        color: isOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isOnline ? 'Kết nối Internet: Trực tuyến' : 'Mạng: Ngoại tuyến',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF374151),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: displayPendingCount == 0 && deadCount == 0
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : const Color(0xFF3B82F6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          displayPendingCount == 0 && deadCount == 0
                              ? 'Hàng đợi sạch'
                              : '$displayPendingCount chờ gửi',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: displayPendingCount == 0 && deadCount == 0
                                ? const Color(0xFF059669)
                                : const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Nút hành động
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          showOfflineSyncModal(context);
                        },
                        icon: const Icon(Icons.list_alt_rounded, size: 18),
                        label: const Text('Hàng đợi'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white70 : AppColors.onSurface,
                          side: BorderSide(
                            color: isDark ? Colors.white24 : AppColors.outlineVariant,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.push('/daily-report');
                        },
                        icon: const Icon(Icons.assessment_outlined, size: 18),
                        label: const Text('Xem báo cáo ngày'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF006E15),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white60 : Colors.black54,
                    ),
                    child: const Text('Đóng'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNotificationDetail(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        notification.category == 'work' ? 'Công việc' : 'Hệ thống',
                        style: AppTypography.labelSmall(color: AppColors.primary),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTimeAgo(notification.createdAt),
                      style: AppTypography.labelSmall(
                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  notification.title,
                  style: AppTypography.titleMedium(
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  notification.message,
                  style: AppTypography.bodyMedium(
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Đã hiểu'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleTap(BuildContext context, WidgetRef ref) {
    // 1. Đánh dấu đã đọc -> bỏ chấm xanh và cập nhật số lượng badge
    ref.read(notificationsViewModelProvider.notifier).markAsRead(notification.id);

    // 2. Nếu có callback tùy chỉnh
    if (onTap != null) {
      onTap!();
      return;
    }

    // 3. Xử lý riêng cho các thông báo đồng bộ ngoại tuyến (tránh đè chồng màn hình notifications)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isOfflineSyncSuccessNotification(notification)) {
      _showSyncSuccessModal(context, ref, isDark);
      return;
    }

    if (isOfflineQueueWarningNotification(notification)) {
      showOfflineSyncModal(context);
      return;
    }

    // 4. Điều hướng tới màn hình tương ứng (tuyệt đối không push /notifications)
    final targetRoute = resolveNotificationRoute(notification);
    if (targetRoute != null && targetRoute.isNotEmpty && targetRoute != '/notifications') {
      if (targetRoute == '/routes' ||
          targetRoute == '/home' ||
          targetRoute == '/customers' ||
          targetRoute == '/forms' ||
          targetRoute == '/profile') {
        context.go(targetRoute);
      } else {
        context.push(targetRoute);
      }
    } else {
      // 5. Nếu là thông báo chung chưa gắn màn cụ thể, hiển thị popup nội dung chi tiết
      _showNotificationDetail(context, isDark);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targetRoute = resolveNotificationRoute(notification);
    final isSyncSuccess = isOfflineSyncSuccessNotification(notification);
    final isQueueWarning = isOfflineQueueWarningNotification(notification);

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
      case 'crm.customer_rejected':
        icon = Icons.cancel_outlined;
        iconColor = const Color(0xFFDC2626);
        iconBg = const Color(0xFFFEE2E2);
        break;
      case 'crm.customer_approved':
        icon = Icons.check_circle_outline_rounded;
        iconColor = const Color(0xFF006E15);
        iconBg = const Color(0xFFE8F5E9);
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
      onTap: () => _handleTap(context, ref),
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
                          const SizedBox(width: 8),
                          Text(
                            isSyncSuccess
                                ? '• Xem kết quả đồng bộ'
                                : isQueueWarning
                                    ? '• Xem hàng đợi ngoại tuyến'
                                    : (targetRoute != null ? '• Nhấn để mở' : '• Xem chi tiết'),
                            style: AppTypography.labelSmall(
                              color: isSyncSuccess
                                  ? const Color(0xFF059669)
                                  : isQueueWarning
                                      ? const Color(0xFFEA580C)
                                      : (targetRoute != null
                                          ? (isDark ? AppColors.primaryFixedDim : AppColors.primary)
                                          : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline)),
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Chấm xanh thông báo chưa đọc: tự động biến mất khi notification.isRead = true
            if (!notification.isRead)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 9,
                  height: 9,
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
