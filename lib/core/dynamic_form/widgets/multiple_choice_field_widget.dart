import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/dynamic_form_field.dart';
import 'dynamic_form_field_wrapper.dart';

class DynamicMultipleChoiceFieldWidget extends StatelessWidget {
  final DynamicFormField field;
  final List<dynamic> selectedValues;
  final ValueChanged<List<dynamic>> onChanged;
  final String? errorText;

  const DynamicMultipleChoiceFieldWidget({
    super.key,
    required this.field,
    required this.selectedValues,
    required this.onChanged,
    this.errorText,
  });

  void _toggleOption(dynamic optValue) {
    if (field.isReadOnly) return;
    final list = List<dynamic>.from(selectedValues);
    if (list.contains(optValue)) {
      list.remove(optValue);
    } else {
      list.add(optValue);
    }
    onChanged(list);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = field.options;

    return DynamicFormFieldWrapper(
      field: field,
      errorText: errorText,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((opt) {
          final isSelected = selectedValues.contains(opt.value);
          return InkWell(
            onTap: field.isReadOnly ? null : () => _toggleOption(opt.value),
            borderRadius: AppRadius.roundedMd,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? AppColors.secondary : AppColors.secondaryContainer)
                    : (isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest),
                borderRadius: AppRadius.roundedMd,
                border: Border.all(
                  color: isSelected
                      ? (isDark ? AppColors.secondary : AppColors.secondaryContainer)
                      : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
                ),
                boxShadow: isSelected ? AppShadows.level1 : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                    size: 16,
                    color: isSelected
                        ? (isDark ? Colors.white : AppColors.onSecondaryContainer)
                        : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    opt.label,
                    style: AppTypography.bodySmall(
                      color: isSelected
                          ? (isDark ? Colors.white : AppColors.onSecondaryContainer)
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
