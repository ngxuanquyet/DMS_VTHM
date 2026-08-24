import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../states/notifications_state.dart';
import '../viewmodels/notifications_view_model.dart';
import '../widgets/notification_item_card.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsViewModelProvider);
    final vm = ref.read(notificationsViewModelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filters = ['Tất cả', 'Chưa đọc', 'Công việc', 'Hệ thống'];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: VthmTopAppBar(
        title: 'Thông báo',
        showBackButton: true,
        showAvatar: false,
        trailing: IconButton(
          icon: const Icon(Icons.done_all_rounded),
          color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
          tooltip: 'Đánh dấu tất cả đã đọc',
          onPressed: () {
            vm.markAllAsRead();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã đánh dấu tất cả thông báo là đã đọc'),
                backgroundColor: AppColors.primary,
              ),
            );
          },
        ),
      ),
      body: state.status == NotificationStatus.loading && state.data == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryContainer),
            )
          : RefreshIndicator(
              color: AppColors.primaryContainer,
              onRefresh: () => vm.loadNotifications(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                  vertical: AppSpacing.stackMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filter Chips Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(filters.length, (index) {
                          final isSelected = state.selectedFilterIndex == index;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              label: Text(filters[index]),
                              selected: isSelected,
                              showCheckmark: false,
                              labelStyle: AppTypography.labelLarge(
                                color: isSelected
                                    ? AppColors.onPrimary
                                    : (isDark
                                        ? AppColors.darkOnSurfaceVariant
                                        : AppColors.onSurfaceVariant),
                              ).copyWith(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
                              selectedColor: AppColors.primaryContainer,
                              backgroundColor: isDark
                                  ? AppColors.darkSurfaceContainer
                                  : AppColors.surfaceContainerLowest,
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.transparent
                                    : (isDark
                                        ? AppColors.darkOutlineVariant
                                        : AppColors.outlineVariant),
                              ),
                              shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedFull),
                              onSelected: (_) => vm.selectFilter(index),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.stackLg),

                    // Section: Hôm nay
                    if (state.filteredToday.isNotEmpty) ...[
                      Text(
                        'Hôm nay',
                        style: AppTypography.titleMedium(
                          color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.filteredToday.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return NotificationItemCard(
                            notification: state.filteredToday[index],
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.stackLg),
                    ],

                    // Section: Trước đó
                    if (state.filteredEarlier.isNotEmpty) ...[
                      Text(
                        'Trước đó',
                        style: AppTypography.titleMedium(
                          color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.filteredEarlier.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return NotificationItemCard(
                            notification: state.filteredEarlier[index],
                          );
                        },
                      ),
                    ],

                    if (state.filteredToday.isEmpty && state.filteredEarlier.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 64.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 54,
                                color: isDark ? AppColors.darkOutline : AppColors.outlineVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Không có thông báo nào phù hợp',
                                style: AppTypography.bodyLarge(
                                  color: isDark
                                      ? AppColors.darkOnSurfaceVariant
                                      : AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
