import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../domain/entities/market_form_entity.dart';

class CurrencyTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Chỉ giữ lại chữ số
    final cleanDigits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanDigits.isEmpty) {
      return const TextEditingValue();
    }

    final parsed = int.tryParse(cleanDigits);
    if (parsed == null) return oldValue;

    // Định dạng phân tách hàng nghìn bằng dấu chấm (185.000)
    final formatted = _formatVnd(parsed);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String _formatVnd(num value) {
    final str = value.toInt().toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write('.');
      }
    }
    return buffer.toString().split('').reversed.join('');
  }
}

class CurrencyFieldWidget extends StatefulWidget {
  final MarketFormBlockEntity block;
  final num? initialValue;
  final ValueChanged<num?> onChanged;
  final String? errorText;

  const CurrencyFieldWidget({
    super.key,
    required this.block,
    this.initialValue,
    required this.onChanged,
    this.errorText,
  });

  @override
  State<CurrencyFieldWidget> createState() => _CurrencyFieldWidgetState();
}

class _CurrencyFieldWidgetState extends State<CurrencyFieldWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final initialText = widget.initialValue != null
        ? CurrencyTextInputFormatter._formatVnd(widget.initialValue!)
        : '';
    _controller = TextEditingController(text: initialText);
  }

  @override
  void didUpdateWidget(covariant CurrencyFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      final currentNum = _parseCurrent();
      if (currentNum != widget.initialValue) {
        final newText = widget.initialValue != null
            ? CurrencyTextInputFormatter._formatVnd(widget.initialValue!)
            : '';
        _controller.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  num? _parseCurrent() {
    final clean = _controller.text.replaceAll(RegExp(r'[^\d]'), '');
    return num.tryParse(clean);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final validation = widget.block.resolved.validation;

    String? helper;
    if (validation != null) {
      if (validation.min != null && validation.max != null) {
        helper = 'Từ ${CurrencyTextInputFormatter._formatVnd(validation.min!)} đến ${CurrencyTextInputFormatter._formatVnd(validation.max!)} VNĐ';
      } else if (validation.min != null) {
        helper = 'Tối thiểu ${CurrencyTextInputFormatter._formatVnd(validation.min!)} VNĐ';
      } else if (validation.max != null) {
        helper = 'Tối đa ${CurrencyTextInputFormatter._formatVnd(validation.max!)} VNĐ';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  text: widget.block.resolved.label,
                  style: AppTypography.titleMedium(
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
                  children: [
                    if (widget.block.required)
                      const TextSpan(
                        text: ' *',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (widget.block.resolved.description != null &&
            widget.block.resolved.description!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            widget.block.resolved.description!,
            style: AppTypography.bodySmall(
              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        TextFormField(
          controller: _controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            CurrencyTextInputFormatter(),
          ],
          style: AppTypography.bodyLarge(
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ).copyWith(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Nhập số tiền...',
            hintStyle: AppTypography.bodyMedium(
              color: isDark ? AppColors.darkOutline : AppColors.outlineVariant,
            ),
            suffixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                'VNĐ',
                style: AppTypography.labelLarge(
                  color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            errorText: widget.errorText,
            helperText: helper,
            helperStyle: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
            ),
            filled: true,
            fillColor: isDark
                ? AppColors.darkSurfaceContainer
                : AppColors.surfaceContainerLowest,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
          onChanged: (_) {
            widget.onChanged(_parseCurrent());
          },
        ),
      ],
    );
  }
}
