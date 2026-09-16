import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/dynamic_form_field.dart';
import 'dynamic_form_field_wrapper.dart';

class DynamicDateTimeFieldWidget extends StatelessWidget {
  final DynamicFormField field;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  const DynamicDateTimeFieldWidget({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  Future<void> _pickDateTime(BuildContext context) async {
    if (field.isReadOnly) return;

    if (field.type == DynamicFormFieldType.time) {
      final nowTime = TimeOfDay.now();
      final picked = await showTimePicker(
        context: context,
        initialTime: nowTime,
      );
      if (picked != null) {
        final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        onChanged(formatted);
      }
      return;
    }

    final initialDate = DateTime.tryParse(value ?? '') ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) return;

    if (field.type == DynamicFormFieldType.date) {
      final formatted = DateFormat('yyyy-MM-dd').format(pickedDate);
      onChanged(formatted);
      return;
    }

    // Datetime mode -> Pick Time as well
    if (context.mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );
      if (pickedTime != null) {
        final fullDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        final formatted = DateFormat('yyyy-MM-dd HH:mm').format(fullDateTime);
        onChanged(formatted);
      } else {
        final formatted = DateFormat('yyyy-MM-dd 00:00').format(pickedDate);
        onChanged(formatted);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasValue = value != null && value!.isNotEmpty;

    IconData icon;
    String defaultHint;
    switch (field.type) {
      case DynamicFormFieldType.time:
        icon = Icons.access_time_rounded;
        defaultHint = 'Chọn giờ (HH:mm)';
        break;
      case DynamicFormFieldType.datetime:
        icon = Icons.event_available_rounded;
        defaultHint = 'Chọn ngày & giờ';
        break;
      case DynamicFormFieldType.date:
      default:
        icon = Icons.calendar_today_rounded;
        defaultHint = 'Chọn ngày (YYYY-MM-DD)';
        break;
    }

    return DynamicFormFieldWrapper(
      field: field,
      errorText: errorText,
      child: InkWell(
        onTap: field.isReadOnly ? null : () => _pickDateTime(context),
        borderRadius: AppRadius.roundedMd,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
            children: [
              Icon(
                icon,
                size: 18,
                color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasValue ? value! : (field.placeholder ?? defaultHint),
                  style: hasValue
                      ? AppTypography.bodyMedium(
                          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                        ).copyWith(fontWeight: FontWeight.w600)
                      : AppTypography.bodySmall(
                          color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
                        ),
                ),
              ),
              if (hasValue && !field.isReadOnly)
                GestureDetector(
                  onTap: () => onChanged(null),
                  child: const Icon(Icons.clear_rounded, size: 16, color: AppColors.outline),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
