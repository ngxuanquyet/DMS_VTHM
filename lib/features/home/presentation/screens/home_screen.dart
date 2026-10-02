import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/rules/mobile_rules_service.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_dialog.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../../../customer/presentation/viewmodels/customer_view_model.dart';
import '../../../forms/data/services/route_customers_service.dart';
import '../../../route/presentation/viewmodels/route_view_model.dart';
import '../states/home_state.dart';
import '../viewmodels/home_view_model.dart';
import '../widgets/attendance_summary_card.dart';
import '../widgets/greeting_header.dart';
import '../widgets/home_quick_actions.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isSyncing = false;

  /// Gọi tất cả các API để đồng bộ dữ liệu mới nhất:
  /// - Quy tắc vận hành (/dms/mobile-rules)
  /// - Danh sách điểm bán theo tuyến (/dms/routes/customers)
  /// - Khách hàng (/dms/customers)
  /// - Tuyến bán hàng & lượt viếng thăm hôm nay (/dms/routes, /dms/visits/today)
  /// - Dashboard trang chủ (/dms/dashboard)
  /// - Đẩy hàng đợi ngoại tuyến nếu có
  Future<void> _handleSyncAll() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Đang đồng bộ dữ liệu (điểm bán, tuyến, quy tắc)...',
                style: AppTypography.bodyMedium(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0284C7),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );

    int failureCount = 0;

    // 1. Cập nhật rules thị trường (/dms/mobile-rules)
    try {
      await ref.read(mobileRulesProvider.notifier).fetchRules(forceRefresh: true);
    } catch (e) {
      debugPrint('[HomeScreenSync] Lỗi fetchRules: $e');
      failureCount++;
    }

    // 2. Cập nhật danh sách điểm bán theo tuyến (/dms/routes/customers)
    try {
      await ref.read(routeCustomersServiceProvider).getRouteCustomers(forceRefresh: true);
    } catch (e) {
      debugPrint('[HomeScreenSync] Lỗi getRouteCustomers: $e');
      failureCount++;
    }

    // 3. Cập nhật khách hàng (/dms/customers)
    try {
      await ref.read(customerViewModelProvider.notifier).loadCustomers(isRefresh: true);
    } catch (e) {
      debugPrint('[HomeScreenSync] Lỗi loadCustomers: $e');
      failureCount++;
    }

    // 4. Cập nhật tuyến bán hàng & lượt viếng thăm hôm nay
    try {
      await ref.read(routeViewModelProvider.notifier).loadRouteDetail(isRefresh: true);
    } catch (e) {
      debugPrint('[HomeScreenSync] Lỗi loadRouteDetail: $e');
      failureCount++;
    }

    // 5. Cập nhật dashboard trang chủ & trạng thái chấm công
    try {
      await ref.read(homeViewModelProvider.notifier).loadDashboard(isRefresh: true);
    } catch (e) {
      debugPrint('[HomeScreenSync] Lỗi loadDashboard: $e');
      failureCount++;
    }

    // 6. Đẩy dữ liệu ngoại tuyến nếu có
    try {
      await ref.read(syncServiceProvider).syncQueue(force: true);
    } catch (e) {
      debugPrint('[HomeScreenSync] Lỗi syncQueue: $e');
    }

    if (!mounted) return;
    setState(() => _isSyncing = false);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (failureCount >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Không thể đồng bộ toàn bộ dữ liệu. Vui lòng kiểm tra kết nối mạng.'),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Đồng bộ thành công! Đã cập nhật điểm bán, tuyến và quy tắc mới nhất.'),
              ),
            ],
          ),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeViewModelProvider);
    final homeVM = ref.read(homeViewModelProvider.notifier);
    final strings = ref.watch(stringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<HomeState>(homeViewModelProvider, (prev, next) {
      if (next.status == HomeStatus.error &&
          next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        AppErrorDialog.show(
          context,
          title: 'Lỗi tải trang chủ',
          message: next.errorMessage!,
          onRetry: () => homeVM.loadDashboard(isRefresh: true),
        );
      }
    });

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: const VthmTopAppBar(),
      body: homeState.status == HomeStatus.loading && homeState.dashboard == null
          ? const Center(
              child: AppLoading(size: 220),
            )
          : homeState.status == HomeStatus.error && homeState.dashboard == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                        const SizedBox(height: 12),
                        Text(
                          homeState.errorMessage ?? strings.error,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium(
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => homeVM.loadDashboard(),
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
                  onRefresh: () => homeVM.loadDashboard(isRefresh: true),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.marginMobile,
                      vertical: AppSpacing.stackMd,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Greeting
                        if (homeState.dashboard?.greeting != null)
                          GreetingHeader(greeting: homeState.dashboard!.greeting),
                        const SizedBox(height: AppSpacing.stackLg),

                        // Card trạng thái chấm công
                        if (homeState.dashboard?.attendance != null) ...[
                          AttendanceSummaryCard(attendance: homeState.dashboard!.attendance),
                          const SizedBox(height: AppSpacing.stackMd),
                        ],

                        // Thao tác nhanh dạng card màu (Chấm công & Khai báo vị trí)
                        const HomeQuickActions(),

                        if (homeState.dashboard == null) ...[
                          const SizedBox(height: AppSpacing.stackLg),
                          AppEmptyState(
                            icon: Icons.dashboard_outlined,
                            title: 'Chưa có dữ liệu trang chủ',
                            description: 'Bấm nút Đồng bộ bên dưới để tải dữ liệu mới nhất từ máy chủ.',
                            actionText: 'Tải lại dữ liệu',
                            onAction: () => homeVM.loadDashboard(isRefresh: true),
                          ),
                        ],

                        const SizedBox(height: 160), // Padding cho FAB & nav bar
                      ],
                    ),
                  ),
                ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton.extended(
          heroTag: 'home_sync_fab',
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          onPressed: _isSyncing ? null : _handleSyncAll,
          icon: _isSyncing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.sync_rounded, size: 24),
          label: Text(
            _isSyncing ? 'Đang đồng bộ...' : 'Đồng bộ',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
