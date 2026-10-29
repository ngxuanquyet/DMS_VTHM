import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/attendance_entity.dart';
import '../viewmodels/attendance_view_model.dart';

/// Thẻ hiển thị ca làm việc hôm nay và lịch ca trong tuần (§8 SPEC-2026-10-17)
class AttendanceShiftCard extends ConsumerStatefulWidget {
  const AttendanceShiftCard({super.key});

  @override
  ConsumerState<AttendanceShiftCard> createState() => _AttendanceShiftCardState();
}

class _AttendanceShiftCardState extends ConsumerState<AttendanceShiftCard> {
  bool _isExpandedWeek = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(attendanceViewModelProvider);
    final today = state.config?.currentToday;
    final shiftSchedule = today?.shift;
    final multiShifts = state.shifts;

    // Nếu không có thông tin ca và chưa load xong config
    if (state.config == null && shiftSchedule == null) {
      return const SizedBox.shrink();
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Tiêu đề + Nút mở rộng xem lịch 7 ngày
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.primaryFixedDim : AppColors.primary)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ca làm việc hôm nay',
                    style: AppTypography.titleMedium(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (multiShifts.isNotEmpty)
                InkWell(
                  onTap: () {
                    setState(() {
                      _isExpandedWeek = !_isExpandedWeek;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          _isExpandedWeek ? 'Thu gọn' : 'Lịch tuần',
                          style: AppTypography.bodySmall(
                            color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        Icon(
                          _isExpandedWeek
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Nội dung ca làm việc hôm nay (§8.3)
          _buildTodayShiftContent(context, shiftSchedule, today?.punchCount ?? 0, isDark),

          // Danh sách lịch tuần mở rộng (GET /attendance/mobile/shifts?days=7)
          if (_isExpandedWeek && multiShifts.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: isDark ? AppColors.darkOutlineVariant : AppColors.surfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Lịch phân ca 7 ngày tới:',
              style: AppTypography.labelLarge(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _buildWeeklyScheduleList(multiShifts, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildTodayShiftContent(
    BuildContext context,
    AttendanceShiftScheduleEntity? schedule,
    int punchCount,
    bool isDark,
  ) {
    if (schedule == null) {
      return Text(
        'Đang cập nhật lịch ca...',
        style: AppTypography.bodyMedium(
          color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
        ),
      );
    }

    // 1. Trường hợp: Ca đã rõ (status == 'shift')
    if (schedule.isShift && schedule.shift != null) {
      final shift = schedule.shift!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  shift.name,
                  style: AppTypography.titleLarge(
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700, fontSize: 17),
                ),
              ),
              _buildSourceBadge(schedule.source, isDark),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 16,
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                '${shift.startTime} – ${shift.endTime}',
                style: AppTypography.bodyMedium(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              if (shift.crossMidnight) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Ca qua đêm (+1)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.purpleAccent,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Hàng ghi chú chuông nhắc ca tự động (§8)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceContainer.withValues(alpha: 0.5)
                  : AppColors.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  punchCount > 0 ? Icons.check_circle_rounded : Icons.notifications_active_outlined,
                  size: 15,
                  color: punchCount > 0
                      ? AppColors.success
                      : (isDark ? AppColors.primaryFixedDim : AppColors.primary),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    punchCount > 0
                        ? 'Đã chấm công hôm nay • Đã tự động hủy nhắc vào ca'
                        : 'Nhắc vào ca: 15\' trước giờ • Nhắc ra ca: Đúng giờ kết thúc',
                    style: AppTypography.bodySmall(
                      color: punchCount > 0
                          ? AppColors.success
                          : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                    ).copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // 2. Trường hợp: Xoay ca (status == 'multiple')
    if (schedule.isMultiple) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ngày xoay ca',
                  style: AppTypography.titleMedium(
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              _buildBadge('Xoay ca', AppColors.warning, isDark),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            schedule.displayText,
            style: AppTypography.bodyMedium(
              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ca làm việc chính thức sẽ được ghi nhận tự động sau lượt chấm công đầu tiên.',
            style: AppTypography.bodySmall(
              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
            ).copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      );
    }

    // 3. Trường hợp: Ngày nghỉ (status == 'day_off')
    if (schedule.isDayOff) {
      return Row(
        children: [
          Icon(
            Icons.weekend_outlined,
            size: 20,
            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Hôm nay bạn không có ca làm việc (Nghỉ tuần)',
              style: AppTypography.bodyMedium(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
          ),
          _buildBadge('Nghỉ', AppColors.outline, isDark),
        ],
      );
    }

    // 4. Trường hợp: Chưa xếp lịch (status == 'no_schedule')
    return Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 20,
          color: AppColors.error,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Chưa được xếp lịch — vui lòng liên hệ nhân sự',
            style: AppTypography.bodyMedium(
              color: AppColors.error,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSourceBadge(String? source, bool isDark) {
    switch (source) {
      case 'override':
        return _buildBadge('Xếp tay', Colors.amber.shade800, isDark);
      case 'schedule':
        return _buildBadge('Lịch tuần', AppColors.primary, isDark);
      case 'auto':
        return _buildBadge('Tự động', Colors.teal, isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBadge(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildWeeklyScheduleList(List<AttendanceShiftScheduleEntity> shifts, bool isDark) {
    final dateFormat = DateFormat('dd/MM');
    final dayNames = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

    return Column(
      children: shifts.map((item) {
        final date = DateTime.tryParse(item.workDate);
        final dateLabel = date != null ? dateFormat.format(date) : item.workDate;
        final dayLabel = date != null ? dayNames[date.weekday % 7] : '';

        String desc = item.displayText;
        if (item.isShift && item.shift != null) {
          desc = '${item.shift!.name} (${item.shift!.startTime}–${item.shift!.endTime})';
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceContainer.withValues(alpha: 0.3)
                : AppColors.surfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(
                  '$dayLabel, $dateLabel',
                  style: AppTypography.labelLarge(
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  desc,
                  style: AppTypography.bodySmall(
                    color: item.isDayOff
                        ? (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant)
                        : (isDark ? AppColors.darkOnSurface : AppColors.onSurface),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.source == 'override')
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'Xếp tay',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
