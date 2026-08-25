import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';

class QuickActionsGrid extends ConsumerWidget {
  const QuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.how_to_reg_outlined,
                label: strings.attendanceSection,
                iconColor: AppColors.primary,
                bgColor: AppColors.primaryContainer.withValues(alpha: 0.12),
                onTap: () => context.push('/attendance'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.location_on_outlined,
                label: strings.checkInAction,
                iconColor: AppColors.secondary,
                bgColor: AppColors.secondaryContainer.withValues(alpha: 0.2),
                onTap: () => context.push('/check-in'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.alt_route_outlined,
                label: strings.navRoutes,
                iconColor: AppColors.tertiary,
                bgColor: AppColors.tertiaryContainer.withValues(alpha: 0.15),
                onTap: () => context.go('/routes'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.assignment_outlined,
                label: strings.navForms,
                iconColor: AppColors.primary,
                bgColor: AppColors.primaryContainer.withValues(alpha: 0.12),
                onTap: () => context.go('/forms'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color bgColor;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, color: iconColor, size: 22),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.labelLarge(
              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
            ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
