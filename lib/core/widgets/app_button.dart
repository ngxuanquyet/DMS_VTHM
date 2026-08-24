import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum AppButtonVariant { primary, secondary, outline, text, error }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final Widget? trailingIcon;
  final bool isLoading;
  final double? width;
  final double height;
  final EdgeInsetsGeometry? padding;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.width,
    this.height = 48,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color fgColor;
    BorderSide borderSide = BorderSide.none;

    switch (variant) {
      case AppButtonVariant.primary:
        bgColor = AppColors.primaryContainer;
        fgColor = AppColors.onPrimary;
        break;
      case AppButtonVariant.secondary:
        bgColor = AppColors.secondary;
        fgColor = AppColors.onSecondary;
        break;
      case AppButtonVariant.outline:
        bgColor = Colors.transparent;
        fgColor = AppColors.primary;
        borderSide = const BorderSide(color: AppColors.outlineVariant, width: 1);
        break;
      case AppButtonVariant.text:
        bgColor = Colors.transparent;
        fgColor = AppColors.primary;
        break;
      case AppButtonVariant.error:
        bgColor = AppColors.errorContainer.withValues(alpha: 0.2);
        fgColor = AppColors.error;
        borderSide = const BorderSide(color: AppColors.error, width: 1);
        break;
    }

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: onPressed == null ? bgColor.withValues(alpha: 0.5) : bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.roundedMd,
          side: borderSide,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          child: Padding(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: fgColor,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 20, color: fgColor),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          text,
                          style: AppTypography.titleMedium(color: fgColor).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (trailingIcon != null) ...[
                          const SizedBox(width: 8),
                          trailingIcon!,
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
