import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/account_key.dart';
import '../../domain/entities/route_entity.dart';
import '../models/route_model.dart';

class RouteApiService {
  final ApiClient _apiClient;

  static const String _legacyUserRoutesCacheKey = 'dms_user_routes_cache_v1';
  static const String _legacyRouteDetailCacheKey = 'dms_route_detail_cache_v1';
  static const String _legacyDealerCheckinCacheKey = 'dms_dealer_checkin_data_cache_v1';

  RouteApiService(this._apiClient);

  /// Lấy họ tên hiển thị của tài khoản hiện tại
  Future<String> _getCurrentUserName(SharedPreferences prefs) async {
    try {
      final userJson = prefs.getString(AppConstants.keyUserData);
      if (userJson != null && userJson.isNotEmpty) {
        final map = jsonDecode(userJson) as Map<String, dynamic>;
        return map['display_name']?.toString().trim() ??
            map['name']?.toString().trim() ??
            map['username']?.toString().trim() ??
            '';
      }
    } catch (_) {}
    return '';
  }

  /// Cache key phân vùng theo từng tài khoản
  Future<String> _getUserRoutesCacheKey(SharedPreferences prefs) async {
    final accountKey = currentAccountKey(prefs);
    // v3: bản v2 của bản app cũ có thể mang id tuyến GIẢ 1, 2, 3… (#24698 vòng 3) — bỏ, tải lại.
    return 'dms_user_routes_${accountKey}_v3';
  }

  Future<String> _getRouteDetailCacheKey(SharedPreferences prefs) async {
    final accountKey = currentAccountKey(prefs);
    return 'dms_route_detail_${accountKey}_v2';
  }

  Future<String> _getDealerCheckinCacheKey(SharedPreferences prefs) async {
    final accountKey = currentAccountKey(prefs);
    return 'dms_dealer_checkin_${accountKey}_v2';
  }

