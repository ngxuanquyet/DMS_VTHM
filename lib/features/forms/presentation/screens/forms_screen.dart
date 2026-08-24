import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/bottom_nav_bar.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../states/forms_state.dart';
import '../viewmodels/forms_view_model.dart';
import '../widgets/form_card_item.dart';

class FormsScreen extends ConsumerWidget {
  const FormsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(formsViewModelProvider);
    final vm = ref.read(formsViewModelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tabs = ['Cần làm', 'Đang thực hiện', 'Hoàn thành'];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: const VthmTopAppBar(),
      body: state.status == FormsStatus.loading && state.allForms.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryContainer),
            )
          : RefreshIndicator(
              color: AppColors.primaryContainer,
              onRefresh: () => vm.loadForms(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                  vertical: AppSpacing.stackMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Danh sách Biểu mẫu',
                      style: AppTypography.headlineSmall(
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),

                    // Tab Navigation with bottom active indicator
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: List.generate(tabs.length, (index) {
                          final isSelected = state.selectedTabIndex == index;

                          return Padding(
                            padding: const EdgeInsets.only(right: 24.0),
                            child: InkWell(
                              onTap: () => vm.selectTab(index),
                              child: Container(
                                padding: const EdgeInsets.only(bottom: 12, top: 4),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: isSelected
                                          ? (isDark ? AppColors.primaryFixedDim : AppColors.primary)
                                          : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  tabs[index],
                                  style: AppTypography.titleMedium(
                                    color: isSelected
                                        ? (isDark ? AppColors.primaryFixedDim : AppColors.primary)
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

                    // Forms List
                    if (state.filteredForms.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.assignment_turned_in_outlined,
                                size: 54,
                                color: isDark ? AppColors.darkOutline : AppColors.outlineVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Không có biểu mẫu nào trong mục này',
                                style: AppTypography.bodyLarge(
                                  color: isDark
                                      ? AppColors.darkOnSurfaceVariant
                                      : AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.filteredForms.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final item = state.filteredForms[index];
                          return FormCardItem(
                            form: item,
                            onAction: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Mở biểu mẫu: "${item.title}"'),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: const VthmBottomNavBar(currentIndex: 2),
    );
  }
}
