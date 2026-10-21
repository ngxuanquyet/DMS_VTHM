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

  /// Kiểu "xổ xuống" (`choiceDisplay == 'dropdown'`, admin đặt cho ô Kênh — chốt 21/10/2026): bảng chọn tick từ dưới lên.
  void _showPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final chon = List<dynamic>.from(selectedValues);
        return StatefulBuilder(
          builder: (ctx, setSheet) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            field.label,
                            style: AppTypography.titleMedium(
                              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            onChanged(chon);
                          },
                          child: const Text('Xong'),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: field.options.map((opt) {
                        final daChon = chon.contains(opt.value);
                        return CheckboxListTile(
                          value: daChon,
                          title: Text(opt.label),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (_) => setSheet(() => daChon ? chon.remove(opt.value) : chon.add(opt.value)),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = field.options;

    if (field.choiceDisplay == 'dropdown') {
      final nhan = options.where((o) => selectedValues.contains(o.value)).map((o) => o.label).toList();
      return DynamicFormFieldWrapper(
        field: field,
        errorText: errorText,
        child: InkWell(
          onTap: field.isReadOnly ? null : () => _showPicker(context),
          borderRadius: AppRadius.roundedMd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
              borderRadius: AppRadius.roundedMd,
              border: Border.all(
                color: errorText != null
                    ? AppColors.error
                    : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    nhan.isEmpty ? (field.placeholder ?? 'Chọn ${field.label.toLowerCase()}') : nhan.join(', '),
                    style: AppTypography.bodyMedium(
                      color: nhan.isEmpty
                          ? (isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline)
                          : (isDark ? AppColors.darkOnSurface : AppColors.onSurface),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
                ),
              ],
            ),
          ),
        ),
      );
    }

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
