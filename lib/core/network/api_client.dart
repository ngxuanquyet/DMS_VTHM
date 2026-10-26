import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../errors/app_exceptions.dart';
import 'api_logger_interceptor.dart';
import 'connectivity_provider.dart';

import '../services/anti_fraud_service.dart';
import '../services/error_tracker_service.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(milliseconds: AppConstants.connectTimeout),
      receiveTimeout: const Duration(milliseconds: AppConstants.receiveTimeout),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        AppConstants.headerClientKey: AppConstants.headerClientValue,
      },
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(dio),
    ServerTimeInterceptor(),
    AppApiLoggerInterceptor(),
  ]);

  // Lỗi app gửi về máy chủ (thay Telegram, 26/10/2026). Gọi thẳng `dio`, KHÔNG qua `ApiClient`: lỗi của chính lời gọi
  // này không được đi vào `trackDioError` — gửi hỏng sinh lỗi mới để gửi là vòng lặp không dừng.
  ErrorTrackerService.instance.attachUploader((errors) async {
    final res = await dio.post('/dms/client-errors', data: {'errors': errors});
    final data = res.data is Map ? res.data['data'] : null;
    final refs = data is Map ? data['refs'] : null;
    return refs is List ? refs.map((e) => e.toString()).toList() : <String>[];
  });

  return dio;
});

/// Interceptor ghi nhận mốc thời gian máy chủ từ HTTP Header Date
class ServerTimeInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _captureServerDate(response.headers);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response != null) {
      _captureServerDate(err.response!.headers);
    }
    handler.next(err);
  }

  void _captureServerDate(Headers headers) {
    final dateStr = headers.value('date') ?? headers.value('Date');
    if (dateStr != null && dateStr.isNotEmpty) {
      try {
        final serverDate = HttpDate.parse(dateStr);
        AntiFraudService.recordServerTime(serverDate);
      } catch (_) {}
    }
  }
}

class AuthInterceptor extends QueuedInterceptor {
  final Dio dio;

  AuthInterceptor(this.dio);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Luôn gửi header X-Client: dms-app theo spec 15/10/2026
    options.headers[AppConstants.headerClientKey] = AppConstants.headerClientValue;

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
                AppConstants.headerClientKey: AppConstants.headerClientValue,
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
        } on DioException catch (refreshErr) {
          final resData = refreshErr.response?.data;
          final errCode = resData is Map ? resData['code']?.toString() : null;
          final isDmsForbidden = refreshErr.response?.statusCode == 403 || errCode == 'DMS_APP_FORBIDDEN';

          // Token refresh failed -> Clear session
          await prefs.remove(AppConstants.keyAccessToken);
          await prefs.remove(AppConstants.keyAuthToken);
          await prefs.remove(AppConstants.keyRefreshToken);
          await prefs.remove(AppConstants.keyUserData);

          if (isDmsForbidden) {
            final msg = (resData is Map ? resData['message']?.toString() : null) ??
                'Tài khoản chưa được cấp quyền dùng app DMS. Vui lòng liên hệ quản lý.';
            return handler.reject(
              DioException(
                requestOptions: err.requestOptions,
                response: refreshErr.response,
                type: DioExceptionType.badResponse,
                error: DmsAppForbiddenException(msg),
              ),
            );
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

  Future<dynamic> postMultipart(
    String path, {
    required FormData formData,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final uploadOptions = (options ?? Options()).copyWith(
        contentType: 'multipart/form-data',
      );
      final response = await _dio.post(
        path,
        data: formData,
        queryParameters: queryParameters,
        options: uploadOptions,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw AppException(e.toString());
    }
  }

  Future<dynamic> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.patch(
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

  Future<dynamic> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put(
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

  Future<dynamic> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete(
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
    // Tự động ghi nhận và sinh mã lỗi Incident Error ID
    final errorRecord = ErrorTrackerService.instance.trackDioError(error);
    final errorId = errorRecord.id;

    if (error.error is DmsAppForbiddenException) {
      final prev = error.error as DmsAppForbiddenException;
      return DmsAppForbiddenException(prev.message, errorId);
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.error is SocketException ||
        error.error is HttpException) {
      connectivityNotifier?.handleNetworkDisconnection();
      return NetworkException(
        'Không có kết nối mạng. Vui lòng kiểm tra lại.',
        errorId,
      );
    }
    if (error.response != null) {
      final statusCode = error.response?.statusCode;
      final data = error.response?.data;
      final rawCode = data is Map ? data['code']?.toString() : null;
      final errCode = rawCode ?? _resolveDefaultCode(statusCode);
      String? message;
      if (data is Map &&
          data.containsKey('message') &&
          data['message'] != null &&
          data['message'].toString().isNotEmpty) {
        message = data['message'].toString();
      }

      // Xử lý mã lỗi 403 DMS_APP_FORBIDDEN theo spec 15/10/2026
      if (errCode == 'DMS_APP_FORBIDDEN' ||
          (statusCode == 403 && (message?.contains('chưa được cấp quyền dùng app DMS') ?? false))) {
        return DmsAppForbiddenException(
          message ?? 'Tài khoản chưa được cấp quyền dùng app DMS. Vui lòng liên hệ quản lý.',
          errorId,
        );
      }

      if (statusCode == 401) {
        return ServerException(
          message ?? 'Tên đăng nhập hoặc mật khẩu không đúng hoặc phiên đăng nhập hết hạn.',
          statusCode,
          errCode,
          errorId,
        );
      }

      if (data is Map && data.containsKey('errors') && data['errors'] is Map) {
        final errMap = data['errors'] as Map;
        final errorList = <String>[];
        errMap.forEach((k, v) {
          if (v is List) {
            errorList.add('$k: ${v.join(", ")}');
          } else {
            errorList.add('$k: $v');
          }
        });
        if (errorList.isNotEmpty) {
          final fullMsg = message != null
              ? '$message\n${errorList.join("\n")}'
              : errorList.join('\n');
          return ServerException(fullMsg, statusCode, errCode, errorId);
        }
      }

      if (message != null) {
        return ServerException(message, statusCode, errCode, errorId);
      }
      return ServerException('Lỗi máy chủ ($statusCode)', statusCode, errCode, errorId);
    }
    return ServerException(error.message ?? 'Đã xảy ra lỗi không xác định', null, 'CONNECTION_ERROR', errorId);
  }

  static String? _resolveDefaultCode(int? statusCode) {
    if (statusCode == null) return null;
    switch (statusCode) {
      case 400:
        return 'BAD_REQUEST';
      case 401:
        return 'UNAUTHORIZED';
      case 403:
        return 'FORBIDDEN';
      case 404:
        return 'NOT_FOUND';
      case 422:
        return 'VALIDATION_ERROR';
      case 500:
        return 'SERVER_ERROR';
      case 502:
        return 'BAD_GATEWAY';
      case 503:
        return 'SERVICE_UNAVAILABLE';
      case 504:
        return 'GATEWAY_TIMEOUT';
      default:
        return 'HTTP_$statusCode';
    }
  }
}
