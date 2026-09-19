import 'dart:async';
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
import '../../domain/entities/customer_entity.dart';
import '../viewmodels/customer_view_model.dart';
import '../widgets/customer_card.dart';
import '../widgets/edit_customer_dialog.dart';
import 'add_customer_screen.dart';

class CustomerScreen extends ConsumerStatefulWidget {
  const CustomerScreen({super.key});

  @override
  ConsumerState<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends ConsumerState<CustomerScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
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
    EditCustomerDialog.show(
      context,
      customer: customer,
      meta: state.meta,
      dynamicColumns: state.dynamicColumns,
      onSave: (changes) => vm.updateCustomer(
        customer.id,
        changes,
      ),
    );
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
                isOnline
                    ? (initialPending > 0
                        ? 'Đang gửi $initialPending mục ngoại tuyến và cập nhật danh sách...'
                        : 'Đang đồng bộ dữ liệu điểm bán từ máy chủ...')
                    : 'Đang tải lại dữ liệu từ bộ nhớ thiết bị...',
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
        await ref.read(syncServiceProvider).syncQueue();
      }
      await ref.read(customerViewModelProvider.notifier).loadCustomers(isRefresh: true);

      final remaining = await db.countPendingSync();
      final totalCustomers = ref.read(customerViewModelProvider).totalCount;

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isOnline ? Icons.check_circle_rounded : Icons.offline_pin_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isOnline
                        ? (initialPending > 0 && remaining == 0
                            ? 'Đã gửi $initialPending mục ngoại tuyến và cập nhật $totalCustomers điểm bán!'
                            : 'Đã đồng bộ $totalCustomers điểm bán từ máy chủ thành công!')
                        : (initialPending > 0
                            ? 'Đang offline. Có $initialPending mục chờ gửi, đã làm mới $totalCustomers điểm bán trên máy.'
                            : 'Đã tải lại $totalCustomers điểm bán từ bộ nhớ máy.'),
                  ),
                ),
              ],
            ),
            backgroundColor: isOnline ? const Color(0xFF10B981) : const Color(0xFFD97706),
            duration: const Duration(seconds: 3),
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

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      floatingActionButton: _buildSyncFab(
        isDark: isDark,
        pendingCount: pendingCount,
        isSyncing: _isSyncing,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header & Search Bar Section
            Container(
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
                children: [
                  // Title Row with Quick Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                      '${state.totalCount} điểm',
                                      style: AppTypography.labelSmall(
                                        color: isDark
                                            ? AppColors.primaryFixedDim
                                            : AppColors.primary,
                                      ).copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                strings.customerSubtitle,
                                style: AppTypography.bodySmall(
                                  color: isDark
                                      ? AppColors.darkOnSurfaceVariant
                                      : AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Add Customer Button
                      InkWell(
                        onTap: () async {
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddCustomerScreen(),
                            ),
                          );
                          if (result == true && mounted) {
                            vm.loadCustomers(isRefresh: true);
                          }
                        },
                        borderRadius: AppRadius.roundedMd,
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.primary : AppColors.primaryContainer,
                            borderRadius: AppRadius.roundedMd,
                            boxShadow: AppShadows.level1,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.person_add_alt_1_rounded,
                                size: 15,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                strings.addCustomer,
                                style: AppTypography.labelSmall(
                                  color: Colors.white,
                                ).copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Search Text Field
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
                              _requestLocationPermission(),
                            ]);
                          },
                          child: customerList.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 80.0),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.person_search_rounded,
                                              size: 56,
                                              color: isDark
                                                  ? AppColors.darkOnSurfaceVariant
                                                  : AppColors.outline,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Không tìm thấy điểm bán nào',
                                              style: AppTypography.titleMedium(
                                                color: isDark
                                                    ? AppColors.darkOnSurfaceVariant
                                                    : AppColors.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
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
                                    return CustomerCard.fromCustomerWithDistance(
                                      key: ValueKey(item.customer.id),
                                      item: item,
                                      onEdit: () => _onEditCustomer(item.customer),
                                      onTap: () => _onEditCustomer(item.customer),
                                    );
                                  },
                                ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncFab({
    required bool isDark,
    required int pendingCount,
    required bool isSyncing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 72),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                Color(0xFF10B981), // Emerald
                Color(0xFF059669), // Dark Emerald
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: Tooltip(
              message: 'Đồng bộ dữ liệu điểm bán',
              child: InkWell(
                onTap: isSyncing ? null : _handleSync,
                customBorder: const CircleBorder(),
                child: Center(
                  child: RotationTransition(
                    turns: _syncAnimationController,
                    child: const Icon(
                      Icons.sync_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Red badge on FAB if there are pending offline items
        if (pendingCount > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Center(
                child: Text(
                  pendingCount > 99 ? '99+' : '$pendingCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
}
