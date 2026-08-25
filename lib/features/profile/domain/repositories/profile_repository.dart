import '../entities/user_profile_detail_entity.dart';
import '../entities/user_profile_entity.dart';
import '../entities/user_relation_entity.dart';

abstract class ProfileRepository {
  Future<UserProfileEntity> getProfile();
  Future<UserProfileDetailEntity> getUserProfileDetail();
  Future<List<UserRelationEntity>> getUserRelations();
  Future<void> updateDarkMode(bool isDark);
}
