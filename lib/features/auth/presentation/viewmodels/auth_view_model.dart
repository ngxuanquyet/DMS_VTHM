import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/services/auth_api_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecases.dart';
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
    logoutUseCase: ref.read(logoutUseCaseProvider),
    getSavedUsernameUseCase: ref.read(getSavedUsernameUseCaseProvider),
  );
});

class AuthViewModel extends StateNotifier<AuthState> {
  final LoginUseCase loginUseCase;
  final CheckAuthUseCase checkAuthUseCase;
  final LogoutUseCase logoutUseCase;
  final GetSavedUsernameUseCase getSavedUsernameUseCase;

  AuthViewModel({
    required this.loginUseCase,
    required this.checkAuthUseCase,
    required this.logoutUseCase,
    required this.getSavedUsernameUseCase,
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
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
        );
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
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString().replaceAll('AppException: ', '').replaceAll('ServerException: ', ''),
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
