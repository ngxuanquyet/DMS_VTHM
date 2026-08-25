import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/dashboard_entity.dart';

class FormSummaryCard extends ConsumerWidget {
  final DashboardFormSummaryEntity formSummary;

  const FormSummaryCard({super.key, required this.formSummary});

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
            children: [
              const Icon(
                Icons.checklist_rounded,
                color: AppColors.outline,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                strings.formsOverview,
                style: AppTypography.titleMedium(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _FormStatItem(
                  count: formSummary.pendingCount.toString(),
                  label: strings.todoStatus,
                  textColor: AppColors.secondary,
                  borderColor: isDark ? AppColors.darkOutlineVariant : AppColors.surfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FormStatItem(
                  count: formSummary.completedCount.toString(),
                  label: strings.completedStatus,
                  textColor: AppColors.primaryContainer,
                  borderColor: isDark ? AppColors.darkOutlineVariant : AppColors.surfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FormStatItem(
                  count: formSummary.overdueCount.toString(),
                  label: strings.overdueStatus,
                  textColor: AppColors.error,
                  borderColor: AppColors.errorContainer,
                  bgColor: AppColors.errorContainer.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormStatItem extends StatelessWidget {
  final String count;
  final String label;
  final Color textColor;
  final Color borderColor;
  final Color? bgColor;

  const _FormStatItem({
    required this.count,
    required this.label,
    required this.textColor,
    required this.borderColor,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor ?? (isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surface),
        borderRadius: AppRadius.roundedMd,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: AppTypography.headlineMedium(color: textColor).copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.labelSmall(
              color: textColor == AppColors.error
                  ? AppColors.error
                  : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
