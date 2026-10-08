import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/attendance_entity.dart';
import '../viewmodels/attendance_view_model.dart';

class AttendanceGeofenceCard extends ConsumerStatefulWidget {
  const AttendanceGeofenceCard({super.key});

  @override
  ConsumerState<AttendanceGeofenceCard> createState() => _AttendanceGeofenceCardState();
}

class _AttendanceGeofenceCardState extends ConsumerState<AttendanceGeofenceCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = ref.watch(attendanceViewModelProvider.select((s) => s.config));
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

    // 🔴 TRƯỜNG HỢP 3: Có danh sách địa điểm (§2)
    final closest = config.closestLocation;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Địa điểm chấm công',
                        style: AppTypography.titleMedium(
                          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${config.group.name} (${config.locations.length} địa điểm)',
                        style: AppTypography.bodySmall(
                          color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (config.locations.length > 1)
                InkWell(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  borderRadius: AppRadius.roundedSm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isExpanded ? 'Thu gọn' : 'Xem tất cả',
                          style: AppTypography.labelSmall(color: AppColors.primary),
                        ),
                        Icon(
                          _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Địa điểm gần nhất
          if (closest != null)
            _buildLocationItem(
              location: closest,
              isClosest: true,
              numberFormat: numberFormat,
              isDark: isDark,
            ),

          // Danh sách các địa điểm khác nếu được mở rộng
          if (_isExpanded && config.locations.length > 1) ...[
            const SizedBox(height: 10),
            Divider(
              height: 1,
              color: isDark ? AppColors.darkOutlineVariant : AppColors.surfaceVariant,
            ),
            const SizedBox(height: 10),
            ...config.locations
                .where((loc) => loc.id != closest?.id)
                .map((loc) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: _buildLocationItem(
                        location: loc,
                        isClosest: false,
                        numberFormat: numberFormat,
                        isDark: isDark,
                      ),
                    )),
          ],

          const SizedBox(height: 10),

          // Bắt buộc geofence tag
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

  Widget _buildLocationItem({
    required AttendanceLocationItemEntity location,
    required bool isClosest,
    required NumberFormat numberFormat,
    required bool isDark,
  }) {
    final isEverywhere = location.isEverywhere;
    final isValid = location.isWithinRadius;
    final hasDistance = location.distanceM != null;

    final String distanceText;
    if (isEverywhere) {
      distanceText = location.kindLabel.isNotEmpty
          ? location.kindLabel
          : 'Mọi nơi (Không ràng buộc vị trí)';
    } else if (!hasDistance) {
      distanceText = 'Đang xác định khoảng cách...';
    } else if (isValid) {
      distanceText = 'Cách ${location.distanceM}m (Trong bán kính ${location.radiusM}m)';
    } else if (location.distanceM! >= 1000) {
      distanceText =
          'Cách ${(location.distanceM! / 1000).toStringAsFixed(1)}km (${numberFormat.format(location.distanceM)}m - Bán kính ${location.radiusM}m)';
    } else {
      distanceText =
          'Cách ${location.distanceM}m (Ngoài bán kính ${location.radiusM}m)';
    }

    final Color statusColor = (isEverywhere || isValid)
        ? AppColors.primary
        : (!hasDistance ? AppColors.secondary : AppColors.error);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surface,
        borderRadius: AppRadius.roundedMd,
        border: Border.all(
          color: (isEverywhere || isValid)
              ? AppColors.primary.withValues(alpha: 0.35)
              : (isDark ? AppColors.darkOutlineVariant : AppColors.surfaceVariant),
          width: (isEverywhere || isValid) ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isEverywhere
                ? Icons.public_rounded
                : (isValid ? Icons.check_circle_rounded : Icons.location_on_rounded),
            color: statusColor,
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
                        location.name,
                        style: AppTypography.titleMedium(
                          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                        ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                    if (isEverywhere)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: AppRadius.roundedSm,
                        ),
                        child: Text(
                          location.kindLabel.isNotEmpty ? location.kindLabel : 'Mọi nơi',
                          style: AppTypography.labelSmall(color: AppColors.primary).copyWith(fontSize: 10),
                        ),
                      )
                    else if (isClosest)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: AppRadius.roundedSm,
                        ),
                        child: Text(
                          'Gần nhất',
                          style: AppTypography.labelSmall(color: AppColors.primary).copyWith(fontSize: 10),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  distanceText,
                  style: AppTypography.bodySmall(
                    color: statusColor,
                  ).copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
