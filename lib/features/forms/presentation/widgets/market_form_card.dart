import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/market_form_entity.dart';

class MarketFormCard extends StatelessWidget {
  final MarketFormConfigEntity config;
  final VoidCallback onTap;
  final bool isSubmitted;
  final bool showStatus;

  const MarketFormCard({
    super.key,
    required this.config,
    required this.onTap,
    this.isSubmitted = false,
    this.showStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveSubmitted = showStatus && isSubmitted;

    return Material(
      color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: effectiveSubmitted
              ? const Color(0xFF10B981)
              : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
          width: effectiveSubmitted ? 1.5 : 1,
        ),
      ),
      elevation: 1,
      shadowColor: const Color(0x0A000000),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.marginMobile),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon + Title + Required Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: effectiveSubmitted
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : (isDark
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : AppColors.primaryContainer.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(
                        effectiveSubmitted
                            ? Icons.check_circle_rounded
                            : Icons.assignment_outlined,
                        color: effectiveSubmitted
                            ? const Color(0xFF10B981)
                            : (isDark ? AppColors.primaryFixedDim : AppColors.primary),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                config.name,
                                style: AppTypography.titleMedium(
                                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (config.isRequired) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppColors.error.withValues(alpha: 0.4),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'Bắt buộc',
                                  style: AppTypography.labelSmall(
                                    color: AppColors.error,
                                  ).copyWith(fontWeight: FontWeight.w700, fontSize: 11),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mã: ${config.code} · ${config.schema.blocks.length} câu hỏi',
                          style: AppTypography.labelSmall(
                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant)
                    .withValues(alpha: 0.5),
              ),
              const SizedBox(height: 10),
              // Footer: Trạng thái & Action
              if (showStatus)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isSubmitted
                              ? Icons.verified_rounded
                              : Icons.pending_actions_rounded,
                          size: 16,
                          color: isSubmitted
                              ? const Color(0xFF10B981)
                              : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isSubmitted ? 'Đã nộp phiếu' : 'Chưa thực hiện',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isSubmitted
                                ? const Color(0xFF10B981)
                                : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: isSubmitted
                            ? (isDark ? AppColors.primaryFixedDim : AppColors.primary)
                            : AppColors.primary,
                      ),
                      icon: Icon(
                        isSubmitted ? Icons.edit_note_rounded : Icons.play_arrow_rounded,
                        size: 18,
                      ),
                      label: Text(
                        isSubmitted ? 'Nộp lại' : 'Điền form',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      onPressed: onTap,
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.edit_note_rounded,
                          size: 18,
                          color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Thu thập thông tin',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text(
                        'Điền form',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      onPressed: onTap,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
