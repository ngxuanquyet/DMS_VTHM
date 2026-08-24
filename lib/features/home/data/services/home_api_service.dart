import '../../../../core/network/api_client.dart';
import '../models/dashboard_model.dart';

class HomeApiService {
  final ApiClient _apiClient;

  HomeApiService(this._apiClient);

  Future<DashboardModel> getDashboardData() async {
    final response = await _apiClient.get('/dashboard');
    return DashboardModel.fromJson(response as Map<String, dynamic>);
  }
}
