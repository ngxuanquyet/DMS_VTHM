import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/form_entity.dart';

class FormCardItem extends StatelessWidget {
  final FormItemEntity form;
  final VoidCallback? onAction;

  const FormCardItem({
    super.key,
    required this.form,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title + Deadline badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      form.title,
                      style: AppTypography.titleLarge(
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.storefront_outlined,
                          size: 16,
                          color: AppColors.outline,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            form.dealerName,
                            style: AppTypography.bodyMedium(
                              color: isDark
                                  ? AppColors.darkOnSurfaceVariant
                                  : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceContainerLowest
                      : AppColors.surfaceContainerHigh,
                  borderRadius: AppRadius.roundedSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, size: 13, color: AppColors.outline),
                    const SizedBox(width: 4),
                    Text(
                      form.deadline,
                      style: AppTypography.labelSmall(
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Progress section if in-progress
          if (form.status == FormStatusType.inProgress) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Đang thực hiện',
                  style: AppTypography.labelSmall(
                    color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${form.answeredCount}/${form.questionsCount} câu hỏi',
                  style: AppTypography.labelSmall(
                    color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: AppRadius.roundedFull,
              child: LinearProgressIndicator(
                value: form.progressPercent,
                minHeight: 6,
                backgroundColor: isDark
                    ? AppColors.darkSurfaceContainerLowest
                    : AppColors.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryContainer),
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Footer info + Action button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.format_list_bulleted,
                    size: 16,
                    color: AppColors.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${form.questionsCount} câu hỏi',
                    style: AppTypography.bodyMedium(
                      color: isDark
                          ? AppColors.darkOnSurfaceVariant
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (form.status == FormStatusType.completed)
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: AppColors.primaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Hoàn thành',
                          style: AppTypography.bodyMedium(
                            color: AppColors.primary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  else if (form.status == FormStatusType.inProgress)
                    Row(
                      children: [
                        const Icon(
                          Icons.play_circle_fill_rounded,
                          size: 16,
                          color: AppColors.primaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Tiếp tục',
                          style: AppTypography.bodyMedium(
                            color: AppColors.primary,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.outlineVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Chưa thực hiện',
                          style: AppTypography.bodyMedium(
                            color: isDark
                                ? AppColors.darkOnSurfaceVariant
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (form.status == FormStatusType.inProgress)
                AppButton(
                  text: 'Tiếp tục',
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  onPressed: onAction,
                )
              else if (form.status == FormStatusType.todo)
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                    onPressed: onAction,
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ],
      ),
    );
  }
}
