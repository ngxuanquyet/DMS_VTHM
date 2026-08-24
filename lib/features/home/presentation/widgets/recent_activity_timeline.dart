import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/dashboard_entity.dart';

class RecentActivityTimeline extends StatelessWidget {
  final List<ActivityTimelineEntity> activities;

  const RecentActivityTimeline({super.key, required this.activities});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hoạt động gần đây',
            style: AppTypography.titleLarge(
              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final item = activities[index];
              final isLast = index == activities.length - 1;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Node + Vertical Line
                    SizedBox(
                      width: 24,
                      child: Column(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: item.isPrimary
                                  ? AppColors.primaryContainer
                                  : (isDark ? AppColors.darkOutline : AppColors.surfaceVariant),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkSurfaceContainer
                                    : AppColors.surfaceContainerLowest,
                                width: 2.5,
                              ),
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: isDark
                                    ? AppColors.darkOutlineVariant
                                    : AppColors.surfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.time,
                              style: AppTypography.labelSmall(
                                color: isDark
                                    ? AppColors.darkOnSurfaceVariant
                                    : AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            RichText(
                              text: TextSpan(
                                text: '${item.title} ',
                                style: AppTypography.bodyLarge(
                                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                ),
                                children: [
                                  if (item.highlight.isNotEmpty)
                                    TextSpan(
                                      text: '${item.highlight} ',
                                      style: AppTypography.bodyLarge(
                                        color: isDark
                                            ? AppColors.darkOnSurface
                                            : AppColors.onSurface,
                                      ).copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  if (item.suffix.isNotEmpty)
                                    TextSpan(
                                      text: item.suffix,
                                      style: AppTypography.bodyLarge(
                                        color: isDark
                                            ? AppColors.darkOnSurface
                                            : AppColors.onSurface,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
