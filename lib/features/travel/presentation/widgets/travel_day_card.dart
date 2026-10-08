import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/travel_day_entity.dart';

/// Card hiển thị quãng đường của 1 ngày công
/// Tuân thủ quy tắc §3 & §4.1 API-QUANG-DUONG-MOBILE-2026-10-08.md
class TravelDayCard extends StatelessWidget {
  final TravelDayEntity day;
  final VoidCallback onTap;

  const TravelDayCard({
    super.key,
    required this.day,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isFinalized = day.isComplete;
    final hasPending = day.legErrorCount > 0;
    final hasMissing = day.legMissingCount > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: isDark ? 0 : 1,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? (isFinalized ? Colors.white12 : const Color(0xFFD97706).withValues(alpha: 0.3))
                    : (isFinalized ? const Color(0xFFE2E8F0) : const Color(0xFFFDE68A)),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hàng 1: Ngày tháng & Badge trạng thái
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceContainer
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.calendar_today_rounded,
                            size: 15,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          day.formattedWorkDate,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    // Badge trạng thái ngày công
                    if (isFinalized)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF86EFAC), width: 0.8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF16A34A)),
                            SizedBox(width: 4),
                            Text(
                              'Đã chốt',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.hourglass_top_rounded, size: 12, color: Color(0xFFD97706)),
                            const SizedBox(width: 4),
                            Text(
                              'Chưa chốt (${day.legErrorCount} chặng chờ)',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Hàng 2: Con số quãng đường & Số lượng chặng
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Cột số km (Làm mờ hoặc ghi chú tạm tính nếu chưa chốt - §4.1)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isFinalized ? 'Quãng đường đường bộ' : 'Quãng đường tạm tính',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                day.kmOnlyText,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: isFinalized
                                      ? (isDark ? const Color(0xFF34D399) : const Color(0xFF0D9488))
                                      : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                                ),
                              ),
                              if (!isFinalized) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '(tạm tính)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Cột tổng chặng
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceContainer
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timeline_rounded,
                            size: 14,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${day.legCount} chặng',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Hàng 3: Cảnh báo chi tiết chặng thiếu mốc / chặng lỗi tách biệt (§4.1)
                if (hasMissing || hasPending) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, thickness: 0.8),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (hasMissing)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.info_outline_rounded, size: 12, color: Color(0xFFD97706)),
                              const SizedBox(width: 4),
                              Text(
                                '${day.legMissingCount} chặng thiếu mốc (0 km)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (hasPending)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                'Còn ${day.legErrorCount} chặng chưa tính',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
