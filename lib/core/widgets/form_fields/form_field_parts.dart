import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Các mảnh VẼ ô nhập DÙNG CHUNG biểu mẫu khảo sát/thu thập (`MarketFormRenderer` — cách vẽ CHUẨN) và form Thêm/Sửa
/// điểm bán (`DynamicFormBuilder`) — #24756. Chỉ lo hình dạng (nhãn, ô nhập, nhóm lựa chọn, lỗi, khung ảnh, khoảng
/// cách); giá trị, kiểm hợp lệ và trạng thái do màn chứa giữ.

/// Khoảng cách dọc giữa hai ô của form.
const double kFormFieldSpacing = AppSpacing.stackMd;

/// Khoảng cách nhãn → ô nhập (ô chữ, số, chọn xổ xuống, ngày, ảnh).
const double kFormLabelGap = 8;

/// Khoảng cách nhãn → nhóm lựa chọn (nút tròn / ô tick / thẻ chọn).
const double kFormLabelGapChoice = 6;

/// Một lựa chọn của nhóm chọn: [value] là giá trị THẬT màn chứa nhận lại khi chọn.
class FormChoiceOption {
  final Object? value;
  final String label;

  const FormChoiceOption(this.value, this.label);
}

/// Nhãn ô: chữ đậm 14, dấu `*` đỏ khi bắt buộc, dòng mô tả nhỏ bên dưới; [trailing] (huy hiệu số ảnh…) nằm NGAY SAU tên
/// ô, không đẩy ra mép phải (chủ hệ thống yêu cầu 09/11/2026).
class FormFieldLabel extends StatelessWidget {
  final String label;
  final bool isRequired;
  final String? description;
  final Widget? trailing;

  /// Vẽ bằng `Text.rich` thay `RichText` — hình y hệt; nhãn là một `Text` (tìm được bằng `find.text`, như vỏ cũ của form
  /// điểm bán). Biểu mẫu khảo sát giữ `RichText` (nút `Chụp ảnh <nhãn>` không trùng nhãn khi tìm theo chữ).
  final bool asTextWidget;

  const FormFieldLabel({
    super.key,
    required this.label,
    this.isRequired = false,
    this.description,
    this.trailing,
    this.asTextWidget = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final desc = description?.trim() ?? '';
    final span = TextSpan(
      text: label,
      style: AppTypography.titleMedium(
        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
      ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
      children: [
        if (isRequired)
          const TextSpan(
            text: ' *',
            style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
          ),
      ],
    );
    // `inherit: false`: không thừa kế DefaultTextStyle nơi đặt (ListTile / Scaffold…) — vẽ y hệt RichText.
    final Widget chu = asTextWidget ? Text.rich(span, style: const TextStyle(inherit: false)) : RichText(text: span);
    // Không mô tả ⇒ chỉ dòng nhãn (không bọc Column — ô nhập là anh em gần nhất của nhãn trong khối ô).
    final nhan = desc.isEmpty
        ? chu
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              chu,
              const SizedBox(height: 3),
              Text(
                desc,
                style: AppTypography.bodySmall(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
                ).copyWith(fontSize: 12),
              ),
            ],
          );
    if (trailing == null) return nhan;
    // Tên ô co theo chữ (Flexible, không Expanded) ⇒ huy hiệu đứng liền sau; tên dài thì tự xuống dòng, huy hiệu vẫn kề bên.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(child: nhan),
        const SizedBox(width: 6),
        trailing!,
      ],
    );
  }
}

/// Dòng lỗi dưới ô không có viền nhập (nhóm lựa chọn, khung ảnh…). Ô có viền nhập hiện lỗi qua
/// [formFieldDecoration] `errorText`.
class FormFieldErrorText extends StatelessWidget {
  final String error;

  const FormFieldErrorText(this.error, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, left: 4),
        child: Text(error, style: const TextStyle(color: AppColors.error, fontSize: 12)),
      );
}

/// Kiểu chữ giá trị trong ô nhập.
TextStyle formFieldTextStyle(bool isDark) =>
    AppTypography.bodyMedium(color: isDark ? AppColors.darkOnSurface : AppColors.onSurface);

