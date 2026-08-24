import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/widgets/bottom_nav_bar.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../viewmodels/profile_view_model.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileViewModelProvider);
    final profileVM = ref.read(profileViewModelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: const VthmTopAppBar(),
      body: SingleChildScrollView(
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
                    profileState.profile?.name ?? 'Nguyễn Văn An',
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          size: 14,
                          color: AppColors.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          profileState.profile?.employeeId ?? 'NV00128',
                          style: AppTypography.labelSmall(
                            color: isDark
                                ? AppColors.darkOnSurfaceVariant
                                : AppColors.onSurfaceVariant,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Role & Region Cards
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
                                'CHỨC VỤ',
                                style: AppTypography.labelSmall(
                                  color: isDark
                                      ? AppColors.darkOnSurfaceVariant
                                      : AppColors.onSurfaceVariant,
                                ).copyWith(letterSpacing: 0.8),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                profileState.profile?.role ?? 'Nhân viên thị trường',
                                textAlign: TextAlign.center,
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
                                'KHU VỰC',
                                style: AppTypography.labelSmall(
                                  color: isDark
                                      ? AppColors.darkOnSurfaceVariant
                                      : AppColors.onSurfaceVariant,
                                ).copyWith(letterSpacing: 0.8),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                profileState.profile?.region ?? 'Khu vực Vĩnh Phúc',
                                textAlign: TextAlign.center,
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
            _buildSectionTitle('TÀI KHOẢN', isDark),
            const SizedBox(height: 6),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.person_outline,
                    title: 'Thông tin cá nhân',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mở thông tin chi tiết cá nhân')),
                      );
                    },
                    isDark: isDark,
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    icon: Icons.lock_outline,
                    title: 'Đổi mật khẩu',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mở form đổi mật khẩu')),
                      );
                    },
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.stackLg),

            // Section 2: Cài đặt ứng dụng
            _buildSectionTitle('CÀI ĐẶT ỨNG DỤNG', isDark),
            const SizedBox(height: 6),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.language,
                    title: 'Ngôn ngữ',
                    trailing: Text(
                      'Tiếng Việt',
                      style: AppTypography.bodyMedium(
                        color: isDark
                            ? AppColors.darkOnSurfaceVariant
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                    onTap: () {},
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
                            'Chế độ tối',
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
                    title: 'Quyền riêng tư',
                    onTap: () {},
                    isDark: isDark,
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    icon: Icons.rocket_launch_outlined,
                    title: 'Xem Màn hình Khởi động (Splash)',
                    onTap: () => context.push('/splash'),
                    isDark: isDark,
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    icon: Icons.wifi_off_rounded,
                    title: 'Mô phỏng Mất mạng & Khôi phục (3s)',
                    onTap: () {
                      final notifier = ref.read(connectivityProvider.notifier);
                      notifier.simulateOffline();
                      Future.delayed(const Duration(seconds: 3), () {
                        notifier.simulateOnline();
                      });
                    },
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.stackLg),

            // Section 3: Hỗ trợ
            _buildSectionTitle('HỖ TRỢ', isDark),
            const SizedBox(height: 6),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.help_outline,
                    title: 'Trợ giúp & Hướng dẫn',
                    onTap: () {},
                    isDark: isDark,
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    icon: Icons.article_outlined,
                    title: 'Điều khoản sử dụng',
                    onTap: () {},
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.stackLg),

            // Logout Button
            AppButton(
              text: 'ĐĂNG XUẤT',
              variant: AppButtonVariant.error,
              icon: Icons.logout_rounded,
              width: double.infinity,
              height: 48,
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Xác nhận đăng xuất'),
                    content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản không?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Hủy'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Đăng xuất', style: TextStyle(color: AppColors.error)),
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
      bottomNavigationBar: const VthmBottomNavBar(currentIndex: 3),
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
