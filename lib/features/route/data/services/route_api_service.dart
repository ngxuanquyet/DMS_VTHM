import '../../../../core/network/api_client.dart';
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
}
