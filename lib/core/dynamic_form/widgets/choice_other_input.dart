import 'package:flutter/material.dart';

import '../../widgets/form_fields/form_field_parts.dart';
import '../choice_other.dart';

/// Ô gõ giá trị «Khác» hiện dưới ô chọn khi đang chọn «Khác…» — kiểu ô nhập chung ([formFieldDecoration]). Tự giữ nội dung; gọi [onChanged] với chuỗi ĐÃ TRIM.
/// Màn chứa đặt `key` theo mã ô để nội dung không nhảy sang ô khác khi danh sách ô ẩn/hiện.
class ChoiceOtherInput extends StatefulWidget {
  final String? initialText;
  final ValueChanged<String> onChanged;
  final bool enabled;

  const ChoiceOtherInput({
    super.key,
    this.initialText,
    required this.onChanged,
    this.enabled = true,
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
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: _ctrl,
        enabled: widget.enabled,
        maxLength: ChoiceOther.maxLength,
        style: formFieldTextStyle(isDark),
        decoration: formFieldDecoration(hintText: 'Nhập giá trị khác...', isDark: isDark),
        onChanged: (v) => widget.onChanged(v.trim()),
      ),
    );
  }
}
