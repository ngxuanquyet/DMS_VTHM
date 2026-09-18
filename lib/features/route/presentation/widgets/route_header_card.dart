import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/route_entity.dart';
import '../viewmodels/route_view_model.dart';

class RouteHeaderCard extends ConsumerWidget {
  final RouteDetailEntity route;

  const RouteHeaderCard({super.key, required this.route});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = ref.watch(stringsProvider);
    final routeState = ref.watch(routeViewModelProvider);
    final vm = ref.read(routeViewModelProvider.notifier);

    final completedText = strings.isVietnamese ? 'hoàn thành' : 'completed';
    final remainingText = strings.isVietnamese ? 'còn lại' : 'remaining';
    final pointsText = strings.isVietnamese ? 'điểm' : 'stops';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkOutlineVariant : const Color(0xFFE0E3E0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route Title
          Text(
            route.title,
            style: AppTypography.titleLarge(
              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
            ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
          ),

          // Route switcher chips if user has multiple routes
          if (routeState.availableRoutes.length > 1) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: routeState.availableRoutes.map((r) {
                  final isSelected = r == routeState.selectedRoute;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => vm.selectRoute(r),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? AppColors.primaryContainer : const Color(0xFFEFF6E8))
                              : (isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHigh),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? (isDark ? AppColors.primaryContainer : const Color(0xFFBECAB7))
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          r,
                          style: TextStyle(
                            color: isSelected
                                ? (isDark ? Colors.white : AppColors.primary)
                                : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Progress statistics row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TIẾN ĐỘ',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: isDark ? AppColors.darkOnSurfaceVariant : const Color(0xFF3F4A3B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  RichText(
                    text: TextSpan(
                      text: '${route.totalDealers} $pointsText • ',
                      style: AppTypography.bodyMedium(
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ).copyWith(fontSize: 13),
                      children: [
                        TextSpan(
                          text: '${route.completedDealers} $completedText',
                          style: TextStyle(
                            color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: ' • ${route.pendingDealers} $remainingText',
                          style: TextStyle(
                            color: isDark ? AppColors.darkOnSurfaceVariant : const Color(0xFF3F4A3B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                '${(route.progressPercent * 100).toInt()}%',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: route.progressPercent,
              minHeight: 8,
              backgroundColor: isDark ? AppColors.darkSurfaceContainer : const Color(0xFFE0E3E0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF47B347)),
            ),
          ),
        ],
      ),
    );
  }
}
