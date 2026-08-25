import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/route_entity.dart';

class RouteHeaderCard extends ConsumerWidget {
  final RouteDetailEntity route;

  const RouteHeaderCard({super.key, required this.route});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = ref.watch(stringsProvider);

    final completedText = strings.isVietnamese ? 'hoàn thành' : 'completed';
    final remainingText = strings.isVietnamese ? 'còn lại' : 'remaining';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            route.title,
            style: AppTypography.titleLarge(
              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.routeProgress.toUpperCase(),
                    style: AppTypography.labelSmall(
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                    ).copyWith(letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 2),
                  RichText(
                    text: TextSpan(
                      text: '${route.totalDealers} ${strings.stopsUnit} • ',
                      style: AppTypography.bodyMedium(
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ),
                      children: [
                        TextSpan(
                          text: '${route.completedDealers} $completedText',
                          style: AppTypography.bodyMedium(
                            color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: ' • ${route.pendingDealers} $remainingText',
                          style: AppTypography.bodyMedium(
                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                '${(route.progressPercent * 100).toInt()}%',
                style: AppTypography.titleMedium(
                  color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: AppRadius.roundedFull,
            child: LinearProgressIndicator(
              value: route.progressPercent,
              minHeight: 8,
              backgroundColor: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceVariant,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
