import '../../../../core/network/api_client.dart';
import '../models/user_profile_detail_model.dart';
import '../models/user_profile_model.dart';
import '../models/user_relation_model.dart';

class ProfileApiService {
  final ApiClient _apiClient;

  ProfileApiService(this._apiClient);

  Future<UserProfileModel> getProfile() async {
    final response = await _apiClient.get('/profile');
    return UserProfileModel.fromJson(response as Map<String, dynamic>);
  }

  Future<UserProfileDetailModel> getUserProfileDetail() async {
    final response = await _apiClient.get('/user/me/profile');
    final resMap = response as Map<String, dynamic>;
    final data = (resMap['data'] ?? resMap) as Map<String, dynamic>;
    return UserProfileDetailModel.fromJson(data);
  }

  Future<List<UserRelationModel>> getUserRelations() async {
    final response = await _apiClient.get('/hr/me/relations');
    final resMap = response as Map<String, dynamic>;
    final data = resMap['data'];
    if (data is List) {
      return data
          .map((e) => UserRelationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}
