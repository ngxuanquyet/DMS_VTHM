import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository _repository;

  LoginUseCase(this._repository);

  Future<UserEntity> call({
    required String username,
    required String password,
    required bool rememberMe,
  }) {
    return _repository.login(
      username: username,
      password: password,
      rememberMe: rememberMe,
    );
  }
}

class CheckAuthUseCase {
  final AuthRepository _repository;

  CheckAuthUseCase(this._repository);

  Future<UserEntity?> call() {
    return _repository.checkAuthStatus();
  }
}

class LogoutUseCase {
  final AuthRepository _repository;

  LogoutUseCase(this._repository);

  Future<void> call() {
    return _repository.logout();
  }
}

class GetSavedUsernameUseCase {
  final AuthRepository _repository;

  GetSavedUsernameUseCase(this._repository);

  Future<String?> call() {
    return _repository.getSavedUsername();
  }
}
