import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../../../../core/services/app_notification_service.dart';
import '../../../../core/widgets/notification_permission_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../viewmodels/profile_view_model.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with WidgetsBindingObserver {
  bool _notifGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNotificationStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNotificationStatus();
    }
  }

  Future<void> _checkNotificationStatus() async {
    try {
      final isGranted = await Permission.notification.isGranted;
      if (mounted) {
        setState(() => _notifGranted = isGranted);
      }
    } catch (_) {}
  }

  void _showNotificationStatusDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedLg),
        title: Row(
          children: [
            const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            Text('Thông báo hệ thống', style: AppTypography.titleMedium().copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quyền thông báo đã được kích hoạt. Các lịch nhắc nhở sau đang hoạt động tự động ngay cả khi tắt app:',
              style: AppTypography.bodyMedium().copyWith(height: 1.45),
            ),
            const SizedBox(height: 12),
            _buildDialogScheduleItem(Icons.alarm_rounded, 'Nhắc Vào ca: 07:50 (Thứ 2 - Thứ 7)'),
            const SizedBox(height: 6),
            _buildDialogScheduleItem(Icons.alarm_off_rounded, 'Nhắc Ra ca: 17:00 (Thứ 2 - Thứ 7)'),
            const SizedBox(height: 6),
            _buildDialogScheduleItem(Icons.alt_route_rounded, 'Cảnh báo lộ trình & đồng bộ dữ liệu'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryContainer.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bạn có thể hẹn giờ 10 giây rồi thoát hẳn app để kiểm tra chuông khi tắt app.',
                      style: AppTypography.bodySmall(color: isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                          .copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.timer_outlined, size: 16),
            label: const Text('Thử khi TẮT APP (10s)'),
            onPressed: () async {
              Navigator.pop(ctx);
              await _startBackgroundTestFlow(seconds: 10);
            },
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AppNotificationService().sendTestNotification();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã phát thông báo tức thì! Kiểm tra khay thông báo.'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
            child: const Text('Thử tức thì'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _startBackgroundTestFlow({int seconds = 10}) async {
    await AppNotificationService().scheduleTestNotificationAfterSeconds(seconds: seconds);
    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedLg),
        title: const Row(
          children: [
            Icon(Icons.hourglass_top_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 10),
            Text('Đã hẹn giờ thử khi tắt app!', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hệ thống đã lên lịch thông báo sau $seconds giây nữa.',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              '👉 BÂY GIỜ HÃY:\n'
              '1. Bấm nút Home hoặc vuốt TẮT HẲN APP (Kill app khỏi đa nhiệm).\n'
              '2. Khóa màn hình điện thoại lại.\n'
              '3. Đợi đúng 10 giây để xem chuông và thông báo tự động xuất hiện trên màn hình khóa!',
              style: TextStyle(height: 1.5, fontSize: 13.5),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ĐÃ HIỂU, TÔI TẮT APP NGAY'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogScheduleItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }


  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Text(content, style: const TextStyle(height: 1.5)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showLanguageSelector(BuildContext context) {
    final currentLang = ref.read(languageProvider);
    final strings = ref.read(stringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      strings.selectLanguage,
                      style: AppTypography.titleMedium(
                        color: isDark
                            ? AppColors.darkOnSurface
                            : AppColors.onSurface,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      color: isDark
                          ? AppColors.darkOnSurfaceVariant
                          : AppColors.outline,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildLanguageOption(
                  context: ctx,
                  language: AppLanguage.vi,
                  isSelected: currentLang == AppLanguage.vi,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildLanguageOption(
                  context: ctx,
                  language: AppLanguage.en,
                  isSelected: currentLang == AppLanguage.en,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required AppLanguage language,
    required bool isSelected,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ref.read(languageProvider.notifier).setLanguage(language);
          Navigator.pop(context);
        },
        borderRadius: AppRadius.roundedMd,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                      ? AppColors.primaryContainer.withValues(alpha: 0.2)
                      : AppColors.primaryContainer.withValues(alpha: 0.12))
                : (isDark
                      ? AppColors.darkSurfaceContainer
                      : AppColors.surfaceContainerLow),
            borderRadius: AppRadius.roundedMd,
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Text(language.flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  language.title,
                  style:
                      AppTypography.bodyLarge(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                  ? AppColors.darkOnSurface
                                  : AppColors.onSurface),
                      ).copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileViewModelProvider);
    final profileVM = ref.read(profileViewModelProvider.notifier);
    final strings = ref.watch(stringsProvider);
    final currentLang = ref.watch(languageProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: const VthmTopAppBar(),
      body: RefreshIndicator(
        color: AppColors.primaryContainer,
        onRefresh: () => profileVM.loadProfile(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.marginMobile,
            vertical: AppSpacing.stackMd,
          ),
          child: Column(
            children: [
              // Profile Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkSurfaceContainer
                              : Colors.white,
                          width: 3,
                        ),
                        boxShadow: AppShadows.level2,
                      ),
                      child: ClipOval(
                        child: Image.network(
                          profileState.profile?.avatarUrl ??
                              AppConstants.userAvatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.person,
                            size: 48,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profileState.profile?.name ?? strings.unknown,
                      style: AppTypography.headlineSmall(
                        color: isDark
                            ? AppColors.darkOnSurface
                            : AppColors.onSurface,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceContainer
                            : AppColors.surfaceContainerHigh,
                        borderRadius: AppRadius.roundedSm,
                      ),
                      child: Text(
                        '${strings.employeeCodePrefix}${profileState.profile?.employeeId ?? strings.unknown}',
                        style: AppTypography.labelSmall(
                          color: isDark
                              ? AppColors.darkOnSurfaceVariant
                              : AppColors.onSurfaceVariant,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Role & Department Cards
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: AppRadius.roundedMd,
                              border: Border.all(
                                color: AppColors.primaryContainer.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  strings.roleLabel,
                                  style:
                                      AppTypography.labelSmall(
                                        color: isDark
                                            ? AppColors.darkOnSurfaceVariant
                                            : AppColors.onSurfaceVariant,
                                      ).copyWith(
                                        letterSpacing: 0.8,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  profileState.profile?.role ?? strings.unknown,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelLarge(
                                    color: isDark
                                        ? AppColors.primaryFixedDim
                                        : AppColors.onPrimaryContainer,
                                  ).copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryContainer.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: AppRadius.roundedMd,
                              border: Border.all(
                                color: AppColors.secondaryContainer.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  strings.departmentLabel,
                                  style:
                                      AppTypography.labelSmall(
                                        color: isDark
                                            ? AppColors.darkOnSurfaceVariant
                                            : AppColors.onSurfaceVariant,
                                      ).copyWith(
                                        letterSpacing: 0.8,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  profileState.profile?.department ??
                                      strings.unknown,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelLarge(
                                    color: isDark
                                        ? AppColors.secondaryFixed
                                        : AppColors.secondary,
                                  ).copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.stackLg),

              // Section 1: Tài khoản
              _buildSectionTitle(strings.accountSection, isDark),
              const SizedBox(height: 6),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildMenuItem(
                      icon: Icons.person_outline,
                      title: strings.personalInfo,
                      onTap: () {
                        context.push('/profile/personal-info');
                      },
                      isDark: isDark,
                    ),
                    const Divider(height: 1),
                    _buildMenuItem(
                      icon: Icons.two_wheeler_rounded,
                      title: 'Quãng đường của tôi',
                      onTap: () {
                        context.push('/travel');
                      },
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.stackLg),

              // Section 2: Cài đặt ứng dụng
              _buildSectionTitle(strings.appSettingsSection, isDark),
              const SizedBox(height: 6),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildMenuItem(
                      icon: Icons.language,
                      title: strings.languageTitle,
                      trailing: Text(
                        currentLang.title,
                        style: AppTypography.bodyMedium(
                          color: isDark
                              ? AppColors.primaryFixedDim
                              : AppColors.primary,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      onTap: () => _showLanguageSelector(context),
                      isDark: isDark,
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceContainerLowest
                                  : AppColors.surfaceContainer,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.dark_mode_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              strings.darkMode,
                              style: AppTypography.bodyLarge(
                                color: isDark
                                    ? AppColors.darkOnSurface
                                    : AppColors.onSurface,
                              ),
                            ),
                          ),
                          Switch(
                            value: profileState.isDarkMode,
                            activeTrackColor: AppColors.primaryContainer,
                            onChanged: (val) {
                              profileVM.toggleDarkMode(val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    _buildMenuItem(
                      icon: Icons.notifications_none_rounded,
                      title: 'Thông báo & Nhắc nhở',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _notifGranted
                                  ? AppColors.primaryContainer.withValues(alpha: 0.25)
                                  : AppColors.errorContainer.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _notifGranted ? 'Đã bật' : 'Chưa bật',
                              style: AppTypography.labelSmall(
                                color: _notifGranted ? AppColors.primary : AppColors.error,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
                          ),
                        ],
                      ),
                      onTap: () async {
                        final isGranted = await Permission.notification.isGranted;
                        if (!isGranted) {
                          if (context.mounted) {
                            final res = await NotificationPermissionDialog.checkAndRequestPermission(
                              context,
                              ignoreCooldown: true,
                            );
                            if (mounted) setState(() => _notifGranted = res);
                          }
                        } else {
                          if (context.mounted) {
                            _showNotificationStatusDialog();
                          }
                        }
                      },
                      isDark: isDark,
                    ),
                    const Divider(height: 1),
                    _buildMenuItem(
                      icon: Icons.shield_outlined,
                      title: strings.privacyPolicy,
                      onTap: () {
                        _showInfoDialog(
                          strings.privacyPolicy,
                          'Ứng dụng VTHM DMS tuân thủ nghiêm ngặt các quy định bảo mật dữ liệu doanh nghiệp và định vị GPS trong thời gian làm việc. Mọi dữ liệu tuyến đường và hình ảnh điểm bán được lưu trữ an toàn trên hệ thống máy chủ nội bộ VTHM Group.',
                        );
                      },
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.stackLg),

              // Section 3: Hỗ trợ
              _buildSectionTitle(strings.supportFeedback.toUpperCase(), isDark),
              const SizedBox(height: 6),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildMenuItem(
                      icon: Icons.help_outline,
                      title: strings.helpGuide,
                      onTap: () {
                        _showInfoDialog(
                          strings.helpGuide,
                          'Hướng dẫn sử dụng nhanh VTHM DMS:\n\n1. Chấm công: Bấm vào thẻ Chấm công để Check-in/Check-out khi đến văn phòng/chi nhánh.\n2. Tuyến bán hàng: Xem danh sách đại lý cần ghé thăm trong ngày và lộ trình bản đồ.\n3. Điểm bán: Check-in tại đại lý để chụp ảnh trưng bày và điền biểu mẫu.\n4. Liên hệ IT hỗ trợ qua hotline nội bộ hoặc tổng đài VTHM.',
                        );
                      },
                      isDark: isDark,
                    ),
                    const Divider(height: 1),
                    _buildMenuItem(
                      icon: Icons.article_outlined,
                      title: strings.termsOfService,
                      onTap: () {
                        _showInfoDialog(
                          strings.termsOfService,
                          'Điều khoản sử dụng phần mềm VTHM DMS:\n\n- Ứng dụng dành riêng cho CBNV VTHM Group phục vụ công tác quản lý thị trường.\n- Nghiêm cấm chia sẻ thông tin khách hàng và lộ trình ra bên ngoài doanh nghiệp.\n- Vui lòng duy trì GPS và kết nối Internet trong suốt ca làm việc để dữ liệu đồng bộ chính xác.',
                        );
                      },
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.stackLg),

              // Logout Button
              AppButton(
                text: strings.logout.toUpperCase(),
                variant: AppButtonVariant.error,
                icon: Icons.logout_rounded,
                width: double.infinity,
                height: 48,
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(strings.logoutConfirmTitle),
                      content: Text(strings.logoutConfirmMessage),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(strings.cancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(
                            strings.logout,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && context.mounted) {
                    await ref.read(authViewModelProvider.notifier).logout();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  }
                },
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(
                  AppConstants.appVersionBuild,
                  style: AppTypography.labelSmall(
                    color: isDark
                        ? AppColors.darkOnSurfaceVariant
                        : AppColors.outline,
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Text(
          title,
          style: AppTypography.labelSmall(
            color: isDark
                ? AppColors.darkOnSurfaceVariant
                : AppColors.onSurfaceVariant,
          ).copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceContainerLowest
              : AppColors.surfaceContainer,
          shape: BoxShape.circle,
        ),
        child: Center(child: Icon(icon, color: AppColors.primary, size: 20)),
      ),
      title: Text(
        title,
        style: AppTypography.bodyLarge(
          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) ...[trailing, const SizedBox(width: 6)],
          const Icon(Icons.chevron_right, color: AppColors.outline, size: 20),
        ],
      ),
    );
  }
}
