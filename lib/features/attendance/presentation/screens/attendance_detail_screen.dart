import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/location/location_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../states/attendance_state.dart';
import '../viewmodels/attendance_view_model.dart';
import '../widgets/attendance_history_card.dart';
import '../widgets/gps_location_card.dart';
import '../widgets/monthly_stats_card.dart';

class AttendanceDetailScreen extends ConsumerWidget {
  const AttendanceDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendanceViewModelProvider);
    final vm = ref.read(attendanceViewModelProvider.notifier);
    final strings = ref.watch(stringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: VthmTopAppBar(
        title: strings.attendanceDetailTitle,
        showBackButton: true,
      ),
      body: state.status == AttendanceStatus.loading && state.detail == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryContainer),
            )
          : state.detail == null
              ? Center(
                  child: Text(state.errorMessage ?? strings.error),
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
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: state.detail!.isWorking
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
                                    color: state.detail!.isWorking
                                        ? AppColors.primary
                                        : AppColors.outline,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  state.detail!.isWorking ? strings.workingStatus : strings.shiftEnded,
                                  style: AppTypography.labelLarge(
                                    color: state.detail!.isWorking
                                        ? (isDark ? AppColors.primaryFixedDim : AppColors.primary)
                                        : AppColors.outline,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            state.liveCurrentTime,
                            style: AppTypography.displayLarge(
                              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: -1),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            state.detail!.currentDateFormatted,
                            style: AppTypography.bodyLarge(
                              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.stackLg),

                      // Location Card
                      GpsLocationCard(location: state.detail!.location),
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
                                  state.detail!.checkInTime,
                                  style: AppTypography.titleMedium(
                                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Divider(height: 1),
                            const SizedBox(height: 10),
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
                                Text(
                                  state.formattedWorkDuration,
                                  style: AppTypography.titleLarge(
                                    color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                                  ).copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            AppButton(
                              text: state.detail!.isWorking ? strings.checkOutButton : strings.checkInButton,
                              height: 52,
                              icon: Icons.logout_rounded,
                              onPressed: () async {
                                final hasLocation = await ref
                                    .read(locationProvider.notifier)
                                    .requestLocationAccess();
                                if (!hasLocation) return;

                                vm.toggleAttendance();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        state.detail!.isWorking
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
                      MonthlyStatsCard(stats: state.detail!.monthlyStats),
                      const SizedBox(height: AppSpacing.stackMd),

                      // History Card
                      AttendanceHistoryCard(history: state.detail!.history),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }
}
