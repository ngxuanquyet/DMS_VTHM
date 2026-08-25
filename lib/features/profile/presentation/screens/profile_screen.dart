import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/location/location_provider.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../viewmodels/profile_view_model.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showLanguageSelector(BuildContext context, WidgetRef ref) {
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
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildLanguageOption(
                  context: ctx,
                  ref: ref,
                  language: AppLanguage.vi,
                  isSelected: currentLang == AppLanguage.vi,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildLanguageOption(
                  context: ctx,
                  ref: ref,
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
    required WidgetRef ref,
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
                : (isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLow),
            borderRadius: AppRadius.roundedMd,
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Text(
                language.flag,
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  language.title,
                  style: AppTypography.bodyLarge(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.darkOnSurface : AppColors.onSurface),
                  ).copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
  Widget build(BuildContext context, WidgetRef ref) {
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
                  Stack(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
                            width: 3,
                          ),
                          boxShadow: AppShadows.level2,
                        ),
                        child: ClipOval(
                          child: Image.network(
                            profileState.profile?.avatarUrl ?? AppConstants.userAvatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              size: 48,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? AppColors.darkSurface : Colors.white,
                              width: 2,
                            ),
                            boxShadow: AppShadows.level1,
                          ),
                          child: const Center(
                            child: Icon(Icons.edit, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profileState.profile?.name ?? strings.unknown,
                    style: AppTypography.headlineSmall(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(alpha: 0.12),
                            borderRadius: AppRadius.roundedMd,
                            border: Border.all(
                              color: AppColors.primaryContainer.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                strings.roleLabel,
                                style: AppTypography.labelSmall(
                                  color: isDark
                                      ? AppColors.darkOnSurfaceVariant
                                      : AppColors.onSurfaceVariant,
                                ).copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w700),
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
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer.withValues(alpha: 0.15),
                            borderRadius: AppRadius.roundedMd,
                            border: Border.all(
                              color: AppColors.secondaryContainer.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                strings.departmentLabel,
                                style: AppTypography.labelSmall(
                                  color: isDark
                                      ? AppColors.darkOnSurfaceVariant
                                      : AppColors.onSurfaceVariant,
                                ).copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                profileState.profile?.department ?? strings.unknown,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelLarge(
                                  color: isDark ? AppColors.secondaryFixed : AppColors.secondary,
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
                    icon: Icons.lock_outline,
                    title: strings.changePassword,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(strings.changePasswordNotice)),
                      );
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
                    onTap: () => _showLanguageSelector(context, ref),
                    isDark: isDark,
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
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
                    onTap: () {},
                    isDark: isDark,
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    icon: Icons.rocket_launch_outlined,
                    title: strings.previewSplash,
                    onTap: () => context.push('/splash'),
                    isDark: isDark,
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    icon: Icons.wifi_off_rounded,
                    title: strings.simulateOffline,
                    onTap: () {
                      final notifier = ref.read(connectivityProvider.notifier);
                      notifier.simulateOffline();
                      Future.delayed(const Duration(seconds: 3), () {
                        notifier.simulateOnline();
                      });
                    },
                    isDark: isDark,
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    icon: Icons.location_off_rounded,
                    title: strings.simulateLocationOff,
                    onTap: () {
                      ref.read(locationProvider.notifier).simulateLocationOff();
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
                    onTap: () {},
                    isDark: isDark,
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    icon: Icons.article_outlined,
                    title: strings.termsOfService,
                    onTap: () {},
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
                        child: Text(strings.logout, style: const TextStyle(color: AppColors.error)),
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
            const SizedBox(height: 12),
            Text(
              AppConstants.appVersionBuild,
              style: AppTypography.labelSmall(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
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
            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
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
          color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainer,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
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
          if (trailing != null) ...[
            trailing,
            const SizedBox(width: 6),
          ],
          const Icon(Icons.chevron_right, color: AppColors.outline, size: 20),
        ],
      ),
    );
  }
}
