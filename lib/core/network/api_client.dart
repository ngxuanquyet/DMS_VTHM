import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../errors/app_exceptions.dart';
import 'connectivity_provider.dart';
import 'mock_backend.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
      receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(dio),
    MockBackendInterceptor(),
    LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: true,
      responseHeader: false,
      error: true,
    ),
  ]);

  return dio;
});

class AuthInterceptor extends QueuedInterceptor {
  final Dio dio;

  AuthInterceptor(this.dio);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Only attach bearer token if not calling login or refresh
    if (!options.path.contains('/auth/login') &&
        !options.path.contains('/auth/refresh')) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyAccessToken) ??
          prefs.getString(AppConstants.keyAuthToken);
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    final path = err.requestOptions.path;

    // Trigger token refresh on 401 if not an auth endpoint
    if (statusCode == 401 &&
        !path.contains('/auth/login') &&
        !path.contains('/auth/refresh')) {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(AppConstants.keyRefreshToken);

      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          final refreshDio = Dio(
            BaseOptions(
              baseUrl: AppConstants.baseUrl,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ),
          );

          final refreshRes = await refreshDio.post(
            '/auth/refresh',
            data: {'refresh_token': refreshToken},
          );

          if (refreshRes.statusCode == 200 &&
              refreshRes.data is Map &&
              refreshRes.data['success'] == true) {
            final data = refreshRes.data['data'] as Map<String, dynamic>;
            final newAccessToken = data['access_token'] as String?;
            final newRefreshToken = data['refresh_token'] as String?;

            if (newAccessToken != null) {
              await prefs.setString(AppConstants.keyAccessToken, newAccessToken);
              await prefs.setString(AppConstants.keyAuthToken, newAccessToken);
            }
            if (newRefreshToken != null) {
              await prefs.setString(AppConstants.keyRefreshToken, newRefreshToken);
            }

            // Retry original request with new token
            final opts = err.requestOptions;
            if (newAccessToken != null) {
              opts.headers['Authorization'] = 'Bearer $newAccessToken';
            }
            final cloneReq = await dio.fetch(opts);
            return handler.resolve(cloneReq);
          }
        } catch (_) {
          // Token refresh failed -> Clear session
          await prefs.remove(AppConstants.keyAccessToken);
          await prefs.remove(AppConstants.keyAuthToken);
          await prefs.remove(AppConstants.keyRefreshToken);
          await prefs.remove(AppConstants.keyUserData);
        }
      }
    }

    handler.next(err);
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    ref.read(dioProvider),
    connectivityNotifier: ref.read(connectivityProvider.notifier),
  );
});

class ApiClient {
  final Dio _dio;
  final ConnectivityNotifier? connectivityNotifier;

  ApiClient(this._dio, {this.connectivityNotifier});

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw AppException(e.toString());
    }
  }

  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw AppException(e.toString());
    }
  }

  AppException _handleDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      connectivityNotifier?.handleNetworkDisconnection();
      return const NetworkException();
    }
    if (error.response != null) {
      final statusCode = error.response?.statusCode;
      final data = error.response?.data;
      String? message;
      if (data is Map &&
          data.containsKey('message') &&
          data['message'] != null &&
          data['message'].toString().isNotEmpty) {
        message = data['message'].toString();
      }

      if (statusCode == 401) {
        return ServerException(
          message ?? 'Tên đăng nhập hoặc mật khẩu không đúng hoặc phiên đăng nhập hết hạn.',
          statusCode,
        );
      }
      if (message != null) {
        return ServerException(message, statusCode);
      }
      return ServerException('Lỗi máy chủ ($statusCode)', statusCode);
    }
    return ServerException(error.message ?? 'Đã xảy ra lỗi không xác định');
  }
}
