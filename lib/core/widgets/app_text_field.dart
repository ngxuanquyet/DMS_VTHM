import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'voice_input_mic_button.dart';

class AppTextField extends StatelessWidget {
  final String? label;
  final String? hintText;
  final TextEditingController? controller;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final FocusNode? focusNode;
  final int? maxLines;
  final bool readOnly;
  final bool? enabled;
  final bool enableVoiceInput;

  const AppTextField({
    super.key,
    this.label,
    this.hintText,
    this.controller,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.autofocus = false,
    this.focusNode,
    this.maxLines = 1,
    this.readOnly = false,
    this.enabled,
    this.enableVoiceInput = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget? effectiveSuffix = suffixIcon;
    if (enableVoiceInput && !readOnly) {
      final voiceBtn = VoiceInputMicButton(
        currentText: controller?.text,
        fieldName: label,
        onTextRecognized: (newText) {
          if (controller != null) {
            controller!.text = newText;
          }
          onChanged?.call(newText);
        },
      );

      if (effectiveSuffix != null) {
        effectiveSuffix = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            effectiveSuffix,
            voiceBtn,
          ],
        );
      } else {
        effectiveSuffix = voiceBtn;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTypography.labelLarge(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.stackSm),
        ],
        TextField(
          controller: controller,
          obscureText: obscureText,
          readOnly: readOnly,
          enabled: enabled,
          maxLines: obscureText ? 1 : maxLines,
          onChanged: onChanged,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofocus: autofocus,
          focusNode: focusNode,
          style: AppTypography.bodyLarge(color: AppColors.onSurface),
          decoration: InputDecoration(
            hintText: hintText,
            errorText: errorText,
            prefixIcon: prefixIcon,
            suffixIcon: effectiveSuffix,
          ),
        ),
      ],
    );
  }
}
