import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/dynamic_form_field.dart';
import 'dynamic_form_field_wrapper.dart';

class DynamicBooleanFieldWidget extends StatelessWidget {
  final DynamicFormField field;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? errorText;

  const DynamicBooleanFieldWidget({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DynamicFormFieldWrapper(
      field: field,
      errorText: errorText,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              children: [
                Icon(
                  value ? Icons.check_circle_rounded : Icons.cancel_outlined,
                  size: 20,
                  color: value ? AppColors.primary : AppColors.outline,
                ),
                const SizedBox(width: 10),
                Text(
                  value ? 'Có / Đạt / Đang bật' : 'Không / Chưa đạt / Tắt',
                  style: AppTypography.bodyMedium(
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Switch(
              value: value,
              activeThumbColor: AppColors.primary,
              onChanged: field.isReadOnly ? null : onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
