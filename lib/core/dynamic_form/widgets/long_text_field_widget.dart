import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/dynamic_form_field.dart';
import 'dynamic_form_field_wrapper.dart';

class DynamicLongTextFieldWidget extends StatefulWidget {
  final DynamicFormField field;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  const DynamicLongTextFieldWidget({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  @override
  State<DynamicLongTextFieldWidget> createState() => _DynamicLongTextFieldWidgetState();
}

class _DynamicLongTextFieldWidgetState extends State<DynamicLongTextFieldWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(covariant DynamicLongTextFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DynamicFormFieldWrapper(
      field: widget.field,
      errorText: widget.errorText,
      child: Container(
        decoration: BoxDecoration(
          color: widget.field.isReadOnly
              ? (isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHigh)
              : (isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest),
          borderRadius: AppRadius.roundedMd,
          border: Border.all(
            color: widget.errorText != null
                ? AppColors.error
                : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextField(
              controller: _controller,
              readOnly: widget.field.isReadOnly,
              minLines: 3,
              maxLines: 6,
              onChanged: (val) {
                setState(() {});
                widget.onChanged(val.trim().isNotEmpty ? val.trim() : null);
              },
              style: AppTypography.bodyMedium(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ),
              decoration: InputDecoration(
                hintText: widget.field.placeholder ?? 'Nhập chi tiết ${widget.field.label.toLowerCase()}...',
                hintStyle: AppTypography.bodySmall(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            if (!widget.field.isReadOnly)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 6),
                child: Text(
                  '${_controller.text.length} ký tự',
                  style: AppTypography.labelSmall(
                    color: isDark ? AppColors.darkOutline : AppColors.outline,
                  ).copyWith(fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
