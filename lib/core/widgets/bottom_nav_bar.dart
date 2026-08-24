import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class VthmBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const VthmBottomNavBar({
    super.key,
    required this.currentIndex,
  });

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/routes');
        break;
      case 2:
        context.go('/forms');
        break;
      case 3:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = [
      _NavItemData(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Trang chủ'),
      _NavItemData(icon: Icons.alt_route_outlined, activeIcon: Icons.alt_route, label: 'Tuyến'),
      _NavItemData(icon: Icons.assignment_outlined, activeIcon: Icons.assignment, label: 'Biểu mẫu'),
      _NavItemData(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Cá nhân'),
    ];

    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
            width: 1,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            offset: Offset(0, -2),
            blurRadius: 8,
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final isSelected = index == currentIndex;
          final item = items[index];

          return InkWell(
            onTap: () => _onItemTapped(context, index),
            borderRadius: AppRadius.roundedLg,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: isSelected
                        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 4)
                        : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? AppColors.primary : AppColors.primaryContainer)
                          : Colors.transparent,
                      borderRadius: AppRadius.roundedFull,
                    ),
                    child: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      size: 22,
                      color: isSelected
                          ? AppColors.onPrimary
                          : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.label,
                    style: AppTypography.labelSmall(
                      color: isSelected
                          ? (isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                          : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                    ).copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
