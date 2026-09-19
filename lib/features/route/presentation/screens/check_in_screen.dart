import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/custom_donut_chart.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../states/route_state.dart';
import '../viewmodels/route_view_model.dart';
import '../widgets/checkout_success_dialog.dart';

class CheckInScreen extends ConsumerWidget {
  const CheckInScreen({super.key});

  Future<void> _showCancelCheckInDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
        title: Text(
          'Hủy check-in',
          style: AppTypography.titleLarge(
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Bạn có chắc chắn muốn hủy phiên check-in này không? Dữ liệu chuyến ghé chưa lưu sẽ không được ghi nhận.',
          style: AppTypography.bodyMedium(
            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Không',
              style: AppTypography.labelLarge(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hủy check-in'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã hủy phiên check-in điểm bán.'),
          backgroundColor: AppColors.error,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkInViewModelProvider);
    final vm = ref.read(checkInViewModelProvider.notifier);
    final strings = ref.watch(stringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: VthmTopAppBar(
        title: strings.visitingStoreTitle,
        showBackButton: true,
        showAvatar: false,
        showLogo: false,
        trailing: const SizedBox.shrink(),
      ),
      body: state.status == CheckInStatus.loading && state.checkinData == null
          ? const Center(
              child: AppLoading(size: 220),
            )
          : state.checkinData == null
              ? Center(child: Text(state.errorMessage ?? 'Không tải được dữ liệu điểm bán'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dealer Info Card (bỏ text VIP, khoảng cách thực tế)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.marginMobile,
                          16,
                          AppSpacing.marginMobile,
                          0,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceContainerLowest
                                : AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkOutlineVariant
                                  : AppColors.outlineVariant,
                              width: 1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A000000),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(AppSpacing.marginMobile),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.checkinData!.dealer.name,
                                style: AppTypography.titleMedium(
                                  color: isDark
                                      ? AppColors.primaryFixedDim
                                      : AppColors.primary,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${state.checkinData!.dealer.id}',
                                style: AppTypography.labelSmall(
                                  color: isDark
                                      ? AppColors.darkOnSurfaceVariant
                                      : AppColors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Divider(
                                height: 1,
                                color: (isDark
                                        ? AppColors.darkOutlineVariant
                                        : AppColors.outlineVariant)
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.darkSurfaceContainerLowest
                                            : AppColors.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.login_rounded,
                                            size: 18,
                                            color: isDark
                                                ? AppColors.primaryFixedDim
                                                : AppColors.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Giờ check-in',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark
                                                        ? AppColors.darkOnSurfaceVariant
                                                        : AppColors.onSurfaceVariant,
                                                    height: 1.1,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  state.checkinTime,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    fontFamily: 'monospace',
                                                    color: isDark
                                                        ? AppColors.primaryFixedDim
                                                        : AppColors.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondaryContainer.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.timer_outlined,
                                            size: 18,
                                            color: AppColors.secondary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Thời gian viếng thăm',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark
                                                        ? AppColors.darkOnSurfaceVariant
                                                        : AppColors.onSurfaceVariant,
                                                    height: 1.1,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  state.liveVisitDuration,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    fontFamily: 'monospace',
                                                    color: AppColors.secondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Tasks Section
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.marginMobile,
                          20,
                          AppSpacing.marginMobile,
                          0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Công việc cần làm',
                              style: AppTypography.titleMedium(
                                color: isDark
                                    ? AppColors.darkOnSurface
                                    : AppColors.onSurface,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),

                            // Task 1: Forms
                            _buildTaskCard(
                              context: context,
                              isDark: isDark,
                              icon: Icons.assignment_outlined,
                              iconColor: AppColors.primary,
                              title: 'Thu thập biểu mẫu',
                              subtitle: 'Đánh giá trưng bày, Tồn kho',
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '2/3',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.primaryFixedDim
                                          : AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  CustomDonutProgress(
                                    progress: 0.66,
                                    size: 24,
                                    strokeWidth: 3.5,
                                    progressColor: isDark
                                        ? AppColors.primaryFixedDim
                                        : AppColors.primaryContainer,
                                  ),
                                ],
                              ),
                              onTap: () => context.go('/forms'),
                            ),
                            const SizedBox(height: 12),

                            // Task 2: Photos
                            _buildTaskCard(
                              context: context,
                              isDark: isDark,
                              icon: Icons.photo_camera_outlined,
                              iconColor: isDark
                                  ? AppColors.darkOnSurfaceVariant
                                  : AppColors.outline,
                              title: 'Chụp ảnh điểm bán',
                              subtitleWidget: const Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 14,
                                    color: AppColors.error,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Chưa có ảnh',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Icon(
                                Icons.chevron_right,
                                color: isDark
                                    ? AppColors.darkOnSurfaceVariant
                                    : AppColors.outline,
                              ),
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Đang mở Camera chụp ảnh điểm bán...')),
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            // Task 3: Notes
                            _buildTaskCard(
                              context: context,
                              isDark: isDark,
                              icon: Icons.edit_note_rounded,
                              iconColor: isDark
                                  ? AppColors.darkOnSurfaceVariant
                                  : AppColors.outline,
                              title: 'Ghi chú chuyến ghé',
                              subtitle: 'Thêm ý kiến phản hồi',
                              trailing: Icon(
                                Icons.chevron_right,
                                color: isDark
                                    ? AppColors.darkOnSurfaceVariant
                                    : AppColors.outline,
                              ),
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Mở form ghi chú chuyến ghé...')),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      // Cố định hàng HỦY CHECK-IN và CHECK-OUT ở cuối màn hình
      bottomNavigationBar: state.checkinData == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.marginMobile),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? AppColors.darkOutlineVariant
                          : AppColors.outlineVariant,
                      width: 1,
                    ),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      offset: Offset(0, -4),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Hủy check-in Button
                    OutlinedButton.icon(
                      onPressed: () => _showCancelCheckInDialog(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppColors.error,
                      ),
                      label: const Text(
                        'Hủy check-in',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.error,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        minimumSize: const Size(0, 48),
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.4),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: isDark
                            ? AppColors.darkSurface
                            : AppColors.surface,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // CHECK-OUT Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: state.status == CheckInStatus.checkingOut
                            ? null
                            : () async {
                                final position = await ref
                                    .read(locationServiceProvider)
                                    .checkAndGetLocation(context);
                                if (position == null) return;

                                final success = await vm.checkout();
                                if (success && context.mounted) {
                                  await CheckoutSuccessDialog.show(
                                    context,
                                    dealerName: state.checkinData?.dealer.name ??
                                        'Khách hàng',
                                  );
                                  if (context.mounted) {
                                    context.pop();
                                  }
                                }
                              },
                        icon: state.status == CheckInStatus.checkingOut
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: AppLoading(size: 28),
                              )
                            : const Icon(
                                Icons.logout_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                        label: const Text(
                          'CHECK-OUT',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 1,
                          shadowColor: const Color(0x1A000000),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTaskCard({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? subtitleWidget,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark
          ? AppColors.darkSurfaceContainerLowest
          : AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark
              ? AppColors.darkOutlineVariant
              : AppColors.outlineVariant,
          width: 1,
        ),
      ),
      elevation: 1,
      shadowColor: const Color(0x0A000000),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.marginMobile),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceContainerLowest
                      : AppColors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleMedium(
                        color: isDark
                            ? AppColors.darkOnSurface
                            : AppColors.onSurface,
                      ).copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    if (subtitleWidget != null)
                      subtitleWidget
                    else if (subtitle != null)
                      Text(
                        subtitle,
                        style: AppTypography.labelSmall(
                          color: isDark
                              ? AppColors.darkOnSurfaceVariant
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
