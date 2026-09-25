import '../../../../core/network/api_client.dart';
import '../../domain/entities/route_entity.dart';
import '../models/route_model.dart';

class RouteApiService {
  final ApiClient _apiClient;

  RouteApiService(this._apiClient);

  Future<RouteDetailModel> getRouteDetail() async {
    final response = await _apiClient.get('/routes');
    return RouteDetailModel.fromJson(response as Map<String, dynamic>);
  }

  Future<DealerCheckinDataModel> getDealerCheckinData() async {
    final response = await _apiClient.get('/dealers/checkin');
    return DealerCheckinDataModel.fromJson(response as Map<String, dynamic>);
  }

  Future<bool> checkoutDealer(String dealerId) async {
    // Simulated checkout API call
    return true;
  }

  /// Lấy danh sách tuyến của chính nhân viên đăng nhập
  /// GET /dms/routes/mine
  /// Trả về mảng các route: [{ id, code, name, visit_day_of_week, sale_group_id }]
  Future<List<UserRouteEntity>> getMyRoutes() async {
    try {
      final response = await _apiClient.get('/dms/routes/mine');
      if (response is Map) {
        final list = response['data'] ?? response['items'] ?? response['routes'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((item) => UserRouteEntity.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
      } else if (response is List) {
        return response
            .whereType<Map>()
            .map((item) => UserRouteEntity.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
