import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity> login({
    required String username,
    required String password,
    required bool rememberMe,
  });

  Future<UserEntity?> checkAuthStatus();

  Future<void> logout();

  Future<String?> getSavedUsername();
}
