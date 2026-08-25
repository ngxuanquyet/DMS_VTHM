import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/data/models/user_model.dart';
import '../../domain/entities/user_profile_detail_entity.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../../domain/entities/user_relation_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../services/profile_api_service.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileApiService _apiService;

  ProfileRepositoryImpl(this._apiService);

  @override
  Future<UserProfileEntity> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkSaved = prefs.getBool(AppConstants.keyIsDarkMode) ?? false;

    // Try fetching freshest live profile details if online
    try {
      final detail = await _apiService.getUserProfileDetail();
      return UserProfileEntity(
        id: detail.id.toString(),
        name: detail.fullName.trim().isNotEmpty
            ? detail.fullName
            : (detail.username.trim().isNotEmpty ? detail.username : 'Không xác định'),
        employeeId: detail.employeeCode.trim().isNotEmpty
            ? detail.employeeCode
            : 'Không xác định',
        role: detail.jobName.trim().isNotEmpty
            ? detail.jobName
            : 'Không xác định',
        department: detail.deptName.trim().isNotEmpty
            ? detail.deptName
            : 'Không xác định',
        avatarUrl: detail.avatarUrl.trim().isNotEmpty
            ? detail.avatarUrl
            : AppConstants.userAvatarUrl,
        email: detail.email,
        phone: detail.phone,
        isDarkMode: isDarkSaved,
        language: 'Tiếng Việt',
      );
    } catch (_) {}

    final userJson = prefs.getString(AppConstants.keyUserData);
    if (userJson != null) {
      try {
        final map = jsonDecode(userJson) as Map<String, dynamic>;
        final userModel = UserModel.fromJson(map);
        return UserProfileEntity(
          id: userModel.id,
          name: userModel.displayName.trim().isNotEmpty
              ? userModel.displayName
              : (userModel.username.trim().isNotEmpty ? userModel.username : 'Không xác định'),
          employeeId: userModel.employeeCode.trim().isNotEmpty
              ? userModel.employeeCode
              : 'Không xác định',
          role: userModel.jobTitle.trim().isNotEmpty
              ? userModel.jobTitle
              : 'Không xác định',
          department: 'Không xác định',
          avatarUrl: userModel.avatarUrl.trim().isNotEmpty
              ? userModel.avatarUrl
              : AppConstants.userAvatarUrl,
          email: userModel.email,
          phone: '',
          isDarkMode: isDarkSaved,
          language: 'Tiếng Việt',
        );
      } catch (_) {}
    }

    try {
      final model = await _apiService.getProfile();
      final entity = model.toEntity();
      return UserProfileEntity(
        id: entity.id,
        name: entity.name.trim().isNotEmpty ? entity.name : 'Không xác định',
        employeeId: entity.employeeId.trim().isNotEmpty ? entity.employeeId : 'Không xác định',
        role: entity.role.trim().isNotEmpty ? entity.role : 'Không xác định',
        department: entity.department.trim().isNotEmpty ? entity.department : 'Không xác định',
        avatarUrl: entity.avatarUrl.trim().isNotEmpty ? entity.avatarUrl : AppConstants.userAvatarUrl,
        email: entity.email,
        phone: entity.phone,
        isDarkMode: isDarkSaved,
        language: entity.language,
      );
    } catch (_) {
      return UserProfileEntity(
        id: '',
        name: 'Không xác định',
        employeeId: 'Không xác định',
        role: 'Không xác định',
        department: 'Không xác định',
        avatarUrl: AppConstants.userAvatarUrl,
        email: '',
        phone: '',
        isDarkMode: isDarkSaved,
        language: 'Tiếng Việt',
      );
    }
  }

  @override
  Future<UserProfileDetailEntity> getUserProfileDetail() async {
    final model = await _apiService.getUserProfileDetail();
    return model.toEntity();
  }

  @override
  Future<List<UserRelationEntity>> getUserRelations() async {
    final models = await _apiService.getUserRelations();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<void> updateDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyIsDarkMode, isDark);
  }
}
