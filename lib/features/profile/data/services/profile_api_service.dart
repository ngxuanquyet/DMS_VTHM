import '../../../../core/network/api_client.dart';
import '../models/user_profile_model.dart';

class ProfileApiService {
  final ApiClient _apiClient;

  ProfileApiService(this._apiClient);

  Future<UserProfileModel> getProfile() async {
    final response = await _apiClient.get('/profile');
    return UserProfileModel.fromJson(response as Map<String, dynamic>);
  }
}
