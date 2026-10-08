import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../domain/entities/travel_day_entity.dart';
import '../viewmodels/travel_view_model.dart';
import '../widgets/travel_leg_item_card.dart';

/// Màn hình Chi tiết chặng di chuyển của 1 ngày công
/// Gọi GET /dms/travel/legs/{userId}/{workDate} (§4.2 & Checklist §7)
class TravelLegDetailScreen extends ConsumerStatefulWidget {
  final TravelDayEntity day;

  const TravelLegDetailScreen({
    super.key,
    required this.day,
  });

  @override
  ConsumerState<TravelLegDetailScreen> createState() =>
      _TravelLegDetailScreenState();
}

class _TravelLegDetailScreenState
    extends ConsumerState<TravelLegDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(travelViewModelProvider.notifier).loadLegsForDay(widget.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(travelViewModelProvider);
    final vm = ref.read(travelViewModelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final legs = state.currentDayLegs;
    final day = widget.day;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Chặng ngày ${day.workDate}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        foregroundColor: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tải lại chặng',
            onPressed: () => vm.loadLegsForDay(day, refresh: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => vm.loadLegsForDay(day, refresh: true),
        color: const Color(0xFF0D9488),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // 1. Thẻ tóm tắt thông tin ngày công
            _buildDayHeaderCard(day, isDark),
            const SizedBox(height: 16),

            // 2. Tiêu đề danh sách chặng
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DANH SÁCH CHẶNG (${legs.length})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  'Thứ tự theo mốc thời gian',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 3. Nội dung danh sách chặng
            if (state.isLoadingLegs)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: AppLoading()),
              )
            else if (state.errorMessage != null &&
                state.errorMessage!.isNotEmpty)
              _buildErrorBox(state.errorMessage!, vm, day)
            else if (legs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: AppEmptyState(
                  icon: Icons.alt_route_rounded,
                  title: 'Không có dữ liệu chặng',
                  description:
                      'Chưa ghi nhận chặng di chuyển nào cho ngày này.\nChặng được ghi nhận từ lượt chấm công và các lượt viếng thăm.',
                ),
              )
            else ...[
              ...List.generate(
                legs.length,
                (index) => TravelLegItemCard(
                  leg: legs[index],
                  isLast: index == legs.length - 1,
                ),
              ),
              const SizedBox(height: 8),

              // Ghi chú nghiệp vụ: Chuỗi dừng ở điểm bán cuối (§1)
              _buildLegRuleNote(isDark),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDayHeaderCard(TravelDayEntity day, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                day.formattedWorkDate,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              if (day.isComplete)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Đã chốt',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF15803D),
                    ),
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Còn ${day.legErrorCount} chặng chờ tính',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng đường bộ',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      day.displayKmText,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: day.isComplete
                            ? (isDark
                                ? const Color(0xFF34D399)
                                : const Color(0xFF0D9488))
                            : const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng số chặng',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${day.legCount} chặng',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegRuleNote(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainer
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.flag_rounded,
            size: 16,
            color: isDark ? Colors.white60 : const Color(0xFF64748B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '🔴 Chuỗi chặng DỪNG ở điểm bán cuối. Không tính đoạn đường từ điểm bán cuối về điểm chấm công ra theo quy định chi công tác phí.',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox(
      String error, TravelViewModel vm, TravelDayEntity day) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFDC2626), size: 28),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF991B1B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => vm.loadLegsForDay(day, refresh: true),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}
