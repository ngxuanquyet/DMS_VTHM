import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  final ScrollController _scrollController = ScrollController();

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
    _scrollController.dispose();
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
    final result = await context.push<bool>('/customers/add');
    if (result == true && mounted) {
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
          SafeArea(
            top: false,
            child: Column(
              children: [
                // Top Header & Search Bar Section (Collapsible title on scroll)
                AnimatedBuilder(
                  animation: _scrollController,
                  builder: (context, _) {
                    final offset = _scrollController.hasClients ? _scrollController.offset : 0.0;
                    final progress = (offset / 60.0).clamp(0.0, 1.0);

                    return Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.surfaceContainerLowest,
                        border: Border(
                          bottom: BorderSide(
                            color: isDark
                                ? AppColors.darkOutlineVariant
                                : AppColors.outlineVariant,
                            width: 1,
                          ),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            offset: Offset(0, 2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Collapsible Title Area
                          ClipRect(
                            child: Align(
                              alignment: Alignment.topCenter,
                              heightFactor: 1.0 - progress,
                              child: Opacity(
                                opacity: (1.0 - progress).clamp(0.0, 1.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title Row with Count Badge & Distance Chip
                                    Row(
                                      children: [
                                        Text(
                                          'Tuyến',
                                          style: AppTypography.titleLarge(
                                            color: isDark
                                                ? AppColors.darkOnSurface
                                                : AppColors.onSurface,
                                          ).copyWith(fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.1),
                                            borderRadius: AppRadius.roundedFull,
                                            border: Border.all(
                                              color: AppColors.primary.withValues(alpha: 0.2),
                                            ),
                                          ),
                                          child: Text(
                                            '${state.routeDetail?.totalDealers ?? 0} ${strings.isVietnamese ? 'điểm' : 'stops'}',
                                            style: AppTypography.labelSmall(
                                              color: isDark
                                                  ? AppColors.primaryFixedDim
                                                  : AppColors.primary,
                                            ).copyWith(fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        if (state.isSortedByDistance) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0284C7)
                                                  .withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: const Color(0xFF0284C7)
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.near_me_rounded,
                                                  size: 11,
                                                  color: Color(0xFF0284C7),
                                                ),
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
                                    const SizedBox(height: 2),
                                    Text(
                                      strings.isVietnamese
                                          ? 'Danh sách điểm bán theo tuyến được giao'
                                          : 'Assigned route store visit plan',
                                      style: AppTypography.bodySmall(
                                        color: isDark
                                            ? AppColors.darkOnSurfaceVariant
                                            : AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Search Text Field (Fixed / Pinned)
                          Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceContainerLowest
                                  : AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
                              borderRadius: AppRadius.roundedMd,
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkOutlineVariant
                                    : AppColors.outlineVariant,
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) => vm.setSearchQuery(val),
                              style: AppTypography.bodyMedium(
                                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Tìm điểm bán, mã KH, SĐT trên tuyến...',
                                hintStyle: AppTypography.bodySmall(
                                  color: isDark
                                      ? AppColors.darkOnSurfaceVariant
                                      : AppColors.outline,
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                  color: isDark
                                      ? AppColors.darkOnSurfaceVariant
                                      : AppColors.outline,
                                ),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 16),
                                        onPressed: () {
                                          _searchController.clear();
                                          vm.setSearchQuery('');
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Main Content List
                Expanded(
                  child: state.status == RouteStatus.loading && state.routeDetail == null
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
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.marginMobile,
                                  vertical: AppSpacing.stackMd,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    RouteDealerTimeline(dealers: state.routeDetail!.dealers),
                                    const SizedBox(height: 160),
                                  ],
                                ),
                              ),
                            ),
                ),
              ],
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
