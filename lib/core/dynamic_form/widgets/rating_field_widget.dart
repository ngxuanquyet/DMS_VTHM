import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/dynamic_form_field.dart';
import 'dynamic_form_field_wrapper.dart';

class DynamicRatingFieldWidget extends StatelessWidget {
  final DynamicFormField field;
  final int value;
  final ValueChanged<int> onChanged;
  final String? errorText;

  const DynamicRatingFieldWidget({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxStars = (field.max ?? 5).toInt();

    return DynamicFormFieldWrapper(
      field: field,
      errorText: errorText,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: field.isReadOnly
              ? (isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHigh)
              : (isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest),
          borderRadius: AppRadius.roundedMd,
          border: Border.all(
            color: errorText != null
                ? AppColors.error
                : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: List.generate(maxStars, (index) {
                final starNumber = index + 1;
                final isFilled = starNumber <= value;
                return GestureDetector(
                  onTap: field.isReadOnly ? null : () => onChanged(starNumber),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 28,
                      color: isFilled ? const Color(0xFFF59E0B) : AppColors.outline,
                    ),
                  ),
                );
              }),
            ),
            Text(
              '$value/$maxStars sao',
              style: AppTypography.labelLarge(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
