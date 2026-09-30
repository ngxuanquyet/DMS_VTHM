import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_dialog.dart';
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

    ref.listen<NotificationsState>(notificationsViewModelProvider, (prev, next) {
      if (next.status == NotificationStatus.error &&
          next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        AppErrorDialog.show(
          context,
          title: 'Lỗi tải thông báo',
          message: next.errorMessage!,
          onRetry: () => vm.loadNotifications(),
        );
      }
    });

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
          : state.status == NotificationStatus.error && state.data == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(
                          state.errorMessage ?? strings.error,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium(
                            color: isDark
                                ? AppColors.darkOnSurface
                                : AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => vm.loadNotifications(),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(strings.retry),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                      AppEmptyState(
                        icon: Icons.notifications_off_outlined,
                        title: strings.noNotifications,
                        description:
                            'Hiện tại bạn không có thông báo nào trong mục này.',
                        actionText: 'Làm mới',
                        onAction: () => vm.loadNotifications(),
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