/// Viền + nền + chữ gợi ý + lỗi của mọi ô nhập. [readOnly] ⇒ nền xám (ô khoá).
InputDecoration formFieldDecoration({
  required bool isDark,
  required String hintText,
  String? errorText,
  Widget? suffixIcon,
  Widget? prefixIcon,
  String? prefixText,
  String? suffixText,
  bool readOnly = false,
}) {
  OutlineInputBorder vien(Color color, [double width = 1.0]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );
  final thuong = vien(isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant);
  return InputDecoration(
    hintText: hintText,
    hintStyle: AppTypography.bodyMedium(color: isDark ? AppColors.darkOutline : AppColors.outlineVariant),
    errorText: errorText,
    errorMaxLines: 3,
    suffixIcon: suffixIcon,
    prefixIcon: prefixIcon,
    prefixText: prefixText,
    suffixText: suffixText,
    filled: true,
    fillColor: readOnly
        ? (isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHigh)
        : (isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    // Đặt đủ mọi trạng thái — khung giữ bo góc / độ dày khi báo lỗi hoặc khoá.
    border: thuong,
    enabledBorder: thuong,
    disabledBorder: thuong,
    focusedBorder: vien(AppColors.primary, 1.5),
    errorBorder: vien(AppColors.error),
    focusedErrorBorder: vien(AppColors.error, 1.5),
  );
}

/// Ô bấm để chọn (ngày, bảng chọn…): trông như ô nhập, hiện [text] (giá trị hoặc chữ "chưa chọn" mờ).
class FormTapField extends StatelessWidget {
  final String text;
  final bool hasValue;
  final String hintText;
  final String? errorText;
  final VoidCallback? onTap;
  final Widget? suffixIcon;
  final bool readOnly;

  const FormTapField({
    super.key,
    required this.text,
    required this.hasValue,
    required this.hintText,
    this.errorText,
    this.onTap,
    this.suffixIcon,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: formFieldDecoration(
          hintText: hintText,
          isDark: isDark,
          errorText: errorText,
          suffixIcon: suffixIcon,
          readOnly: readOnly,
        ),
        child: Text(
          text,
          style: AppTypography.bodyMedium(
            color: hasValue
                ? (isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                : (isDark ? AppColors.darkOutline : AppColors.outlineVariant),
          ),
        ),
      ),
    );
  }
}

/// Ô chọn một kiểu xổ xuống — [items] do màn chứa dựng (giữ kiểu giá trị riêng).
class FormDropdown<T> extends StatelessWidget {
  final T? initialValue;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String hintText;
  final String? errorText;
  final FocusNode? focusNode;
  final bool isExpanded;
  final bool readOnly;

  const FormDropdown({
    super.key,
    required this.initialValue,
    required this.items,
    required this.onChanged,
    required this.hintText,
    this.errorText,
    this.focusNode,
    this.isExpanded = false,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<T>(
      focusNode: focusNode,
      initialValue: initialValue,
      items: items,
      isExpanded: isExpanded,
      style: formFieldTextStyle(isDark),
      dropdownColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest,
      decoration: formFieldDecoration(hintText: hintText, isDark: isDark, errorText: errorText, readOnly: readOnly),
      onChanged: onChanged,
    );
  }
}

/// Khung viền bo của nhóm lựa chọn dạng danh sách (đỏ khi lỗi).
class _ChoiceListFrame extends StatelessWidget {
  final bool hasError;
  final List<Widget> children;

  const _ChoiceListFrame({required this.hasError, required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: hasError ? AppColors.error : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
        ),
      ),
      child: Column(children: children),
    );
  }
}

/// Chọn một — danh sách nút tròn trong khung. [selectedKey] so theo `value.toString()`.
class FormRadioGroup extends StatelessWidget {
  final List<FormChoiceOption> options;
  final String? selectedKey;
  final ValueChanged<Object?>? onChanged;
  final bool hasError;

