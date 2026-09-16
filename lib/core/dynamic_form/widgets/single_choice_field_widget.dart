import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/dynamic_form_field.dart';
import 'dynamic_form_field_wrapper.dart';

class DynamicSingleChoiceFieldWidget extends StatelessWidget {
  final DynamicFormField field;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  final String? errorText;

  const DynamicSingleChoiceFieldWidget({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = field.options;

    // If options > 4, render a beautiful Dropdown
    if (options.length > 4) {
      return DynamicFormFieldWrapper(
        field: field,
        errorText: errorText,
        child: Container(
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
          child: DropdownButtonFormField<dynamic>(
            initialValue: options.any((o) => o.value == value) ? value : null,
            isDense: true,
            isExpanded: true,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              prefixIcon: const Icon(Icons.radio_button_checked_rounded, size: 18),
              border: InputBorder.none,
              hintText: field.placeholder ?? 'Chọn ${field.label.toLowerCase()}',
            ),
            items: [
              const DropdownMenuItem<dynamic>(
                value: null,
                child: Text('(Chưa chọn)', style: TextStyle(color: AppColors.outline)),
              ),
              ...options.map(
                (opt) => DropdownMenuItem<dynamic>(
                  value: opt.value,
                  child: Text(opt.label, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: field.isReadOnly ? null : onChanged,
          ),
        ),
      );
    }

    // Otherwise render selectable Chip cards / Radio list
    return DynamicFormFieldWrapper(
      field: field,
      errorText: errorText,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((opt) {
          final isSelected = opt.value == value;
          return InkWell(
            onTap: field.isReadOnly ? null : () => onChanged(opt.value),
            borderRadius: AppRadius.roundedMd,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? AppColors.primary : AppColors.primaryContainer)
                    : (isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest),
                borderRadius: AppRadius.roundedMd,
                border: Border.all(
                  color: isSelected
                      ? (isDark ? AppColors.primary : AppColors.primaryContainer)
                      : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
                ),
                boxShadow: isSelected ? AppShadows.level1 : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    opt.label,
                    style: AppTypography.bodySmall(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppColors.darkOnSurface : AppColors.onSurface),
                    ).copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
