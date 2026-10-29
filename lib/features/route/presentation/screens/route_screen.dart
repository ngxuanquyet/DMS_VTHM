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
import '../../../../core/widgets/app_snackbar.dart';
import '../states/route_state.dart';
import '../viewmodels/route_view_model.dart';
import '../widgets/route_circular_menu.dart';
import '../widgets/route_dealer_timeline.dart';
import '../widgets/route_filter_drawer.dart';
import '../widgets/route_map_view.dart';
import '../../../visit/domain/entities/visit_entity.dart';
import '../../domain/entities/route_entity.dart';
import '../../../customer/data/repositories/customer_repository_impl.dart';
import '../../../customer/presentation/screens/add_customer_screen.dart';
import '../../../../core/rules/mobile_rules_service.dart';
import '../../../../core/constants/search_target.dart';
import '../../../../core/services/erp_catalog_service.dart';
import '../../../../core/widgets/search_target_chips.dart';

class RouteScreen extends ConsumerStatefulWidget {
  const RouteScreen({super.key});

  @override
  ConsumerState<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends ConsumerState<RouteScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isMapView = false;
  DealerEntity? _selectedDealerOnMap;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onSearchFocusOrTextChanged);
    _searchController.addListener(_onSearchFocusOrTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestLocationPermission();
    });
  }

  void _onSearchFocusOrTextChanged() {
    if (mounted) setState(() {});
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(routeViewModelProvider.notifier).setSearchQuery('');
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
    _searchFocusNode.dispose();
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
        AppSnackBar.showError(
          context,
          'Không thể lấy tọa độ GPS để tính khoảng cách.',
        );
      }
    }
  }

  Future<void> _handleSync() async {
    final vm = ref.read(routeViewModelProvider.notifier);
    final isOnline = ref.read(connectivityProvider).isOnline;
    final customerRepo = ref.read(customerRepositoryProvider);
    // Danh mục khách ERP cho bước nối điểm bán (#24327) — "Đồng bộ" luôn tải lại ngầm.
    ref.read(erpCatalogServiceProvider).refreshInBackground(online: isOnline);

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
    await context.push('/customers/add');
    if (mounted) {
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
          content: const Text(
            'Đã định vị vị trí hiện tại thành công',
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
                                    // Title Header with Subtitle on Left & Filter Button on Right
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
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
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildViewModeToggle(context, isDark),
                                        const SizedBox(width: 8),
                                        _buildFilterButton(context, state, isDark),
                                      ],
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
                                color: _searchFocusNode.hasFocus
                                    ? (isDark
                                        ? const Color(0xFF38BDF8)
                                        : AppColors.primary)
                                    : (isDark
                                        ? AppColors.darkOutlineVariant
                                        : AppColors.outlineVariant),
                                width: _searchFocusNode.hasFocus ? 1.4 : 1.0,
                              ),
                            ),
                            child: TextField(
                              focusNode: _searchFocusNode,
                              controller: _searchController,
                              onChanged: vm.setSearchQueryDebounced,
                              style: AppTypography.bodyMedium(
                                color: isDark
                                    ? AppColors.darkOnSurface
                                    : AppColors.onSurface,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: state.searchTarget.hintText,
                                hintStyle: AppTypography.bodySmall(
                                  color: isDark
                                      ? AppColors.darkOnSurfaceVariant
                                      : AppColors.outline,
                                ),
                                prefixIcon: PopupMenuButton<SearchTarget>(
                                  tooltip: 'Chọn tiêu chí tìm kiếm',
                                  initialValue: state.searchTarget,
                                  onSelected: (target) => vm.setSearchTarget(target),
                                  itemBuilder: (context) => SearchTarget.values
                                      .map(
                                        (target) => PopupMenuItem<SearchTarget>(
                                          value: target,
                                          child: Row(
                                            children: [
                                              Icon(
                                                target.icon,
                                                size: 16,
                                                color: state.searchTarget == target
                                                    ? (isDark
                                                        ? const Color(0xFF38BDF8)
                                                        : const Color(0xFF006874))
                                                    : (isDark
                                                        ? AppColors.darkOnSurfaceVariant
                                                        : AppColors.onSurfaceVariant),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                target.label,
                                                style: TextStyle(
                                                  fontWeight: state.searchTarget == target
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: state.searchTarget == target
                                                      ? (isDark
                                                          ? const Color(0xFF38BDF8)
                                                          : const Color(0xFF006874))
                                                      : null,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(width: 10),
                                      Icon(
                                        state.searchTarget.icon,
                                        size: 18,
                                        color: isDark
                                            ? AppColors.darkOnSurfaceVariant
                                            : AppColors.outline,
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        Icons.arrow_drop_down_rounded,
                                        size: 16,
                                        color: isDark
                                            ? AppColors.darkOnSurfaceVariant
                                            : AppColors.outline,
                                      ),
                                      Container(
                                        margin: const EdgeInsets.only(left: 4, right: 6),
                                        width: 1,
                                        height: 18,
                                        color: isDark
                                            ? AppColors.darkOutlineVariant
                                            : AppColors.outlineVariant,
                                      ),
                                    ],
                                  ),
                                ),
                                prefixIconConstraints:
                                    const BoxConstraints(minWidth: 40, maxHeight: 42),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.clear_rounded,
                                          size: 16,
                                        ),
                                        onPressed: _clearSearch,
                                      )
                                    : null,
                                suffixIconConstraints:
                                    const BoxConstraints(minWidth: 36, maxHeight: 42),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                filled: false,
                                fillColor: Colors.transparent,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),

                          // Options tìm kiếm dạng Filter Chips (Hiện khi gõ hoặc khi focus)
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            child: (_searchFocusNode.hasFocus || _searchController.text.isNotEmpty)
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: SearchTargetChips(
                                      currentTarget: state.searchTarget,
                                      onTargetChanged: (target) => vm.setSearchTarget(target),
                                      isDark: isDark,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),

                          // Row lọc tuyến theo ngày ở dưới thanh tìm kiếm
                          const SizedBox(height: 10),
                          _buildDayFilterRow(context, state, vm, isDark),
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
                      : _isMapView
                          ? RouteMapView(
                              dealers: state.routeDetail?.dealers ?? [],
                              onSelectedDealerChanged: (dealer) {
                                if (_selectedDealerOnMap?.id != dealer?.id) {
                                  setState(() => _selectedDealerOnMap = dealer);
                                }
                              },
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
                                                  'Không có điểm bán nào trên tuyến khớp với từ khóa "${state.searchQuery}" (${state.searchTarget.label}).',
                                              actionText: state.searchTarget != SearchTarget.all
                                                  ? 'Tìm trong tất cả tiêu chí'
                                                  : 'Xóa tìm kiếm',
                                              onAction: () {
                                                if (state.searchTarget != SearchTarget.all) {
                                                  vm.setSearchTarget(SearchTarget.all);
                                                } else {
                                                  _clearSearch();
                                                }
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
                              : RouteDealerTimeline(
                                  dealers: state.routeDetail!.dealers,
                                  controller: _scrollController,
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.marginMobile,
                                    AppSpacing.stackMd,
                                    AppSpacing.marginMobile,
                                    160, // Khoảng trống tránh bị che bởi menu tròn và nav bar
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
              onOpenRejected: () => context.push('/customers/rejected'),
              onRefreshGps: _handleRefreshGps,
              onToggleMapView: () => setState(() {
                _isMapView = !_isMapView;
                if (!_isMapView) _selectedDealerOnMap = null;
              }),
              isSortedByDistance: state.isSortedByDistance,
              isMapView: _isMapView,
              pendingOfflineCount: pendingOfflineCount,
              isSyncing: state.status == RouteStatus.loading,
              bottomOffset: (_isMapView && _selectedDealerOnMap != null) ? 202.0 : 88.0,
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
            onPressed: () async {
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
                await context.push('/check-in', extra: dealerToInit);
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
                await context.push('/check-in', extra: fallbackDealer);
              }
              if (context.mounted) {
                ref.read(routeViewModelProvider.notifier).loadRouteDetail();
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

  Widget _buildViewModeToggle(BuildContext context, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _isMapView = !_isMapView;
            if (!_isMapView) _selectedDealerOnMap = null;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _isMapView
                ? (isDark ? const Color(0xFF006E15) : AppColors.primary)
                : (isDark
                    ? AppColors.darkSurfaceContainer
                    : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isMapView
                  ? AppColors.primary
                  : (isDark
                      ? AppColors.darkOutlineVariant
                      : AppColors.outlineVariant),
              width: _isMapView ? 1.5 : 1,
            ),
            boxShadow: _isMapView
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                _isMapView ? Icons.format_list_bulleted_rounded : Icons.map_rounded,
                size: 16,
                color: _isMapView
                    ? Colors.white
                    : (isDark
                        ? AppColors.darkOnSurfaceVariant
                        : AppColors.onSurfaceVariant),
              ),
              const SizedBox(width: 5),
              Text(
                _isMapView ? 'Danh sách' : 'Bản đồ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _isMapView ? FontWeight.w700 : FontWeight.w600,
                  color: _isMapView
                      ? Colors.white
                      : (isDark
                          ? AppColors.darkOnSurface
                          : AppColors.onSurface),
                ),
              ),
            ],
          ),
        ),
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
            crossAxisAlignment: CrossAxisAlignment.center,
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
                  height: 1.15,
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

  /// Row lọc tuyến theo ngày trong tuần (T2 .. CN / Hôm nay / DatePicker)
  Widget _buildDayFilterRow(
    BuildContext context,
    RouteState state,
    RouteViewModel vm,
    bool isDark,
  ) {
    final todayWeekday = DateTime.now().weekday;
    final selectedDay = state.selectedDayOfWeek;

    final days = const [
      (day: 1, label: 'Thứ 2', short: 'T2'),
      (day: 2, label: 'Thứ 3', short: 'T3'),
      (day: 3, label: 'Thứ 4', short: 'T4'),
      (day: 4, label: 'Thứ 5', short: 'T5'),
      (day: 5, label: 'Thứ 6', short: 'T6'),
      (day: 6, label: 'Thứ 7', short: 'T7'),
      (day: 7, label: 'Chủ nhật', short: 'CN'),
    ];

    final isAllSelected = selectedDay == null;

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          // Nút Chọn Lịch (DatePicker dialog)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2025),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                    helpText: 'CHỌN NGÀY ĐI TUYẾN',
                    cancelText: 'HỦY',
                    confirmText: 'CHỌN',
                  );
                  if (picked != null) {
                    vm.selectDayOfWeek(picked.weekday);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceContainer
                        : AppColors.surfaceContainerHigh.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkOutlineVariant
                          : AppColors.outlineVariant.withValues(alpha: 0.7),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 16,
                        color: isDark
                            ? AppColors.darkOnSurfaceVariant
                            : AppColors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Chip "Tất cả"
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => vm.selectDayOfWeek(null),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isAllSelected
                        ? (isDark ? const Color(0xFF006E15) : AppColors.primary)
                        : (isDark
                            ? AppColors.darkSurfaceContainer
                            : AppColors.surfaceContainerHigh.withValues(alpha: 0.6)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isAllSelected
                          ? AppColors.primary
                          : (isDark
                              ? AppColors.darkOutlineVariant
                              : AppColors.outlineVariant.withValues(alpha: 0.7)),
                      width: isAllSelected ? 1.4 : 1,
                    ),
                    boxShadow: isAllSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.28),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.apps_rounded,
                        size: 13,
                        color: isAllSelected
                            ? Colors.white
                            : (isDark
                                ? AppColors.darkOnSurfaceVariant
                                : AppColors.onSurfaceVariant),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Tất cả',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isAllSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isAllSelected
                              ? Colors.white
                              : (isDark
                                  ? AppColors.darkOnSurface
                                  : AppColors.onSurface),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Chips các ngày trong tuần (T2 .. CN)
          ...days.map((item) {
            final isSelected = selectedDay == item.day;
            final isToday = item.day == todayWeekday;
            final count = vm.getDealerCountForDay(item.day);

            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => vm.selectDayOfWeek(item.day),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? const Color(0xFF006E15) : AppColors.primary)
                          : (isDark
                              ? AppColors.darkSurfaceContainer
                              : AppColors.surfaceContainerHigh.withValues(alpha: 0.6)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : isToday
                                ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                                : (isDark
                                    ? AppColors.darkOutlineVariant
                                    : AppColors.outlineVariant.withValues(alpha: 0.7)),
                        width: isSelected ? 1.4 : (isToday ? 1.2 : 1),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.28),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isToday) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          isToday ? '${item.label} (Hôm nay)' : item.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected || isToday
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                                    : (isDark
                                        ? AppColors.darkOnSurface
                                        : AppColors.onSurface),
                          ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                        ? AppColors.darkOnSurfaceVariant
                                        : AppColors.onSurfaceVariant),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
