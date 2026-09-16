import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../models/dynamic_form_field.dart';

class DynamicFormFieldWrapper extends StatelessWidget {
  final DynamicFormField field;
  final Widget child;
  final String? errorText;

  const DynamicFormFieldWrapper({
    super.key,
    required this.field,
    required this.child,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label Row with Required marker & ReadOnly badge
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    text: field.label,
                    style: AppTypography.labelLarge(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ).copyWith(fontWeight: FontWeight.w600),
                    children: [
                      if (field.isRequired)
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
              if (field.isReadOnly)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceContainer
                        : AppColors.surfaceContainerHigh,
                    borderRadius: AppRadius.roundedSm,
                  ),
                  child: Text(
                    'Chỉ đọc',
                    style: AppTypography.labelSmall(
                      color: isDark
                          ? AppColors.darkOnSurfaceVariant
                          : AppColors.onSurfaceVariant,
                    ).copyWith(fontSize: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Main Field Input
          child,

          // Helper Text or Error Text
          if (errorText != null && errorText!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 13, color: AppColors.error),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    errorText!,
                    style: AppTypography.bodySmall(color: AppColors.error).copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
          ] else if (field.helperText != null && field.helperText!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              field.helperText!,
              style: AppTypography.bodySmall(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
              ).copyWith(fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
