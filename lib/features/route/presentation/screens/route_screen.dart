import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/map/goong_providers.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../states/route_state.dart';
import '../viewmodels/route_view_model.dart';
import '../widgets/route_dealer_timeline.dart';
import '../widgets/route_header_card.dart';
import '../widgets/route_map_view.dart';

class RouteScreen extends ConsumerStatefulWidget {
  const RouteScreen({super.key});

  @override
  ConsumerState<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends ConsumerState<RouteScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestLocationPermission();
    });
  }

  Future<void> _requestLocationPermission() async {
    final position = await ref.read(locationServiceProvider).checkAndGetLocation(context);
    if (position != null && mounted) {
      ref.invalidate(currentPointProvider);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routeViewModelProvider);
    final vm = ref.read(routeViewModelProvider.notifier);
    final strings = ref.watch(stringsProvider);
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
                  child: Text(state.errorMessage ?? strings.error),
                )
              : RefreshIndicator(
                  color: AppColors.primaryContainer,
                  onRefresh: () async {
                    await Future.wait([
                      vm.loadRouteDetail(isRefresh: true),
                      _requestLocationPermission(),
                    ]);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.marginMobile,
                      vertical: AppSpacing.stackMd,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Card with route selection & progress
                        RouteHeaderCard(route: state.routeDetail!),
                        const SizedBox(height: AppSpacing.stackMd),

                        // Search box for customers on the route
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? AppColors.darkOutlineVariant : const Color(0xFFE0E3E0),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => vm.setSearchQuery(val),
                            decoration: InputDecoration(
                              hintText: 'Tìm điểm bán, mã KH, SĐT trên tuyến...',
                              hintStyle: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: isDark ? AppColors.darkOnSurfaceVariant : const Color(0xFF6F7A74),
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                size: 20,
                                color: isDark ? AppColors.darkOnSurfaceVariant : const Color(0xFF6F7A74),
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        vm.setSearchQuery('');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.stackMd),

                        // Segmented Control (Danh sách / Bản đồ)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceContainer : const Color(0xFFE4EADD),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? AppColors.darkOutlineVariant : const Color(0xFFBECAB7),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => vm.selectTab(0),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: state.selectedTab == 0
                                          ? (isDark
                                              ? AppColors.darkSurfaceContainerLowest
                                              : AppColors.surfaceContainerLowest)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: state.selectedTab == 0
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              )
                                            ]
                                          : [],
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.format_list_bulleted_rounded,
                                            size: 16,
                                            color: state.selectedTab == 0
                                                ? (isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                                                : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            strings.routeListTab,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 13,
                                              color: state.selectedTab == 0
                                                  ? (isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                                                  : (isDark
                                                      ? AppColors.darkOnSurfaceVariant
                                                      : AppColors.onSurfaceVariant),
                                              fontWeight: state.selectedTab == 0
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => vm.selectTab(1),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: state.selectedTab == 1
                                          ? (isDark
                                              ? AppColors.darkSurfaceContainerLowest
                                              : AppColors.surfaceContainerLowest)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: state.selectedTab == 1
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              )
                                            ]
                                          : [],
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.map_rounded,
                                            size: 16,
                                            color: state.selectedTab == 1
                                                ? (isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                                                : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            strings.routeMapTab,
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 13,
                                              color: state.selectedTab == 1
                                                  ? (isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                                                  : (isDark
                                                      ? AppColors.darkOnSurfaceVariant
                                                      : AppColors.onSurfaceVariant),
                                              fontWeight: state.selectedTab == 1
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ],
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
                          RouteMapView(dealers: state.routeDetail!.dealers),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimary,
        shape: const CircleBorder(),
        onPressed: () async {
          final position = await ref
              .read(locationServiceProvider)
              .checkAndGetLocation(context);
          if (position == null) return;
          ref.invalidate(currentPointProvider);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  strings.isVietnamese
                      ? 'Đã định vị thành công: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}'
                      : 'Position acquired: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
                ),
              ),
            );
          }
        },
        child: const Icon(Icons.my_location_rounded),
      ),
    );
  }
}
