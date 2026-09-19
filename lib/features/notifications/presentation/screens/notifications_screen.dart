import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_loading.dart';
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
    final strings = ref.watch(stringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filters = [strings.all, strings.unread, strings.work, strings.system];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: VthmTopAppBar(
        title: strings.notificationsTitle,
        showBackButton: true,
        showAvatar: false,
        trailing: IconButton(
          icon: const Icon(Icons.done_all_rounded),
          color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
          tooltip: strings.markAllAsRead,
          onPressed: () {
            vm.markAllAsRead();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(strings.markAllSuccess),
                backgroundColor: AppColors.primary,
              ),
            );
          },
        ),
      ),
      body: state.status == NotificationStatus.loading && state.data == null
          ? const Center(
              child: AppLoading(size: 220),
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
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: List.generate(filters.length, (index) {
                          final isSelected = state.selectedFilterIndex == index;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: InkWell(
                              onTap: () => vm.selectFilter(index),
                              borderRadius: AppRadius.roundedFull,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark ? AppColors.primary : AppColors.primaryContainer)
                                      : (isDark
                                          ? AppColors.darkSurfaceContainer
                                          : AppColors.surfaceContainerLowest),
                                  borderRadius: AppRadius.roundedFull,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.transparent
                                        : (isDark
                                            ? AppColors.darkOutlineVariant
                                            : AppColors.outlineVariant),
                                  ),
                                  boxShadow: isSelected ? AppShadows.level1 : [],
                                ),
                                child: Text(
                                  filters[index],
                                  style: AppTypography.labelSmall(
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                            ? AppColors.darkOnSurfaceVariant
                                            : AppColors.onSurfaceVariant),
                                  ).copyWith(
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.stackLg),

                    // Section: Hôm nay
                    if (state.filteredToday.isNotEmpty) ...[
                      Text(
                        strings.todaySection,
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
                        strings.earlierSection,
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
                                strings.noNotifications,
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