  /// Dọn dẹp cache mock cũ hoặc cache dùng chung không theo tài khoản
  Future<void> _cleanStaleMockRoutes(SharedPreferences prefs, String cacheKey) async {
    // 1. Xóa cache legacy dùng chung
    await prefs.remove(_legacyUserRoutesCacheKey);
    // Bản v2 có thể mang id tuyến giả của bản app cũ (#24698 vòng 3).
    await prefs.remove('dms_user_routes_${currentAccountKey(prefs)}_v2');
    await prefs.remove(_legacyRouteDetailCacheKey);
    await prefs.remove(_legacyDealerCheckinCacheKey);

    // 2. Nếu tài khoản hiện tại không phải Vũ Tùng Dương mà trong cache có mock data 'Vũ Tùng Dương' -> Xóa ngay
    final currentUserName = await _getCurrentUserName(prefs);
    final isMockUser = currentUserName.toLowerCase().contains('vũ tùng dương') ||
        currentUserName.toLowerCase().contains('vu tung duong');

    if (!isMockUser) {
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null &&
          (cachedJson.contains('Vũ Tùng Dương') || cachedJson.contains('Vu Tung Duong'))) {
        debugPrint('[RouteApiService] Đã tự động dọn dẹp cache tuyến mock cũ không thuộc tài khoản hiện tại ($currentUserName)');
        await prefs.remove(cacheKey);
      }
    }
  }

  Future<RouteDetailModel> getRouteDetail({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final detailCacheKey = await _getRouteDetailCacheKey(prefs);

    if (!forceRefresh) {
      final cachedJson = prefs.getString(detailCacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
          final model = RouteDetailModel.fromJson(decoded);
          unawaited(_fetchAndCacheRouteDetail(prefs, detailCacheKey));
          return model;
        } catch (_) {}
      }
    }

    try {
      final response = await _apiClient.get('/routes');
      if (response is Map<String, dynamic>) {
        await prefs.setString(detailCacheKey, jsonEncode(response));
        return RouteDetailModel.fromJson(response);
      }
    } catch (_) {
      final cachedJson = prefs.getString(detailCacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
          return RouteDetailModel.fromJson(decoded);
        } catch (_) {}
      }
      return const RouteDetailModel(
        id: '',
        title: 'Tất cả tuyến',
        totalDealers: 0,
        completedDealers: 0,
        pendingDealers: 0,
        progressPercent: 0.0,
        dealers: [],
      );
    }
    return const RouteDetailModel(
      id: '',
      title: 'Tất cả tuyến',
      totalDealers: 0,
      completedDealers: 0,
      pendingDealers: 0,
      progressPercent: 0.0,
      dealers: [],
    );
  }

  Future<void> _fetchAndCacheRouteDetail(SharedPreferences prefs, String detailCacheKey) async {
    try {
      final response = await _apiClient.get('/routes');
      if (response is Map<String, dynamic>) {
        await prefs.setString(detailCacheKey, jsonEncode(response));
      }
    } catch (_) {}
  }

  Future<DealerCheckinDataModel> getDealerCheckinData({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final checkinCacheKey = await _getDealerCheckinCacheKey(prefs);

    if (!forceRefresh) {
      final cachedJson = prefs.getString(checkinCacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
          final model = DealerCheckinDataModel.fromJson(decoded);
          unawaited(_fetchAndCacheDealerCheckin(prefs, checkinCacheKey));
          return model;
        } catch (_) {}
      }
    }

    try {
      final response = await _apiClient.get('/dealers/checkin');
      if (response is Map<String, dynamic>) {
        await prefs.setString(checkinCacheKey, jsonEncode(response));
        return DealerCheckinDataModel.fromJson(response);
      }
    } catch (_) {
      final cachedJson = prefs.getString(checkinCacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
          return DealerCheckinDataModel.fromJson(decoded);
        } catch (_) {}
      }
      return const DealerCheckinDataModel(
        dealer: CheckinDealerModel(
          id: '',
          name: '',
          address: '',
          isVip: false,
          distanceMeters: 0,
          visitDuration: '00:00:00',
          lat: 0.0,
          lng: 0.0,
        ),
        tasks: [],
      );
    }
    return const DealerCheckinDataModel(
      dealer: CheckinDealerModel(
        id: '',
        name: '',
        address: '',
        isVip: false,
        distanceMeters: 0,
        visitDuration: '00:00:00',
        lat: 0.0,
        lng: 0.0,
      ),
      tasks: [],
    );
  }

  Future<void> _fetchAndCacheDealerCheckin(SharedPreferences prefs, String checkinCacheKey) async {
    try {
      final response = await _apiClient.get('/dealers/checkin');
      if (response is Map<String, dynamic>) {
        await prefs.setString(checkinCacheKey, jsonEncode(response));
      }
    } catch (_) {}
  }

  Future<bool> checkoutDealer(String dealerId) async {
    return true;
  }

  /// Lấy danh sách tuyến của chính nhân viên đăng nhập hiện tại
  /// GET /dms/routes/mine
  /// Hỗ trợ lưu trữ ngoại tuyến (offline cache theo tài khoản) và tự động đồng bộ ghi đè khi online
  Future<List<UserRouteEntity>> getMyRoutes({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = await _getUserRoutesCacheKey(prefs);

    // Dọn sạch cache mock cũ không đúng tài khoản
    await _cleanStaleMockRoutes(prefs, cacheKey);

    final currentUserName = await _getCurrentUserName(prefs);
    final isMockUser = currentUserName.toLowerCase().contains('vũ tùng dương') ||
        currentUserName.toLowerCase().contains('vu tung duong');

    // 1. Nếu không yêu cầu bắt buộc tải mới và đã có cache của tài khoản hiện tại -> trả về ngay lập tức
    if (!forceRefresh) {
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final list = jsonDecode(cachedJson) as List<dynamic>;
          final cachedRoutes = list
              .whereType<Map<String, dynamic>>()
              .map((item) => UserRouteEntity.fromJson(item))
              .where((r) => isMockUser || (!r.name.contains('Vũ Tùng Dương') && !r.name.contains('Vu Tung Duong')))
              .toList();
          if (cachedRoutes.isNotEmpty) {
            unawaited(_fetchAndCacheMyRoutes(prefs, cacheKey));
            return cachedRoutes;
          }
        } catch (_) {}
      }
    }

    // 2. Tải trực tiếp từ server
    try {
      final response = await _apiClient.get('/dms/routes/mine');
      List<dynamic>? list;
      if (response is Map) {
        list = response['data'] ?? response['items'] ?? response['routes'];
      } else if (response is List) {
        list = response;
      }
      if (list is List) {
        final routes = list
            .whereType<Map>()
            .map((item) => UserRouteEntity.fromJson(Map<String, dynamic>.from(item)))
            .where((r) => isMockUser || (!r.name.contains('Vũ Tùng Dương') && !r.name.contains('Vu Tung Duong')))
            .toList();

        if (routes.isNotEmpty) {
          // Ghi đè bộ nhớ đệm cho riêng tài khoản hiện tại
          await prefs.setString(
            cacheKey,
            jsonEncode(routes.map((r) => r.toJson()).toList()),
          );
          return routes;
        }
        // Máy chủ trả RỖNG (không còn tuyến nào) ⇒ bỏ bộ đệm cũ, đừng phục vụ lại danh sách cũ (#24698 vòng 3).
        await prefs.remove(cacheKey);
      }
    } catch (_) {
      // 3. Khi không có mạng hoặc lỗi kết nối -> Đọc lại từ cache tài khoản
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final list = jsonDecode(cachedJson) as List<dynamic>;
          final cachedRoutes = list
              .whereType<Map<String, dynamic>>()
              .map((item) => UserRouteEntity.fromJson(item))
              .where((r) => isMockUser || (!r.name.contains('Vũ Tùng Dương') && !r.name.contains('Vu Tung Duong')))
              .toList();
          if (cachedRoutes.isNotEmpty) {
            return cachedRoutes;
          }
        } catch (_) {}
      }

      // Không trích tuyến từ điểm bán trong máy: id tuyến lưu ở điểm bán có thể là id GIẢ của bản app cũ (1, 2, 3… trùng
      // tuyến thật trên prod) — chỉ tin danh sách /dms/routes/mine (#24698 vòng 3, chủ hệ thống chốt 03/11/2026).
    }

    return [];
  }

  Future<void> _fetchAndCacheMyRoutes(SharedPreferences prefs, String cacheKey) async {
    try {
      final response = await _apiClient.get('/dms/routes/mine');
      List<dynamic>? list;
      if (response is Map) {
        list = response['data'] ?? response['items'] ?? response['routes'];
      } else if (response is List) {
        list = response;
      }
      if (list is List) {
        final currentUserName = await _getCurrentUserName(prefs);
        final isMockUser = currentUserName.toLowerCase().contains('vũ tùng dương') ||
            currentUserName.toLowerCase().contains('vu tung duong');

        final routes = list
            .whereType<Map>()
            .map((item) => UserRouteEntity.fromJson(Map<String, dynamic>.from(item)))
            .where((r) => isMockUser || (!r.name.contains('Vũ Tùng Dương') && !r.name.contains('Vu Tung Duong')))
            .toList();

        if (routes.isNotEmpty) {
          await prefs.setString(
            cacheKey,
            jsonEncode(routes.map((r) => r.toJson()).toList()),
          );
        } else {
          await prefs.remove(cacheKey);
        }
      }
    } catch (_) {}
  }
}
