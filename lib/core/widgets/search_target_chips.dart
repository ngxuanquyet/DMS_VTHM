import 'package:flutter/material.dart';
import '../constants/search_target.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Thanh chọn tiêu chí tìm kiếm dạng Filter Chips ngang
class SearchTargetChips extends StatelessWidget {
  final SearchTarget currentTarget;
  final ValueChanged<SearchTarget> onTargetChanged;
  final bool isDark;

  const SearchTargetChips({
    super.key,
    required this.currentTarget,
    required this.onTargetChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: SearchTarget.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final target = SearchTarget.values[index];
          final isSelected = target == currentTarget;

          final activeBg = isDark
              ? const Color(0xFF0284C7)
              : const Color(0xFF006874);
          final activeFg = Colors.white;

          final inactiveBg = isDark
              ? AppColors.darkSurfaceContainer
              : AppColors.surfaceContainerHigh.withValues(alpha: 0.6);
          final inactiveBorder = isDark
              ? AppColors.darkOutlineVariant.withValues(alpha: 0.7)
              : AppColors.outlineVariant;
          final inactiveFg = isDark
              ? AppColors.darkOnSurfaceVariant
              : AppColors.onSurfaceVariant;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onTargetChanged(target),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? activeBg : inactiveBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? activeBg : inactiveBorder,
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: activeBg.withValues(alpha: 0.35),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      target.icon,
                      size: 13,
                      color: isSelected ? activeFg : inactiveFg,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      target.label,
                      style: AppTypography.labelSmall(
                        color: isSelected ? activeFg : inactiveFg,
                      ).copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
