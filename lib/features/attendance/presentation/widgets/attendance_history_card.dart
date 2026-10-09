import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/attendance_entity.dart';
import '../viewmodels/attendance_view_model.dart';
import 'attendance_photo_capture_dialog.dart';
import 'attendance_photo_viewer_dialog.dart';

class AttendanceHistoryCard extends ConsumerWidget {
  final List<AttendancePunchEntity> history;

  const AttendanceHistoryCard({super.key, required this.history});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedDays = ref.watch(attendanceViewModelProvider.select((s) => s.selectedDays));
    final vm = ref.read(attendanceViewModelProvider.notifier);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + Filters
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    color: AppColors.secondary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Lịch sử chấm công',
                    style: AppTypography.titleMedium(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              // Day filter pills: 7d | 14d | 30d (§5)
              Row(
                children: [7, 14, 30].map((days) {
                  final isSelected = selectedDays == days;
                  return Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: InkWell(
                      onTap: () => vm.setHistoryDays(days),
                      borderRadius: AppRadius.roundedSm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
            ],
          ),
          const SizedBox(height: 14),

          if (history.isEmpty)
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
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = history[index];
                final isSatisfied = item.requirements.satisfied;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surface,
                    borderRadius: AppRadius.roundedMd,
                    border: Border(
                      left: BorderSide(
                        color: isSatisfied ? AppColors.primary : AppColors.secondary,
                        width: 3.5,
                      ),
                      top: BorderSide(
                        color: isDark ? AppColors.darkOutlineVariant : AppColors.surfaceVariant,
                      ),
                      right: BorderSide(
                        color: isDark ? AppColors.darkOutlineVariant : AppColors.surfaceVariant,
                      ),
                      bottom: BorderSide(
                        color: isDark ? AppColors.darkOutlineVariant : AppColors.surfaceVariant,
                      ),
                    ),
                  ),
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
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : AppColors.secondary.withValues(alpha: 0.15),
                              borderRadius: AppRadius.roundedSm,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSatisfied ? Icons.check_circle_rounded : Icons.camera_alt_outlined,
                                  size: 13,
                                  color: isSatisfied ? AppColors.primary : AppColors.secondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isSatisfied
                                      ? 'Đủ ảnh (${item.photos.length})'
                                      : 'Thiếu ảnh (${item.photos.length}/${item.requirements.minPhotos})',
                                  style: AppTypography.labelSmall(
                                    color: isSatisfied ? AppColors.primary : AppColors.secondary,
                                  ).copyWith(fontWeight: FontWeight.w600, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Cờ cảnh báo nếu có (§7)
                      if (item.isTimeTampered || item.isMockLocation || item.isOutsideGeofence) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (item.isTimeTampered)
                              _flagBadge('Giờ lệch (>15p)', AppColors.error),
                            if (item.isMockLocation)
                              _flagBadge('GPS giả lập', AppColors.secondary),
                            if (item.isOutsideGeofence)
                              _flagBadge('Ngoài vùng', AppColors.error),
                          ],
                        ),
                      ],

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
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _flagBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.roundedSm,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _directionBadge(String? direction, String label) {
    // Hiển thị nguyên văn direction_label từ server (§1 & §5 SPEC-2026-10-06)
    final isOut = label == 'Ra' || direction == 'out';
    final isMid = label == 'Giữa ca' || direction == 'mid';
    final isNone = label == '—' || direction == null;

    final Color badgeBg;
    final Color textColor;

    if (isOut) {
      badgeBg = Colors.orange.withValues(alpha: 0.15);
      textColor = Colors.orange.shade800;
    } else if (isMid) {
      badgeBg = Colors.blue.withValues(alpha: 0.15);
      textColor = Colors.blue.shade800;
    } else if (isNone) {
      badgeBg = AppColors.surfaceVariant;
      textColor = AppColors.outline;
    } else {
      badgeBg = AppColors.primary.withValues(alpha: 0.12);
      textColor = AppColors.primary;
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
