import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../states/travel_state.dart';
import '../viewmodels/travel_view_model.dart';
import '../widgets/travel_day_card.dart';
import '../widgets/travel_summary_card.dart';

/// Màn hình "Quãng đường của tôi"
/// Gọi GET /dms/travel/mine, hiện road_km + is_complete (§4.1 & Checklist §7)
class MyTravelScreen extends ConsumerStatefulWidget {
  const MyTravelScreen({super.key});

  @override
  ConsumerState<MyTravelScreen> createState() => _MyTravelScreenState();
}

class _MyTravelScreenState extends ConsumerState<MyTravelScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(travelViewModelProvider);
    final vm = ref.read(travelViewModelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Quãng đường của tôi',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        foregroundColor: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: () => vm.loadMyTravel(refresh: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => vm.loadMyTravel(refresh: true),
        color: const Color(0xFF0D9488),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // 1. Thẻ tóm tắt tổng quan
            TravelSummaryCard(state: state),
            const SizedBox(height: 16),

            // 2. Thanh lọc thời gian dạng Filter Chips
            _buildFilterChips(context, state, vm, isDark),
            const SizedBox(height: 14),

            // 3. Thông báo giải thích cơ chế tính (§1 & §6)
            _buildExplanationBanner(isDark),
            const SizedBox(height: 16),

            // 4. Thông báo lỗi nếu có
            if (state.errorMessage != null && state.errorMessage!.isNotEmpty) ...[
              _buildErrorBanner(state.errorMessage!, isDark, vm),
              const SizedBox(height: 16),
            ],

            // 5. Danh sách các ngày công
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: AppLoading()),
              )
            else if (state.days.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: AppEmptyState(
                  icon: Icons.route_rounded,
                  title: 'Chưa có dữ liệu quãng đường',
                  description:
                      'Chưa có dữ liệu quãng đường trong khoảng thời gian đã chọn.\nDữ liệu được tính tự động hàng đêm từ các lượt chấm công và viếng thăm.',
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'LỊCH SỬ THEO NGÀY (${state.days.length})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      'Nhấn để xem chi tiết chặng',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              ...state.days.map(
                (day) => TravelDayCard(
                  day: day,
                  onTap: () {
                    context.push('/travel/legs', extra: day);
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(
    BuildContext context,
    TravelState state,
    TravelViewModel vm,
    bool isDark,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip(
            label: 'Tháng này',
            isSelected: state.filterPreset == DateFilterPreset.thisMonth,
            onTap: () => vm.setFilterPreset(DateFilterPreset.thisMonth),
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _filterChip(
            label: 'Tháng trước',
            isSelected: state.filterPreset == DateFilterPreset.lastMonth,
            onTap: () => vm.setFilterPreset(DateFilterPreset.lastMonth),
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _filterChip(
            label: '7 ngày qua',
            isSelected: state.filterPreset == DateFilterPreset.last7Days,
            onTap: () => vm.setFilterPreset(DateFilterPreset.last7Days),
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _filterChip(
            label: 'Tất cả',
            isSelected: state.filterPreset == DateFilterPreset.all,
            onTap: () => vm.setFilterPreset(DateFilterPreset.all),
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _filterChip(
            label: state.filterPreset == DateFilterPreset.custom &&
                    state.fromDate != null &&
                    state.toDate != null
                ? '${DateFormat('dd/MM').format(state.fromDate!)} - ${DateFormat('dd/MM').format(state.toDate!)}'
                : 'Tùy chọn...',
            isSelected: state.filterPreset == DateFilterPreset.custom,
            icon: Icons.date_range_rounded,
            onTap: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2025),
                lastDate: DateTime.now().add(const Duration(days: 1)),
                initialDateRange: state.fromDate != null && state.toDate != null
                    ? DateTimeRange(start: state.fromDate!, end: state.toDate!)
                    : null,
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                            primary: const Color(0xFF0D9488),
                          ),
                    ),
                    child: child!,
                  );
                },
              );
              if (range != null) {
                vm.setCustomDateRange(range.start, range.end);
              }
            },
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    IconData? icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0D9488)
              : (isDark ? AppColors.darkSurfaceContainer : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0D9488)
                : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF064E3B).withValues(alpha: 0.3)
            : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF059669).withValues(alpha: 0.3) : const Color(0xFFBBF7D0),
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFF10B981),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Quãng đường đo theo đường bộ xe máy từ mốc Chấm công vào qua các điểm bán và DỪNG ở điểm bán cuối. Hệ thống tự động tính lúc 01:30 mỗi đêm.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF166534),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(
      String error, bool isDark, TravelViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 20, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => vm.loadMyTravel(refresh: true),
            child: const Text('Thử lại', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
