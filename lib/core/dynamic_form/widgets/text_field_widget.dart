import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/voice_input_mic_button.dart';
import '../models/dynamic_form_field.dart';
import 'dynamic_form_field_wrapper.dart';

class DynamicTextFieldWidget extends StatefulWidget {
  final DynamicFormField field;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  const DynamicTextFieldWidget({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  @override
  State<DynamicTextFieldWidget> createState() => _DynamicTextFieldWidgetState();
}

class _DynamicTextFieldWidgetState extends State<DynamicTextFieldWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(covariant DynamicTextFieldWidget oldWidget) {
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
        child: TextField(
          controller: _controller,
          readOnly: widget.field.isReadOnly,
          onChanged: (val) {
            widget.onChanged(val.trim().isNotEmpty ? val.trim() : null);
          },
          style: AppTypography.bodyMedium(
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ),
          decoration: InputDecoration(
            hintText: widget.field.placeholder ?? 'Nhập ${widget.field.label.toLowerCase()}...',
            hintStyle: AppTypography.bodySmall(
              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
            ),
            prefixText: widget.field.prefixText != null ? '${widget.field.prefixText} ' : null,
            suffixText: widget.field.suffixText,
            prefixIcon: const Icon(Icons.edit_note_rounded, size: 18),
            suffixIcon: !widget.field.isReadOnly
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_controller.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          tooltip: 'Xóa nội dung',
                          onPressed: () {
                            setState(() {
                              _controller.clear();
                            });
                            widget.onChanged(null);
                          },
                        ),
                      VoiceInputMicButton(
                        currentText: _controller.text,
                        fieldName: widget.field.label,
                        onTextRecognized: (newText) {
                          setState(() {
                            _controller.text = newText;
                          });
                          widget.onChanged(newText.trim().isNotEmpty ? newText.trim() : null);
                        },
                      ),
                      const SizedBox(width: 4),
                    ],
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ),
    );
  }
}
