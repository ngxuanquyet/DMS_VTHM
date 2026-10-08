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
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_dialog.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../states/route_state.dart';
import '../viewmodels/route_view_model.dart';
import '../widgets/route_circular_menu.dart';
import '../widgets/route_dealer_timeline.dart';
import '../widgets/route_filter_drawer.dart';
import '../../../visit/domain/entities/visit_entity.dart';
import '../../domain/entities/route_entity.dart';
import '../../../customer/data/repositories/customer_repository_impl.dart';
import '../../../customer/presentation/screens/add_customer_screen.dart';
import '../../../../core/rules/mobile_rules_service.dart';

class RouteScreen extends ConsumerStatefulWidget {
  const RouteScreen({super.key});

  @override
  ConsumerState<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends ConsumerState<RouteScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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
    final position = await ref
        .read(locationServiceProvider)
        .checkAndGetLocation(context);
    if (position != null && mounted) {
      ref.invalidate(currentPointProvider);
      ref
          .read(routeViewModelProvider.notifier)
          .updateUserLocation(lat: position.latitude, lng: position.longitude);
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
      final pos = await ref
          .read(locationServiceProvider)
          .checkAndGetLocation(context);
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
                Expanded(
                  child: Text('Đã sắp xếp điểm bán theo khoảng cách gần nhất!'),
                ),
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
    final customerRepo = ref.read(customerRepositoryProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const AppLoading(size: 32),
            const SizedBox(width: 10),
            Text(
              isOnline
                  ? 'Đang đồng bộ...'
                  : 'Đang tải lại dữ liệu từ bộ nhớ máy...',
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      if (isOnline) {
        // Đồng bộ các tác vụ ngoại tuyến (như huỷ lượt, upload ảnh) trước khi tải lại từ server
        try {
          await ref.read(syncServiceProvider).syncQueue();
        } catch (_) {}
        await Future.wait([
          vm.loadRouteDetail(isRefresh: true),
          ref.read(mobileRulesProvider.notifier).fetchRules(forceRefresh: true),
          customerRepo.getCustomerFormSchema(forceRefresh: true).catchError((
            e,
          ) {
            debugPrint('[RouteSync] Lỗi làm mới schema form: $e');
            return <String, dynamic>{};
          }),
          customerRepo.getCustomerMeta(forceRefresh: true).catchError((e) {
            debugPrint('[RouteSync] Lỗi làm mới meta khách hàng: $e');
            return kDefaultCustomerMeta;
          }),
        ]);
      } else {
        await vm.loadRouteDetail(isRefresh: true);
      }
    } catch (e) {
      debugPrint('[RouteScreenSync] Lỗi đồng bộ: $e');
    }

    // Làm mới provider của form nhập khách hàng
    ref.invalidate(customerFormSchemaProvider);
    ref.invalidate(customerMetaProvider);
    ref.invalidate(userAssignedRoutesProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isOnline
                    ? Icons.check_circle_rounded
                    : Icons.offline_pin_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOnline
                      ? 'Đồng bộ thành công!'
                      : 'Đã làm mới dữ liệu trên máy.',
                ),
              ),
            ],
          ),
          backgroundColor: isOnline
              ? AppColors.primary
              : const Color(0xFFD97706),
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
                Text('Tất cả dữ liệu đã được cập nhật thành công!'),
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
                  child: Text(
                    'Hiện chưa có mạng. Có $pendingCount mục đã lưu và sẽ tự động gửi khi có mạng lại.',
                  ),
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
              Expanded(
                child: Text('Đang gửi $pendingCount mục lên hệ thống...'),
              ),
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
                Text('Đã gửi thành công toàn bộ dữ liệu!'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref
            .read(routeViewModelProvider.notifier)
            .loadRouteDetail(isRefresh: true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã gửi thành công. Còn $remaining mục đang xử lý.',
                  ),
                ),
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
      ref
          .read(routeViewModelProvider.notifier)
          .loadRouteDetail(isRefresh: true);
    }
  }

  Future<void> _handleRefreshGps() async {
    final position = await ref
        .read(locationServiceProvider)
        .checkAndGetLocation(context);
    if (position == null) return;
    ref.invalidate(currentPointProvider);
    ref
        .read(routeViewModelProvider.notifier)
        .updateUserLocation(lat: position.latitude, lng: position.longitude);

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
    final pendingOfflineCount =
        ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;

    ref.listen<RouteState>(routeViewModelProvider, (prev, next) {
      if (next.status == RouteStatus.error &&
          next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        AppErrorDialog.show(
          context,
          title: 'Lỗi tải lộ trình',
          message: next.errorMessage!,
          onRetry: () => vm.loadRouteDetail(isRefresh: true),
        );
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: const VthmTopAppBar(),
      endDrawer: RouteFilterDrawer(state: state, vm: vm),
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
                    final offset = _scrollController.hasClients
                        ? _scrollController.offset
                        : 0.0;
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
                                          style:
                                              AppTypography.titleLarge(
                                                color: isDark
                                                    ? AppColors.darkOnSurface
                                                    : AppColors.onSurface,
                                              ).copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: state.hasActiveFilter
                                                ? AppColors.primary.withValues(
                                                    alpha: isDark ? 0.25 : 0.15,
                                                  )
                                                : AppColors.primary.withValues(
                                                    alpha: 0.1,
                                                  ),
                                            borderRadius: AppRadius.roundedFull,
                                            border: Border.all(
                                              color: state.hasActiveFilter
                                                  ? AppColors.primary.withValues(
                                                      alpha: 0.4,
                                                    )
                                                  : AppColors.primary.withValues(
                                                      alpha: 0.2,
                                                    ),
                                            ),
                                          ),
                                          child: Text(
                                            state.hasActiveFilter
                                                ? '${state.routeDetail?.dealers.length ?? 0}/${state.routeDetail?.totalDealers ?? 0} ${strings.isVietnamese ? 'điểm' : 'stops'}'
                                                : '${state.routeDetail?.totalDealers ?? 0} ${strings.isVietnamese ? 'điểm' : 'stops'}',
                                            style:
                                                AppTypography.labelSmall(
                                                  color: isDark
                                                      ? AppColors
                                                            .primaryFixedDim
                                                      : AppColors.primary,
                                                ).copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
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
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                                        const Spacer(),
                                        _buildFilterButton(context, state, isDark),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      state.hasActiveFilter
                                          ? 'Đang lọc ${state.routeDetail?.dealers.length ?? 0} trên tổng ${state.routeDetail?.totalDealers ?? 0} điểm bán'
                                          : (strings.isVietnamese
                                              ? 'Danh sách điểm bán theo tuyến được giao'
                                              : 'Assigned route store visit plan'),
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
                                  : AppColors.surfaceContainerHigh.withValues(
                                      alpha: 0.5,
                                    ),
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
                                color: isDark
                                    ? AppColors.darkOnSurface
                                    : AppColors.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'Tìm điểm bán, mã KH, SĐT trên tuyến...',
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
                                        icon: const Icon(
                                          Icons.clear_rounded,
                                          size: 16,
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          vm.setSearchQuery('');
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Active Hanging Visit Banner (§3 Luật 3)
                if (state.activeVisit != null) ...[
                  _buildActiveVisitBanner(
                    context,
                    state.activeVisit!,
                    state.routeDetail?.dealers,
                  ),
                ],

                // Main Content List
                Expanded(
                  child:
                      state.status == RouteStatus.loading &&
                          state.routeDetail == null
                      ? const Center(child: AppLoading(size: 220))
                      : state.status == RouteStatus.error &&
                            state.routeDetail == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 48,
                                  color: AppColors.error,
                                ),
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
                                  onPressed: () =>
                                      vm.loadRouteDetail(isRefresh: true),
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 18,
                                  ),
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
                          onRefresh: () async {
                            try {
                              await ref.read(syncServiceProvider).syncQueue();
                            } catch (_) {}
                            await Future.wait([
                              vm.loadRouteDetail(isRefresh: true),
                              ref
                                  .read(mobileRulesProvider.notifier)
                                  .fetchRules(forceRefresh: true),
                              _requestLocationPermission(),
                            ]);
                          },
                          child:
                              state.routeDetail == null ||
                                  state.routeDetail!.dealers.isEmpty
                              ? ListView(
                                  controller: _scrollController,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 40.0),
                                      child: state.searchQuery.trim().isNotEmpty
                                          ? AppEmptyState(
                                              icon: Icons.search_off_rounded,
                                              title: 'Không tìm thấy điểm bán',
                                              description:
                                                  'Không có điểm bán nào trên tuyến khớp với từ khóa "${state.searchQuery}".',
                                              actionText: 'Xóa tìm kiếm',
                                              onAction: () {
                                                _searchController.clear();
                                                vm.setSearchQuery('');
                                              },
                                            )
                                          : state.hasActiveFilter
                                              ? AppEmptyState(
                                                  icon: Icons.filter_alt_off_rounded,
                                                  title: 'Không có điểm bán phù hợp',
                                                  description:
                                                      'Không tìm thấy điểm bán nào thỏa mãn các tiêu chí lọc đã chọn.',
                                                  actionText: 'Đặt lại bộ lọc',
                                                  onAction: () =>
                                                      vm.resetFilters(),
                                                )
                                              : AppEmptyState(
                                                  icon: Icons.alt_route_rounded,
                                              title:
                                                  'Chưa có lộ trình điểm bán',
                                              description: 'Hiện tại chưa có điểm bán nào trên tuyến được giao trong ngày hôm nay. Hãy bấm làm mới để đồng bộ dữ liệu tuyến.',
                                              actionText: 'Làm mới lộ trình',
                                              onAction: () =>
                                                  vm.loadRouteDetail(
                                                    isRefresh: true,
                                                  ),
                                              secondaryActionText:
                                                  'Thêm điểm bán',
                                              onSecondaryAction:
                                                  _handleAddCustomer,
                                            ),
                                    ),
                                  ],
                                )
                              : SingleChildScrollView(
                                  controller: _scrollController,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.marginMobile,
                                    vertical: AppSpacing.stackMd,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      RouteDealerTimeline(
                                        dealers: state.routeDetail!.dealers,
                                      ),
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

  Widget _buildActiveVisitBanner(
    BuildContext context,
    VisitEntity visit,
    List<DealerEntity>? dealers,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dealer = dealers
        ?.where(
          (d) => d.id == visit.customerId.toString() || d.visit?.id == visit.id,
        )
        .firstOrNull;
    final customerName = visit.customerName.isNotEmpty
        ? visit.customerName
        : (dealer?.name ?? 'Điểm bán');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0284C7).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF0284C7).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFF0284C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storefront_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ĐANG CÓ LƯỢT VIẾNG THĂM CHƯA ĐÓNG',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0284C7),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkOnSurface
                        : AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: () {
              if (dealer != null) {
                final dealerToInit = dealer.visit != null
                    ? dealer
                    : dealer.copyWith(
                        visit: visit,
                        status: DealerVisitStatus.inProgress,
                      );
                ref
                    .read(checkInViewModelProvider.notifier)
                    .initCheckinWithDealer(dealerToInit);
                context.push('/check-in', extra: dealerToInit);
              } else {
                final fallbackDealer = DealerEntity(
                  id: visit.customerId.toString(),
                  order: '01',
                  name: customerName,
                  address: '',
                  status: DealerVisitStatus.inProgress,
                  statusLabel: 'Đang ghé',
                  isVip: false,
                  visit: visit,
                );
                ref
                    .read(checkInViewModelProvider.notifier)
                    .initCheckinWithDealer(fallbackDealer);
                context.push('/check-in', extra: fallbackDealer);
              }
            },
            child: const Text(
              'Vào lượt',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(
    BuildContext context,
    RouteState state,
    bool isDark,
  ) {
    final count = state.activeFiltersCount;
    final hasFilters = state.hasActiveFilter;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _scaffoldKey.currentState?.openEndDrawer();
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: hasFilters
                ? AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.12)
                : (isDark
                    ? AppColors.darkSurfaceContainer
                    : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasFilters
                  ? AppColors.primary
                  : (isDark
                      ? AppColors.darkOutlineVariant
                      : AppColors.outlineVariant),
              width: hasFilters ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 16,
                color: hasFilters
                    ? AppColors.primary
                    : (isDark ? AppColors.darkOnSurface : AppColors.onSurface),
              ),
              const SizedBox(width: 5),
              Text(
                'Lọc',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: hasFilters ? FontWeight.w700 : FontWeight.w600,
                  color: hasFilters
                      ? AppColors.primary
                      : (isDark ? AppColors.darkOnSurface : AppColors.onSurface),
                ),
              ),
              if (hasFilters) ...[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
