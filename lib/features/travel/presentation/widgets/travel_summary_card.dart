import 'package:flutter/material.dart';
import '../states/travel_state.dart';

/// Card tổng quan thống kê quãng đường với thiết kế gradient thanh lịch
class TravelSummaryCard extends StatelessWidget {
  final TravelState state;

  const TravelSummaryCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF064E3B), // Deep Emerald
                  const Color(0xFF0F766E), // Deep Teal
                ]
              : [
                  const Color(0xFF0D9488), // Teal 600
                  const Color(0xFF059669), // Emerald 600
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.two_wheeler_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'TỔNG QUÃNG ĐƯỜNG ĐÃ CHỐT',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${state.completedDaysCount}/${state.totalDays} ngày đã chốt',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Con số chính: Tổng km đã chốt
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  state.totalFinalizedKm.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'km',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (state.totalPendingKm > 0) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '+${state.totalPendingKm.toStringAsFixed(1)} km tạm tính',
                      style: const TextStyle(
                        color: Color(0xFFFEF08A),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 14),

            // Các chỉ số phụ
            Row(
              children: [
                // Chỉ số 1: Chặng thiếu mốc
                Expanded(
                  child: _MiniMetric(
                    icon: Icons.warning_amber_rounded,
                    iconColor: const Color(0xFFFDE68A),
                    title: 'Thiếu mốc (0 km)',
                    value: '${state.totalMissingAnchorsCount} chặng',
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: Colors.white24,
                ),
                // Chỉ số 2: Chặng chưa tính
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: _MiniMetric(
                      icon: Icons.schedule_rounded,
                      iconColor: const Color(0xFF93C5FD),
                      title: 'Chờ tính đêm',
                      value: '${state.totalErrorLegsCount} chặng',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  const _MiniMetric({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
