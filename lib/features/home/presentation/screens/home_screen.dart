import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/rules/mobile_rules_service.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_dialog.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../customer/data/repositories/customer_repository_impl.dart';
import '../../../customer/presentation/screens/add_customer_screen.dart';
import '../../../customer/presentation/viewmodels/customer_view_model.dart';
import '../../../forms/data/services/route_customers_service.dart';
import '../../../forms/presentation/viewmodels/forms_view_model.dart';
import '../../../route/presentation/viewmodels/route_view_model.dart';
import '../../../../core/services/anti_fraud_service.dart';
import '../states/home_state.dart';
import '../viewmodels/home_view_model.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/services/app_notification_service.dart';
import '../../../../core/services/geo_catalog_service.dart';
import '../../../../core/widgets/notification_permission_dialog.dart';
import '../../../attendance/presentation/states/attendance_state.dart';
import '../../../attendance/presentation/viewmodels/attendance_view_model.dart';
import '../../../notifications/presentation/viewmodels/notifications_view_model.dart';
import '../widgets/attendance_punch_reminder.dart';
import '../widgets/attendance_summary_card.dart';
import '../widgets/greeting_header.dart';
import '../widgets/home_quick_actions.dart';
import '../../../daily_report/domain/entities/daily_activity_entity.dart';
import '../../../daily_report/presentation/widgets/daily_activity_timeline_card.dart';
import '../../../employee_tracking/presentation/services/employee_tracking_service.dart';
import '../../../../core/services/erp_catalog_service.dart';
import '../../../visit/domain/entities/visit_entity.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  bool _isSyncing = false;
  static DateTime? _lastAutoSyncTime;
  final GlobalKey _attendanceActionKey = GlobalKey();
  Timer? _punchReminderTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndAutoSync();
      ref.read(employeeTrackingProvider.notifier).startService();
    });
    // Nhắc chấm công: dò mỗi giây tới khi đủ điều kiện hiện (dữ liệu chấm công + dashboard đã tải, Home đang ở trên
    // cùng — không có hộp thoại/màn khác đè) hoặc hết lý do nhắc; dò thay vì nghe state vì hộp thoại khởi động
    // (quyền thông báo, cảnh báo gian lận) đóng lúc nào không có sự kiện.
    if (!AttendancePunchReminder.shownThisLaunch) {
      _punchReminderTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tryShowPunchReminder());
    }
  }

  @override
  void dispose() {
    _punchReminderTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAttendanceOnResume();
      // Quay lại app: làm mới ngầm danh mục khách ERP nếu lần tải gần nhất đã quá 10 phút (#24327).
      ref.read(erpCatalogServiceProvider).refreshInBackground(
            online: ref.read(connectivityProvider).isOnline,
            minAge: const Duration(minutes: 10),
          );
    }
  }

  void _tryShowPunchReminder() {
    if (!mounted || AttendancePunchReminder.shownThisLaunch) {
      _punchReminderTimer?.cancel();
      return;
    }
    final att = ref.read(attendanceViewModelProvider);
    final dashboard = ref.read(homeViewModelProvider).dashboard;
    final today = att.config?.today;
    if (att.status != AttendanceStatus.loaded || att.config == null || dashboard == null) return;

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final punched = (today?.punchCount ?? 0) > 0 ||
        att.history.any((p) => p.punchAt.startsWith(todayStr)) ||
        dashboard.attendance.isCheckedIn;
    if (punched || today?.shift?.status == 'day_off') {
      _punchReminderTimer?.cancel();
      return;
    }

    // Chỉ hiện khi trang chủ đang thật sự ở trước mặt người dùng.
    if (rootNavigatorKey.currentState?.canPop() ?? true) return;
    if (GoRouter.of(context).routerDelegate.currentConfiguration.uri.path != '/home') return;

    final shown = AttendancePunchReminder.show(
      context: context,
      targetKey: _attendanceActionKey,
      strings: ref.read(stringsProvider),
      userName: dashboard.greeting.userName,
      onPunchNow: () async {
        await context.push('/attendance');
        if (mounted) ref.read(homeViewModelProvider.notifier).loadDashboard(isRefresh: true);
      },
    );
    if (shown) _punchReminderTimer?.cancel();
  }

  Future<void> _refreshAttendanceOnResume() async {
    try {
      // Tự động kiểm tra và cập nhật ca làm việc mới nhất nếu admin vừa đổi ca
      ref.read(attendanceViewModelProvider.notifier).loadInitialData();
    } catch (_) {}
  }

  Future<void> _checkAndAutoSync() async {
    final now = DateTime.now();
    // Luôn làm mới quy tắc mobile/khoảng cách mới nhất khi vào ứng dụng
    ref.read(mobileRulesProvider.notifier).fetchRules();

    // 🔴 KIỂM TRA GIAN LẬN & TOÀN VẸN THIẾT BỊ KHI NHÂN VIÊN VÀO APP
    if (mounted) {
      ref.read(antiFraudServiceProvider).checkAndWarnOnAppEntry(context);
    }

    // 🔔 KIỂM TRA QUYỀN THÔNG BÁO (NẾU CHƯA CẤP THÌ HIỆN YÊU CẦU CẤP QUYỀN)
    if (mounted) {
      final language = ref.read(languageProvider);
      final strings = AppStrings(language);
      NotificationPermissionDialog.checkAndRequestPermission(
        context,
        strings: strings,
      );
    }

    // Tự động đồng bộ các dữ liệu về form, khách hàng, tuyến,... ngay khi vào máy
    if (_lastAutoSyncTime == null || now.difference(_lastAutoSyncTime!).inMinutes >= 5) {
      _lastAutoSyncTime = now;
      final isOnline = ref.read(connectivityProvider).isOnline;
      if (isOnline) {
        _handleSyncAll();
      }
    }

    // 🔔 KIỂM TRA VÀ KÍCH HOẠT CÁC THÔNG BÁO NHẮC NHỞ THEO KHUNG GIỜ
    try {
      final db = ref.read(appDatabaseProvider);
      final pendingCount = await db.countPendingSync();
      final notifService = ref.read(appNotificationServiceProvider);
      final routeState = ref.read(routeViewModelProvider);

      await notifService.checkDailyReminders(
            totalDealers: routeState.routeDetail?.totalDealers,
            completedDealers: routeState.routeDetail?.completedDealers,
            routeName: routeState.selectedRoute,
            pendingSyncCount: pendingCount,
          );
      ref.invalidate(unreadNotificationCountProvider);
    } catch (_) {}
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

    // 3b'. Danh mục đơn vị hành chính (/geo/catalog, #24072) — tải về máy LÚC CÓ MẠNG để ô Tỉnh → Xã chạy được khi ra
    // thị trường mất sóng. Hỏi kèm `version`: không đổi thì server trả vài chục byte. Lỗi không ném (dùng bản đã lưu).
    // KHÔNG chờ: lần đầu là ~450 KB — chờ ở đây là chặn các bước đồng bộ sau trên mạng yếu. Không `force`: service tự hỏi
    // lại server theo nhịp 6 giờ (danh mục chỉ đổi khi có nghị quyết) — review 23/10.
    unawaited(ref.read(geoCatalogServiceProvider).load());
    // 3b''. Danh mục khách ERP cho bước nối điểm bán (#24327) — "Đồng bộ" và lúc vào app luôn tải lại NGẦM (admin vừa đổi
    // kênh theo vai thì NV thấy ngay), không chặn các bước sau.
    ref.read(erpCatalogServiceProvider).refreshInBackground(online: ref.read(connectivityProvider).isOnline);

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

    // 5b. Cập nhật ca làm việc mới nhất & đặt lại lịch nhắc nếu admin đổi ca
    try {
      await ref.read(attendanceViewModelProvider.notifier).loadInitialData();
    } catch (e) {
      debugPrint('[HomeScreenSync] Lỗi cập nhật ca làm việc: $e');
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
    final attState = ref.watch(attendanceViewModelProvider);

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

                        // Thao tác nhanh dạng card màu (Chấm công & Báo cáo & Viếng thăm & Đồng bộ)
                        HomeQuickActions(
                          isSyncing: _isSyncing,
                          onSync: _handleSyncAll,
                          onAttendanceReturn: () => homeVM.loadDashboard(isRefresh: true),
                          attendanceKey: _attendanceActionKey,
                        ),
                        const SizedBox(height: AppSpacing.stackLg),

                        // Dòng thời gian hoạt động trong ngày (Daily Activity Timeline)
                        if (homeState.dashboard != null) ...[
                          Builder(
                            builder: (context) {
                              final now = DateTime.now();
                              final todayStr = DateFormat('yyyy-MM-dd').format(now);
                              final routeState = ref.watch(routeViewModelProvider);

                              // Bắt đầu từ các hoạt động gần đây của dashboard (nếu có)
                              final activityItems = <DailyActivityEntity>[];

                              if (homeState.dashboard?.recentActivities != null) {
                                for (final e in homeState.dashboard!.recentActivities) {
                                  final isAttOut = e.title.contains('Ra') || e.title.toLowerCase().contains('ra');
                                  final isVisitIn = e.title.contains('Check-in');
                                  final isVisitOut = e.title.contains('Hoàn thành');
                                  final isPosDecl = e.title.contains('vị trí');

                                  final DailyActivityType type;
                                  if (e.title.contains('Chấm công')) {
                                    type = isAttOut ? DailyActivityType.attendanceOut : DailyActivityType.attendanceIn;
                                  } else if (isVisitIn) {
                                    type = DailyActivityType.checkIn;
                                  } else if (isVisitOut) {
                                    type = DailyActivityType.checkOut;
                                  } else if (isPosDecl) {
                                    type = DailyActivityType.positionDeclaration;
                                  } else {
                                    type = DailyActivityType.formSubmission;
                                  }

                                  activityItems.add(
                                    DailyActivityEntity(
                                      id: e.id,
                                      time: e.time,
                                      title: e.title,
                                      subtitle: '${e.highlight} ${e.suffix}'.trim(),
                                      type: type,
                                      customerName: e.highlight,
                                      photos: e.photos,
                                      lat: e.lat,
                                      lng: e.lng,
                                      isHighlight: e.isPrimary,
                                    ),
                                  );
                                }
                              }

                              // 1. Hợp nhất tức thời các lượt chấm công trong ngày từ attState.history
                              for (int i = 0; i < attState.history.length; i++) {
                                final p = attState.history[i];
                                final punchAt = p.punchAt;
                                final isToday = p.punchAtDateTime != null
                                    ? DateFormat('yyyy-MM-dd').format(p.punchAtDateTime!) == todayStr
                                    : punchAt.startsWith(todayStr);

                                if (isToday) {
                                  final punchId = 'att_${p.id > 0 ? p.id : (p.clientUuid.isNotEmpty ? p.clientUuid : i)}';
                                  String directionLabel = p.directionLabel ?? '';
                                  if (directionLabel.isEmpty) {
                                    directionLabel = (p.direction == 'in' || p.directionLabel == 'Vào') ? 'Vào' : 'Ra';
                                  }
                                  final isOut = directionLabel == 'Ra' || p.direction == 'out';
                                  final formattedTime = p.punchAtDateTime != null
                                      ? DateFormat('HH:mm').format(p.punchAtDateTime!.toLocal())
                                      : p.timeFormatted;
                                  final photoUrls = p.photos.map((ph) => ph.getFullUrl(AppConstants.baseUrl)).toList();

                                  final existingIdx = activityItems.indexWhere((a) =>
                                      a.id == punchId ||
                                      (a.type == DailyActivityType.attendanceIn && a.time == formattedTime) ||
                                      (a.type == DailyActivityType.attendanceOut && a.time == formattedTime));

                                  if (existingIdx >= 0) {
                                    // Cập nhật lại ảnh chụp để không bị mất khi xem chi tiết
                                    if (photoUrls.isNotEmpty) {
                                      final old = activityItems[existingIdx];
                                      activityItems[existingIdx] = DailyActivityEntity(
                                        id: old.id,
                                        time: formattedTime,
                                        title: old.title,
                                        subtitle: old.subtitle,
                                        type: old.type,
                                        customerName: old.customerName,
                                        customerAddress: old.customerAddress,
                                        photos: photoUrls,
                                        notes: old.notes,
                                        lat: old.lat,
                                        lng: old.lng,
                                        isHighlight: old.isHighlight,
                                      );
                                    }
                                  } else {
                                    activityItems.add(
                                      DailyActivityEntity(
                                        id: punchId,
                                        time: formattedTime,
                                        title: 'Chấm công $directionLabel',
                                        subtitle: '${p.geofenceName ?? 'Địa bàn làm việc'} ${p.isOutsideGeofence ? '(Ngoài vùng)' : '(Trong vùng)'}'.trim(),
                                        type: isOut ? DailyActivityType.attendanceOut : DailyActivityType.attendanceIn,
                                        customerName: p.geofenceName ?? 'Địa bàn làm việc',
                                        photos: photoUrls,
                                        lat: p.lat,
                                        lng: p.lng,
                                        isHighlight: !isOut,
                                      ),
                                    );
                                  }
                                }
                              }

                              // 2. Hợp nhất tức thời các lượt viếng thăm trong ngày từ routeState (theo từng mốc check-in / check-out)
                              final visitsToProcess = <VisitEntity>[];
                              for (final v in routeState.todayVisits) {
                                if (!v.isCancelled) {
                                  final vDate = v.visitDate ?? (v.checkinAt != null ? DateFormat('yyyy-MM-dd').format(v.checkinAt!.toLocal()) : '');
                                  if (vDate.isEmpty || vDate == todayStr) {
                                    visitsToProcess.add(v);
                                  }
                                }
                              }
                              if (routeState.activeVisit != null && !routeState.activeVisit!.isCancelled) {
                                if (!visitsToProcess.any((v) => v.id == routeState.activeVisit!.id)) {
                                  visitsToProcess.add(routeState.activeVisit!);
                                }
                              }

                              for (final v in visitsToProcess) {
                                // Mốc Check-in của lượt viếng thăm
                                if (v.checkinAt != null) {
                                  final checkinTime = DateFormat('HH:mm').format(v.checkinAt!.toLocal());
                                  final inId = 'visit_in_${v.id > 0 ? v.id : (v.clientUuid ?? v.customerId)}_$checkinTime';

                                  final existingInIdx = activityItems.indexWhere((a) =>
                                      a.id == inId ||
                                      (a.type == DailyActivityType.checkIn &&
                                          (a.customerName == v.customerName || a.title.contains(v.customerName)) &&
                                          a.time == checkinTime));

                                  if (existingInIdx >= 0) {
                                    if (v.photoUrls.isNotEmpty) {
                                      final old = activityItems[existingInIdx];
                                      activityItems[existingInIdx] = DailyActivityEntity(
                                        id: old.id,
                                        time: old.time,
                                        title: old.title,
                                        subtitle: old.subtitle,
                                        type: old.type,
                                        customerName: v.customerName,
                                        customerAddress: v.customerAddress ?? old.customerAddress,
                                        photos: v.photoUrls,
                                        notes: v.closedNote ?? old.notes,
                                        lat: v.checkoutLat ?? old.lat,
                                        lng: v.checkoutLng ?? old.lng,
                                        isHighlight: old.isHighlight,
                                      );
                                    }
                                  } else {
                                    activityItems.add(
                                      DailyActivityEntity(
                                        id: inId,
                                        time: checkinTime,
                                        title: v.isOpen ? 'Đang viếng thăm: ${v.customerName}' : 'Check-in: ${v.customerName}',
                                        subtitle: v.customerAddress ?? (v.isOnRoute ? '(Trong tuyến)' : '(Ngoài tuyến)'),
                                        type: DailyActivityType.checkIn,
                                        customerName: v.customerName,
                                        customerAddress: v.customerAddress,
                                        photos: v.photoUrls,
                                        notes: v.closedNote,
                                        lat: v.checkoutLat,
                                        lng: v.checkoutLng,
                                        isHighlight: v.isOpen,
                                      ),
                                    );
                                  }
                                }

                                // Mốc Hoàn thành (Check-out) của lượt viếng thăm
                                if (v.checkoutAt != null) {
                                  final checkoutTime = DateFormat('HH:mm').format(v.checkoutAt!.toLocal());
                                  final outId = 'visit_out_${v.id > 0 ? v.id : (v.clientUuid ?? v.customerId)}_$checkoutTime';

                                  final existingOutIdx = activityItems.indexWhere((a) =>
                                      a.id == outId ||
                                      (a.type == DailyActivityType.checkOut &&
                                          (a.customerName == v.customerName || a.title.contains(v.customerName)) &&
                                          a.time == checkoutTime));

                                  final durationText = v.durationSeconds != null ? ' • ${(v.durationSeconds! / 60).round()}p' : '';
                                  final resultText = v.visitResult == 'closed' ? '(Đóng cửa)' : '(Mở cửa)';

                                  if (existingOutIdx >= 0) {
                                    if (v.photoUrls.isNotEmpty) {
                                      final old = activityItems[existingOutIdx];
                                      activityItems[existingOutIdx] = DailyActivityEntity(
                                        id: old.id,
                                        time: old.time,
                                        title: old.title,
                                        subtitle: old.subtitle,
                                        type: old.type,
                                        customerName: v.customerName,
                                        customerAddress: v.customerAddress ?? old.customerAddress,
                                        photos: v.photoUrls,
                                        notes: v.closedNote ?? old.notes,
                                        lat: v.checkoutLat ?? old.lat,
                                        lng: v.checkoutLng ?? old.lng,
                                        isHighlight: false,
                                      );
                                    }
                                  } else {
                                    activityItems.add(
                                      DailyActivityEntity(
                                        id: outId,
                                        time: checkoutTime,
                                        title: 'Hoàn thành: ${v.customerName}',
                                        subtitle: 'Kết quả: $resultText$durationText',
                                        type: DailyActivityType.checkOut,
                                        customerName: v.customerName,
                                        customerAddress: v.customerAddress,
                                        photos: v.photoUrls,
                                        notes: v.closedNote,
                                        lat: v.checkoutLat,
                                        lng: v.checkoutLng,
                                        isHighlight: false,
                                      ),
                                    );
                                  }
                                }
                              }

                              // 3. Sắp xếp toàn bộ hoạt động theo đúng tiến trình mốc thời gian trong ngày (chronological order)
                              int parseTimeToMinutes(String timeStr) {
                                try {
                                  final clean = timeStr.trim();
                                  final parts = clean.split(':');
                                  if (parts.length >= 2) {
                                    final h = int.tryParse(parts[0]) ?? 0;
                                    final m = int.tryParse(parts[1]) ?? 0;
                                    return h * 60 + m;
                                  }
                                } catch (_) {}
                                return 0;
                              }

                              activityItems.sort((a, b) {
                                final mA = parseTimeToMinutes(a.time);
                                final mB = parseTimeToMinutes(b.time);
                                if (mA != mB) {
                                  return mA.compareTo(mB);
                                }
                                if (a.type == DailyActivityType.checkIn && b.type == DailyActivityType.checkOut) {
                                  return -1;
                                }
                                if (a.type == DailyActivityType.checkOut && b.type == DailyActivityType.checkIn) {
                                  return 1;
                                }
                                return 0;
                              });

                              return DailyActivityTimelineCard(
                                title: 'Dòng thời gian hôm nay',
                                activities: activityItems,
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.stackLg),
                        ],

                        if (homeState.dashboard == null) ...[
                          const SizedBox(height: AppSpacing.stackLg),
                          AppEmptyState(
                            icon: Icons.dashboard_outlined,
                            title: 'Chưa có dữ liệu trang chủ',
                            description: 'Bấm nút Tải lại bên dưới để cập nhật dữ liệu mới nhất.',
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
