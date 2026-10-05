import 'dart:async';
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
import '../../domain/entities/customer_entity.dart';
import '../viewmodels/customer_view_model.dart';
import '../widgets/customer_card.dart';
import '../widgets/customer_circular_menu.dart';
import 'add_customer_screen.dart';
import 'edit_customer_screen.dart';
import '../../data/repositories/customer_repository_impl.dart';
import '../widgets/pending_sync_dismissible.dart';
import '../../../../core/rules/mobile_rules_service.dart';
import '../widgets/customer_filter_drawer.dart';

class CustomerScreen extends ConsumerStatefulWidget {
  const CustomerScreen({super.key});

  @override
  ConsumerState<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends ConsumerState<CustomerScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  late final AnimationController _syncAnimationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  bool _isSyncing = false;

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

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        ref.read(customerViewModelProvider.notifier).setSearchQuery(query);
      }
    });
  }

  void _onEditCustomer(CustomerEntity customer) {
    final state = ref.read(customerViewModelProvider);
    final vm = ref.read(customerViewModelProvider.notifier);
    EditCustomerScreen.open(
      context,
      customer: customer,
      meta: state.meta,
      dynamicColumns: state.dynamicColumns,
      onSave: (changes) => vm.updateCustomer(
        customer.id,
        changes,
        clientUuid: customer.clientUuid,
      ),
    );
  }

  Future<void> _onOpenCustomerDetail(CustomerEntity customer) async {
    final updated = await context.push<CustomerEntity>(
      '/customers/detail',
      extra: customer,
    );
    if (updated != null && mounted) {
      ref.read(customerViewModelProvider.notifier).loadCustomers(isRefresh: false);
    }
  }

  Future<void> _handleAddCustomer() async {
    final result = await context.push<bool>('/customers/add');
    if (result == true && mounted) {
      final vm = ref.read(customerViewModelProvider.notifier);
      final currentTab = ref.read(customerViewModelProvider).selectedTab;
      if (currentTab == CustomerFilterTab.visited) {
        vm.selectTab(CustomerFilterTab.all);
      }
      if (_searchController.text.isNotEmpty) {
        _debounceTimer?.cancel();
        _searchController.clear();
        vm.setSearchQuery('');
      }
      await vm.loadCustomers(isRefresh: true);
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
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
                  child: Text(
                      'Hiện không có mạng. Có $pendingCount mục sẽ tự động gửi khi có kết nối.'),
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
                child: Text('Đang tải lên $pendingCount mục dữ liệu ngoại tuyến...'),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    final syncResult = await ref.read(syncServiceProvider).syncQueue(force: true);
    await ref.read(customerViewModelProvider.notifier).loadCustomers(isRefresh: true);
    final remaining = await db.countPendingSync();
    final deadCount = await db.countDeadSync();

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (syncResult.hasDeadErrors || deadCount > 0) {
        final deadItems = await db.getDeadQueueEntries();
        if (!mounted) return;
        final msgs = deadItems.map((e) => e.lastError ?? 'Lỗi không xác định (4xx)').take(3).join('\n• ');
        AppErrorDialog.show(
          context,
          title: 'Lỗi dữ liệu vĩnh viễn (4xx)',
          message: 'Máy chủ từ chối $deadCount mục do lỗi dữ liệu hoặc thông tin không hợp lệ (4xx):\n\n• $msgs\n\nCác mục này sẽ KHÔNG được gửi lại để tránh lỗi lặp lại. Vui lòng kiểm tra hoặc chỉnh sửa lại thông tin điểm bán.',
          dismissText: 'Đã hiểu',
        );
      } else if (remaining == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Đã tải lên thành công toàn bộ dữ liệu!'),
                ),
              ],
            ),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mất mạng hoặc lỗi máy chủ (500), còn $remaining mục sẽ tự động thử lại khi có kết nối.',
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
    }
  }

  Future<void> _handleRefreshGps() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              AppLoading(size: 32),
              SizedBox(width: 10),
              Text('Đang lấy vị trí GPS chính xác...'),
            ],
          ),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    final pos =
        await ref.read(locationServiceProvider).checkAndGetLocation(context);
    if (pos != null && mounted) {
      ref.invalidate(currentPointProvider);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.my_location_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đã cập nhật vị trí GPS: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2563EB),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleSortByDistance() async {
    final vm = ref.read(customerViewModelProvider.notifier);
    final state = ref.read(customerViewModelProvider);

    if (state.isSortedByDistance) {
      vm.toggleSortByDistance(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã hủy sắp xếp theo khoảng cách.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    var livePoint = ref.read(currentPointProvider).value;
    if (livePoint == null) {
      final pos =
          await ref.read(locationServiceProvider).checkAndGetLocation(context);
      if (pos != null) {
        ref.invalidate(currentPointProvider);
        livePoint = ref.read(currentPointProvider).value;
      }
    }

    vm.toggleSortByDistance(true);
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
  }

  Future<void> _handleSync() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _syncAnimationController.repeat();
    });

    final isOnline = ref.read(connectivityProvider).isOnline;
    final db = ref.read(appDatabaseProvider);
    final initialPending = await db.countPendingSync();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const AppLoading(size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isOnline ? 'Đang đồng bộ...' : 'Đang tải lại dữ liệu từ bộ nhớ máy...',
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      if (isOnline && initialPending > 0) {
        final syncResult = await ref.read(syncServiceProvider).syncQueue(force: true);
        if (syncResult.hasDeadErrors && mounted) {
          final msgs = syncResult.deadErrors.map((e) => e.message).take(3).join('\n• ');
          AppErrorDialog.show(
            context,
            title: 'Lỗi dữ liệu vĩnh viễn (4xx)',
            message: 'Máy chủ từ chối ${syncResult.deadErrors.length} mục do dữ liệu không hợp lệ (4xx):\n\n• $msgs\n\nCác mục này sẽ KHÔNG được gửi lại để tránh lỗi lặp lại.',
            dismissText: 'Đã hiểu',
          );
        }
      }
      await ref.read(customerViewModelProvider.notifier).loadCustomers(isRefresh: true);
      if (isOnline) {
        try {
          final customerRepo = ref.read(customerRepositoryProvider);
          await Future.wait([
            customerRepo.getCustomerFormSchema(forceRefresh: true),
            customerRepo.getCustomerMeta(forceRefresh: true),
          ]);
        } catch (e) {
          debugPrint('[CustomerSync] Lỗi làm mới schema form: $e');
        }
      }
      ref.invalidate(customerFormSchemaProvider);
      ref.invalidate(customerMetaProvider);
      ref.invalidate(userAssignedRoutesProvider);

      final deadCount = await db.countDeadSync();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isOnline
                      ? (deadCount > 0
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_rounded)
                      : Icons.offline_pin_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isOnline
                        ? (deadCount > 0
                            ? 'Có $deadCount mục lỗi dữ liệu vĩnh viễn (4xx).'
                            : 'Đồng bộ thành công!')
                        : (initialPending > 0
                            ? 'Đang offline, có $initialPending mục chờ gửi.'
                            : 'Đã tải lại dữ liệu từ bộ nhớ máy.'),
                  ),
                ),
              ],
            ),
            backgroundColor: isOnline
                ? (deadCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF10B981))
                : const Color(0xFFD97706),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đồng bộ: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncAnimationController.stop();
          _syncAnimationController.reset();
        });
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _syncAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerViewModelProvider);
    final vm = ref.read(customerViewModelProvider.notifier);
    final customerList = ref.watch(filteredCustomersProvider);
    final strings = ref.watch(stringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendingCount = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final deadCount = ref.watch(deadSyncCountProvider).valueOrNull ?? 0;
    final isFiltered = state.activeFiltersCount > 0 ||
        state.searchQuery.trim().isNotEmpty ||
        state.selectedTab != CustomerFilterTab.all ||
        customerList.length != state.totalCount;

    ref.listen<CustomerState>(customerViewModelProvider, (prev, next) {
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        AppErrorDialog.show(
          context,
          title: 'Lỗi tải dữ liệu điểm bán',
          message: next.errorMessage!,
          onRetry: () => ref.read(customerViewModelProvider.notifier).loadCustomers(isRefresh: true),
        );
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: const VthmTopAppBar(),
      endDrawer: CustomerFilterDrawer(state: state, vm: vm),
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
                                // Title Row with Count Badge & Filter
                                Row(
                                  children: [
                                    Text(
                                      strings.customerScreenTitle,
                                      style: AppTypography.titleLarge(
                                        color: isDark
                                            ? AppColors.darkOnSurface
                                            : AppColors.onSurface,
                                      ).copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isFiltered
                                              ? AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.15)
                                              : AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: AppRadius.roundedFull,
                                          border: Border.all(
                                            color: isFiltered
                                                ? AppColors.primary.withValues(alpha: 0.4)
                                                : AppColors.primary.withValues(alpha: 0.2),
                                          ),
                                        ),
                                        child: Text(
                                          isFiltered
                                              ? '${customerList.length}/${state.totalCount} điểm'
                                              : '${state.totalCount} điểm',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.labelSmall(
                                            color: isDark
                                                ? AppColors.primaryFixedDim
                                                : AppColors.primary,
                                          ).copyWith(fontWeight: FontWeight.w700),
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
                                    const Spacer(),
                                    _buildFilterButton(context, state, isDark),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isFiltered
                                      ? 'Đang hiển thị ${customerList.length} trên tổng ${state.totalCount} điểm bán'
                                      : strings.customerSubtitle,
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
                          onChanged: _onSearchChanged,
                          style: AppTypography.bodyMedium(
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: strings.customerSearchHint,
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
                                      _debounceTimer?.cancel();
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

            // Banner cảnh báo lỗi vĩnh viễn (4xx) không thể tự động retry
            if (deadCount > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFFCA5A5), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Có $deadCount mục lỗi dữ liệu (4xx) không thể gửi.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () async {
                        final db = ref.read(appDatabaseProvider);
                        final deadEntries = await db.getDeadQueueEntries();
                        if (!context.mounted) return;
                        final msgs = deadEntries
                            .map((e) => e.lastError ?? 'Lỗi không xác định (4xx)')
                            .take(3)
                            .join('\n• ');
                        AppErrorDialog.show(
                          context,
                          title: 'Lỗi dữ liệu vĩnh viễn (4xx)',
                          message:
                              'Máy chủ từ chối các mục này do dữ liệu không hợp lệ (4xx):\n\n• $msgs\n\nHệ thống đã dừng gửi lại các mục này để tránh lỗi lặp lại. Vui lòng bấm Sửa để chỉnh lại thông tin điểm bán.',
                          dismissText: 'Đã hiểu',
                        );
                      },
                      child: const Text(
                        'Xem lỗi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Customer List View / Status Area
            Expanded(
              child: state.isLoading && state.allCustomers.isEmpty
                  ? const Center(
                      child: AppLoading(size: 220),
                    )
                  : state.errorMessage != null && state.allCustomers.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                                const SizedBox(height: 12),
                                Text(
                                  state.errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyMedium(
                                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => vm.loadCustomers(isRefresh: true),
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
                          onRefresh: () async {
                            await Future.wait([
                              vm.loadCustomers(isRefresh: true),
                              ref.read(mobileRulesProvider.notifier).fetchRules(forceRefresh: true),
                              _requestLocationPermission(),
                            ]);
                          },
                          child: customerList.isEmpty
                              ? ListView(
                                  controller: _scrollController,
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 40.0),
                                      child: isFiltered
                                          ? AppEmptyState(
                                              icon: Icons.search_off_rounded,
                                              title: 'Không tìm thấy điểm bán phù hợp',
                                              description: state.searchQuery.trim().isNotEmpty
                                                  ? 'Không có điểm bán nào khớp với từ khóa "${state.searchQuery}".'
                                                  : 'Không có điểm bán nào khớp với bộ lọc đang chọn.',
                                              actionText: 'Đặt lại bộ lọc',
                                              onAction: () {
                                                _debounceTimer?.cancel();
                                                _searchController.clear();
                                                vm.resetFilters();
                                              },
                                            )
                                          : AppEmptyState(
                                              icon: Icons.storefront_outlined,
                                              title: 'Chưa có dữ liệu điểm bán',
                                              description:
                                                  'Danh sách điểm bán hiện đang trống hoặc chưa được đồng bộ từ hệ thống máy chủ.',
                                              actionText: 'Làm mới dữ liệu',
                                              onAction: () => vm.loadCustomers(isRefresh: true),
                                              secondaryActionText: 'Thêm điểm bán',
                                              onSecondaryAction: _handleAddCustomer,
                                            ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  controller: _scrollController,
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.marginMobile,
                                    AppSpacing.stackMd,
                                    AppSpacing.marginMobile,
                                    160, // Khoảng trống tránh bị che bởi floating button và nav bar
                                  ),
                                  itemCount: customerList.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final item = customerList[index];
                                    final isPending = item.customer.syncStatus == 'pending' ||
                                        item.customer.syncStatus == 'error';
                                    final clientUuid = item.customer.clientUuid;
                                    final itemKey = clientUuid ?? 'customer_${item.customer.id}_$index';

                                    return PendingSyncDismissible(
                                      key: ValueKey('dismissible_$itemKey'),
                                      itemKey: itemKey,
                                      title: item.customer.name,
                                      isPending: isPending,
                                      onConfirmDelete: () async {
                                        if (clientUuid != null) {
                                          return await vm.deletePendingCustomer(clientUuid);
                                        }
                                        return false;
                                      },
                                        child: CustomerCard.fromCustomerWithDistance(
                                          key: ValueKey(itemKey),
                                          item: item,
                                          onEdit: () => _onEditCustomer(item.customer),
                                          onTap: () => _onOpenCustomerDetail(item.customer),
                                        ),
                                    );
                                  },
                                ),
                        ),
            ),
          ],
        ),
      ),

      // Circular Radial Menu overlay
      Positioned.fill(
        child: CustomerCircularMenu(
          onAddCustomer: _handleAddCustomer,
          onSync: _handleSync,
          onSendOfflineData: _handleSendOfflineData,
          onRefreshGps: _handleRefreshGps,
          onSortByDistance: _handleSortByDistance,
          isSortedByDistance: state.isSortedByDistance,
          pendingOfflineCount: pendingCount,
          isSyncing: _isSyncing || state.isLoading,
        ),
      ),
    ],
  ),
);
  }

  Widget _buildFilterButton(
    BuildContext context,
    CustomerState state,
    bool isDark,
  ) {
    final count = state.activeFiltersCount;
    final hasFilters = count > 0;

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
                : (isDark ? AppColors.darkSurfaceContainer : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasFilters
                  ? AppColors.primary
                  : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
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
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
