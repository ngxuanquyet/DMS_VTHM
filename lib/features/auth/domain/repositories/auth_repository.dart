import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity> login({
    required String username,
    required String password,
    required bool rememberMe,
  });

  Future<UserEntity?> checkAuthStatus();

  Future<String?> refreshToken();

  /// [keepAccountDrafts]: đăng xuất CƯỠNG BỨC (hết phiên / bị thu quyền) giữ nháp theo tài khoản (ngăn nháp khoá theo tài khoản, người khác không đọc được); chỉ TỰ đăng xuất mới xoá.
  Future<void> logout({bool keepAccountDrafts = false});

  Future<String?> getSavedUsername();

  /// Kiểm tra tài khoản có quyền truy cập app DMS không (GET /dms/app-access)
  Future<bool> checkAppAccess();
}
