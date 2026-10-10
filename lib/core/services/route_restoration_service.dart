import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dịch vụ lưu trữ và khôi phục màn hình khi ứng dụng bị OS tắt (SIGKILL trên iOS / process kill trên Android)
/// do người dùng thay đổi quyền trong Cài đặt hệ thống (Settings).
class RouteRestorationService {
  static const String _kPendingRestoreRoute = 'pending_permission_restore_route';
  static const String _kPendingRestoreTimestamp = 'pending_permission_restore_timestamp';
  static const String _kLastActiveRoute = 'last_active_route';
  static const String _kLastActiveTimestamp = 'last_active_timestamp';

  /// Thời gian hiệu lực tối đa để khôi phục phiên (15 phút)
  static const int _kMaxRestoreAgeMs = 15 * 60 * 1000;

  /// Lưu lại route sắp chuyển sang Cài đặt hệ thống
  static Future<void> savePendingRoute(String route) async {
    try {
      if (_isIgnoredRoute(route)) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPendingRestoreRoute, route);
      await prefs.setInt(_kPendingRestoreTimestamp, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Tự động trích xuất route hiện tại từ BuildContext và lưu lại trước khi mở Settings
  static Future<void> savePendingRouteFromContext(BuildContext? context) async {
    if (context == null) return;
    try {
      final router = GoRouter.maybeOf(context);
      final uri = router?.routerDelegate.currentConfiguration.uri.toString();
      if (uri != null && uri.isNotEmpty && !_isIgnoredRoute(uri)) {
        await savePendingRoute(uri);
      }
    } catch (_) {}
  }

  /// Ghi nhận route cuối cùng người dùng đang xem
  static Future<void> saveLastActiveRoute(String route) async {
    try {
      if (_isIgnoredRoute(route)) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastActiveRoute, route);
      await prefs.setInt(_kLastActiveTimestamp, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Lấy route cần khôi phục và xoá cờ pending.
  /// Ưu tiên route khi bấm "Đi đến Cài đặt", nếu không có thì kiểm tra route cuối cùng.
  static Future<String?> getAndClearPendingRestoreRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;

      final pendingRoute = prefs.getString(_kPendingRestoreRoute);
      final pendingTime = prefs.getInt(_kPendingRestoreTimestamp) ?? 0;

      // Xoá ngay cờ pending để tránh loop
      await prefs.remove(_kPendingRestoreRoute);
      await prefs.remove(_kPendingRestoreTimestamp);

      if (pendingRoute != null && (now - pendingTime) <= _kMaxRestoreAgeMs) {
        if (!_isIgnoredRoute(pendingRoute)) {
          return pendingRoute;
        }
      }

      // Nếu không có pendingRoute do bấm nút, kiểm tra lastActiveRoute
      final lastRoute = prefs.getString(_kLastActiveRoute);
      final lastTime = prefs.getInt(_kLastActiveTimestamp) ?? 0;
      if (lastRoute != null && (now - lastTime) <= _kMaxRestoreAgeMs) {
        if (!_isIgnoredRoute(lastRoute) && lastRoute != '/home') {
          return lastRoute;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Bỏ qua các route không cần khôi phục hoặc route khởi tạo
  static bool _isIgnoredRoute(String route) {
    return route.isEmpty ||
        route == '/' ||
        route == '/splash' ||
        route == '/login';
  }
}
