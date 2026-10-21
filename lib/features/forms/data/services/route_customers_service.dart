import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/account_key.dart';
import '../models/route_customer_model.dart';

final routeCustomersServiceProvider = Provider<RouteCustomersService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final db = ref.watch(appDatabaseProvider);
  return RouteCustomersService(apiClient, db);
});

final routeCustomersListProvider =
    FutureProvider.autoDispose<RouteCustomersData>((ref) async {
  final service = ref.watch(routeCustomersServiceProvider);
  return service.getRouteCustomers();
});

class RouteCustomersService {
  final ApiClient _apiClient;
  final AppDatabase? _db;
  /// Khoá lưu trong máy, TÁCH theo tài khoản: đây là điểm bán thuộc TUYẾN ĐƯỢC GIAO cho chính người tải về — dùng chung
  /// một khoá thì người sau đăng nhập lúc mất mạng thấy (và nộp phiếu vào) điểm bán của người trước. `logout()` xoá
  /// `dms_route_customers_cache*`.
  static String _cacheKey(String account) => 'dms_route_customers_cache_v2_$account';

  RouteCustomersService(this._apiClient, [this._db]);

  /// Lấy danh sách điểm bán thuộc các tuyến được giao:
  /// - Thử gọi GET /dms/routes/customers
  /// - Nếu thành công: cache vào SharedPreferences và trả về
  /// - Nếu thất bại (hoặc offline): đọc từ cache SharedPreferences
  Future<RouteCustomersData> getRouteCustomers({bool forceRefresh = false}) async {
    const empty = RouteCustomersData(items: [], truncated: false);
    final prefs = await SharedPreferences.getInstance();
    final account = cacheAccountKey(prefs);

    // 🔴 Gọi SAU MỖI `await`: đổi tài khoản / đăng xuất trong lúc chờ ⇒ dữ liệu đang có là tuyến của người cũ — không ghi
    // lại bản lưu, không đưa ra; phiên hết ⇒ rỗng, tài khoản khác ⇒ làm lại cho người đang đăng nhập. `null` = không đổi.
    Future<RouteCustomersData?> neuDoiTaiKhoan() async {
      final now = cacheAccountKey(prefs);
      if (now == account) return null;
      if (now == null) return empty;
      return getRouteCustomers(forceRefresh: forceRefresh);
    }

    try {
      final response = await _apiClient.get('/dms/routes/customers');
      final doi = await neuDoiTaiKhoan();
      if (doi != null) return doi;
      if (response is Map<String, dynamic>) {
        final dataJson = response['data'];
        if (dataJson is Map<String, dynamic>) {
          var data = RouteCustomersData.fromJson(dataJson);
          data = await _enrichCoordinates(data);
          final doiSauDb = await neuDoiTaiKhoan();
          if (doiSauDb != null) return doiSauDb;
          // Lưu vào local cache để dùng khi offline
          await _saveToCache(data, account);
          return data;
        }
      }
    } catch (_) {
      // Khi gặp lỗi mạng hoặc server error, đọc từ cache
      final doi = await neuDoiTaiKhoan();
      if (doi != null) return doi;
    }

    // Đọc từ cache (của đúng tài khoản đang đăng nhập)
    final cached = await getCachedData();
    if (cached != null) {
      final data = await _enrichCoordinates(cached);
      final doi = await neuDoiTaiKhoan();
      return doi ?? data;
    }

    return empty;
  }

  Future<RouteCustomersData> _enrichCoordinates(RouteCustomersData data) async {
    if (data.items.isEmpty) return data;
    if (data.items.every((it) => it.hasCoordinates)) return data;

    final Map<int, (double, double, int?)> idCoords = {};
    final Map<String, (double, double, int?)> codeCoords = {};

    if (_db != null) {
      try {
        final locals = await _db.getAllLocalCustomers();
        for (final c in locals) {
          if (c.lat != null && c.lng != null && c.lat != 0 && c.lng != 0) {
            if (c.id != null) idCoords[c.id!] = (c.lat!, c.lng!, c.geofenceRadiusM);
            if (c.code.isNotEmpty) codeCoords[c.code] = (c.lat!, c.lng!, c.geofenceRadiusM);
          }
        }
      } catch (_) {}
    }

    final enriched = data.items.map((it) {
      final found = idCoords[it.id] ?? codeCoords[it.code];
      if (found != null) {
        return it.copyWith(
          lat: it.lat ?? found.$1,
          lng: it.lng ?? found.$2,
          geofenceRadiusM: it.geofenceRadiusM ?? found.$3,
        );
      }
      return it;
    }).toList();

    return RouteCustomersData(items: enriched, truncated: data.truncated);
  }

  /// Đọc dữ liệu từ local cache — của tài khoản ĐANG đăng nhập; chưa rõ tài khoản ⇒ không có.
  Future<RouteCustomersData?> getCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final account = cacheAccountKey(prefs);
      if (account == null) return null;
      final raw = prefs.getString(_cacheKey(account));
      if (raw == null || raw.isEmpty) return null;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      return RouteCustomersData.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Lưu vào local cache của [account] — bỏ qua khi chưa rõ tài khoản hoặc tài khoản đã đổi.
  Future<void> _saveToCache(RouteCustomersData data, String? account) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (account == null || cacheAccountKey(prefs) != account) return;
      final raw = jsonEncode(data.toJson());
      await prefs.setString(_cacheKey(account), raw);
    } catch (_) {}
  }
}
