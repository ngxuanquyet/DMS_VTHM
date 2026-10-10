import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../localization/app_language.dart';
import '../localization/app_strings.dart';
import '../services/app_notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

enum NotificationDialogType {
  /// Quyền bị từ chối thông thường
  permissionDenied,

  /// Đã bị từ chối vĩnh viễn (cần mở Cài đặt ứng dụng để bật lại)
  permissionDeniedForever,
}

/// Dialog chuyên dụng khi quyền Thông báo chưa được cấp hoặc bị từ chối,
/// giải thích rõ mục đích và cung cấp nút mở Cài đặt để nhân viên bật quyền.
class NotificationPermissionDialog extends StatelessWidget {
  final NotificationDialogType type;
  final VoidCallback onOpenSettings;
  final VoidCallback? onDismiss;
  final AppStrings? strings;

  // ignore: prefer_const_constructors_in_immutables
  NotificationPermissionDialog({
    super.key,
    required this.type,
    VoidCallback? onOpenSettings,
    VoidCallback? onPrimaryAction,
    this.onDismiss,
    this.strings,
  }) : onOpenSettings = onOpenSettings ?? onPrimaryAction ?? openAppSettings;

  static bool isShowing = false;
  static BuildContext? _activeDialogContext;
  static DateTime? _lastPromptTime;

  /// Hiển thị Dialog thông báo quyền nhận thông báo bị từ chối
  static Future<void> show(
    BuildContext context, {
    required NotificationDialogType type,
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
          child: NotificationPermissionDialog(
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

  /// Helper kiểm tra trạng thái và yêu cầu quyền thông báo.
  /// Nếu chưa có quyền:
  /// - Thử yêu cầu hệ thống
  /// - Nếu vẫn chưa có hoặc đã bị chặn vĩnh viễn: hiển thị Dialog giải thích và mở Cài đặt.
  /// [cooldown]: thời gian giãn cách giữa các lần tự động hiện Dialog (mặc định 10 phút để tránh làm phiền).
  static Future<bool> checkAndRequestPermission(
    BuildContext context, {
    AppStrings? strings,
    Duration cooldown = const Duration(minutes: 10),
    bool ignoreCooldown = false,
  }) async {
    try {
      final status = await Permission.notification.status;

      if (status.isGranted) {
        // Đã có quyền -> Đồng bộ lại lịch hẹn thông báo nền với Hệ điều hành
        await AppNotificationService().setupDefaultWeeklySchedules();
        return true;
      }

      // Kiểm tra cooldown để không gây phiền khi nhân viên vừa bấm 'Để sau'
      final now = DateTime.now();
      if (!ignoreCooldown && _lastPromptTime != null) {
        if (now.difference(_lastPromptTime!) < cooldown) {
          return false;
        }
      }
      _lastPromptTime = now;

      if (status.isPermanentlyDenied) {
        if (context.mounted) {
          show(
            context,
            type: NotificationDialogType.permissionDeniedForever,
            strings: strings,
            onOpenSettings: () => openAppSettings(),
          );
        }
        return false;
      }

      // Yêu cầu quyền hệ thống (Android 13+ & iOS sẽ hiện popup của OS)
      final result = await Permission.notification.request();
      if (result.isGranted) {
        await AppNotificationService().setupDefaultWeeklySchedules();
        return true;
      }

      // Người dùng từ chối -> Hiện dialog giải thích
      if (context.mounted) {
        show(
          context,
          type: result.isPermanentlyDenied
              ? NotificationDialogType.permissionDeniedForever
              : NotificationDialogType.permissionDenied,
          strings: strings,
          onOpenSettings: () => openAppSettings(),
        );
      }

      return false;
    } catch (e) {
      debugPrint('[NotificationPermissionDialog] Lỗi kiểm tra quyền thông báo: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = strings ?? const AppStrings(AppLanguage.vi);

    final isForever = type == NotificationDialogType.permissionDeniedForever;
    final title = isForever
        ? s.notificationPermissionDeniedForeverTitle
        : s.notificationPermissionDeniedTitle;
    final description = isForever
        ? s.notificationPermissionDeniedForeverDesc
        : s.notificationPermissionDeniedDesc;
    final buttonText = isForever ? s.goToSettingsAction : s.enableNotificationAction;
    final iconData = isForever ? Icons.notifications_off_rounded : Icons.notifications_active_rounded;
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
            // Icon Bell Header
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

            // Lợi ích cốt lõi của thông báo
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
                    icon: Icons.alarm_rounded,
                    color: AppColors.primary,
                    text: 'Nhắc Vào ca (07:50) & Ra ca (17:00) đúng giờ',
                  ),
                  const SizedBox(height: 8),
                  _buildBenefitRow(
                    context,
                    icon: Icons.alt_route_rounded,
                    color: AppColors.tertiary,
                    text: 'Cảnh báo tiến độ lộ trình & gợi ý điểm bán',
                  ),
                  const SizedBox(height: 8),
                  _buildBenefitRow(
                    context,
                    icon: Icons.sync_rounded,
                    color: AppColors.secondary,
                    text: 'Nhắc nhở đồng bộ dữ liệu tránh thất thoát công',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Option 1: "ĐI ĐẾN CÀI ĐẶT" / "BẬT THÔNG BÁO" (Primary CTA)
            AppButton(
              text: buttonText,
              icon: isForever ? Icons.settings_outlined : Icons.check_circle_outline_rounded,
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
