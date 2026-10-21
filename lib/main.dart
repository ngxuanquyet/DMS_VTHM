import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/localization/language_provider.dart';
import 'core/network/connectivity_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/app_notification_service.dart';
import 'core/services/error_tracker_service.dart';
import 'core/services/fcm_push_service.dart';
import 'core/theme/app_theme.dart';
import 'features/profile/presentation/viewmodels/profile_view_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo dịch vụ theo dõi lỗi và nhật ký hệ thống
  await ErrorTrackerService.instance.initialize();

  // Bắt các ngoại lệ Flutter không bắt được
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    ErrorTrackerService.instance.trackCustomError(
      message: details.exceptionAsString(),
      module: 'FLUTTER',
      stackTrace: details.stack,
    );
  };

  // Khởi tạo dịch vụ thông báo cục bộ + huỷ lịch nhắc chấm công cục bộ của bản cũ (nhắc ca nay chỉ qua push server)
  try {
    final notifService = AppNotificationService();
    await notifService.init();
    await notifService.cancelLegacyAttendanceReminders();
  } catch (e) {
    debugPrint('[Main] Khởi tạo AppNotificationService lỗi: $e');
  }

  // Khởi tạo dịch vụ thông báo đẩy Firebase Cloud Messaging (§1, §5.2 API-THONG-BAO-DAY-MOBILE-2026-10-19)
  try {
    final fcmService = FcmPushService();
    await fcmService.init();
  } catch (e) {
    debugPrint('[Main] Khởi tạo FcmPushService lỗi: $e');
  }

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const ProviderScope(
      child: VthmApp(),
    ),
  );
}

class VthmApp extends ConsumerWidget {
  const VthmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final profileState = ref.watch(profileViewModelProvider);
    // Watch current language to rebuild the app on language change
    ref.watch(languageProvider);
    // Initialize & watch real-time connectivity monitor
    ref.watch(connectivityProvider);
    // Connect ref to FCM Push Service
    ref.watch(fcmPushServiceProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: profileState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: child,
        );
      },
    );
  }
}
