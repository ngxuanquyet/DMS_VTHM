class AppConstants {
  AppConstants._();

  static const String appName = 'VTHM Group';
  static const String appSubtitle = 'Hệ thống Quản lý Nhân viên Thị trường';
  static const String appVersion = 'Phiên bản 1.0.0 (Field Ops)';
  static const String appVersionBuild = 'Phiên bản 1.0.0 (Build 1)';
  static const String appVersionSimple = 'Phiên bản 1.0.0';

  // API Endpoints & Headers
  static const String baseUrl = 'https://api-app.vthmgroup.vn';
  static const int connectTimeout = 15000;
  static const int receiveTimeout = 15000;
  /// Chờ phản hồi khi GỬI ẢNH (multipart): server còn xử lý ảnh sau khi nhận đủ — 15s là quá giờ oan, app gửi lại cả ảnh.
  static const int uploadReceiveTimeout = 60000;
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
