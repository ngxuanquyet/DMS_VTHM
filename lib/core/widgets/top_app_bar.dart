import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../../../features/profile/presentation/viewmodels/profile_view_model.dart';
import '../constants/app_constants.dart';
import '../localization/language_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class VthmTopAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final bool showAvatar;
  final bool showBackButton;
  final Widget? trailing;
  final VoidCallback? onNotificationPressed;

  const VthmTopAppBar({
    super.key,
    this.title = 'VTHM Group',
    this.showAvatar = true,
    this.showBackButton = false,
    this.trailing,
    this.onNotificationPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = ref.watch(stringsProvider);

    // Dynamic user avatar from login / profile
    final authUser = ref.watch(authViewModelProvider).user;
    final profileUser = ref.watch(profileViewModelProvider).profile;

    final avatarUrl = (authUser != null && authUser.avatarUrl.isNotEmpty)
        ? authUser.avatarUrl
        : (profileUser != null && profileUser.avatarUrl.isNotEmpty)
            ? profileUser.avatarUrl
            : AppConstants.userAvatarUrl;

    final userInitial = (authUser != null && authUser.initial.isNotEmpty)
        ? authUser.initial
        : (authUser != null && authUser.displayName.isNotEmpty)
            ? authUser.displayName.trim().split(' ').last.substring(0, 1)
            : (profileUser != null && profileUser.name.isNotEmpty)
                ? profileUser.name.trim().split(' ').last.substring(0, 1)
                : 'V';

    return AppBar(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
        ),
      ),
      titleSpacing: 16,
      title: Row(
        children: [
          if (showBackButton) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back),
              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/home');
                }
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
          ] else if (showAvatar) ...[
            GestureDetector(
              onTap: () => context.go('/profile'),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.primaryContainer.withValues(alpha: 0.3),
                      child: Center(
                        child: Text(
                          userInitial,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Text(
            title,
            style: AppTypography.headlineSmallMobile(
              color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        if (trailing != null)
          trailing!
        else
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.notifications_none_rounded),
              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              tooltip: strings.notificationsTitle,
              onPressed: onNotificationPressed ?? () => context.push('/notifications'),
            ),
          ),
      ],
    );
  }
}
