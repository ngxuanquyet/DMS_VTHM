import '../entities/user_profile_detail_entity.dart';
import '../entities/user_profile_entity.dart';
import '../entities/user_relation_entity.dart';
import '../repositories/profile_repository.dart';

class GetProfileUseCase {
  final ProfileRepository _repository;

  GetProfileUseCase(this._repository);

  Future<UserProfileEntity> call() {
    return _repository.getProfile();
  }
}

class GetUserProfileDetailUseCase {
  final ProfileRepository _repository;

  GetUserProfileDetailUseCase(this._repository);

  Future<UserProfileDetailEntity> call() {
    return _repository.getUserProfileDetail();
  }
}

class GetUserRelationsUseCase {
  final ProfileRepository _repository;

  GetUserRelationsUseCase(this._repository);

  Future<List<UserRelationEntity>> call() {
    return _repository.getUserRelations();
  }
}

class UpdateDarkModeUseCase {
  final ProfileRepository _repository;

  UpdateDarkModeUseCase(this._repository);

  Future<void> call(bool isDark) {
    return _repository.updateDarkMode(isDark);
  }
}
