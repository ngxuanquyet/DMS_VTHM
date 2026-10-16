import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity> login({
    required String username,
    required String password,
    required bool rememberMe,
  });

  Future<UserEntity?> checkAuthStatus();

  Future<String?> refreshToken();

  Future<void> logout();

  Future<String?> getSavedUsername();

  /// Kiểm tra tài khoản có quyền truy cập app DMS không (GET /dms/app-access)
  Future<bool> checkAppAccess();
}
