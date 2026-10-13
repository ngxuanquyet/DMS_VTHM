import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../services/employee_tracking_service.dart';

/// Huy hiệu hiển thị trạng thái "Đang chia sẻ vị trí" trên VthmTopAppBar (§0 & §7)
class LocationSharingBadge extends ConsumerStatefulWidget {
  const LocationSharingBadge({super.key});

  @override
  ConsumerState<LocationSharingBadge> createState() => _LocationSharingBadgeState();
}

class _LocationSharingBadgeState extends ConsumerState<LocationSharingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(employeeTrackingProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isSharing = trackingState.isSharing;
    final isPinging = trackingState.isPinging;

    final badgeColor = isSharing ? AppColors.success : AppColors.outline;

    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: Tooltip(
        message: isSharing
            ? 'Đang chia sẻ vị trí (${trackingState.nextIntervalSec}s)'
            : 'Định vị theo dõi đang tắt',
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showTrackingInfoSheet(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSharing
                  ? badgeColor.withValues(alpha: isDark ? 0.2 : 0.12)
                  : (isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHigh),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSharing
                    ? badgeColor.withValues(alpha: 0.4)
                    : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPinging)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.success),
                    ),
                  )
                else if (isSharing)
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success,
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.location_off_outlined,
                    size: 13,
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  ),
                const SizedBox(width: 5),
                Icon(
                  Icons.gps_fixed_rounded,
                  size: 14,
                  color: isSharing
                      ? badgeColor
                      : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTrackingInfoSheet(BuildContext context, WidgetRef ref) {
    final trackingState = ref.read(employeeTrackingProvider);
    final trackingNotifier = ref.read(employeeTrackingProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final timeFormatter = DateFormat('HH:mm:ss dd/MM');
    final lastTimeStr = trackingState.lastPingTime != null
        ? timeFormatter.format(trackingState.lastPingTime!)
        : 'Chưa có lượt gửi';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_location_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Theo dõi vị trí nhân viên',
                            style: AppTypography.titleMedium().copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Phục vụ bản đồ điều phối quản lý',
                            style: AppTypography.bodySmall(
                              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: trackingState.isSharing
                            ? AppColors.success.withValues(alpha: 0.15)
                            : AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        trackingState.isSharing ? 'Đang hoạt động' : 'Tạm tắt',
                        style: AppTypography.labelSmall(
                          color: trackingState.isSharing ? AppColors.success : AppColors.error,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        Icons.timer_outlined,
                        'Nhịp gửi tự động',
                        '${trackingState.nextIntervalSec} giây (server điều khiển)',
                        isDark,
                      ),
                      const Divider(height: 16),
                      _buildInfoRow(
                        Icons.history_rounded,
                        'Lần gửi gần nhất',
                        lastTimeStr,
                        isDark,
                      ),
                      const Divider(height: 16),
                      _buildInfoRow(
                        Icons.cloud_queue_rounded,
                        'Hàng đợi ngoại tuyến',
                        '${trackingState.pendingPointsCount} điểm chờ gửi bù',
                        isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaryContainer.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tuân thủ Luật BVDLCN 91/2025: Vị trí chỉ gửi khi bạn ĐANG MỞ APP. Không theo dõi ngầm khi đóng ứng dụng.',
                          style: AppTypography.bodySmall(
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ).copyWith(fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!trackingState.isPermissionGranted) ...[
                  const SizedBox(height: 18),
                  AppButton(
                    text: 'CẤP QUYỀN VỊ TRÍ',
                    variant: AppButtonVariant.primary,
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await trackingNotifier.requestPermission();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppTypography.bodySmall(
            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTypography.bodySmall(
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
