import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/custom_donut_chart.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../states/route_state.dart';
import '../viewmodels/route_view_model.dart';

class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key});

  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        trailing: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Icon(
            Icons.location_on,
            color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
            size: 24,
          ),
        ),
      ),
      body: state.status == CheckInStatus.loading && state.checkinData == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryContainer),
            )
          : state.checkinData == null
              ? Center(child: Text(state.errorMessage ?? 'Không tải được dữ liệu điểm bán'))
              : Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Map Preview Area with Geofence radar pulse overlay
                          SizedBox(
                            height: 200,
                            width: double.infinity,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  AppConstants.mapPreviewUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: AppColors.surfaceContainerHigh,
                                  ),
                                ),
                                Center(
                                  child: AnimatedBuilder(
                                    animation: _pulseAnimation,
                                    builder: (context, child) {
                                      return Container(
                                        width: 120 * _pulseAnimation.value,
                                        height: 120 * _pulseAnimation.value,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.primaryContainer.withValues(
                                            alpha: (1.3 - _pulseAnimation.value) * 0.35,
                                          ),
                                          border: Border.all(
                                            color: AppColors.primaryContainer.withValues(
                                              alpha: (1.3 - _pulseAnimation.value) * 0.8,
                                            ),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Center(
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.primaryContainer,
                                            ),
                                            child: const Icon(
                                              Icons.location_on,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Dealer Info Card (overlapping map)
                          Transform.translate(
                            offset: const Offset(0, -28),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.marginMobile,
                              ),
                              child: AppCard(
                                padding: const EdgeInsets.all(AppSpacing.gutter),
                                shadows: AppShadows.level2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                state.checkinData!.dealer.name,
                                                style: AppTypography.titleLarge(
                                                  color: isDark
                                                      ? AppColors.primaryFixedDim
                                                      : AppColors.primary,
                                                ).copyWith(fontWeight: FontWeight.w700),
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
                                            ],
                                          ),
                                        ),
                                        if (state.checkinData!.dealer.isVip)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryContainer.withValues(alpha: 0.15),
                                              borderRadius: AppRadius.roundedSm,
                                              border: Border.all(
                                                color: AppColors.primaryContainer.withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Text(
                                              'VIP',
                                              style: AppTypography.labelSmall(
                                                color: isDark
                                                    ? AppColors.primaryFixedDim
                                                    : AppColors.primary,
                                              ).copyWith(fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? AppColors.darkSurfaceContainerLowest
                                                : AppColors.surfaceContainerLow,
                                            borderRadius: AppRadius.roundedSm,
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.directions_walk,
                                                size: 16,
                                                color: AppColors.outline,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${state.checkinData!.dealer.distanceMeters}m',
                                                style: AppTypography.labelSmall(
                                                  color: isDark
                                                      ? AppColors.darkOnSurface
                                                      : AppColors.onSurface,
                                                ).copyWith(fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.secondaryContainer.withValues(alpha: 0.25),
                                            borderRadius: AppRadius.roundedSm,
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.timer_outlined,
                                                size: 16,
                                                color: AppColors.secondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                state.liveVisitDuration,
                                                style: AppTypography.labelSmall(
                                                  color: AppColors.secondary,
                                                ).copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Tasks Section
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.marginMobile,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Công việc cần làm',
                                  style: AppTypography.titleLarge(
                                    color: isDark
                                        ? AppColors.darkOnSurface
                                        : AppColors.onSurface,
                                  ).copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 12),

                                // Task 1: Forms
                                AppCard(
                                  padding: const EdgeInsets.all(AppSpacing.gutter),
                                  onTap: () => context.go('/forms'),
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
                                        child: const Center(
                                          child: Icon(
                                            Icons.assignment_outlined,
                                            color: AppColors.primary,
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
                                              'Thu thập biểu mẫu',
                                              style: AppTypography.titleMedium(
                                                color: isDark
                                                    ? AppColors.darkOnSurface
                                                    : AppColors.onSurface,
                                              ).copyWith(fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Đánh giá trưng bày, Tồn kho',
                                              style: AppTypography.labelSmall(
                                                color: isDark
                                                    ? AppColors.darkOnSurfaceVariant
                                                    : AppColors.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            '2/3',
                                            style: AppTypography.labelLarge(
                                              color: isDark
                                                  ? AppColors.primaryFixedDim
                                                  : AppColors.primary,
                                            ).copyWith(fontWeight: FontWeight.w700),
                                          ),
                                          const SizedBox(width: 8),
                                          const CustomDonutProgress(
                                            progress: 0.66,
                                            size: 22,
                                            strokeWidth: 3.5,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Task 2: Photos
                                AppCard(
                                  padding: const EdgeInsets.all(AppSpacing.gutter),
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Đang mở Camera chụp ảnh điểm bán...')),
                                    );
                                  },
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
                                        child: const Center(
                                          child: Icon(
                                            Icons.photo_camera_outlined,
                                            color: AppColors.outline,
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
                                              'Chụp ảnh điểm bán',
                                              style: AppTypography.titleMedium(
                                                color: isDark
                                                    ? AppColors.darkOnSurface
                                                    : AppColors.onSurface,
                                              ).copyWith(fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.error_outline,
                                                  size: 14,
                                                  color: AppColors.error,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Chưa có ảnh',
                                                  style: AppTypography.labelSmall(
                                                    color: AppColors.error,
                                                  ).copyWith(fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right,
                                        color: AppColors.outline,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Task 3: Notes
                                AppCard(
                                  padding: const EdgeInsets.all(AppSpacing.gutter),
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Mở form ghi chú chuyến ghé...')),
                                    );
                                  },
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
                                        child: const Center(
                                          child: Icon(
                                            Icons.edit_note_rounded,
                                            color: AppColors.outline,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Ghi chú chuyến ghé',
                                              style: AppTypography.titleMedium(
                                                color: isDark
                                                    ? AppColors.darkOnSurface
                                                    : AppColors.onSurface,
                                              ).copyWith(fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Thêm ý kiến phản hồi',
                                              style: AppTypography.labelSmall(
                                                color: isDark
                                                    ? AppColors.darkOnSurfaceVariant
                                                    : AppColors.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right,
                                        color: AppColors.outline,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Sticky Bottom CTA Button
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.marginMobile),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.surface,
                          border: Border(
                            top: BorderSide(
                              color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                              width: 1,
                            ),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0F000000),
                              offset: Offset(0, -4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: AppButton(
                          text: 'CHECK-OUT',
                          height: 52,
                          icon: Icons.logout_rounded,
                          isLoading: state.status == CheckInStatus.checkingOut,
                          onPressed: () async {
                            final success = await vm.checkout();
                            if (success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Check-out thành công! Đã lưu dữ liệu chuyến ghé.'),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                              context.pop();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
