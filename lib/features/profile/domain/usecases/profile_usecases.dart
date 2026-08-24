import '../entities/user_profile_entity.dart';
import '../repositories/profile_repository.dart';

class GetProfileUseCase {
  final ProfileRepository _repository;

  GetProfileUseCase(this._repository);

  Future<UserProfileEntity> call() {
    return _repository.getProfile();
  }
}

class UpdateDarkModeUseCase {
  final ProfileRepository _repository;

  UpdateDarkModeUseCase(this._repository);

  Future<void> call(bool isDark) {
    return _repository.updateDarkMode(isDark);
  }
}
