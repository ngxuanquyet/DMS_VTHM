import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/map/goong_providers.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../../../customer/presentation/screens/add_customer_screen.dart';
import '../states/route_state.dart';
import '../viewmodels/route_view_model.dart';
import '../widgets/route_circular_menu.dart';
import '../widgets/route_dealer_timeline.dart';

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
      ref.read(routeViewModelProvider.notifier).updateUserLocation(
        lat: position.latitude,
        lng: position.longitude,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSortByDistance() async {
    final vm = ref.read(routeViewModelProvider.notifier);
    final state = ref.read(routeViewModelProvider);

    if (state.isSortedByDistance) {
      vm.toggleSortByDistance();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã khôi phục thứ tự mặc định của tuyến.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Nếu chưa có vị trí GPS -> lấy vị trí hiện tại
    final livePoint = ref.read(currentPointProvider).value;
    double? lat = livePoint?.lat;
    double? lng = livePoint?.lng;

    if (lat == null || lng == null) {
      final pos = await ref.read(locationServiceProvider).checkAndGetLocation(context);
      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
        ref.invalidate(currentPointProvider);
      }
    }

    if (lat != null && lng != null) {
      vm.toggleSortByDistance(userLat: lat, userLng: lng);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Đã sắp xếp điểm bán theo khoảng cách gần nhất!')),
              ],
            ),
            backgroundColor: Color(0xFF0284C7),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể lấy tọa độ GPS để tính khoảng cách.'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleSync() async {
    final vm = ref.read(routeViewModelProvider.notifier);
    final isOnline = ref.read(connectivityProvider).isOnline;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const AppLoading(size: 32),
            const SizedBox(width: 10),
            Text(isOnline ? 'Đang đồng bộ dữ liệu tuyến từ máy chủ...' : 'Đang tải lại dữ liệu từ bộ nhớ máy...'),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    await vm.loadRouteDetail(isRefresh: true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(isOnline ? Icons.check_circle_rounded : Icons.offline_pin_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(isOnline ? 'Đồng bộ dữ liệu tuyến thành công!' : 'Đã làm mới dữ liệu ngoại tuyến.'),
              ),
            ],
          ),
          backgroundColor: isOnline ? AppColors.primary : const Color(0xFFD97706),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleSendOfflineData() async {
    final isOnline = ref.read(connectivityProvider).isOnline;
    final db = ref.read(appDatabaseProvider);
    final pendingCount = await db.countPendingSync();

    if (pendingCount == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.cloud_done_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Tất cả dữ liệu đã được gửi lên máy chủ!'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_off_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Hiện không có mạng. Có $pendingCount mục sẽ tự động gửi khi có kết nối.'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFD97706),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const AppLoading(size: 32),
              const SizedBox(width: 10),
              Expanded(child: Text('Đang gửi $pendingCount mục ngoại tuyến lên máy chủ...')),
            ],
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    await ref.read(syncServiceProvider).syncQueue();

    final remaining = await db.countPendingSync();
    if (mounted) {
      if (remaining == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Đã gửi toàn bộ dữ liệu ngoại tuyến thành công!'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(routeViewModelProvider.notifier).loadRouteDetail(isRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Đã gửi thành công. Còn $remaining mục đang xử lý.')),
              ],
            ),
            backgroundColor: const Color(0xFF0284C7),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleAddCustomer() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
    );
    if (result == true) {
      ref.read(routeViewModelProvider.notifier).loadRouteDetail(isRefresh: true);
    }
  }

  Future<void> _handleRefreshGps() async {
    final position = await ref.read(locationServiceProvider).checkAndGetLocation(context);
    if (position == null) return;
    ref.invalidate(currentPointProvider);
    ref.read(routeViewModelProvider.notifier).updateUserLocation(
      lat: position.latitude,
      lng: position.longitude,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã định vị thành công: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routeViewModelProvider);
    final vm = ref.read(routeViewModelProvider.notifier);
    final strings = ref.watch(stringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendingOfflineCount = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: const VthmTopAppBar(),
      body: Stack(
        children: [
          state.status == RouteStatus.loading && state.routeDetail == null
              ? const Center(
                  child: AppLoading(size: 220),
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
                            // Route title & count header (clean, without progress statistics card)
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    state.routeDetail!.title,
                                    style: AppTypography.titleMedium(
                                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                    ).copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Text(
                                    '${state.routeDetail!.totalDealers} ${strings.isVietnamese ? 'điểm' : 'stops'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                                    ),
                                  ),
                                ),
                                if (state.isSortedByDistance) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.near_me_rounded, size: 11, color: Color(0xFF0284C7)),
                                        SizedBox(width: 3),
                                        Text(
                                          'Theo cự ly',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0284C7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            // Route switcher chips if user has multiple routes
                            if (state.availableRoutes.length > 1) ...[
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: state.availableRoutes.map((r) {
                                    final isSelected = r == state.selectedRoute;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: InkWell(
                                        onTap: () => vm.selectRoute(r),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? (isDark ? AppColors.primaryContainer : const Color(0xFFEFF6E8))
                                                : (isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHigh),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isSelected
                                                  ? (isDark ? AppColors.primaryContainer : const Color(0xFFBECAB7))
                                                  : Colors.transparent,
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            r,
                                            style: TextStyle(
                                              color: isSelected
                                                ? (isDark ? Colors.white : AppColors.primary)
                                                : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
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

                            // Timeline List of dealers on route
                            RouteDealerTimeline(dealers: state.routeDetail!.dealers),
                            const SizedBox(height: 160),
                          ],
                        ),
                      ),
                    ),

          // Circular Radial Menu overlay
          Positioned.fill(
            child: RouteCircularMenu(
              onSortByDistance: _handleSortByDistance,
              onSync: _handleSync,
              onSendOfflineData: _handleSendOfflineData,
              onAddCustomer: _handleAddCustomer,
              onRefreshGps: _handleRefreshGps,
              isSortedByDistance: state.isSortedByDistance,
              pendingOfflineCount: pendingOfflineCount,
              isSyncing: state.status == RouteStatus.loading,
            ),
          ),
        ],
      ),
    );
  }
}
