import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/api_client.dart';
import '../models/route_customer_model.dart';

final routeCustomersServiceProvider = Provider<RouteCustomersService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RouteCustomersService(apiClient);
});

final routeCustomersListProvider =
    FutureProvider.autoDispose<RouteCustomersData>((ref) async {
  final service = ref.watch(routeCustomersServiceProvider);
  return service.getRouteCustomers();
});

class RouteCustomersService {
  final ApiClient _apiClient;
  static const String _cacheKey = 'dms_route_customers_cache_v1';

  RouteCustomersService(this._apiClient);

  /// Lấy danh sách điểm bán thuộc các tuyến được giao:
  /// - Thử gọi GET /dms/routes/customers
  /// - Nếu thành công: cache vào SharedPreferences và trả về
  /// - Nếu thất bại (hoặc offline): đọc từ cache SharedPreferences
  Future<RouteCustomersData> getRouteCustomers({bool forceRefresh = false}) async {
    try {
      final response = await _apiClient.get('/dms/routes/customers');

      if (response is Map<String, dynamic>) {
        final dataJson = response['data'];
        if (dataJson is Map<String, dynamic>) {
          final data = RouteCustomersData.fromJson(dataJson);
          // Lưu vào local cache để dùng khi offline
          await _saveToCache(data);
          return data;
        }
      }
    } catch (_) {
      // Khi gặp lỗi mạng hoặc server error, đọc từ cache
    }

    // Đọc từ cache
    final cached = await getCachedData();
    if (cached != null) {
      return cached;
    }

    return const RouteCustomersData(items: [], truncated: false);
  }

  /// Đọc dữ liệu từ local cache
  Future<RouteCustomersData?> getCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return null;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      return RouteCustomersData.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Lưu vào local cache
  Future<void> _saveToCache(RouteCustomersData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(data.toJson());
      await prefs.setString(_cacheKey, raw);
    } catch (_) {}
  }
}
