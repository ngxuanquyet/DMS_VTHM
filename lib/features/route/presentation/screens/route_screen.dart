import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/bottom_nav_bar.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../states/route_state.dart';
import '../viewmodels/route_view_model.dart';
import '../widgets/route_dealer_timeline.dart';
import '../widgets/route_header_card.dart';

class RouteScreen extends ConsumerWidget {
  const RouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(routeViewModelProvider);
    final vm = ref.read(routeViewModelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: const VthmTopAppBar(),
      body: state.status == RouteStatus.loading && state.routeDetail == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryContainer),
            )
          : state.routeDetail == null
              ? Center(
                  child: Text(state.errorMessage ?? 'Không tải được tuyến đường'),
                )
              : RefreshIndicator(
                  color: AppColors.primaryContainer,
                  onRefresh: () => vm.loadRouteDetail(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.marginMobile,
                      vertical: AppSpacing.stackMd,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Card with progress
                        RouteHeaderCard(route: state.routeDetail!),
                        const SizedBox(height: AppSpacing.stackMd),

                        // Segmented Control (Danh sách / Bản đồ)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHigh,
                            borderRadius: AppRadius.roundedMd,
                            border: Border.all(
                              color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => vm.selectTab(0),
                                  borderRadius: AppRadius.roundedSm,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: state.selectedTab == 0
                                          ? (isDark
                                              ? AppColors.darkSurfaceContainerLowest
                                              : AppColors.surfaceContainerLowest)
                                          : Colors.transparent,
                                      borderRadius: AppRadius.roundedSm,
                                      boxShadow: state.selectedTab == 0 ? AppShadows.level1 : [],
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Danh sách',
                                        style: AppTypography.labelLarge(
                                          color: state.selectedTab == 0
                                              ? (isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                                              : (isDark
                                                  ? AppColors.darkOnSurfaceVariant
                                                  : AppColors.onSurfaceVariant),
                                        ).copyWith(
                                          fontWeight: state.selectedTab == 0
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => vm.selectTab(1),
                                  borderRadius: AppRadius.roundedSm,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: state.selectedTab == 1
                                          ? (isDark
                                              ? AppColors.darkSurfaceContainerLowest
                                              : AppColors.surfaceContainerLowest)
                                          : Colors.transparent,
                                      borderRadius: AppRadius.roundedSm,
                                      boxShadow: state.selectedTab == 1 ? AppShadows.level1 : [],
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Bản đồ',
                                        style: AppTypography.labelLarge(
                                          color: state.selectedTab == 1
                                              ? (isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                                              : (isDark
                                                  ? AppColors.darkOnSurfaceVariant
                                                  : AppColors.onSurfaceVariant),
                                        ).copyWith(
                                          fontWeight: state.selectedTab == 1
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.stackLg),

                        // View content based on selected tab
                        if (state.selectedTab == 0)
                          RouteDealerTimeline(dealers: state.routeDetail!.dealers)
                        else
                          AppCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 380,
                                  width: double.infinity,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        AppConstants.mapPreviewUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Center(
                                          child: Icon(Icons.map, size: 48, color: AppColors.outline),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 16,
                                        left: 16,
                                        right: 16,
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? AppColors.darkSurfaceContainer
                                                : AppColors.surfaceContainerLowest,
                                            borderRadius: AppRadius.roundedMd,
                                            boxShadow: AppShadows.level2,
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.location_on,
                                                color: AppColors.primaryContainer,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Hiển thị 12 điểm dừng trên tuyến',
                                                  style: AppTypography.bodyMedium(
                                                    color: isDark
                                                        ? AppColors.darkOnSurface
                                                        : AppColors.onSurface,
                                                  ).copyWith(fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimary,
        shape: const CircleBorder(),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đang định vị vị trí hiện tại của bạn...')),
          );
        },
        child: const Icon(Icons.my_location_rounded),
      ),
      bottomNavigationBar: const VthmBottomNavBar(currentIndex: 1),
    );
  }
}
