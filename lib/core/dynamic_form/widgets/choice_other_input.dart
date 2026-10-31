import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../choice_other.dart';

/// Ô gõ giá trị «Khác» hiện dưới ô chọn khi đang chọn «Khác…». Tự giữ nội dung; gọi [onChanged] với chuỗi ĐÃ TRIM.
/// Màn chứa đặt `key` theo mã ô để nội dung không nhảy sang ô khác khi danh sách ô ẩn/hiện.
class ChoiceOtherInput extends StatefulWidget {
  final String? initialText;
  final ValueChanged<String> onChanged;
  final bool enabled;

  /// Kiểu viền riêng của màn chứa; `null` = kiểu mặc định của form động.
  final InputDecoration? decoration;

  const ChoiceOtherInput({
    super.key,
    this.initialText,
    required this.onChanged,
    this.enabled = true,
    this.decoration,
  });

  @override
  State<ChoiceOtherInput> createState() => _ChoiceOtherInputState();
}

class _ChoiceOtherInputState extends State<ChoiceOtherInput> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initialText ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = OutlineInputBorder(
      borderRadius: AppRadius.roundedMd,
      borderSide: BorderSide(color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: _ctrl,
        enabled: widget.enabled,
        maxLength: ChoiceOther.maxLength,
        style: AppTypography.bodyMedium(color: isDark ? AppColors.darkOnSurface : AppColors.onSurface),
        decoration: widget.decoration ??
            InputDecoration(
              hintText: 'Nhập giá trị khác...',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              prefixIcon: const Icon(Icons.edit_note_rounded, size: 18),
              filled: true,
              fillColor: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
              border: border,
              enabledBorder: border,
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.roundedMd,
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
        onChanged: (v) => widget.onChanged(v.trim()),
      ),
    );
  }
}
