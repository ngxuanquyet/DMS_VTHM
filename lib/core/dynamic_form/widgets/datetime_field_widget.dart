import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/dynamic_form_field.dart';
import '../../widgets/form_fields/form_field_parts.dart';
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
    final hasValue = value != null && value!.isNotEmpty;

    final String chuaChon;
    switch (field.type) {
      case DynamicFormFieldType.time:
        chuaChon = 'Chưa chọn giờ';
        break;
      case DynamicFormFieldType.datetime:
        chuaChon = 'Chưa chọn ngày giờ';
        break;
      case DynamicFormFieldType.date:
      default:
        chuaChon = 'Chưa chọn ngày';
        break;
    }

    return DynamicFormFieldWrapper(
      field: field,
      child: FormTapField(
        text: hasValue ? value! : (field.placeholder ?? chuaChon),
        hasValue: hasValue,
        hintText: chuaChon,
        errorText: errorText,
        readOnly: field.isReadOnly,
        onTap: field.isReadOnly ? null : () => _pickDateTime(context),
        suffixIcon: hasValue && !field.isReadOnly
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                tooltip: 'Xoá',
                onPressed: () => onChanged(null),
              )
            : Icon(field.type == DynamicFormFieldType.time ? Icons.access_time_rounded : Icons.calendar_today_rounded, size: 20),
      ),
    );
  }
}
