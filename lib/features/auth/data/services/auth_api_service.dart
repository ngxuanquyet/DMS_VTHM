import '../../../../core/network/api_client.dart';

class AuthApiService {
  final ApiClient _apiClient;

  AuthApiService(this._apiClient);

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/auth/login',
      data: {
        'username': username,
        'password': password,
      },
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> refreshToken({
    required String refreshToken,
  }) async {
    final response = await _apiClient.post(
      '/auth/refresh',
      data: {
        'refresh_token': refreshToken,
      },
    );
    return response as Map<String, dynamic>;
  }

  /// Endpoint mới 15/10/2026: GET /dms/app-access
  /// Kiểm tra tài khoản có quyền truy cập app DMS không
  Future<bool> checkAppAccess() async {
    final response = await _apiClient.get('/dms/app-access');
    if (response is Map && response['success'] == true) {
      final data = response['data'];
      if (data is Map && data['allowed'] == true) {
        return true;
      }
    }
    return false;
  }
}
