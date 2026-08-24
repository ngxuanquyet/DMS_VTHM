import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    MockBackendInterceptor(),
    LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: false,
      responseHeader: false,
      error: true,
    ),
  ]);

  return dio;
});

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
      // Trigger automatic offline disconnect popup
      connectivityNotifier?.handleNetworkDisconnection();
      return const NetworkException();
    }
    if (error.response != null) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) {
        return const UnauthorizedException();
      }
      final data = error.response?.data;
      if (data is Map && data.containsKey('message')) {
        return ServerException(data['message'].toString(), statusCode);
      }
      return ServerException('Lỗi máy chủ ($statusCode)', statusCode);
    }
    return ServerException(error.message ?? 'Đã xảy ra lỗi không xác định');
  }
}
