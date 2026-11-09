import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/form_fields/form_field_parts.dart';
import '../models/dynamic_form_field.dart';

/// Vỏ một ô của form động — CÙNG cách vẽ biểu mẫu khảo sát/thu thập (#24756): [FormFieldLabel] (huy hiệu ngay sau tên
/// ô) → [gap] → ô → dòng lỗi [FormFieldErrorText]; cách ô sau [kFormFieldSpacing]. Ô có viền nhập hiện lỗi
/// trong viền (`formFieldDecoration(errorText:)`) và KHÔNG truyền [errorText] vào đây.
class DynamicFormFieldWrapper extends StatelessWidget {
  final DynamicFormField field;
  final Widget child;
  final String? errorText;
  final double gap;

  const DynamicFormFieldWrapper({
    super.key,
    required this.field,
    required this.child,
    this.errorText,
    this.gap = kFormLabelGap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kFormFieldSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FormFieldLabel(
            label: field.label,
            isRequired: field.isRequired,
            description: field.description,
            asTextWidget: true,
            trailing: DynamicFieldBadge.of(field),
          ),
          SizedBox(height: gap),
          child,
          if (errorText != null && errorText!.isNotEmpty) FormFieldErrorText(errorText!),
        ],
      ),
    );
  }
}

/// Huy hiệu ngay sau tên ô: [DynamicFormField.badge]; `null` = không có. Ô khoá KHÔNG còn tag "Chỉ đọc" (chủ hệ thống bỏ
/// 09/11/2026) — ô khoá tự hiện xám, không bấm được.
class DynamicFieldBadge extends StatelessWidget {
  final String text;

  const DynamicFieldBadge(this.text, {super.key});

  static Widget? of(DynamicFormField field) {
    final t = field.badge?.trim() ?? '';
    return t.isEmpty ? null : DynamicFieldBadge(t);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHigh,
        borderRadius: AppRadius.roundedSm,
      ),
      child: Text(
        text,
        style: AppTypography.labelSmall(
          color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
        ).copyWith(fontSize: 10),
      ),
    );
  }
}
