import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../localization/app_language.dart';
import '../localization/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

enum MicrophoneDialogType {
  /// Quyền bị từ chối
  permissionDenied,

  /// Đã bị từ chối vĩnh viễn (cần mở Cài đặt ứng dụng để bật lại)
  permissionDeniedForever,
}

/// Dialog chuyên dụng khi quyền Microphone bị từ chối,
/// cung cấp tùy chọn đi đến Cài đặt để người dùng cấp quyền.
class MicrophonePermissionDialog extends StatelessWidget {
  final MicrophoneDialogType type;
  final VoidCallback onOpenSettings;
  final VoidCallback? onDismiss;
  final AppStrings? strings;

  MicrophonePermissionDialog({
    super.key,
    required this.type,
    VoidCallback? onOpenSettings,
    VoidCallback? onPrimaryAction,
    this.onDismiss,
    this.strings,
  }) : onOpenSettings = onOpenSettings ?? onPrimaryAction ?? openAppSettings;

  static bool isShowing = false;
  static BuildContext? _activeDialogContext;

  /// Hiển thị Dialog thông báo quyền truy cập Microphone bị từ chối
  /// kèm tùy chọn đi đến Cài đặt để cấp quyền.
  static Future<void> show(
    BuildContext context, {
    required MicrophoneDialogType type,
    VoidCallback? onOpenSettings,
    VoidCallback? onPrimaryAction,
    VoidCallback? onDismiss,
    AppStrings? strings,
  }) {
    if (isShowing) {
      dismiss();
    }

    isShowing = true;
    final effectiveOpenSettings =
        onOpenSettings ?? onPrimaryAction ?? () => openAppSettings();

    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        _activeDialogContext = ctx;
        return PopScope(
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              isShowing = false;
              _activeDialogContext = null;
              onDismiss?.call();
            }
          },
          child: MicrophonePermissionDialog(
            type: type,
            strings: strings,
            onOpenSettings: effectiveOpenSettings,
            onDismiss: () {
              isShowing = false;
              _activeDialogContext = null;
              onDismiss?.call();
            },
          ),
        );
      },
    ).then((_) {
      isShowing = false;
      _activeDialogContext = null;
    });
  }

  static void dismiss() {
    if (isShowing) {
      if (_activeDialogContext != null && _activeDialogContext!.mounted) {
        try {
          Navigator.of(_activeDialogContext!).pop();
        } catch (_) {}
      }
      isShowing = false;
      _activeDialogContext = null;
    }
  }

  /// Helper kiểm tra và yêu cầu quyền microphone trước khi ghi âm
  /// Trả về true nếu đã có quyền, false nếu chưa có (kèm dialog hướng dẫn)
  static Future<bool> checkAndRequestPermission(
    BuildContext context, {
    AppStrings? strings,
  }) async {
    // 1. Kiểm tra trạng thái quyền microphone hiện tại
    final status = await Permission.microphone.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      if (context.mounted) {
        show(
          context,
          type: MicrophoneDialogType.permissionDeniedForever,
          strings: strings,
          onOpenSettings: () => openAppSettings(),
        );
      }
      return false;
    }

    // Nếu chưa cấp hoặc bị từ chối -> Gọi request hệ thống
    final result = await Permission.microphone.request();
    if (result.isGranted) {
      return true;
    }

    // Khi người dùng từ chối (hoặc đã bị từ chối trước đó):
    // Hiển thị dialog thông báo kèm option đi đến Cài đặt để người dùng cấp quyền
    if (context.mounted) {
      show(
        context,
        type: result.isPermanentlyDenied
            ? MicrophoneDialogType.permissionDeniedForever
            : MicrophoneDialogType.permissionDenied,
        strings: strings,
        onOpenSettings: () => openAppSettings(),
      );
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = strings ?? const AppStrings(AppLanguage.vi);

    final isForever = type == MicrophoneDialogType.permissionDeniedForever;
    final title = isForever
        ? s.micPermissionDeniedForeverTitle
        : s.micPermissionDeniedTitle;
    final description = isForever
        ? s.micPermissionDeniedForeverDesc
        : s.micPermissionDeniedDesc;
    final buttonText = s.goToSettingsAction;
    final iconData = isForever ? Icons.mic_off_rounded : Icons.mic_off_outlined;
    final iconColor = isForever ? AppColors.error : AppColors.secondary;
    final iconBgColor = isForever
        ? AppColors.errorContainer.withValues(alpha: 0.35)
        : AppColors.secondaryContainer.withValues(alpha: 0.35);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceContainer
              : AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.roundedXl,
          boxShadow: AppShadows.level3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Microphone Icon Header
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  iconData,
                  color: iconColor,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.headlineSmall(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium(
                  color: isDark
                      ? AppColors.darkOnSurfaceVariant
                      : AppColors.onSurfaceVariant,
                ).copyWith(height: 1.4),
              ),
            ),
            const SizedBox(height: 24),

            // Option 1: "ĐI ĐẾN CÀI ĐẶT" (Primary CTA)
            AppButton(
              text: buttonText,
              icon: Icons.settings_outlined,
              width: double.infinity,
              height: 48,
              onPressed: () {
                Navigator.of(context).pop();
                onOpenSettings();
              },
            ),
            const SizedBox(height: 8),

            // Option 2: "Để sau" (Dismiss)
            SizedBox(
              width: double.infinity,
              height: 40,
              child: TextButton(
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.roundedMd,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  onDismiss?.call();
                },
                child: Text(
                  s.laterAction,
                  style: AppTypography.labelLarge(
                    color: isDark
                        ? AppColors.primaryFixedDim
                        : AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
