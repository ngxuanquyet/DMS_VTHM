import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/map/goong_models.dart';
import '../../../../core/map/goong_static_map.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/workplace_location.dart';

class AttendanceOutOfRangeDialog extends StatelessWidget {
  final WorkplaceLocation workplace;
  final GoongLatLng userPoint;
  final double distanceMeters;
  final double maxAllowedMeters;

  const AttendanceOutOfRangeDialog({
    super.key,
    required this.workplace,
    required this.userPoint,
    required this.distanceMeters,
    this.maxAllowedMeters = 100.0,
  });

  static Future<void> show(
    BuildContext context, {
    required WorkplaceLocation workplace,
    required GoongLatLng userPoint,
    required double distanceMeters,
    double maxAllowedMeters = 100.0,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => AttendanceOutOfRangeDialog(
        workplace: workplace,
        userPoint: userPoint,
        distanceMeters: distanceMeters,
        maxAllowedMeters: maxAllowedMeters,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final numberFormat = NumberFormat('#,###', 'vi_VN');

    final distanceStr = distanceMeters >= 1000
        ? '${(distanceMeters / 1000).toStringAsFixed(1)} km (${numberFormat.format(distanceMeters.round())} m)'
        : '${numberFormat.format(distanceMeters.round())} m';

    final excessMeters = (distanceMeters - maxAllowedMeters).clamp(0, double.infinity);
    final excessStr = excessMeters >= 1000
        ? '${(excessMeters / 1000).toStringAsFixed(1)} km (${numberFormat.format(excessMeters.round())} m)'
        : '${numberFormat.format(excessMeters.round())} m';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceContainer
              : AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.roundedXl,
          boxShadow: AppShadows.level3,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.errorContainer.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.wrong_location_rounded,
                    color: AppColors.error,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                'Ngoài phạm vi chấm công',
                textAlign: TextAlign.center,
                style: AppTypography.headlineSmall(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),

              // Workplace Target Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceContainer
                      : AppColors.surfaceContainerHigh,
                  borderRadius: AppRadius.roundedFull,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.apartment_rounded,
                      size: 15,
                      color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      workplace.name,
                      style: AppTypography.labelLarge(
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Route Map Preview (Goong Static Route Map with highlighted road path)
              Container(
                height: 175,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.roundedLg,
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkOutlineVariant
                        : AppColors.outlineVariant,
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GoongStaticMap(
                      center: userPoint,
                      destination: workplace.toGoongLatLng,
                      width: 500,
                      height: 300,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        color: AppColors.surfaceContainerHigh,
                        child: const Center(
                          child: Icon(
                            Icons.map_outlined,
                            size: 40,
                            color: AppColors.outline,
                          ),
                        ),
                      ),
                    ),
                    // Direction Overlay Pill
                    Positioned(
                      bottom: 8,
                      left: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: AppRadius.roundedSm,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.my_location_rounded,
                              color: Colors.greenAccent,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Vị trí của bạn',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white70,
                              size: 13,
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.place_rounded,
                              color: Colors.redAccent,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                workplace.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Distance Stats Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer.withValues(alpha: 0.18),
                  borderRadius: AppRadius.roundedMd,
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Khoảng cách hiện tại:',
                          style: AppTypography.bodySmall(
                            color: isDark
                                ? AppColors.darkOnSurfaceVariant
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          distanceStr,
                          style: AppTypography.bodyMedium(
                            color: AppColors.error,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bán kính tối đa cho phép:',
                          style: AppTypography.bodySmall(
                            color: isDark
                                ? AppColors.darkOnSurfaceVariant
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '≤ ${maxAllowedMeters.round()} m',
                          style: AppTypography.bodyMedium(
                            color: isDark
                                ? AppColors.primaryFixedDim
                                : AppColors.primary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Divider(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cách địa điểm hợp lệ:',
                          style: AppTypography.bodySmall(
                            color: isDark
                                ? AppColors.darkOnSurface
                                : AppColors.onSurface,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          excessStr,
                          style: AppTypography.bodyLarge(
                            color: AppColors.error,
                          ).copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Explanation note
              Text(
                'Quy định yêu cầu nhân viên phải có mặt trong bán kính ≤ ${maxAllowedMeters.round()}m quanh vị trí làm việc để ghi nhận chấm công.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall(
                  color: isDark
                      ? AppColors.darkOnSurfaceVariant
                      : AppColors.onSurfaceVariant,
                ).copyWith(height: 1.35),
              ),
              const SizedBox(height: 18),

              // Action button
              AppButton(
                text: 'ĐÃ HIỂU',
                width: double.infinity,
                height: 46,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
