import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../customer/data/models/customer_model.dart';
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
  static const String _cacheKey = 'dms_route_customers_cache_v1';

  RouteCustomersService(this._apiClient, [this._db]);

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
          var data = RouteCustomersData.fromJson(dataJson);
          data = await _enrichCoordinates(data);
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
      return _enrichCoordinates(cached);
    }

    return const RouteCustomersData(items: [], truncated: false);
  }

  Future<RouteCustomersData> _enrichCoordinates(RouteCustomersData data) async {
    if (data.items.isEmpty) return data;
    if (data.items.every((it) => it.hasCoordinates)) return data;

    final Map<int, (double, double)> idCoords = {};
    final Map<String, (double, double)> codeCoords = {};

    if (_db != null) {
      try {
        final locals = await _db.getAllLocalCustomers();
        for (final c in locals) {
          if (c.lat != null && c.lng != null && c.lat != 0 && c.lng != 0) {
            if (c.id != null) idCoords[c.id!] = (c.lat!, c.lng!);
            if (c.code.isNotEmpty) codeCoords[c.code] = (c.lat!, c.lng!);
          }
        }
      } catch (_) {}
    }

    for (final c in kMockCustomers) {
      if (c.lat != null && c.lng != null && c.lat != 0 && c.lng != 0) {
        idCoords.putIfAbsent(c.id, () => (c.lat!, c.lng!));
        codeCoords.putIfAbsent(c.code, () => (c.lat!, c.lng!));
      }
    }

    final enriched = data.items.map((it) {
      if (it.hasCoordinates) return it;
      final found = idCoords[it.id] ?? codeCoords[it.code];
      if (found != null) {
        return it.copyWith(lat: found.$1, lng: found.$2);
      }
      return it;
    }).toList();

    return RouteCustomersData(items: enriched, truncated: data.truncated);
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
