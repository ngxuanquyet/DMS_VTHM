import 'package:flutter/material.dart';
import '../models/dynamic_form_field.dart';
import '../../widgets/form_fields/form_field_parts.dart';
import 'dynamic_form_field_wrapper.dart';

class DynamicNumberFieldWidget extends StatefulWidget {
  final DynamicFormField field;
  final num? value;
  final ValueChanged<num?> onChanged;
  final String? errorText;
  final FocusNode? focusNode;

  const DynamicNumberFieldWidget({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.focusNode,
  });

  @override
  State<DynamicNumberFieldWidget> createState() => _DynamicNumberFieldWidgetState();
}

class _DynamicNumberFieldWidgetState extends State<DynamicNumberFieldWidget> {
  late final TextEditingController _controller;
  late FocusNode _focusNode; // đổi được trong didUpdateWidget khi màn chứa đổi focusNode
  bool _isInternalFocusNode = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value != null ? widget.value.toString() : '');
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _isInternalFocusNode = true;
    }
  }

  @override
  void didUpdateWidget(covariant DynamicNumberFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Chỉ đồng bộ khi giá trị đổi TỪ NGOÀI (khác số của chữ đang gõ) — không ghi đè chữ gõ dở ('1,' / '1.').
    if (widget.value != oldWidget.value && num.tryParse(_controller.text.trim()) != widget.value) {
      _controller.text = widget.value != null ? widget.value.toString() : '';
    }
    if (widget.focusNode != oldWidget.focusNode) {
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
    }
  }

  @override
  void dispose() {
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
      child: TextField(
        focusNode: _focusNode,
        controller: _controller,
        readOnly: widget.field.isReadOnly,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        onChanged: (val) {
          final parsed = num.tryParse(val.trim());
          widget.onChanged(parsed);
        },
        style: formFieldTextStyle(isDark),
        decoration: formFieldDecoration(
          isDark: isDark,
          readOnly: widget.field.isReadOnly,
          errorText: widget.errorText,
          hintText: widget.field.placeholder ?? 'Nhập số...',
          prefixText: widget.field.prefixText != null ? '${widget.field.prefixText} ' : null,
          suffixText: widget.field.suffixText,
        ),
      ),
    );
  }
}
