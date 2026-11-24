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

  /// Tự đổi mật khẩu (POST /user/me/change-password — route `user/user/me-change-password`, được miễn khi đang buộc đổi
  /// mật khẩu). Gửi kèm [refreshToken] để máy chủ GIỮ phiên này khi cắt mọi phiên khác; access token hiện tại bị chặn
  /// (phát trước lần đổi) ⇒ nơi gọi làm mới token ngay sau. Sai mật khẩu hiện tại / mật khẩu mới quá ngắn ⇒ 422.
  Future<void> changeOwnPassword({
    required String currentPassword,
    required String newPassword,
    String? refreshToken,
  }) async {
    await _apiClient.post(
      '/user/me/change-password',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
        if (refreshToken != null && refreshToken.isNotEmpty) 'refresh_token': refreshToken,
      },
    );
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
