import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/screens/error_log_screen.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/offline_sync_badge.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../route/presentation/viewmodels/route_view_model.dart';
import '../../../route/presentation/widgets/active_visit_blocking_dialog.dart';
import '../../../route/presentation/viewmodels/open_visit.dart';
import '../viewmodels/profile_view_model.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _loggingOut = false;

  /// Đăng xuất xoá hàng đợi đồng bộ trong máy ⇒ CHẶN khi còn lượt viếng thăm chưa đóng (phải check-out hoặc huỷ
  /// lượt) hoặc còn mục chưa đồng bộ (phải đồng bộ xong). Mục bị server từ chối (dead) thì cảnh báo sẽ mất trong hộp
  /// xác nhận.
  Future<void> _handleLogout() async {
    if (_loggingOut) return;
    _loggingOut = true;
    try {
      await _logoutFlow();
    } finally {
      _loggingOut = false;
    }
  }

  Future<void> _logoutFlow() async {
    final strings = ref.read(stringsProvider);
    final db = ref.read(appDatabaseProvider);

    if (await _blockedByActiveVisit()) return;

    var pending = await db.countPendingSync();
    while (pending > 0) {
      if (!mounted) return;
      final choice = await showDialog<_PendingChoice>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(strings.logoutBlockedTitle),
          content: Text(strings.logoutBlockedMessage(pending)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(strings.close)),
            TextButton(onPressed: () => Navigator.pop(ctx, _PendingChoice.details), child: Text(strings.viewDetails)),
            TextButton(onPressed: () => Navigator.pop(ctx, _PendingChoice.sync), child: Text(strings.syncNow)),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      if (choice == _PendingChoice.details) {
        // Màn chi tiết hàng đợi dùng chung (badge đồng bộ): xem mục nào đang kẹt, xoá mục lỗi.
        showOfflineSyncModal(context);
        return;
      }
      if (!await _syncAll(db)) return;
      pending = await db.countPendingSync();
      if (!mounted) return;
      if (pending == 0) AppSnackBar.showSuccess(context, strings.logoutSyncDone);
    }

    final dead = await db.countDeadSync();
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.logoutConfirmTitle),
        content: Text(strings.logoutConfirmMessage + (dead > 0 ? strings.logoutDeadWarning(dead) : '')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(strings.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(strings.logout, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    var loggedOut = false;
    try {
      loggedOut = await ref.read(authViewModelProvider.notifier).logout(requireCleared: true);
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
      return;
    }
    if (!mounted) return;
    if (!loggedOut) {
      // Có lượt viếng thăm/mục mới phát sinh trong lúc hộp xác nhận đang mở ⇒ chưa đăng xuất, cho người dùng xử lý lại.
      if (await _blockedByActiveVisit() || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.logoutBlockedTitle), backgroundColor: AppColors.error),
      );
      return;
    }
    context.go('/login');
  }

  /// Còn lượt viếng thăm chưa đóng ⇒ hiện hộp chặn dùng chung với check-in (nút "Vào lượt đang mở" dẫn tới màn
  /// check-in — nơi check-out hoặc huỷ lượt). Trả true nếu bị chặn.
  Future<bool> _blockedByActiveVisit() async {
    final active = await findOpenVisit(ref.read);
    if (active == null) return false;
    if (!mounted) return true;
    final strings = ref.read(stringsProvider);
    final chosenDealer = await showActiveVisitBlockingDialog(
      context: context,
      ref: ref,
      activeVisit: active,
      activeDealerName: active.customerName.isNotEmpty ? active.customerName : strings.dealerFallbackName,
      blockedReason: strings.logoutActiveVisitReason,
      blockedInstruction: strings.logoutActiveVisitInstruction,
    );
    if (chosenDealer != null && mounted) {
      ref.read(checkInViewModelProvider.notifier).initCheckinWithDealer(chosenDealer);
      // Không await: _handleLogout giữ cờ chống bấm đúp suốt lúc chờ — ở màn check-in lâu là nút Đăng xuất "chết".
      context.push('/check-in', extra: chosenDealer).then((_) {
        if (mounted) ref.read(routeViewModelProvider.notifier).loadRouteDetail();
      });
    }
    return true;
  }

  /// Đồng bộ cưỡng bức tới khi hết hàng đợi hoặc một lượt không gửi thêm được mục nào. Trả false nếu lỗi (đã báo).
  Future<bool> _syncAll(AppDatabase db) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(ref.read(stringsProvider).syncingInProgress), duration: const Duration(minutes: 5)),
    );
    final sync = ref.read(syncServiceProvider);
    try {
      // Mỗi lượt syncQueue chỉ gửi một lô 50 mục ⇒ lặp tới khi hết hoặc một lượt không làm số mục chờ giảm (gửi được
      // hoặc chuyển dead đều làm giảm).
      var before = await db.countPendingSync();
      for (var round = 0; round < 20 && before > 0; round++) {
        // Lượt đồng bộ nền đang chạy thì syncQueue trả về ngay (không làm gì) ⇒ chờ nó xong (tối đa 2 phút) mỗi vòng.
        for (var i = 0; i < 240 && sync.isSyncing; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        await sync.syncQueue(force: true);
        final after = await db.countPendingSync();
        if (after >= before) break;
        before = after;
      }
      messenger.clearSnackBars();
      return true;
    } catch (e) {
      messenger.clearSnackBars();
      if (mounted) AppSnackBar.showError(context, e);
      return false;
    }
  }

  int _versionTapCount = 0;


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
                          cacheWidth: 300,
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
                      title: 'Quãng đường di chuyển',
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
                onPressed: _handleLogout,
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    // Màn nhật ký lỗi hiện nội dung request/response của các lỗi trong máy ⇒ chỉ super admin mở được.
                    if (ref.read(authViewModelProvider).user?.isSuperAdmin != true) {
                      return;
                    }
                    _versionTapCount++;
                    if (_versionTapCount >= 5) {
                      _versionTapCount = 0;
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ErrorLogScreen()),
                      );
                    }
                  },
                  child: Text(
                    AppConstants.appVersionBuild,
                    style: AppTypography.labelSmall(
                      color: isDark
                          ? AppColors.darkOnSurfaceVariant
                          : AppColors.outline,
                    ),
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

enum _PendingChoice { sync, details }
