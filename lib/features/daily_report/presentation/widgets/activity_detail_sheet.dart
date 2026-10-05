import 'package:flutter/material.dart';
import '../../domain/entities/daily_activity_entity.dart';

/// Bottom Sheet hiển thị chi tiết của một hoạt động trong ngày khi bấm vào timeline
class ActivityDetailSheet extends StatelessWidget {
  final DailyActivityEntity activity;

  const ActivityDetailSheet({super.key, required this.activity});

  static Future<void> show(BuildContext context, DailyActivityEntity activity) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ActivityDetailSheet(activity: activity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2420) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thanh kéo
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getTypeColor(activity.type).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getTypeIcon(activity.type),
                      color: _getTypeColor(activity.type),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Thời gian: ${activity.time}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : const Color(0xFF6F7A74),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: activity.isSynced
                          ? const Color(0xFF10B981).withValues(alpha: 0.12)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      activity.isSynced ? 'Đã đồng bộ' : 'Chờ đồng bộ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: activity.isSynced
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Thông tin chi tiết
              if (activity.customerName != null) ...[
                _DetailRow(
                  icon: Icons.storefront_rounded,
                  label: 'Điểm bán',
                  value: activity.customerName!,
                ),
                const SizedBox(height: 10),
              ],

              if (activity.customerAddress != null) ...[
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Địa chỉ',
                  value: activity.customerAddress!,
                ),
                const SizedBox(height: 10),
              ],

              if (activity.lat != null && activity.lng != null) ...[
                _DetailRow(
                  icon: Icons.my_location_rounded,
                  label: 'Toạ độ GPS',
                  value: '${activity.lat!.toStringAsFixed(6)}, ${activity.lng!.toStringAsFixed(6)} (±5m)',
                ),
                const SizedBox(height: 10),
              ],

              if (activity.notes != null && activity.notes!.isNotEmpty) ...[
                _DetailRow(
                  icon: Icons.notes_rounded,
                  label: 'Ghi chú',
                  value: activity.notes!,
                ),
                const SizedBox(height: 10),
              ],

              // Ảnh chụp nếu có
              if (activity.photos.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Hình ảnh thực địa (${activity.photos.length} ảnh đóng dấu):',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: activity.photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 90,
                          height: 90,
                          color: isDark ? Colors.white10 : Colors.black12,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                activity.photos[i],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.image_outlined, color: Colors.grey),
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                left: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Đóng dấu GPS',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
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
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(DailyActivityType type) {
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

  IconData _getTypeIcon(DailyActivityType type) {
    switch (type) {
      case DailyActivityType.attendanceIn:
      case DailyActivityType.attendanceOut:
        return Icons.access_time_filled_rounded;
      case DailyActivityType.checkIn:
        return Icons.login_rounded;
      case DailyActivityType.checkOut:
        return Icons.logout_rounded;
      case DailyActivityType.positionDeclaration:
        return Icons.location_on_rounded;
      case DailyActivityType.formSubmission:
        return Icons.assignment_turned_in_rounded;
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: isDark ? Colors.white60 : const Color(0xFF6F7A74)),
        const SizedBox(width: 10),
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
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
