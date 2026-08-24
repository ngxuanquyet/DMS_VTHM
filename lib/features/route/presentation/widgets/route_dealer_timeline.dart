import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/entities/route_entity.dart';

class RouteDealerTimeline extends StatelessWidget {
  final List<DealerEntity> dealers;

  const RouteDealerTimeline({super.key, required this.dealers});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: dealers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final dealer = dealers[index];
        final isLast = index == dealers.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Node + Timeline Line
              SizedBox(
                width: 32,
                child: Column(
                  children: [
                    _buildTimelineNode(dealer, isDark),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: isDark ? AppColors.darkOutlineVariant : AppColors.surfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Dealer Card
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: _buildDealerCard(context, dealer, isDark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimelineNode(DealerEntity dealer, bool isDark) {
    if (dealer.status == DealerVisitStatus.completed) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primaryContainer, width: 2),
        ),
        child: const Center(
          child: Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: AppColors.primaryContainer,
          ),
        ),
      );
    } else if (dealer.status == DealerVisitStatus.inProgress) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryContainer.withValues(alpha: 0.35),
              blurRadius: 8,
              spreadRadius: 2,
            )
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.radio_button_checked,
            size: 18,
            color: AppColors.onPrimary,
          ),
        ),
      );
    } else {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? AppColors.darkOutline : AppColors.outlineVariant,
            width: 2,
          ),
        ),
      );
    }
  }

  Widget _buildDealerCard(BuildContext context, DealerEntity dealer, bool isDark) {
    if (dealer.status == DealerVisitStatus.completed) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        onTap: () => context.push('/check-in'),
        child: Opacity(
          opacity: 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${dealer.order} - ${dealer.name}',
                      style: AppTypography.titleMedium(
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ).copyWith(
                        decoration: TextDecoration.lineThrough,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const StatusBadge(
                    label: 'Đã ghé',
                    type: StatusBadgeType.success,
                  ),
                ],
              ),
              if (dealer.visitedTime != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: AppColors.outline),
                    const SizedBox(width: 4),
                    Text(
                      dealer.visitedTime!,
                      style: AppTypography.bodyMedium(
                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    } else if (dealer.status == DealerVisitStatus.inProgress) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.roundedXl,
          border: Border.all(
            color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            )
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/check-in'),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: AppColors.primaryContainer),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.gutter),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${dealer.order} - ${dealer.name}',
                                  style: AppTypography.titleMedium(
                                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                  ).copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              const StatusBadge(
                                label: 'Chưa ghé',
                                type: StatusBadgeType.neutral,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.outline),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  dealer.address,
                                  style: AppTypography.bodyMedium(
                                    color: isDark
                                        ? AppColors.darkOnSurfaceVariant
                                        : AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          AppButton(
                            text: 'Chỉ đường',
                            height: 38,
                            icon: Icons.directions_outlined,
                            onPressed: () => context.push('/check-in'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        onTap: () => context.push('/check-in'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${dealer.order} - ${dealer.name}',
                    style: AppTypography.titleMedium(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const StatusBadge(
                  label: 'Chưa ghé',
                  type: StatusBadgeType.neutral,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.outline),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    dealer.address,
                    style: AppTypography.bodyMedium(
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
  }
}
