import '../../domain/entities/user_entity.dart';

enum AuthStatus { initial, unauthenticated, authenticated, authenticating, error }

class AuthState {
  final AuthStatus status;
  final UserEntity? user;
  final String? errorMessage;
  final bool rememberMe;
  final String savedUsername;
  final bool isPasswordVisible;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.rememberMe = false,
    this.savedUsername = '',
    this.isPasswordVisible = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserEntity? user,
    String? errorMessage,
    bool? rememberMe,
    String? savedUsername,
    bool? isPasswordVisible,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      rememberMe: rememberMe ?? this.rememberMe,
      savedUsername: savedUsername ?? this.savedUsername,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
    );
  }
}
