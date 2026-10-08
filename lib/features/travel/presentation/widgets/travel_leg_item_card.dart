import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/travel_leg_entity.dart';

/// Card hiển thị từng chặng di chuyển trong ngày
/// Tuân thủ quy tắc §3 & §4.2 API-QUANG-DUONG-MOBILE-2026-10-08.md
class TravelLegItemCard extends StatelessWidget {
  final TravelLegEntity leg;
  final bool isLast;

  const TravelLegItemCard({
    super.key,
    required this.leg,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isStart = leg.legKind == 'start';
    final distanceText = leg.displayDistance;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hàng 1: Thứ tự chặng, loại chặng, và badge trạng thái từ server
            Row(
              children: [
                // Thứ tự chặng (#1, #2...)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isStart
                        ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF))
                        : (isDark ? const Color(0xFF14532D) : const Color(0xFFF0FDF4)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isStart
                          ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE))
                          : (isDark ? const Color(0xFF22C55E) : const Color(0xFFBBF7D0)),
                      width: 0.8,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '#${leg.seq}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isStart
                            ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))
                            : (isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Nhãn loại chặng từ server (leg_kind_label)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        leg.legKindLabel.isNotEmpty
                            ? leg.legKindLabel
                            : (isStart ? 'Chấm công vào → Điểm bán đầu tiên' : 'Giữa hai điểm bán'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isStart ? 'Chặng khởi đầu ngày' : 'Chặng di chuyển bán hàng',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Badge trạng thái dùng status_label và status_color của server (§4.2)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: leg.statusBackgroundColorValue,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: leg.statusColorValue.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    leg.statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: leg.statusColorValue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 0.6),
            const SizedBox(height: 12),

            // Hàng 2: Con số quãng đường theo 3 trạng thái (§3)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Bên trái: Khoảng cách đường bộ
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quãng đường đường bộ:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          distanceText,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: leg.isOk || leg.isSkippedShort
                                ? (isDark ? const Color(0xFF34D399) : const Color(0xFF0D9488))
                                : leg.isMissingAnchor
                                    ? const Color(0xFFDC2626)
                                    : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                          ),
                        ),
                        if (leg.isMissingAnchor) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Thiếu mốc',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ] else if (leg.isPending || leg.isProviderError) ...[
                          const SizedBox(width: 8),
                          Text(
                            '(chờ tác vụ đêm tính)',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                // Bên phải: Đường chim bay đối chứng (nếu có)
                if (leg.displayHaversineKm != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Chim bay đối chứng',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        leg.displayHaversineKm!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // Chú ý: Tuyệt đối KHÔNG hiển thị leg.errorNote cho nhân viên theo §4.2
          ],
        ),
      ),
    );
  }
}
