import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/attendance_entity.dart';
import '../viewmodels/attendance_view_model.dart';
import 'attendance_photo_capture_dialog.dart';
import 'attendance_photo_viewer_dialog.dart';

enum AttendanceViewMode { calendar, list }

enum DayAttendanceStatus { valid, warning, violation, none, future }

class AttendanceHistoryCard extends ConsumerStatefulWidget {
  final List<AttendancePunchEntity> history;

  const AttendanceHistoryCard({super.key, required this.history});

  @override
  ConsumerState<AttendanceHistoryCard> createState() => _AttendanceHistoryCardState();
}

class _AttendanceHistoryCardState extends ConsumerState<AttendanceHistoryCard> {
  AttendanceViewMode _viewMode = AttendanceViewMode.calendar;
  late DateTime _focusedMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
    // Thẻ dựng lại (màn tải lại) thì tháng đang xem về tháng hiện tại — tải đúng tháng đó, không để VM giữ tháng cũ.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadResults();
    });
  }

  void _previousMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
    _loadResults();
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
    _loadResults();
  }

  void _goToToday() {
    final now = DateTime.now();
    final changed = _focusedMonth.year != now.year || _focusedMonth.month != now.month;
    setState(() {
      _focusedMonth = DateTime(now.year, now.month, 1);
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
    if (changed) _loadResults();
  }

  /// Kết quả công (vào muộn / ra sớm) của tháng đang xem — server tính (§8.4), app không tự đếm.
  void _loadResults() {
    ref.read(attendanceViewModelProvider.notifier).loadMonthResults(_focusedMonth);
  }

  /// Tổng muộn/sớm của tháng đang xem, vd "Đi muộn 3 ngày (25 phút) · Về sớm 1 ngày (10 phút)".
  /// Số ngày = ngày có ÍT NHẤT một bảng công muộn/sớm; số phút = cộng theo từng bảng công (người nhiều mã).
  /// `null` khi dữ liệu đang có không phải của tháng này (chưa tải / tải lỗi) — hiện câu "chưa có kết quả" thay vì số 0.
  String? _monthSummary(Map<String, List<AttendanceDayResultEntity>> results, String? loadedMonth) {
    if (loadedMonth != DateFormat('yyyy-MM').format(_focusedMonth)) return null;
    final days = results.values.toList();
    final lateDays = days.where((rows) => rows.any((r) => r.isLate)).length;
    final earlyDays = days.where((rows) => rows.any((r) => r.isEarly)).length;
    final all = days.expand((rows) => rows);
    final lateMin = all.fold<int>(0, (sum, r) => sum + r.lateMinutes);
    final earlyMin = all.fold<int>(0, (sum, r) => sum + r.earlyMinutes);
    return 'Đi muộn $lateDays ngày ($lateMin phút) · Về sớm $earlyDays ngày ($earlyMin phút)';
  }

  /// Nhãn kết quả công của một ngày — mỗi bảng công một cụm; nhiều mã thì ghi kèm mã cho người đọc biết của vị trí nào.
  Widget _buildDayResults(List<AttendanceDayResultEntity> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows.map((r) => _buildDayResultChips(r, rows.length > 1 ? r.employeeCode : null)).toList(),
    );
  }

  /// Nhãn kết quả công của một bảng công: trạng thái + số phút muộn/sớm.
  Widget _buildDayResultChips(AttendanceDayResultEntity result, String? code) {
    Widget chip(String text, Color color) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: AppRadius.roundedSm,
          ),
          child: Text(
            text,
            style: AppTypography.labelSmall(color: color).copyWith(fontWeight: FontWeight.w700),
          ),
        );

    // TẠM ẨN nhãn trạng thái ngày (chủ hệ thống chốt 22/10/2026): ngày chỉ một lượt chấm, bảng công đoán Vào/Ra theo nửa ca
    // nên lượt bấm "Vào" buổi chiều hiện "Thiếu giờ vào" — ngược nhãn "Vào" của app. Chỉ hiện phút muộn/sớm.
    final chips = <Widget>[
      if (result.isLate) chip('Muộn ${result.lateMinutes} phút', AppColors.warning),
      if (result.isEarly) chip('Sớm ${result.earlyMinutes} phút', AppColors.warning),
      if (result.lateEarlyExcused) chip('Đã giải trình', AppColors.primary),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    if (code != null && code.isNotEmpty) chips.insert(0, chip(code, Colors.grey.shade600));

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(spacing: 6, runSpacing: 6, children: chips),
    );
  }

  List<AttendancePunchEntity> _getPunchesForDate(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final punches = widget.history.where((p) {
      if (p.punchAt.startsWith(dateStr)) return true;
      final dt = p.punchAtDateTime;
      if (dt != null) {
        return DateUtils.isSameDay(dt, date);
      }
      return false;
    }).toList();

    punches.sort((a, b) => a.punchAt.compareTo(b.punchAt));
    return punches;
  }

  DayAttendanceStatus _getDayStatus(
    DateTime date,
    List<AttendancePunchEntity> dayPunches,
    List<AttendanceDayResultEntity>? dayResults,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cellDay = DateTime(date.year, date.month, date.day);

    if (dayPunches.isEmpty) {
      if (cellDay.isAfter(today)) return DayAttendanceStatus.future;
      return DayAttendanceStatus.none;
    }



    // 2. Thiếu ảnh chụp -> Vàng
    if (dayPunches.any((p) => !p.requirements.satisfied)) {
      return DayAttendanceStatus.warning;
    }

    // 3. Server đã tính công ngày này ⇒ theo KẾT QUẢ server, không đếm lượt thô: hai lượt sát nhau bị gộp thành một
    //    (`punch_merge_minutes`) nên vẫn là "thiếu giờ ra/vào" dù app thấy hai lượt (VTG902, 27/10/2026).
    final results = dayResults ?? const <AttendanceDayResultEntity>[];
    if (results.isNotEmpty) {
      const incomplete = {'missing_in', 'missing_out', 'absent_unexcused'};
      return results.any((r) => incomplete.contains(r.dayStatus))
          ? DayAttendanceStatus.warning
          : DayAttendanceStatus.valid;
    }

    // 4. Chưa đủ ca ra (nếu không phải hôm nay mà chỉ có 1 lượt chấm) -> Vàng
    if (!DateUtils.isSameDay(cellDay, today) && dayPunches.length < 2) {
      return DayAttendanceStatus.warning;
    }

    // 5. Nếu là hôm nay và mới có 1 lượt chấm vào -> Vàng (đang trong ca)
    if (DateUtils.isSameDay(cellDay, today) && dayPunches.length == 1 && dayPunches.first.direction == 'in') {
      return DayAttendanceStatus.warning;
    }

    return DayAttendanceStatus.valid;
  }

  Color _getStatusColor(DayAttendanceStatus status) {
    switch (status) {
      case DayAttendanceStatus.valid:
        return const Color(0xFF10B981); // Xanh lá
      case DayAttendanceStatus.warning:
        return AppColors.warning; // Vàng hổ phách
      case DayAttendanceStatus.violation:
        return const Color(0xFF10B981);
      case DayAttendanceStatus.none:
        return Colors.grey.shade400; // Xám
      case DayAttendanceStatus.future:
        return Colors.transparent;
    }
  }

  String _formatDateTitle(DateTime date) {
    final weekdays = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    final weekdayStr = weekdays[date.weekday - 1];
    return '$weekdayStr, ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedDays = ref.watch(attendanceViewModelProvider.select((s) => s.selectedDays));
    final vm = ref.read(attendanceViewModelProvider.notifier);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Tiêu đề + Chuyển chế độ xem (Bảng lịch / Danh sách)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _viewMode == AttendanceViewMode.calendar
                        ? Icons.calendar_month_rounded
                        : Icons.history_rounded,
                    color: AppColors.secondary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _viewMode == AttendanceViewMode.calendar
                        ? 'Bảng lịch chấm công'
                        : 'Lịch sử chấm công',
                    style: AppTypography.titleMedium(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              // Nút toggle Lịch <-> Danh sách
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceVariant,
                  borderRadius: AppRadius.roundedSm,
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    _buildModeButton(
                      mode: AttendanceViewMode.calendar,
                      icon: Icons.calendar_view_month_rounded,
                      label: 'Lịch',
                      isSelected: _viewMode == AttendanceViewMode.calendar,
                      isDark: isDark,
                    ),
                    _buildModeButton(
                      mode: AttendanceViewMode.list,
                      icon: Icons.view_list_rounded,
                      label: 'Danh sách',
                      isSelected: _viewMode == AttendanceViewMode.list,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Hiển thị giao diện theo chế độ đã chọn
          if (_viewMode == AttendanceViewMode.calendar)
            _buildCalendarView(context, isDark)
          else
            _buildListView(context, isDark, selectedDays, vm),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required AttendanceViewMode mode,
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
      borderRadius: AppRadius.roundedSm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: AppRadius.roundedSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.labelSmall(
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
              ).copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. GIAO DIỆN BẢNG LỊCH THÁNG (CALENDAR VIEW)
  // ===========================================================================
  Widget _buildCalendarView(BuildContext context, bool isDark) {
    final now = DateTime.now();
    final isCurrentMonth = _focusedMonth.year == now.year && _focusedMonth.month == now.month;
    final punchesForSelectedDay = _getPunchesForDate(_selectedDate);
    final dayResults = ref.watch(attendanceViewModelProvider.select((s) => s.dayResults));
    final dayResultsMonth = ref.watch(attendanceViewModelProvider.select((s) => s.dayResultsMonth));
    final selectedResults = dayResultsMonth == DateFormat('yyyy-MM').format(_selectedDate)
        ? dayResults[DateFormat('yyyy-MM-dd').format(_selectedDate)]
        : null;
    final monthSummary = _monthSummary(dayResults, dayResultsMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Điều hướng Tháng / Năm + Nút "Hôm nay"
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceContainerLowest.withValues(alpha: 0.6)
                : AppColors.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: AppRadius.roundedMd,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: _previousMonth,
                tooltip: 'Tháng trước',
              ),
              Row(
                children: [
                  Text(
                    'Tháng ${_focusedMonth.month.toString().padLeft(2, '0')}/${_focusedMonth.year}',
                    style: AppTypography.titleMedium(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (!isCurrentMonth) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _goToToday,
                      borderRadius: AppRadius.roundedSm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: AppRadius.roundedSm,
                        ),
                        child: Text(
                          'Hôm nay',
                          style: AppTypography.labelSmall(color: AppColors.primary)
                              .copyWith(fontWeight: FontWeight.w600, fontSize: 10),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: _nextMonth,
                tooltip: 'Tháng sau',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Hàng tiêu đề các thứ trong tuần (T2 -> CN)
        Row(
          children: ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'].map((w) {
            final isWeekend = w == 'CN' || w == 'T7';
            return Expanded(
              child: Center(
                child: Text(
                  w,
                  style: AppTypography.labelSmall(
                    color: isWeekend
                        ? (isDark ? Colors.red.shade300 : Colors.red.shade700)
                        : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),

        // Lưới các ngày trong tháng (Calendar Grid)
        _buildCalendarGrid(isDark),
        const SizedBox(height: 12),

        // Tổng vào muộn / ra sớm của tháng — số server đã tính trên bảng công; chưa tải được thì nói rõ, không hiện số 0
        ...[
          Text(
            monthSummary ?? 'Chưa có kết quả công của tháng này',
            style: AppTypography.bodySmall(
              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
        ],

        // Bảng chú thích màu sắc trạng thái (§A3)
        _buildLegendBar(isDark),
        const SizedBox(height: 14),

        Divider(
          height: 1,
          color: isDark ? AppColors.darkOutlineVariant : AppColors.surfaceVariant,
        ),
        const SizedBox(height: 14),

        // =====================================================================
        // CHI TIẾT NGÀY ĐƯỢC CHỌN TRÊN BẢNG LỊCH
        // =====================================================================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDateTitle(_selectedDate),
                  style: AppTypography.titleMedium(
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  punchesForSelectedDay.isEmpty
                      ? 'Chưa có lượt chấm công'
                      : '${punchesForSelectedDay.length} lượt chấm công',
                  style: AppTypography.bodySmall(
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  ),
                ),
                if (selectedResults != null && selectedResults.isNotEmpty) _buildDayResults(selectedResults),
              ],
              ),
            ),
            if (punchesForSelectedDay.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.roundedSm,
                ),
                child: Text(
                  '${punchesForSelectedDay.length} lượt',
                  style: AppTypography.labelSmall(color: AppColors.primary).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (punchesForSelectedDay.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceContainerLowest.withValues(alpha: 0.5)
                  : AppColors.surfaceVariant.withValues(alpha: 0.3),
              borderRadius: AppRadius.roundedMd,
            ),
            child: Column(
              children: [
                Icon(
                  Icons.event_available_outlined,
                  size: 36,
                  color: isDark ? AppColors.darkOutline : AppColors.outline,
                ),
                const SizedBox(height: 8),
                Text(
                  'Không có dữ liệu chấm công cho ngày này',
                  style: AppTypography.bodyMedium(
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: punchesForSelectedDay.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) => _buildPunchItem(
              context,
              punchesForSelectedDay[idx],
              isDark,
            ),
          ),
      ],
    );
  }

  Widget _buildCalendarGrid(bool isDark) {
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final prevMonthLastDay = DateTime(_focusedMonth.year, _focusedMonth.month, 0).day;

    // weekday: 1 (Mon) -> 7 (Sun)
    final daysBefore = firstDayOfMonth.weekday - 1;
    final totalCells = daysBefore + daysInMonth;
    final dayResults = ref.watch(attendanceViewModelProvider.select((s) => s.dayResults));
    final trailingDays = (7 - (totalCells % 7)) % 7;
    final totalCount = totalCells + trailingDays;

    final now = DateTime.now();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, index) {
        final bool isPrevMonth = index < daysBefore;
        final bool isNextMonth = index >= daysBefore + daysInMonth;
        final bool isCurrentMonth = !isPrevMonth && !isNextMonth;

        final DateTime cellDate;
        final int dayNumber;

        if (isPrevMonth) {
          dayNumber = prevMonthLastDay - (daysBefore - 1 - index);
          cellDate = DateTime(_focusedMonth.year, _focusedMonth.month - 1, dayNumber);
        } else if (isNextMonth) {
          dayNumber = index - (daysBefore + daysInMonth) + 1;
          cellDate = DateTime(_focusedMonth.year, _focusedMonth.month + 1, dayNumber);
        } else {
          dayNumber = index - daysBefore + 1;
          cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayNumber);
        }

        final isSelected = DateUtils.isSameDay(cellDate, _selectedDate);
        final isToday = DateUtils.isSameDay(cellDate, now);

        final dayPunches = _getPunchesForDate(cellDate);
        final status = _getDayStatus(cellDate, dayPunches, dayResults[DateFormat('yyyy-MM-dd').format(cellDate)]);
        final statusColor = _getStatusColor(status);

        return InkWell(
          onTap: () {
            setState(() {
              _selectedDate = cellDate;
              if (!isCurrentMonth) {
                _focusedMonth = DateTime(cellDate.year, cellDate.month, 1);
              }
            });
            if (!isCurrentMonth) _loadResults();
          },
          borderRadius: AppRadius.roundedSm,
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.15)
                  : (isToday
                      ? AppColors.secondary.withValues(alpha: 0.1)
                      : (isDark
                          ? AppColors.darkSurfaceContainerLowest.withValues(alpha: 0.4)
                          : Colors.transparent)),
              borderRadius: AppRadius.roundedSm,
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : (isToday
                        ? AppColors.secondary
                        : (isDark ? AppColors.darkOutlineVariant.withValues(alpha: 0.3) : Colors.transparent)),
                width: isSelected ? 1.8 : 1.0,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dayNumber',
                  style: AppTypography.bodySmall(
                    color: !isCurrentMonth
                        ? (isDark ? Colors.white24 : Colors.black26)
                        : (isSelected
                            ? (isDark ? AppColors.primaryFixedDim : AppColors.primary)
                            : (isDark ? AppColors.darkOnSurface : AppColors.onSurface)),
                  ).copyWith(
                    fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                // Chấm màu trạng thái (§A3)
                if (status != DayAttendanceStatus.future)
                  Container(
                    width: 5.5,
                    height: 5.5,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(height: 5.5),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegendBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLowest.withValues(alpha: 0.4)
            : AppColors.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: AppRadius.roundedSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem(const Color(0xFF10B981), 'Đủ công'),
          _buildLegendItem(AppColors.warning, 'Thiếu ảnh/ca'),
          _buildLegendItem(Colors.grey.shade400, 'Không chấm'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. GIAO DIỆN XEM DẠNG DANH SÁCH (LIST VIEW - BỘ LỌC 7d | 14d | 30d)
  // ===========================================================================
  Widget _buildListView(
    BuildContext context,
    bool isDark,
    int selectedDays,
    AttendanceViewModel vm,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter pills: 7d | 14d | 30d
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [7, 14, 30].map((days) {
            final isSelected = selectedDays == days;
            return Padding(
              padding: const EdgeInsets.only(left: 6.0),
              child: InkWell(
                onTap: () => vm.setHistoryDays(days),
                borderRadius: AppRadius.roundedSm,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceVariant),
                    borderRadius: AppRadius.roundedSm,
                  ),
                  child: Text(
                    '$days ngày',
                    style: AppTypography.labelSmall(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                    ).copyWith(fontSize: 11, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        if (widget.history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.history_toggle_off_rounded,
                    size: 40,
                    color: isDark ? AppColors.darkOutline : AppColors.outline,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chưa có lượt chấm công nào trong $selectedDays ngày qua',
                    style: AppTypography.bodyMedium(
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _buildPunchItem(context, widget.history[index], isDark);
            },
          ),
      ],
    );
  }

  // ===========================================================================
  // THẺ CHI TIẾT LƯỢT CHẤM CÔNG (ITEM PUNCH CARD)
  // ===========================================================================
  Widget _buildPunchItem(
    BuildContext context,
    AttendancePunchEntity item,
    bool isDark,
  ) {
    final isSatisfied = item.requirements.satisfied;
    final Color indicatorColor =
        isSatisfied ? const Color(0xFF10B981) : AppColors.warning;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surface,
        borderRadius: AppRadius.roundedMd,
        border: Border.all(
          color: isDark ? AppColors.darkOutlineVariant : AppColors.surfaceVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              color: indicatorColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
          // Hàng thời gian + Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${item.timeFormatted} · ${item.dateFormatted}',
                        style: AppTypography.titleMedium(
                          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (item.directionLabel != null && item.directionLabel!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _directionBadge(item.direction, item.directionLabel!),
                      ] else ...[
                        const SizedBox(width: 8),
                        _directionBadge(item.direction, '—'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.geofenceName ?? 'Điểm không xác định',
                    style: AppTypography.bodySmall(
                      color: isDark
                          ? AppColors.darkOnSurfaceVariant
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSatisfied
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: AppRadius.roundedSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSatisfied ? Icons.check_circle_rounded : Icons.camera_alt_outlined,
                      size: 13,
                      color: isSatisfied ? const Color(0xFF10B981) : AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isSatisfied
                          ? 'Đủ ảnh (${item.photos.length})'
                          : 'Thiếu ảnh (${item.photos.length}/${item.requirements.minPhotos})',
                      style: AppTypography.labelSmall(
                        color: isSatisfied ? const Color(0xFF10B981) : AppColors.warning,
                      ).copyWith(fontWeight: FontWeight.w600, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),



          // Danh sách thumbnail ảnh của lượt chấm (§4.4)
          if (item.photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 54,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: item.photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, photoIndex) {
                  final photo = item.photos[photoIndex];
                  final fullUrl = photo.getFullUrl(AppConstants.baseUrl);

                  return InkWell(
                    onTap: () => AttendancePhotoViewerDialog.show(context, photo: photo),
                    borderRadius: AppRadius.roundedSm,
                    child: ClipRRect(
                      borderRadius: AppRadius.roundedSm,
                      child: Container(
                        width: 54,
                        height: 54,
                        color: Colors.black12,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (photo.url.isNotEmpty && File(photo.url).existsSync())
                              Image.file(
                                File(photo.url),
                                fit: BoxFit.cover,
                                cacheWidth: 300,
                              )
                            else
                              Image.network(
                                fullUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(
                                    Icons.image_not_supported_rounded,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                ),
                                cacheWidth: 300,
                              ),
                            if (photo.id < 0)
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.cloud_upload_outlined,
                                    color: Colors.white,
                                    size: 11,
                                  ),
                                ),
                              ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                color: Colors.black54,
                                padding: const EdgeInsets.symmetric(vertical: 1),
                                child: Text(
                                  photo.photoType == 'front' ? 'Trước' : 'Sau',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          // Nút "Chụp bổ sung ảnh" nếu chưa đủ (§4.1)
          if (!isSatisfied) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () => AttendancePhotoCaptureDialog.show(context, punch: item),
                borderRadius: AppRadius.roundedSm,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_a_photo_rounded, size: 16, color: AppColors.secondary),
                      const SizedBox(width: 6),
                      Text(
                        'Bổ sung ảnh',
                        style: AppTypography.labelSmall(
                          color: AppColors.secondary,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _directionBadge(String? direction, String label) {
    final isOut = label == 'Ra' || direction == 'out';
    final isNone = label == '—' || direction == null;

    final Color badgeBg;
    final Color textColor;

    if (isOut) {
      badgeBg = Colors.orange.withValues(alpha: 0.15);
      textColor = Colors.orange.shade800;
    } else if (isNone) {
      badgeBg = AppColors.surfaceVariant;
      textColor = AppColors.outline;
    } else {
      badgeBg = const Color(0xFF10B981).withValues(alpha: 0.12);
      textColor = const Color(0xFF10B981);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: AppRadius.roundedSm,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
