import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../services/profile_api_service.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileApiService _apiService;

  ProfileRepositoryImpl(this._apiService);

  @override
  Future<UserProfileEntity> getProfile() async {
    final model = await _apiService.getProfile();
    final prefs = await SharedPreferences.getInstance();
    final isDarkSaved = prefs.getBool(AppConstants.keyIsDarkMode) ?? false;

    final entity = model.toEntity();
    return UserProfileEntity(
      id: entity.id,
      name: entity.name,
      employeeId: entity.employeeId,
      role: entity.role,
      region: entity.region,
      avatarUrl: entity.avatarUrl,
      email: entity.email,
      phone: entity.phone,
      isDarkMode: isDarkSaved,
      language: entity.language,
    );
  }

  @override
  Future<void> updateDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyIsDarkMode, isDark);
  }
}
