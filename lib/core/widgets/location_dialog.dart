import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

enum LocationDialogType {
  serviceDisabled, // GPS tắt trên thiết bị
  permissionDenied, // Chưa cấp quyền (có thể hiện popup xin quyền hệ thống)
  permissionDeniedForever, // Đã từ chối vĩnh viễn (cần mở Settings)
}

class LocationPermissionDialog extends StatelessWidget {
  final LocationDialogType type;
  final AppStrings strings;
  final VoidCallback onPrimaryAction;
  final VoidCallback? onDismiss;

  const LocationPermissionDialog({
    super.key,
    required this.type,
    required this.strings,
    required this.onPrimaryAction,
    this.onDismiss,
  });

  static bool isShowing = false;
  static LocationDialogType? currentDialogType;
  static BuildContext? _activeDialogContext;

  static Future<void> show(
    BuildContext context, {
    required LocationDialogType type,
    required AppStrings strings,
    required VoidCallback onPrimaryAction,
    VoidCallback? onDismiss,
  }) {
    if (isShowing) {
      if (currentDialogType == type) {
        return Future.value();
      }
      // If switching dialog type, dismiss previous one first
      dismiss();
    }

    isShowing = true;
    currentDialogType = type;

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
              currentDialogType = null;
              _activeDialogContext = null;
              onDismiss?.call();
            }
          },
          child: LocationPermissionDialog(
            type: type,
            strings: strings,
            onPrimaryAction: onPrimaryAction,
            onDismiss: () {
              isShowing = false;
              currentDialogType = null;
              _activeDialogContext = null;
              onDismiss?.call();
            },
          ),
        );
      },
    ).then((_) {
      isShowing = false;
      currentDialogType = null;
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
      currentDialogType = null;
      _activeDialogContext = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String title;
    final String description;
    final String buttonText;
    final IconData iconData;
    final Color iconColor;
    final Color iconBgColor;

    switch (type) {
      case LocationDialogType.serviceDisabled:
        title = strings.locationServiceDisabledTitle;
        description = strings.locationServiceDisabledDesc;
        buttonText = strings.enableGpsAction;
        iconData = Icons.location_off_rounded;
        iconColor = AppColors.secondary;
        iconBgColor = AppColors.secondaryContainer.withValues(alpha: 0.35);
        break;
      case LocationDialogType.permissionDeniedForever:
        title = strings.locationPermissionDeniedTitle;
        description = strings.locationPermissionDeniedForeverDesc;
        buttonText = strings.openSettingsAction;
        iconData = Icons.wrong_location_rounded;
        iconColor = AppColors.error;
        iconBgColor = AppColors.errorContainer.withValues(alpha: 0.35);
        break;
      case LocationDialogType.permissionDenied:
        title = strings.locationPermissionDeniedTitle;
        description = strings.locationPermissionDeniedDesc;
        buttonText = strings.grantPermissionAction;
        iconData = Icons.near_me_disabled_rounded;
        iconColor = AppColors.primary;
        iconBgColor = AppColors.primaryContainer.withValues(alpha: 0.25);
        break;
    }

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
            // Location Warning Icon Header
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
                  size: 32,
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
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
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

            // Primary CTA Button
            AppButton(
              text: buttonText,
              width: double.infinity,
              height: 48,
              onPressed: () {
                Navigator.of(context).pop();
                onPrimaryAction();
              },
            ),
            const SizedBox(height: 8),

            // Secondary "Đóng" button
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
                  strings.close,
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
