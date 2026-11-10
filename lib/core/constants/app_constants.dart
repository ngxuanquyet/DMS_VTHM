import 'package:package_info_plus/package_info_plus.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'VTHM Group';
  static const String appSubtitle = 'Hệ thống Quản lý Nhân viên Thị trường';

  /// Số phiên bản đọc từ chính bản build (`version: x.y.z+n` của pubspec) — nạp một lần ở `main()` qua [loadVersion],
  /// không gõ tay: chuỗi cứng cũ đứng yên '1.0.0' dù APK đã lên 1.0.1+2.
  static String versionName = '';
  static String buildNumber = '';

  static Future<void> loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    versionName = info.version;
    buildNumber = info.buildNumber;
  }

  static String get appVersion => 'Phiên bản $versionName (Field Ops)';
  static String get appVersionBuild => 'Phiên bản $versionName (Build $buildNumber)';
  static String get appVersionSimple => 'Phiên bản $versionName';

  // API Endpoints & Headers
  static const String baseUrl = 'https://api-app.vthmgroup.vn';
  static const int connectTimeout = 15000;
  static const int receiveTimeout = 15000;
  /// Chờ phản hồi khi GỬI ẢNH (multipart): server còn xử lý ảnh sau khi nhận đủ — 15s là quá giờ oan, app gửi lại cả ảnh.
  static const int uploadReceiveTimeout = 60000;

  /// Trần thời gian GỬI tệp (ảnh đã nén vài trăm KB) — trần kỹ thuật: quá trần là lỗi mạng tạm, hàng đợi thử lại sau.
  static const int uploadSendTimeout = 120000;
  static const String headerClientKey = 'X-Client';
  static const String headerClientValue = 'dms-app';

  // Storage Keys
  static const String keyAuthToken = 'vthm_auth_token';
  static const String keyAccessToken = 'vthm_access_token';
  static const String keyRefreshToken = 'vthm_refresh_token';
  static const String keyUserData = 'vthm_user_data';
  static const String keyIsDarkMode = 'vthm_is_dark_mode';
  static const String keyLanguage = 'vthm_app_language';
  static const String keyRememberLogin = 'vthm_remember_login';
  static const String keySavedUsername = 'vthm_saved_username';
  static const String keyRecentErrorLogs = 'vthm_recent_error_logs';

  // Remote placeholder assets matching design_reference
  static const String logoUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBQiCm7T-W41x8U7Ttw9UasGxeoMCgqLCv6T8470k3COTf_bYUJQS4-E3yCigHLcjScpdNvMxkP-HtnrURBe4ZH-cjMswFzsb1JXPhXMZjt1pjOG9SmG_0c33NIxuurELfCI0RupzIR9wrra1SKSwxdpmQMLqVcosRKxBg1W_bCvkIp2E37BjmrInRLYTFdAHgy1Ldt7nZz-qIsNLE6qlEjIXh1PHTHrm38xeGHqjKdXvYkbaLsXCjvuMsHhcWEBR2gzQ4';
}
