import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/map/goong_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/workplace_location.dart';

final selectedWorkplaceProvider = StateProvider<WorkplaceLocation>((ref) {
  return kFixedWorkplaces.first;
});

class WorkplaceSelectionCard extends ConsumerWidget {
  const WorkplaceSelectionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = ref.watch(stringsProvider);
    final selectedWorkplace = ref.watch(selectedWorkplaceProvider);
    final livePointAsync = ref.watch(currentPointProvider);
    final livePoint = livePointAsync.value;

    double? distanceMeters;
    if (livePoint != null) {
      distanceMeters = Geolocator.distanceBetween(
        livePoint.lat,
        livePoint.lng,
        selectedWorkplace.lat,
        selectedWorkplace.lng,
      );
    }

    final isValid = distanceMeters != null && distanceMeters <= 100.0;
    final numberFormat = NumberFormat('#,###', 'vi_VN');

    final String distanceLabel;
    if (distanceMeters == null) {
      distanceLabel = 'Đang xác định khoảng cách...';
    } else if (isValid) {
      distanceLabel = 'Khoảng cách: ${distanceMeters.round()}m (Hợp lệ)';
    } else if (distanceMeters >= 1000) {
      distanceLabel =
          'Khoảng cách: ${(distanceMeters / 1000).toStringAsFixed(1)} km (${numberFormat.format(distanceMeters.round())}m - Ngoài phạm vi)';
    } else {
      distanceLabel =
          'Khoảng cách: ${distanceMeters.round()}m (Ngoài phạm vi)';
    }

    final Color statusColor = distanceMeters == null
        ? AppColors.secondary
        : (isValid ? AppColors.primary : AppColors.error);

    final Color statusBgColor = distanceMeters == null
        ? AppColors.secondary.withValues(alpha: 0.1)
        : (isValid
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.errorContainer.withValues(alpha: 0.2));

    final Color statusBorderColor = distanceMeters == null
        ? AppColors.secondary.withValues(alpha: 0.22)
        : (isValid
            ? AppColors.primary.withValues(alpha: 0.22)
            : AppColors.error.withValues(alpha: 0.25));

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
                  Icon(
                    Icons.domain_rounded,
                    color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    strings.workplaceSectionTitle,
                    style: AppTypography.titleMedium(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: AppRadius.roundedSm,
                ),
                child: Text(
                  strings.groupBadge,
                  style: AppTypography.labelSmall(
                    color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: isDark ? AppColors.darkOutlineVariant : AppColors.surfaceVariant,
          ),
          const SizedBox(height: 12),

          // Dropdown Label
          Row(
            children: [
              Icon(
                Icons.corporate_fare_rounded,
                size: 16,
                color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                strings.workplaceCompanyLabel,
                style: AppTypography.labelSmall(
                  color: isDark
                      ? AppColors.darkOnSurfaceVariant
                      : AppColors.onSurfaceVariant,
                ).copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Fixed Workplace Dropdown Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceContainerLowest
                  : AppColors.surface,
              borderRadius: AppRadius.roundedMd,
              border: Border.all(
                color: isDark
                    ? AppColors.darkOutlineVariant
                    : AppColors.outlineVariant,
                width: 1,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<WorkplaceLocation>(
                value: selectedWorkplace,
                isExpanded: true,
                dropdownColor: isDark
                    ? AppColors.darkSurfaceContainer
                    : AppColors.surfaceContainerLowest,
                icon: Icon(
                  Icons.arrow_drop_down_rounded,
                  color: isDark
                      ? AppColors.darkOnSurfaceVariant
                      : AppColors.onSurfaceVariant,
                ),
                items: kFixedWorkplaces.map((workplace) {
                  return DropdownMenuItem<WorkplaceLocation>(
                    value: workplace,
                    child: Text(
                      workplace.name,
                      style: AppTypography.bodyMedium(
                        color: isDark
                            ? AppColors.darkOnSurface
                            : AppColors.onSurface,
                      ).copyWith(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(selectedWorkplaceProvider.notifier).state = val;
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Distance Validation Box (Dynamic Geofence Status: ≤ 100m)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusBgColor,
              borderRadius: AppRadius.roundedMd,
              border: Border.all(
                color: statusBorderColor,
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  isValid ? Icons.verified_rounded : (distanceMeters == null ? Icons.radar_rounded : Icons.wrong_location_rounded),
                  color: isDark && isValid ? AppColors.primaryFixedDim : statusColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        distanceLabel,
                        style: AppTypography.labelSmall(
                          color: isDark && isValid
                              ? AppColors.primaryFixedDim
                              : statusColor,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Bán kính cho phép: ≤ 100m quanh vị trí làm việc',
                        style: AppTypography.bodySmall(
                          color: isDark
                              ? AppColors.darkOnSurfaceVariant
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
