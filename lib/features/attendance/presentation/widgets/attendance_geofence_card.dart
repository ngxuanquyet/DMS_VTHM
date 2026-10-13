import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/attendance_entity.dart';
import '../viewmodels/attendance_view_model.dart';

class AttendanceGeofenceCard extends ConsumerWidget {
  const AttendanceGeofenceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = ref.watch(attendanceViewModelProvider.select((s) => s.config));
    final activeLocation = ref.watch(attendanceViewModelProvider.select((s) => s.activeLocation));
    final vm = ref.read(attendanceViewModelProvider.notifier);
    final numberFormat = NumberFormat('#,###', 'vi_VN');

    if (config == null) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Đang tải cấu hình địa điểm chấm công...',
              style: AppTypography.bodyMedium(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // 🔴 TRƯỜNG HỢP 1: Tài khoản chưa có mã nhân viên (§1.2)
    if (!config.canPunch) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        decoration: BoxDecoration(
          color: AppColors.errorContainer.withValues(alpha: 0.25),
          borderRadius: AppRadius.roundedLg,
          border: Border.all(color: AppColors.error, width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.block_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Không thể chấm công',
                    style: AppTypography.titleMedium(color: AppColors.error).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    config.blockedReason ??
                        'Tài khoản của bạn chưa có mã nhân viên — liên hệ nhân sự để chấm công được.',
                    style: AppTypography.bodyMedium(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 🔴 TRƯỜNG HỢP 2: Chưa khai địa điểm chấm công nào (§0 & §2)
    if (config.locations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.12),
          borderRadius: AppRadius.roundedLg,
          border: Border.all(color: AppColors.secondary, width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_off_rounded, color: AppColors.secondary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chưa khai địa điểm chấm công',
                    style: AppTypography.titleMedium(color: AppColors.secondary).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chưa khai địa điểm chấm công nào — liên hệ nhân sự trước khi chấm công bằng app.',
                    style: AppTypography.bodyMedium(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Quản trị viên cần khai báo địa điểm tại mục Chấm công → Địa điểm chấm công trên One Portal.',
                    style: AppTypography.bodySmall(
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 🔴 TRƯỜNG HỢP 3: Có danh sách địa điểm - Giao diện tinh gọn với 1 nút xem danh sách sắp xếp theo khoảng cách
    final closest = config.closestLocation;
    final selected = activeLocation ?? closest ?? config.locations.first;

    // Sắp xếp danh sách địa điểm theo khoảng cách tăng dần (gần nhất lên đầu)
    final sortedLocations = _sortLocationsByDistance(config.locations);

    final isSelectedValid = selected.isWithinRadius || selected.isEverywhere;
    final distanceText = _formatDistanceText(selected, numberFormat);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Tiêu đề + Nút "Đổi địa điểm"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      color: AppColors.primary,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Địa điểm chấm công',
                        style: AppTypography.titleMedium(
                          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${config.group.name} (${config.locations.length} điểm)',
                        style: AppTypography.bodySmall(
                          color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Nút bấm duy nhất để xem toàn bộ danh sách sắp xếp theo khoảng cách
              if (config.locations.length > 1)
                InkWell(
                  onTap: () => _showLocationPickerBottomSheet(
                    context,
                    sortedLocations: sortedLocations,
                    selected: selected,
                    closest: closest,
                    vm: vm,
                    numberFormat: numberFormat,
                    isDark: isDark,
                  ),
                  borderRadius: AppRadius.roundedSm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: AppRadius.roundedSm,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.format_list_bulleted_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Đổi địa điểm',
                          style: AppTypography.labelSmall(
                            color: AppColors.primary,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Thẻ hiển thị địa điểm đang chọn (bấm vào cũng mở danh sách chọn)
          InkWell(
            onTap: config.locations.length > 1
                ? () => _showLocationPickerBottomSheet(
                      context,
                      sortedLocations: sortedLocations,
                      selected: selected,
                      closest: closest,
                      vm: vm,
                      numberFormat: numberFormat,
                      isDark: isDark,
                    )
                : null,
            borderRadius: AppRadius.roundedMd,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelectedValid
                    ? (isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surface)
                    : (isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surface),
                borderRadius: AppRadius.roundedMd,
                border: Border.all(
                  color: isSelectedValid
                      ? const Color(0xFF10B981).withValues(alpha: 0.6)
                      : AppColors.error.withValues(alpha: 0.6),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isSelectedValid
                          ? const Color(0xFF10B981).withValues(alpha: 0.12)
                          : AppColors.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      selected.isEverywhere
                          ? Icons.public_rounded
                          : (isSelectedValid ? Icons.check_circle_rounded : Icons.location_on_rounded),
                      color: isSelectedValid ? const Color(0xFF10B981) : AppColors.error,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                selected.name,
                                style: AppTypography.titleMedium(
                                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                ).copyWith(fontWeight: FontWeight.w700, fontSize: 14.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (selected.id == closest?.id) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: AppRadius.roundedSm,
                                ),
                                child: const Text(
                                  'Gần nhất',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          distanceText,
                          style: AppTypography.bodySmall(
                            color: isSelectedValid
                                ? (isDark ? AppColors.primaryFixedDim : AppColors.primary)
                                : AppColors.error,
                          ).copyWith(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  if (config.locations.length > 1) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Quy định geofence
          Row(
            children: [
              Icon(
                config.group.enforceGeofence ? Icons.security_rounded : Icons.info_outline_rounded,
                size: 14,
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  config.group.enforceGeofence
                      ? 'Quy định: Bắt buộc đứng trong bán kính địa điểm chấm công.'
                      : 'Quy định: Không bắt buộc geofence.',
                  style: AppTypography.bodySmall(
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Sắp xếp danh sách địa điểm theo khoảng cách từ gần đến xa
  static List<AttendanceLocationItemEntity> _sortLocationsByDistance(
    List<AttendanceLocationItemEntity> locations,
  ) {
    final sorted = List<AttendanceLocationItemEntity>.from(locations);
    sorted.sort((a, b) {
      final distA = a.distanceM;
      final distB = b.distanceM;

      // 1. So sánh khoảng cách tính bằng mét
      if (distA != null && distB != null) {
        return distA.compareTo(distB);
      }
      if (distA != null && distB == null) return -1;
      if (distA == null && distB != null) return 1;

      // 2. Nếu cùng null (vd: Mọi nơi), ưu tiên Mọi nơi
      if (a.isEverywhere && !b.isEverywhere) return -1;
      if (!a.isEverywhere && b.isEverywhere) return 1;

      return a.name.compareTo(b.name);
    });
    return sorted;
  }

  /// Định dạng chuỗi khoảng cách hiển thị
  static String _formatDistanceText(
    AttendanceLocationItemEntity location,
    NumberFormat numberFormat,
  ) {
    if (location.isEverywhere) {
      return location.kindLabel.isNotEmpty
          ? '${location.kindLabel} (Không ràng buộc vị trí - Hợp lệ)'
          : 'Mọi nơi (Không ràng buộc vị trí - Hợp lệ)';
    }
    if (location.distanceM == null) {
      return 'Đang xác định khoảng cách...';
    }
    if (location.isWithinRadius) {
      return 'Cách ${location.distanceM}m · Trong bán kính ${location.radiusM}m (Hợp lệ)';
    }
    if (location.distanceM! >= 1000) {
      return 'Cách ${(location.distanceM! / 1000).toStringAsFixed(1)}km (${numberFormat.format(location.distanceM)}m) · Ngoài bán kính ${location.radiusM}m';
    }
    return 'Cách ${location.distanceM}m · Ngoài bán kính ${location.radiusM}m';
  }

  /// Hiển thị Modal BottomSheet danh sách địa điểm được sắp xếp theo khoảng cách
  void _showLocationPickerBottomSheet(
    BuildContext context, {
    required List<AttendanceLocationItemEntity> sortedLocations,
    required AttendanceLocationItemEntity selected,
    required AttendanceLocationItemEntity? closest,
    required AttendanceViewModel vm,
    required NumberFormat numberFormat,
    required bool isDark,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chọn địa điểm chấm công',
                            style: AppTypography.titleMedium(
                              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.sort_rounded,
                                size: 13,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Đã sắp xếp theo khoảng cách gần nhất (${sortedLocations.length} địa điểm)',
                                  style: AppTypography.bodySmall(
                                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                                  ).copyWith(fontSize: 11.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Danh sách địa điểm đã sắp xếp theo khoảng cách
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: sortedLocations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final loc = sortedLocations[index];
                      final isCurrentSelected = loc.id == selected.id;
                      final isClosestLoc = loc.id == closest?.id;
                      final isValid = loc.isWithinRadius || loc.isEverywhere;
                      final distLabel = _formatDistanceText(loc, numberFormat);

                      return InkWell(
                        onTap: () {
                          vm.selectLocation(loc);
                          Navigator.pop(ctx);
                        },
                        borderRadius: AppRadius.roundedMd,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isCurrentSelected
                                ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08)
                                : (isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceVariant.withValues(alpha: 0.3)),
                            borderRadius: AppRadius.roundedMd,
                            border: Border.all(
                              color: isCurrentSelected
                                  ? AppColors.primary
                                  : (isDark ? AppColors.darkOutlineVariant.withValues(alpha: 0.4) : Colors.transparent),
                              width: isCurrentSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isCurrentSelected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                color: isCurrentSelected ? AppColors.primary : AppColors.outline,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            loc.name,
                                            style: AppTypography.titleMedium(
                                              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                            ).copyWith(
                                              fontWeight: isCurrentSelected ? FontWeight.w700 : FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isClosestLoc) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                              borderRadius: AppRadius.roundedSm,
                                            ),
                                            child: const Text(
                                              'Gần nhất',
                                              style: TextStyle(
                                                color: Color(0xFF10B981),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (isCurrentSelected) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius: AppRadius.roundedSm,
                                            ),
                                            child: const Text(
                                              'Đang chọn',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(
                                          loc.isEverywhere
                                              ? Icons.public_rounded
                                              : (isValid ? Icons.check_circle_rounded : Icons.location_on_rounded),
                                          size: 13,
                                          color: isValid ? const Color(0xFF10B981) : AppColors.error,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            distLabel,
                                            style: AppTypography.bodySmall(
                                              color: isValid
                                                  ? (isDark ? AppColors.primaryFixedDim : AppColors.primary)
                                                  : AppColors.error,
                                            ).copyWith(fontSize: 12, fontWeight: FontWeight.w500),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
