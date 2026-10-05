import 'package:flutter/material.dart';
import '../../domain/entities/daily_activity_entity.dart';
import 'activity_detail_sheet.dart';

/// Card dòng thời gian hoạt động trong ngày (Daily Activity Timeline)
class DailyActivityTimelineCard extends StatelessWidget {
  final List<DailyActivityEntity> activities;
  final String title;
  final bool showHeader;

  const DailyActivityTimelineCard({
    super.key,
    required this.activities,
    this.title = 'Dòng thời gian hoạt động',
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (activities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
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
              Icon(
                Icons.event_note_outlined,
                size: 40,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
              const SizedBox(height: 8),
              Text(
                'Chưa có hoạt động nào trong ngày',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : const Color(0xFF6F7A74),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2420) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E7E2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Row(
              children: [
                const Icon(
                  Icons.timeline_rounded,
                  size: 20,
                  color: Color(0xFF006E15),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF006E15).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${activities.length} hoạt động',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF006E15),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 14),
          ],
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final item = activities[index];
              final isLast = index == activities.length - 1;

              return InkWell(
                onTap: () => ActivityDetailSheet.show(context, item),
                borderRadius: BorderRadius.circular(12),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cột nút điểm & đường nối dọc
                      SizedBox(
                        width: 24,
                        child: Column(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: _getNodeColor(item.type),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF1E2420)
                                      : Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _getNodeColor(item.type).withValues(alpha: 0.4),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 2,
                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                  color: isDark
                                      ? Colors.white12
                                      : const Color(0xFFDEE5D8),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Nội dung hoạt động
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    item.time,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white60 : const Color(0xFF6F7A74),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (item.photos.isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF006E15).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.camera_alt_rounded, size: 10, color: Color(0xFF006E15)),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${item.photos.length} ảnh',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF006E15),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF181C1B),
                                ),
                              ),
                              if (item.subtitle.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : const Color(0xFF6F7A74),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: isDark ? Colors.white38 : Colors.black26,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getNodeColor(DailyActivityType type) {
    switch (type) {
      case DailyActivityType.attendanceIn:
      case DailyActivityType.attendanceOut:
        return const Color(0xFFD97706);
      case DailyActivityType.checkIn:
        return const Color(0xFF006E15);
      case DailyActivityType.checkOut:
        return const Color(0xFF10B981);
      case DailyActivityType.positionDeclaration:
        return const Color(0xFF0D9488);
      case DailyActivityType.formSubmission:
        return const Color(0xFF4F46E5);
    }
  }
}
