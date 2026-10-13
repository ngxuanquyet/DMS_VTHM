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
  final FocusNode? focusNode;

  const DynamicTextFieldWidget({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.focusNode,
  });

  @override
  State<DynamicTextFieldWidget> createState() => _DynamicTextFieldWidgetState();
}

class _DynamicTextFieldWidgetState extends State<DynamicTextFieldWidget> {
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
  void didUpdateWidget(covariant DynamicTextFieldWidget oldWidget) {
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
        child: TextField(
          focusNode: _focusNode,
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
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            filled: false,
            fillColor: Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ),
    );
  }
}
