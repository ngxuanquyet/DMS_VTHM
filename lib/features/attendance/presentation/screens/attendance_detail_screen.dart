import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/map/goong_models.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../states/attendance_state.dart';
import '../viewmodels/attendance_view_model.dart';
import '../widgets/attendance_history_card.dart';
import '../widgets/attendance_out_of_range_dialog.dart';
import '../widgets/gps_location_card.dart';
import '../widgets/monthly_stats_card.dart';
import '../widgets/workplace_selection_card.dart';

class AttendanceDetailScreen extends ConsumerWidget {
  const AttendanceDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(attendanceViewModelProvider.select((s) => s.status));
    final detail = ref.watch(attendanceViewModelProvider.select((s) => s.detail));
    final errorMessage = ref.watch(attendanceViewModelProvider.select((s) => s.errorMessage));
    final vm = ref.read(attendanceViewModelProvider.notifier);
    final strings = ref.watch(stringsProvider);
    final selectedWorkplace = ref.watch(selectedWorkplaceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: VthmTopAppBar(
        title: strings.attendanceDetailTitle,
        showBackButton: true,
      ),
      body: status == AttendanceStatus.loading && detail == null
          ? const Center(
              child: AppLoading(size: 220),
            )
          : detail == null
              ? Center(
                  child: Text(errorMessage ?? strings.error),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.marginMobile,
                    vertical: AppSpacing.stackLg,
                  ),
                  child: Column(
                    children: [
                      // Hero / Timer Section
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: detail.isWorking
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : AppColors.surfaceVariant,
                              borderRadius: AppRadius.roundedFull,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: detail.isWorking
                                        ? AppColors.primary
                                        : AppColors.outline,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  detail.isWorking ? strings.workingStatus : strings.shiftEnded,
                                  style: AppTypography.labelLarge(
                                    color: detail.isWorking
                                        ? (isDark ? AppColors.primaryFixedDim : AppColors.primary)
                                        : AppColors.outline,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Consumer(
                            builder: (context, ref, _) {
                              final liveTime = ref.watch(
                                attendanceViewModelProvider.select((s) => s.liveCurrentTime),
                              );
                              return Text(
                                liveTime,
                                style: AppTypography.displayLarge(
                                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                ).copyWith(fontWeight: FontWeight.w700, letterSpacing: -1),
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            detail.currentDateFormatted,
                            style: AppTypography.bodyLarge(
                              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.stackLg),

                      // Workplace & Unit Selection Card
                      const WorkplaceSelectionCard(),
                      const SizedBox(height: AppSpacing.stackMd),

                      // Location Card (Goong Vector Map)
                      GpsLocationCard(location: detail.location),
                      const SizedBox(height: AppSpacing.stackMd),

                      // Action / Status Card
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.gutter),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  strings.checkedInAt,
                                  style: AppTypography.bodyMedium(
                                    color: isDark
                                        ? AppColors.darkOnSurfaceVariant
                                        : AppColors.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  detail.checkInTime,
                                  style: AppTypography.titleMedium(
                                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(
                              height: 1,
                              color: isDark ? AppColors.darkOutlineVariant : AppColors.surfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  strings.workingDurationFull,
                                  style: AppTypography.bodyMedium(
                                    color: isDark
                                        ? AppColors.darkOnSurfaceVariant
                                        : AppColors.onSurfaceVariant,
                                  ),
                                ),
                                Consumer(
                                  builder: (context, ref, _) {
                                    final durationStr = ref.watch(
                                      attendanceViewModelProvider.select(
                                        (s) => s.formattedWorkDuration,
                                      ),
                                    );
                                    return Text(
                                      durationStr,
                                      style: AppTypography.titleMedium(
                                        color: isDark
                                            ? AppColors.primaryFixedDim
                                            : AppColors.primary,
                                      ).copyWith(fontWeight: FontWeight.w600),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            AppButton(
                              text: detail.isWorking ? strings.checkOutButton : strings.checkInButton,
                              height: 52,
                              icon: detail.isWorking ? Icons.logout_rounded : Icons.login_rounded,
                              onPressed: () async {
                                final position = await ref
                                    .read(locationServiceProvider)
                                    .checkAndGetLocation(context);
                                if (position == null) return;

                                // Tính khoảng cách thực tế giữa nhân viên và địa điểm làm việc đã chọn
                                final distanceMeters = Geolocator.distanceBetween(
                                  position.latitude,
                                  position.longitude,
                                  selectedWorkplace.lat,
                                  selectedWorkplace.lng,
                                );

                                // Bán kính cho phép tối đa là 100m
                                const maxAllowedDistance = 100.0;

                                if (distanceMeters > maxAllowedDistance) {
                                  if (context.mounted) {
                                    AttendanceOutOfRangeDialog.show(
                                      context,
                                      workplace: selectedWorkplace,
                                      userPoint: GoongLatLng(position.latitude, position.longitude),
                                      distanceMeters: distanceMeters,
                                      maxAllowedMeters: maxAllowedDistance,
                                    );
                                  }
                                  return;
                                }

                                await vm.toggleAttendance();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        detail.isWorking
                                            ? strings.checkOutSuccess
                                            : strings.checkInSuccess,
                                      ),
                                      backgroundColor: AppColors.primary,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.stackMd),

                      // Monthly Statistics
                      MonthlyStatsCard(stats: detail.monthlyStats),
                      const SizedBox(height: AppSpacing.stackMd),

                      // History Card
                      AttendanceHistoryCard(history: detail.history),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }
}
