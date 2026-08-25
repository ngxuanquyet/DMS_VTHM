import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/entities/attendance_entity.dart';

class AttendanceHistoryCard extends ConsumerWidget {
  final List<AttendanceHistoryItemEntity> history;

  const AttendanceHistoryCard({super.key, required this.history});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = ref.watch(stringsProvider);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    strings.recentHistory,
                    style: AppTypography.titleMedium(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Text(
                strings.viewAll,
                style: AppTypography.labelSmall(
                  color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = history[index];
              final statusText = item.isLate
                  ? (strings.isVietnamese ? item.status : strings.late)
                  : (strings.isVietnamese ? item.status : strings.onTime);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surface,
                  borderRadius: AppRadius.roundedMd,
                  border: Border(
                    left: BorderSide(
                      color: item.isLate ? AppColors.error : AppColors.primary,
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.date,
                          style: AppTypography.titleMedium(
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.timeRange,
                          style: AppTypography.bodyMedium(
                            color: isDark
                                ? AppColors.darkOnSurfaceVariant
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    StatusBadge(
                      label: statusText,
                      type: item.isLate ? StatusBadgeType.error : StatusBadgeType.success,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
