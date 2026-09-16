import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/dynamic_form_field.dart';
import 'dynamic_form_field_wrapper.dart';

class DynamicNumberFieldWidget extends StatefulWidget {
  final DynamicFormField field;
  final num? value;
  final ValueChanged<num?> onChanged;
  final String? errorText;

  const DynamicNumberFieldWidget({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  @override
  State<DynamicNumberFieldWidget> createState() => _DynamicNumberFieldWidgetState();
}

class _DynamicNumberFieldWidgetState extends State<DynamicNumberFieldWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value != null ? widget.value.toString() : '');
  }

  @override
  void didUpdateWidget(covariant DynamicNumberFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      final text = widget.value != null ? widget.value.toString() : '';
      if (_controller.text != text) {
        _controller.text = text;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _stepValue(num delta) {
    if (widget.field.isReadOnly) return;
    num current = num.tryParse(_controller.text.trim()) ?? (widget.field.min ?? 0);
    num next = current + delta;
    if (widget.field.min != null && next < widget.field.min!) {
      next = widget.field.min!;
    }
    if (widget.field.max != null && next > widget.field.max!) {
      next = widget.field.max!;
    }
    _controller.text = next.toString();
    widget.onChanged(next);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final step = widget.field.step ?? 1;

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
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                readOnly: widget.field.isReadOnly,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                onChanged: (val) {
                  final parsed = num.tryParse(val.trim());
                  widget.onChanged(parsed);
                },
                style: AppTypography.bodyMedium(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: widget.field.placeholder ?? '0',
                  hintStyle: AppTypography.bodySmall(
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
                  ),
                  prefixText: widget.field.prefixText != null ? '${widget.field.prefixText} ' : null,
                  suffixText: widget.field.suffixText,
                  prefixIcon: const Icon(Icons.pin_outlined, size: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            if (!widget.field.isReadOnly) ...[
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                onPressed: () => _stepValue(-step),
                tooltip: 'Giảm $step',
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                onPressed: () => _stepValue(step),
                tooltip: 'Tăng $step',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
