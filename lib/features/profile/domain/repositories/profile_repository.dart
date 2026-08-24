import '../entities/user_profile_entity.dart';

abstract class ProfileRepository {
  Future<UserProfileEntity> getProfile();
  Future<void> updateDarkMode(bool isDark);
}
