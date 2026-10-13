import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/voice_input_mic_button.dart';
import '../models/dynamic_form_field.dart';
import 'dynamic_form_field_wrapper.dart';

class DynamicLongTextFieldWidget extends StatefulWidget {
  final DynamicFormField field;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? errorText;
  final FocusNode? focusNode;

  const DynamicLongTextFieldWidget({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.focusNode,
  });

  @override
  State<DynamicLongTextFieldWidget> createState() => _DynamicLongTextFieldWidgetState();
}

class _DynamicLongTextFieldWidgetState extends State<DynamicLongTextFieldWidget> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isInternalFocusNode = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _isInternalFocusNode = true;
    }
    _isFocused = _focusNode.hasFocus;
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted && _isFocused != _focusNode.hasFocus) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  @override
  void didUpdateWidget(covariant DynamicLongTextFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value ?? '';
    }
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_onFocusChange);
      if (_isInternalFocusNode) {
        _focusNode.dispose();
      }
      if (widget.focusNode != null) {
        _focusNode = widget.focusNode!;
        _isInternalFocusNode = false;
      } else {
        _focusNode = FocusNode();
        _isInternalFocusNode = true;
      }
      _isFocused = _focusNode.hasFocus;
      _focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (_isInternalFocusNode) {
      _focusNode.dispose();
    }
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
                : (_isFocused
                    ? AppColors.primary
                    : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant)),
            width: _isFocused ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextField(
              focusNode: _focusNode,
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
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            if (!widget.field.isReadOnly)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4, left: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_controller.text.length} ký tự',
                      style: AppTypography.labelSmall(
                        color: isDark ? AppColors.darkOutline : AppColors.outline,
                      ).copyWith(fontSize: 10),
                    ),
                    VoiceInputMicButton(
                      currentText: _controller.text,
                      fieldName: widget.field.label,
                      size: 18,
                      onTextRecognized: (newText) {
                        setState(() {
                          _controller.text = newText;
                        });
                        widget.onChanged(newText.trim().isNotEmpty ? newText.trim() : null);
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
