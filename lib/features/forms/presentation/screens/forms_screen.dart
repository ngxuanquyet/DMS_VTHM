import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
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
    final strings = ref.watch(stringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tabs = [strings.todoStatus, strings.inProgressForm, strings.completedStatus];

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
                      strings.formsTitle,
                      style: AppTypography.headlineSmall(
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),

                    // Segmented Tab Navigation
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceContainer
                            : AppColors.surfaceContainerHigh,
                        borderRadius: AppRadius.roundedMd,
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkOutlineVariant
                              : AppColors.outlineVariant,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: List.generate(tabs.length, (index) {
                          final isSelected = state.selectedTabIndex == index;

                          return Expanded(
                            child: InkWell(
                              onTap: () => vm.selectTab(index),
                              borderRadius: AppRadius.roundedSm,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark
                                          ? AppColors.darkSurfaceContainerLowest
                                          : AppColors.surfaceContainerLowest)
                                      : Colors.transparent,
                                  borderRadius: AppRadius.roundedSm,
                                  boxShadow: isSelected ? AppShadows.level1 : [],
                                ),
                                child: Center(
                                  child: Text(
                                    tabs[index],
                                    style: AppTypography.labelLarge(
                                      color: isSelected
                                          ? (isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                                          : (isDark
                                              ? AppColors.darkOnSurfaceVariant
                                              : AppColors.onSurfaceVariant),
                                    ).copyWith(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    ),
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
                                strings.isVietnamese
                                    ? 'Không có biểu mẫu nào trong mục này'
                                    : 'No forms available in this section',
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
                                  content: Text(
                                    strings.isVietnamese
                                        ? 'Mở biểu mẫu: "${item.title}"'
                                        : 'Open form: "${item.title}"',
                                  ),
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
    );
  }
}
