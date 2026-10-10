import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../localization/app_language.dart';
import '../localization/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';
import '../services/route_restoration_service.dart';

enum CameraDialogType {
  /// Quyền bị từ chối
  permissionDenied,

  /// Đã bị từ chối vĩnh viễn (cần mở Cài đặt ứng dụng để bật lại)
  permissionDeniedForever,
}

/// Dialog chuyên dụng khi quyền Máy ảnh (Camera) chưa được cấp hoặc bị từ chối,
/// giải thích lý do cần quyền cho các tính năng như chấm công, viếng thăm, chụp ảnh khảo sát
/// kèm nút chuyển thẳng đến Cài đặt ứng dụng để người dùng cấp quyền.
class CameraPermissionDialog extends StatelessWidget {
  final CameraDialogType type;
  final String featureName;
  final String? customDescription;
  final VoidCallback onOpenSettings;
  final VoidCallback? onDismiss;
  final AppStrings? strings;

  // ignore: prefer_const_constructors_in_immutables
  CameraPermissionDialog({
    super.key,
    required this.type,
    this.featureName = 'chụp ảnh',
    this.customDescription,
    VoidCallback? onOpenSettings,
    VoidCallback? onPrimaryAction,
    this.onDismiss,
    this.strings,
  }) : onOpenSettings = onOpenSettings ?? onPrimaryAction ?? openAppSettings;

  static bool isShowing = false;
  static BuildContext? _activeDialogContext;

  /// Hiển thị Dialog thông báo quyền Camera bị từ chối
  static Future<void> show(
    BuildContext context, {
    required CameraDialogType type,
    String featureName = 'chụp ảnh',
    String? customDescription,
    VoidCallback? onOpenSettings,
    VoidCallback? onPrimaryAction,
    VoidCallback? onDismiss,
    AppStrings? strings,
  }) {
    if (isShowing) {
      dismiss();
    }

    isShowing = true;
    final effectiveOpenSettings = onOpenSettings ??
        onPrimaryAction ??
        () async {
          await RouteRestorationService.savePendingRouteFromContext(context);
          await openAppSettings();
        };

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
          child: CameraPermissionDialog(
            type: type,
            featureName: featureName,
            customDescription: customDescription,
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

  /// Helper kiểm tra trạng thái và yêu cầu quyền Camera trước khi thực hiện chụp ảnh.
  /// Trả về true nếu đã có quyền, false nếu chưa có (kèm hiển thị dialog hướng dẫn).
  static Future<bool> checkAndRequestPermission(
    BuildContext context, {
    String featureName = 'chụp ảnh',
    String? customDescription,
    AppStrings? strings,
    VoidCallback? onOpenSettings,
  }) async {
    // 1. Kiểm tra trạng thái quyền Camera hiện tại
    final status = await Permission.camera.status;

    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      if (context.mounted) {
        show(
          context,
          type: CameraDialogType.permissionDeniedForever,
          featureName: featureName,
          customDescription: customDescription,
          strings: strings,
          onOpenSettings: onOpenSettings ?? () => openAppSettings(),
        );
      }
      return false;
    }

    // 2. Yêu cầu quyền hệ thống (OS popup)
    final result = await Permission.camera.request();
    if (result.isGranted || result.isLimited) {
      return true;
    }

    // 3. Nếu người dùng từ chối: hiển thị Dialog giải thích và nút đi đến Cài đặt
    if (context.mounted) {
      show(
        context,
        type: result.isPermanentlyDenied
            ? CameraDialogType.permissionDeniedForever
            : CameraDialogType.permissionDenied,
        featureName: featureName,
        customDescription: customDescription,
        strings: strings,
        onOpenSettings: onOpenSettings ?? () => openAppSettings(),
      );
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = strings ?? const AppStrings(AppLanguage.vi);

    final isForever = type == CameraDialogType.permissionDeniedForever;
    final title = isForever
        ? s.cameraPermissionDeniedForeverTitle
        : 'Cần quyền Máy ảnh cho $featureName';

    final description = customDescription ??
        (isForever
            ? 'Quyền truy cập Máy ảnh đã bị tắt trong Cài đặt thiết bị. Tính năng $featureName cần sử dụng Camera để chụp ảnh thực tế và xác thực dữ liệu. Vui lòng mở Cài đặt để cấp lại quyền.'
            : 'Ứng dụng cần quyền truy cập Máy ảnh để chụp ảnh $featureName thực tế tại hiện trường và đóng dấu thông tin toạ độ/thời gian.');

    final buttonText = s.goToSettingsAction;
    final iconData = isForever ? Icons.no_photography_rounded : Icons.camera_alt_outlined;
    final iconColor = isForever ? AppColors.error : AppColors.primary;
    final iconBgColor = isForever
        ? AppColors.errorContainer.withValues(alpha: 0.35)
        : AppColors.primaryContainer.withValues(alpha: 0.35);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
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
            // Camera Icon Header
            Container(
              width: 64,
              height: 64,
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
            const SizedBox(height: 18),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.headlineSmall(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ).copyWith(fontWeight: FontWeight.w700, fontSize: 19),
            ),
            const SizedBox(height: 10),

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
                ).copyWith(height: 1.45, fontSize: 13.5),
              ),
            ),
            const SizedBox(height: 16),

            // Mục đích sử dụng quyền Camera
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildBenefitRow(
                    context,
                    icon: Icons.camera_enhance_rounded,
                    color: AppColors.primary,
                    text: 'Chụp ảnh thực tế hiện trường (khuôn mặt / điểm bán)',
                  ),
                  const SizedBox(height: 8),
                  _buildBenefitRow(
                    context,
                    icon: Icons.location_on_rounded,
                    color: AppColors.tertiary,
                    text: 'Tự động đóng dấu Watermark toạ độ GPS & thời gian',
                  ),
                  const SizedBox(height: 8),
                  _buildBenefitRow(
                    context,
                    icon: Icons.verified_user_rounded,
                    color: AppColors.secondary,
                    text: 'Bảo vệ quyền lợi ghi nhận công và tiến độ viếng thăm',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Button 1: "ĐI ĐẾN CÀI ĐẶT" (Primary CTA)
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

            // Button 2: "Để sau" (Dismiss)
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

  Widget _buildBenefitRow(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String text,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall(
              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
            ).copyWith(fontWeight: FontWeight.w500, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}
