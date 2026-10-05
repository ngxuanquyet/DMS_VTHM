import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../attendance/presentation/viewmodels/attendance_view_model.dart';
import '../../domain/entities/dashboard_entity.dart';

class AttendanceSummaryCard extends ConsumerWidget {
  final DashboardAttendanceEntity? attendance;

  const AttendanceSummaryCard({super.key, this.attendance});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = ref.watch(stringsProvider);

    // 🔴 Đọc dữ liệu chấm công thực tế theo thời gian thực từ AttendanceViewModel
    final attState = ref.watch(attendanceViewModelProvider);
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final todayPunches = attState.history.where((p) => p.punchAt.startsWith(todayStr)).toList();

    bool isWorking = false;
    String checkInTime = '--:--';
    String workDuration = '00:00';
    String statusLabel = 'Chưa chấm công';

    if (todayPunches.isNotEmpty) {
      todayPunches.sort((a, b) => a.punchAt.compareTo(b.punchAt));
      isWorking = true;
      checkInTime = todayPunches.first.timeFormatted;
      final firstDt = todayPunches.first.punchAtDateTime;
      if (firstDt != null) {
        final diff = now.difference(firstDt);
        final hours = diff.inHours.toString().padLeft(2, '0');
        final mins = (diff.inMinutes % 60).toString().padLeft(2, '0');
        workDuration = '$hours:$mins';
      }
      statusLabel = todayPunches.length > 1
          ? 'Đã chấm (${todayPunches.length} lượt)'
          : (strings.isVietnamese ? 'Đang làm việc' : strings.workingStatus);
    } else if (attendance != null && attendance!.isCheckedIn) {
      isWorking = attendance!.isCheckedIn;
      checkInTime = attendance!.checkInTime;
      workDuration = attendance!.workDuration;
      statusLabel = attendance!.statusLabel;
    }

    final statusText = isWorking ? statusLabel : (strings.isVietnamese ? 'Chưa chấm công' : strings.shiftEnded);

    return InkWell(
      onTap: () => context.push('/attendance'),
      borderRadius: AppRadius.roundedLg,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.alarm_on_rounded,
                      color: isWorking
                          ? AppColors.primaryContainer
                          : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      strings.status,
                      style: AppTypography.titleMedium(
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                StatusBadge(
                  label: statusText,
                  type: isWorking ? StatusBadgeType.success : StatusBadgeType.neutral,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.checkInTime,
                      style: AppTypography.bodyMedium(
                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      checkInTime,
                      style: AppTypography.headlineSmall(
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      strings.workingTimeShort,
                      style: AppTypography.bodyMedium(
                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      workDuration,
                      style: AppTypography.headlineSmall(
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
