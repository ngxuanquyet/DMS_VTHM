import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/rules/mobile_rules_service.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_dialog.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../../../customer/data/repositories/customer_repository_impl.dart';
import '../../../customer/presentation/screens/add_customer_screen.dart';
import '../../../customer/presentation/viewmodels/customer_view_model.dart';
import '../../../forms/data/services/route_customers_service.dart';
import '../../../forms/presentation/viewmodels/forms_view_model.dart';
import '../../../route/presentation/viewmodels/route_view_model.dart';
import '../states/home_state.dart';
import '../viewmodels/home_view_model.dart';
import '../widgets/attendance_summary_card.dart';
import '../widgets/greeting_header.dart';
import '../widgets/home_quick_actions.dart';
import '../../../daily_report/domain/entities/daily_activity_entity.dart';
import '../../../daily_report/presentation/widgets/daily_activity_timeline_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isSyncing = false;
  static DateTime? _lastAutoSyncTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndAutoSync();
    });
  }

  Future<void> _checkAndAutoSync() async {
    final now = DateTime.now();
    // Luôn làm mới quy tắc mobile/khoảng cách mới nhất khi vào ứng dụng
    ref.read(mobileRulesProvider.notifier).fetchRules();

    // Tự động đồng bộ các dữ liệu về form, khách hàng, tuyến,... ngay khi vào máy
    if (_lastAutoSyncTime == null || now.difference(_lastAutoSyncTime!).inMinutes >= 5) {
      _lastAutoSyncTime = now;
      final isOnline = ref.read(connectivityProvider).isOnline;
      if (isOnline) {
        _handleSyncAll();
      }
    }
  }

  /// Gọi tất cả các API để đồng bộ dữ liệu mới nhất:
  /// - Quy tắc vận hành (/dms/mobile-rules)
  /// - Danh sách điểm bán theo tuyến (/dms/routes/customers)
  /// - Khách hàng (/dms/customers)
  /// - Cấu hình form thêm khách hàng & danh mục (/dms/customer-form-schema, /dms/customers/meta)
  /// - Biểu mẫu thị trường (/dms/forms)
  /// - Tuyến bán hàng & lượt viếng thăm hôm nay (/dms/routes, /dms/visits/today)
  /// - Dashboard trang chủ (/dms/dashboard)
  /// - Đẩy hàng đợi ngoại tuyến nếu có
  Future<void> _handleSyncAll() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Đang đồng bộ...',
                style: TextStyle(color: Colors.white, fontSize: 14),
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

    // 3b. Cập nhật form thêm khách hàng & danh mục (/dms/customer-form-schema, /dms/customers/meta)
    try {
      final customerRepo = ref.read(customerRepositoryProvider);
      await Future.wait([
        customerRepo.getCustomerFormSchema(forceRefresh: true),
        customerRepo.getCustomerMeta(forceRefresh: true),
      ]);
      ref.invalidate(customerFormSchemaProvider);
      ref.invalidate(customerMetaProvider);
      ref.invalidate(userAssignedRoutesProvider);
    } catch (e) {
      debugPrint('[HomeScreenSync] Lỗi làm mới schema form: $e');
    }

    // 3c. Cập nhật biểu mẫu thị trường (/dms/forms)
    try {
      await ref.read(formsViewModelProvider.notifier).loadForms();
    } catch (e) {
      debugPrint('[HomeScreenSync] Lỗi loadForms: $e');
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
    if (failureCount >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Không thể đồng bộ. Vui lòng kiểm tra kết nối mạng.'),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Đồng bộ thành công!'),
              ),
            ],
          ),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
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
                        AttendanceSummaryCard(attendance: homeState.dashboard?.attendance),
                        const SizedBox(height: AppSpacing.stackMd),

                        // Thao tác nhanh dạng card màu (Chấm công & Báo cáo & Khai báo vị trí & Đồng bộ)
                        HomeQuickActions(
                          isSyncing: _isSyncing,
                          onSync: _handleSyncAll,
                        ),
                        const SizedBox(height: AppSpacing.stackLg),

                        // Dòng thời gian hoạt động trong ngày (Daily Activity Timeline)
                        if (homeState.dashboard != null) ...[
                          DailyActivityTimelineCard(
                            title: 'Dòng thời gian hôm nay',
                            activities: homeState.dashboard!.recentActivities.map((e) {
                              return DailyActivityEntity(
                                id: e.id,
                                time: e.time,
                                title: e.title,
                                subtitle: '${e.highlight} ${e.suffix}'.trim(),
                                type: e.title.contains('Chấm công')
                                    ? DailyActivityType.attendanceIn
                                    : (e.title.contains('Check-in')
                                        ? DailyActivityType.checkIn
                                        : (e.title.contains('vị trí')
                                            ? DailyActivityType.positionDeclaration
                                            : DailyActivityType.formSubmission)),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: AppSpacing.stackLg),
                        ],

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

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }
}
