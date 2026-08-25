import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class VthmBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const VthmBottomNavBar({
    super.key,
    required this.currentIndex,
    this.onTap,
  });

  void _handleTap(BuildContext context, int index) {
    if (onTap != null) {
      onTap!(index);
      return;
    }

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
      _NavItemData(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Trang chủ'),
      _NavItemData(icon: Icons.alt_route_outlined, activeIcon: Icons.alt_route_rounded, label: 'Tuyến'),
      _NavItemData(icon: Icons.assignment_outlined, activeIcon: Icons.assignment_rounded, label: 'Biểu mẫu'),
      _NavItemData(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Cá nhân'),
    ];

    return Container(
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
            color: Color(0x0A000000),
            offset: Offset(0, -3),
            blurRadius: 10,
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (index) {
              final isSelected = index == currentIndex;
              final item = items[index];

              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleTap(context, index),
                    splashColor: AppColors.primary.withValues(alpha: 0.12),
                    highlightColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Active pill indicator & icon
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            padding: isSelected
                                ? const EdgeInsets.symmetric(horizontal: 18, vertical: 3)
                                : const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

                          // Single-line adaptive title (Never wraps)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                item.label,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSmall(
                                  color: isSelected
                                      ? (isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                                      : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                                ).copyWith(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
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
