import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../services/auth_api_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthApiService _apiService;

  AuthRepositoryImpl(this._apiService);

  @override
  Future<UserEntity> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    final response = await _apiService.login(
      username: username,
      password: password,
    );

    if (response['success'] == true && response['data'] != null) {
      final data = response['data'] as Map<String, dynamic>;
      final userMap = data['user'] as Map<String, dynamic>? ?? {};
      final permissions = (data['permissions'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      final userModel = UserModel.fromJson(userMap, permissions: permissions);
      final accessToken = data['access_token'] as String?;
      final refreshToken = data['refresh_token'] as String?;

      final prefs = await SharedPreferences.getInstance();
      if (accessToken != null) {
        await prefs.setString(AppConstants.keyAccessToken, accessToken);
        await prefs.setString(AppConstants.keyAuthToken, accessToken);
      }
      if (refreshToken != null) {
        await prefs.setString(AppConstants.keyRefreshToken, refreshToken);
      }
      await prefs.setString(
          AppConstants.keyUserData, jsonEncode(userModel.toJson()));
      await prefs.setBool(AppConstants.keyRememberLogin, rememberMe);

      if (rememberMe) {
        await prefs.setString(AppConstants.keySavedUsername, username);
      } else {
        await prefs.remove(AppConstants.keySavedUsername);
      }

      return userModel.toEntity();
    } else {
      throw ServerException(
          response['message']?.toString() ?? 'Đăng nhập không thành công');
    }
  }

  @override
  Future<UserEntity?> checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyAccessToken) ??
        prefs.getString(AppConstants.keyAuthToken);
    final userJson = prefs.getString(AppConstants.keyUserData);

    if (token != null && userJson != null) {
      try {
        final map = jsonDecode(userJson) as Map<String, dynamic>;
        return UserModel.fromJson(map).toEntity();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<String?> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final currentRefreshToken = prefs.getString(AppConstants.keyRefreshToken);
    if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
      return null;
    }

    try {
      final response = await _apiService.refreshToken(
        refreshToken: currentRefreshToken,
      );

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        final newAccessToken = data['access_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;

        if (newAccessToken != null) {
          await prefs.setString(AppConstants.keyAccessToken, newAccessToken);
          await prefs.setString(AppConstants.keyAuthToken, newAccessToken);
        }
        if (newRefreshToken != null) {
          await prefs.setString(AppConstants.keyRefreshToken, newRefreshToken);
        }
        return newAccessToken;
      }
    } catch (_) {
      // Refresh token failed or expired
    }
    return null;
  }

  @override
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyAccessToken);
    await prefs.remove(AppConstants.keyAuthToken);
    await prefs.remove(AppConstants.keyRefreshToken);
    await prefs.remove(AppConstants.keyUserData);
  }

  @override
  Future<String?> getSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keySavedUsername);
  }
}
