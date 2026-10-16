import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/services/auth_api_service.dart';
import '../../../../core/rules/mobile_rules_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../../../route/presentation/viewmodels/route_view_model.dart';
import '../states/auth_state.dart';

final authApiServiceProvider = Provider<AuthApiService>((ref) {
  return AuthApiService(ref.read(apiClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.read(authApiServiceProvider));
});

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.read(authRepositoryProvider));
});

final checkAuthUseCaseProvider = Provider<CheckAuthUseCase>((ref) {
  return CheckAuthUseCase(ref.read(authRepositoryProvider));
});

final checkAppAccessUseCaseProvider = Provider<CheckAppAccessUseCase>((ref) {
  return CheckAppAccessUseCase(ref.read(authRepositoryProvider));
});

final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  return LogoutUseCase(ref.read(authRepositoryProvider));
});

final getSavedUsernameUseCaseProvider = Provider<GetSavedUsernameUseCase>((ref) {
  return GetSavedUsernameUseCase(ref.read(authRepositoryProvider));
});

final authViewModelProvider = StateNotifierProvider<AuthViewModel, AuthState>((ref) {
  return AuthViewModel(
    loginUseCase: ref.read(loginUseCaseProvider),
    checkAuthUseCase: ref.read(checkAuthUseCaseProvider),
    checkAppAccessUseCase: ref.read(checkAppAccessUseCaseProvider),
    logoutUseCase: ref.read(logoutUseCaseProvider),
    getSavedUsernameUseCase: ref.read(getSavedUsernameUseCaseProvider),
    ref: ref,
  );
});

class AuthViewModel extends StateNotifier<AuthState> {
  final LoginUseCase loginUseCase;
  final CheckAuthUseCase checkAuthUseCase;
  final CheckAppAccessUseCase checkAppAccessUseCase;
  final LogoutUseCase logoutUseCase;
  final GetSavedUsernameUseCase getSavedUsernameUseCase;
  final Ref? ref;

  AuthViewModel({
    required this.loginUseCase,
    required this.checkAuthUseCase,
    required this.checkAppAccessUseCase,
    required this.logoutUseCase,
    required this.getSavedUsernameUseCase,
    this.ref,
  }) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final savedUser = await getSavedUsernameUseCase();
    if (savedUser != null && savedUser.isNotEmpty) {
      state = state.copyWith(savedUsername: savedUser, rememberMe: true);
    }
  }

  Future<bool> checkAuth() async {
    try {
      final user = await checkAuthUseCase();
      if (user != null) {
        // Kiểm tra quyền app-access (§2.3 spec 15/10/2026: GET /dms/app-access)
        try {
          await checkAppAccessUseCase();
        } on DmsAppForbiddenException catch (e) {
          // Bị thu quyền -> Thu hồi phiên, đẩy về màn đăng nhập kèm thông báo
          await logout();
          state = state.copyWith(
            status: AuthStatus.error,
            errorMessage: e.message,
          );
          return false;
        } on ServerException catch (e) {
          if (e.statusCode == 403 || e.code == 'DMS_APP_FORBIDDEN') {
            await logout();
            state = state.copyWith(
              status: AuthStatus.error,
              errorMessage: 'Tài khoản chưa được cấp quyền dùng app DMS. Vui lòng liên hệ quản lý.',
            );
            return false;
          }
        } catch (_) {
          // Mất mạng / ngoại tuyến: Không đẩy ra ngoài, giữ phiên để app chạy offline
        }

        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
        );
        // Tải luật thị trường khi khởi động phiên đăng nhập (§1.3)
        ref?.read(mobileRulesProvider.notifier).fetchRules();
        try {
          ref?.read(routeApiServiceProvider).getMyRoutes(forceRefresh: true);
        } catch (_) {}
        return true;
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return false;
      }
    } catch (_) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return false;
    }
  }

  void togglePasswordVisibility() {
    state = state.copyWith(isPasswordVisible: !state.isPasswordVisible);
  }

  void setRememberMe(bool value) {
    state = state.copyWith(rememberMe: value);
  }

  Future<bool> login(String username, String password) async {
    if (username.trim().isEmpty || password.trim().isEmpty) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Vui lòng điền đầy đủ tài khoản và mật khẩu',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.authenticating, errorMessage: null);

    try {
      final user = await loginUseCase(
        username: username.trim(),
        password: password.trim(),
        rememberMe: state.rememberMe,
      );

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
      );
      // Gọi GET /dms/mobile-rules lúc đăng nhập, lưu bản sao trong máy (§1.3)
      ref?.read(mobileRulesProvider.notifier).fetchRules();
      try {
        ref?.read(routeApiServiceProvider).getMyRoutes(forceRefresh: true);
      } catch (_) {}
      return true;
    } catch (e) {
      String msg;
      if (e is DmsAppForbiddenException) {
        msg = e.message;
      } else {
        msg = e.toString()
            .replaceAll('AppException: ', '')
            .replaceAll('ServerException: ', '')
            .replaceAll('DmsAppForbiddenException: ', '');
      }
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: msg,
      );
      return false;
    }
  }

  Future<void> logout() async {
    await logoutUseCase();
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      user: null,
    );
  }
}
