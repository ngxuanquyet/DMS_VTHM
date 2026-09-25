import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../localization/language_provider.dart';

/// Provider phát tín hiệu đóng floating circular menu khi user chuyển tab
final closeFloatingMenuProvider = StateProvider<int>((ref) => 0);

class VthmBottomNavBar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const VthmBottomNavBar({
    super.key,
    required this.currentIndex,
    this.onTap,
  });

  void _handleTap(BuildContext context, WidgetRef ref, int index) {
    ref.read(closeFloatingMenuProvider.notifier).state++;

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
        context.go('/customers');
        break;
      case 2:
        context.go('/routes');
        break;
      case 3:
        context.go('/forms');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = ref.watch(stringsProvider);

    return CurvedNavigationBar(
      index: currentIndex,
      height: 64.0,
      backgroundColor: Colors.transparent,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      buttonBackgroundColor: const Color(0xFF10B981), // Emerald brand color
      animationCurve: Curves.easeInOutCubic,
      animationDuration: const Duration(milliseconds: 350),
      onTap: (index) => _handleTap(context, ref, index),
      items: [
        Tooltip(
          message: strings.navHome,
          child: Icon(
            Icons.home_rounded,
            size: 26,
            color: currentIndex == 0
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF64748B)),
          ),
        ),
        Tooltip(
          message: strings.navCustomers,
          child: Icon(
            Icons.storefront_rounded,
            size: 26,
            color: currentIndex == 1
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF64748B)),
          ),
        ),
        Tooltip(
          message: strings.navRoutes,
          child: Icon(
            Icons.alt_route_rounded,
            size: 26,
            color: currentIndex == 2
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF64748B)),
          ),
        ),
        Tooltip(
          message: strings.navForms,
          child: Icon(
            Icons.assignment_rounded,
            size: 26,
            color: currentIndex == 3
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF64748B)),
          ),
        ),
        Tooltip(
          message: strings.navProfile,
          child: Icon(
            Icons.person_rounded,
            size: 26,
            color: currentIndex == 4
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }
}
