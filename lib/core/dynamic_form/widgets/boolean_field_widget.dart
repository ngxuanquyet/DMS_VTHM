import 'package:flutter/material.dart';
import '../../widgets/form_fields/form_field_parts.dart';
import '../models/dynamic_form_field.dart';
import 'dynamic_form_field_wrapper.dart';

/// Ô Có/Không — công tắc trong khung, nhãn nằm trong khung (cách vẽ biểu mẫu khảo sát/thu thập, #24756).
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
    return Padding(
      padding: const EdgeInsets.only(bottom: kFormFieldSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormSwitchTile(
            title: FormFieldLabel(
              label: field.label,
              isRequired: field.isRequired,
              description: field.description,
              asTextWidget: true,
              trailing: DynamicFieldBadge.of(field),
            ),
            value: value,
            hasError: errorText != null,
            onChanged: field.isReadOnly ? null : onChanged,
          ),
          if (errorText != null && errorText!.isNotEmpty) FormFieldErrorText(errorText!),
        ],
      ),
    );
  }
}
