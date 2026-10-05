import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/daily_activity_entity.dart';
import 'package:vthm_dms/features/position_declaration/presentation/viewmodels/position_declaration_view_model.dart';
import '../viewmodels/visit_report_view_model.dart';
import '../widgets/daily_activity_timeline_card.dart';
import '../widgets/visit_report_card.dart';

/// Màn hình Báo cáo viếng thăm & Hoạt động trong ngày
/// Cung cấp cái nhìn tổng thể về số điểm chăm sóc, tỷ lệ mở/đóng cửa,
/// thời gian làm việc, ảnh thực địa và danh sách các lượt viếng thăm thiết yếu.
/// Dữ liệu được lưu trữ và truy xuất cục bộ (local storage), không fix cứng mock data.
class DailyReportScreen extends ConsumerStatefulWidget {
  const DailyReportScreen({super.key});

  @override
  ConsumerState<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends ConsumerState<DailyReportScreen> {
  bool _showTimeline = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reportState = ref.watch(visitReportViewModelProvider);
    final reportVm = ref.read(visitReportViewModelProvider.notifier);
    final posState = ref.watch(positionDeclarationViewModelProvider);

    final selectedDate = reportState.selectedDate;
    final dateStr = DateFormat('dd/MM/yyyy').format(selectedDate);
    final isToday = _isSameDay(selectedDate, DateTime.now());
    final isYesterday = _isSameDay(
      selectedDate,
      DateTime.now().subtract(const Duration(days: 1)),
    );

    // Xây dựng dòng thời gian hoạt động thực tế từ các lượt viếng thăm và khai báo vị trí
    final dynamicActivities = _buildRealActivities(
      reportState,
      posState,
      selectedDate,
    );

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: AppBar(
        title: const Text('Báo cáo viếng thăm'),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới dữ liệu',
            onPressed: () {
              reportVm.loadVisits(forceRefresh: true);
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded, size: 20),
            tooltip: 'Chọn ngày',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime(2025),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (picked != null) {
                reportVm.setDate(picked);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await reportVm.loadVisits(forceRefresh: true);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Thanh chọn ngày nhanh
              _buildDateBar(
                context: context,
                selectedDate: selectedDate,
                dateStr: dateStr,
                isToday: isToday,
                isYesterday: isYesterday,
                isDark: isDark,
                onDateChanged: (d) => reportVm.setDate(d),
              ),
              const SizedBox(height: 14),

              // 2. Lưới chỉ số tóm tắt ngày ("Mang lại cái nhìn tổng thể")
              Row(
                children: [
                  Expanded(
                    child: _SummaryBox(
                      label: 'Điểm viếng thăm',
                      value: reportState.totalVisits > 0
                          ? '${reportState.visitedCount} / ${reportState.totalVisits} điểm'
                          : '0 điểm',
                      color: const Color(0xFF006E15),
                      bgColor: const Color(0xFFE8F5E9),
                      icon: Icons.store_mall_directory_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryBox(
                      label: 'Ảnh đóng dấu',
                      value: '${reportState.totalPhotos} ảnh',
                      color: const Color(0xFFD97706),
                      bgColor: const Color(0xFFFEF3C7),
                      icon: Icons.camera_alt_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SummaryBox(
                      label: 'Biểu mẫu nộp',
                      value: '${reportState.totalForms} phiếu',
                      color: const Color(0xFF4F46E5),
                      bgColor: const Color(0xFFEEF2FF),
                      icon: Icons.assignment_turned_in_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryBox(
                      label: 'Giờ làm việc',
                      value: reportState.formattedDuration,
                      color: const Color(0xFF0D9488),
                      bgColor: const Color(0xFFCCFBF1),
                      icon: Icons.timer_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Thanh lọc trạng thái viếng thăm
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      'Tất cả (${reportState.totalVisits})',
                      'all',
                      reportState.selectedFilter,
                      isDark,
                      (val) => reportVm.setFilter(val),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'Mở cửa (${reportState.visitedCount})',
                      'visited',
                      reportState.selectedFilter,
                      isDark,
                      (val) => reportVm.setFilter(val),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'Đóng cửa (${reportState.closedCount})',
                      'closed',
                      reportState.selectedFilter,
                      isDark,
                      (val) => reportVm.setFilter(val),
                    ),
                    if (reportState.inProgressCount > 0) ...[
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Đang mở (${reportState.inProgressCount})',
                        'in_progress',
                        reportState.selectedFilter,
                        isDark,
                        (val) => reportVm.setFilter(val),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. Danh sách các lượt viếng thăm
              Row(
                children: [
                  const Icon(
                    Icons.format_list_bulleted_rounded,
                    color: Color(0xFF006E15),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Danh sách lượt viếng thăm',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${reportState.filteredVisits.length} lượt',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (reportState.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              else if (reportState.filteredVisits.isEmpty)
                _buildEmptyVisitsState(context, isDark, dateStr)
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reportState.filteredVisits.length,
                  itemBuilder: (context, idx) {
                    final visit = reportState.filteredVisits[idx];
                    return VisitReportCard(visit: visit);
                  },
                ),

              const SizedBox(height: 20),

              // 5. Nhật ký dòng thời gian hoạt động thực địa trong ngày
              InkWell(
                onTap: () => setState(() => _showTimeline = !_showTimeline),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.timeline_rounded,
                        color: Color(0xFF4F46E5),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Dòng thời gian hoạt động',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        _showTimeline
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              if (_showTimeline)
                DailyActivityTimelineCard(
                  activities: dynamicActivities,
                  showHeader: false,
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateBar({
    required BuildContext context,
    required DateTime selectedDate,
    required String dateStr,
    required bool isToday,
    required bool isYesterday,
    required bool isDark,
    required ValueChanged<DateTime> onDateChanged,
  }) {
    String badgeText = 'Ngày khác';
    if (isToday) badgeText = 'Hôm nay';
    if (isYesterday) badgeText = 'Hôm qua';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2420) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E7E2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.event_available_rounded,
            color: Color(0xFF006E15),
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            'Ngày: $dateStr',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const Spacer(),
          if (!isToday)
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => onDateChanged(DateTime.now()),
              child: const Text(
                'Về hôm nay',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF006E15),
                ),
              ),
            ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF006E15).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badgeText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF006E15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String currentValue,
    bool isDark,
    ValueChanged<String> onSelected,
  ) {
    final isSelected = currentValue == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF006E15),
      backgroundColor: isDark ? const Color(0xFF262D28) : Colors.white,
      side: BorderSide(
        color: isSelected
            ? const Color(0xFF006E15)
            : (isDark ? Colors.white12 : const Color(0xFFE2E7E2)),
      ),
      onSelected: (selected) {
        if (selected) {
          onSelected(value);
        }
      },
    );
  }

  Widget _buildEmptyVisitsState(
      BuildContext context, bool isDark, String dateStr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2420) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E7E2),
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.storefront_outlined,
                size: 44,
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Chưa có lượt viếng thăm nào trong ngày $dateStr',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Dữ liệu viếng thăm sẽ được lưu tự động trên máy khi bạn thực hiện check-in / check-out tại các điểm bán.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006E15),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.route_rounded, size: 18),
              label: const Text(
                'Đến danh sách tuyến',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              onPressed: () => context.go('/routes'),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<DailyActivityEntity> _buildRealActivities(
    VisitReportState reportState,
    dynamic posState,
    DateTime selectedDate,
  ) {
    final list = <DailyActivityEntity>[];
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    // 1. Chuyển đổi các lượt viếng thăm thành activity
    for (final v in reportState.visits) {
      // Check-in
      if (v.checkinAt != null) {
        list.add(
          DailyActivityEntity(
            id: 'visit-in-${v.id}',
            time: DateFormat('HH:mm').format(v.checkinAt!.toLocal()),
            title: 'Check-in: ${v.customerName}',
            subtitle: v.customerAddress ??
                (v.isOnRoute ? 'Trong tuyến' : 'Ngoài tuyến'),
            type: DailyActivityType.checkIn,
            customerName: v.customerName,
            customerAddress: v.customerAddress,
            photos: v.photoUrls,
            notes: v.closedNote,
            lat: v.checkoutLat,
            lng: v.checkoutLng,
          ),
        );
      }

      // Check-out
      if (v.checkoutAt != null) {
        list.add(
          DailyActivityEntity(
            id: 'visit-out-${v.id}',
            time: DateFormat('HH:mm').format(v.checkoutAt!.toLocal()),
            title: 'Check-out: ${v.customerName}',
            subtitle:
                'Kết quả: ${v.visitResult == 'closed' ? "Đóng cửa" : "Mở cửa"} • Thời lượng: ${v.durationSeconds != null ? "${v.durationSeconds! ~/ 60}p" : "--"}',
            type: DailyActivityType.checkOut,
            customerName: v.customerName,
            customerAddress: v.customerAddress,
            photos: v.photoUrls,
            notes: v.closedNote,
            lat: v.checkoutLat,
            lng: v.checkoutLng,
          ),
        );
      }
    }

    // 2. Chuyển đổi các lượt khai báo vị trí trong ngày thành activity
    if (posState != null && posState.history is List) {
      for (final dec in posState.history) {
        if (dec.createdAtMs > 0) {
          final dt = DateTime.fromMillisecondsSinceEpoch(dec.createdAtMs);
          if (DateFormat('yyyy-MM-dd').format(dt) == selectedDateStr) {
            list.add(
              DailyActivityEntity(
                id: 'decl-${dec.clientUuid}',
                time: DateFormat('HH:mm').format(dt),
                title: 'Khai báo vị trí: ${dec.reasonDisplay}',
                subtitle: dec.address ??
                    'Toạ độ: ${dec.lat.toStringAsFixed(4)}, ${dec.lng.toStringAsFixed(4)}',
                type: DailyActivityType.positionDeclaration,
                notes: dec.note,
                lat: dec.lat,
                lng: dec.lng,
              ),
            );
          }
        }
      }
    }

    // Sắp xếp các hoạt động theo thời gian tăng dần
    list.sort((a, b) => a.time.compareTo(b.time));
    return list;
  }
}

class _SummaryBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  final IconData icon;

  const _SummaryBox({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.14) : bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.3 : 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : const Color(0xFF6F7A74),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