  const FormRadioGroup({
    super.key,
    required this.options,
    required this.selectedKey,
    required this.onChanged,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _ChoiceListFrame(
      hasError: hasError,
      children: options.map((opt) {
        // ignore: deprecated_member_use
        return RadioListTile<String>(
          title: Text(opt.label, style: formFieldTextStyle(isDark)),
          value: opt.value.toString(),
          // ignore: deprecated_member_use
          groupValue: selectedKey,
          activeColor: AppColors.primary,
          // ignore: deprecated_member_use
          onChanged: onChanged == null ? null : (_) => onChanged!(opt.value),
        );
      }).toList(),
    );
  }
}

/// Chọn nhiều — danh sách ô tick trong khung.
class FormCheckboxGroup extends StatelessWidget {
  final List<FormChoiceOption> options;
  final bool Function(Object? value) isChecked;
  final void Function(Object? value, bool checked)? onChanged;
  final bool hasError;

  const FormCheckboxGroup({
    super.key,
    required this.options,
    required this.isChecked,
    required this.onChanged,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _ChoiceListFrame(
      hasError: hasError,
      children: options.map((opt) {
        return CheckboxListTile(
          title: Text(opt.label, style: formFieldTextStyle(isDark)),
          value: isChecked(opt.value),
          activeColor: AppColors.primary,
          onChanged: onChanged == null ? null : (checked) => onChanged!(opt.value, checked == true),
        );
      }).toList(),
    );
  }
}

/// Chọn nhiều — các thẻ chọn xếp hàng.
class FormChipGroup extends StatelessWidget {
  final List<FormChoiceOption> options;
  final bool Function(Object? value) isSelected;
  final void Function(Object? value, bool selected)? onSelected;

  const FormChipGroup({super.key, required this.options, required this.isSelected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final chon = isSelected(opt.value);
        return FilterChip(
          label: Text(opt.label),
          selected: chon,
          selectedColor: isDark
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.primaryContainer.withValues(alpha: 0.3),
          checkmarkColor: isDark ? AppColors.primaryFixedDim : AppColors.primary,
          labelStyle: TextStyle(
            color: chon
                ? (isDark ? AppColors.primaryFixedDim : AppColors.primary)
                : (isDark ? AppColors.darkOnSurface : AppColors.onSurface),
            fontWeight: chon ? FontWeight.w600 : FontWeight.normal,
          ),
          onSelected: onSelected == null ? null : (s) => onSelected!(opt.value, s),
        );
      }).toList(),
    );
  }
}

/// Có/không — công tắc trong khung, nhãn ([title]) nằm trong khung.
class FormSwitchTile extends StatelessWidget {
  final Widget title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool hasError;

  const FormSwitchTile({super.key, required this.title, required this.value, required this.onChanged, this.hasError = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasError ? AppColors.error : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
        ),
      ),
      child: SwitchListTile(
        tileColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: title,
        value: value,
        activeThumbColor: AppColors.primary,
        onChanged: onChanged,
      ),
    );
  }
}

/// Huy hiệu số ảnh của ô ảnh ("2/10 ảnh · tối thiểu 3") — đỏ khi chưa đủ tối thiểu, màu chính khi đã đủ tối đa.
class FormPhotoCountBadge extends StatelessWidget {
  final int count;
  final int max;
  final int min;

  const FormPhotoCountBadge({super.key, required this.count, required this.max, this.min = 0});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        min > 0 ? '$count/$max ảnh · tối thiểu $min' : '$count/$max ảnh',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: AppTypography.labelSmall(
          color: count > 0 && count < min
              ? AppColors.error
              : count >= max
                  ? AppColors.primary
                  : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
        ).copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Khung chứa ảnh đã chụp + nút chụp của ô ảnh (đỏ đậm khi lỗi).
class FormPhotoFrame extends StatelessWidget {
  final bool hasError;
  final Widget child;

  const FormPhotoFrame({super.key, required this.hasError, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasError ? AppColors.error : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
          width: hasError ? 1.5 : 1.0,
        ),
      ),
      child: child,
    );
  }
}
