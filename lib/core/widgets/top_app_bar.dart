import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class VthmTopAppBar extends StatelessWidget implements PreferredSizeWidget {
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                  width: 1,
                ),
              ),
              child: ClipOval(
                child: Image.network(
                  AppConstants.userAvatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.person,
                    size: 20,
                    color: AppColors.primary,
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
              tooltip: 'Thông báo',
              onPressed: onNotificationPressed ?? () => context.push('/notifications'),
            ),
          ),
      ],
    );
  }
}
