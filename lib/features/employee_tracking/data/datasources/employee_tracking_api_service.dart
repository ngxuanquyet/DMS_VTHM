import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../models/location_access_log_model.dart';
import '../models/location_ping_point_model.dart';
import '../models/location_ping_response_model.dart';
import '../../../../core/network/refresh_outcome.dart';

/// Các ngoại lệ đặc thù theo §1 & §2 API-VI-TRI-NHAN-VIEN-MOBILE-2026-10-09.md
class LocationTrackingDisabledException implements Exception {
  final String message;
  const LocationTrackingDisabledException(this.message);
  @override
  String toString() => message;
}

class LocationPermissionDeniedException implements Exception {
  final String message;
  const LocationPermissionDeniedException(this.message);
  @override
  String toString() => message;
}

class LocationValidationException implements Exception {
  final String message;
  const LocationValidationException(this.message);
  @override
  String toString() => message;
}

final employeeTrackingApiServiceProvider = Provider<EmployeeTrackingApiService>((ref) {
  final dio = ref.watch(dioProvider);
  return EmployeeTrackingApiService(dio);
});

class EmployeeTrackingApiService {
  final Dio _dio;

  EmployeeTrackingApiService(this._dio);

  /// Gửi danh sách điểm vị trí lên server: POST /dms/locations/ping
  /// Luôn gửi mảng points (kể cả 1 điểm). Tối đa 200 điểm một lượt gọi.
  Future<LocationPingResponseModel> pingLocations(List<LocationPingPointModel> points) async {
    if (points.isEmpty) {
      return const LocationPingResponseModel(
        success: true,
        message: 'Không có điểm nào để gửi',
        saved: 0,
        duplicated: 0,
      );
    }

    try {
      final response = await _dio.post(
        '/dms/locations/ping',
        data: {
          'points': points.map((p) => p.toJson()).toList(),
        },
      );

      if (response.data is Map<String, dynamic>) {
        return LocationPingResponseModel.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Phản hồi server không đúng định dạng');
      }
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Hỏi trạng thái và lệnh "Xin vị trí ngay" đang chờ: GET /dms/locations/pending
  Future<LocationPendingResponseModel> getPendingRequest() async {
    try {
      final response = await _dio.get('/dms/locations/pending');
      if (response.data is Map<String, dynamic>) {
        return LocationPendingResponseModel.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Phản hồi server không đúng định dạng');
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  /// Đọc nhật ký "Ai đã xem vị trí của tôi": GET /dms/locations/my-access-log
  Future<LocationAccessLogResponseModel> getMyAccessLog({
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/dms/locations/my-access-log',
        queryParameters: {
          'page': page,
          'per-page': perPage,
        },
      );
      if (response.data is Map<String, dynamic>) {
        final log = LocationAccessLogResponseModel.fromJson(response.data as Map<String, dynamic>);
        // Gọi Dio trực tiếp (không qua ApiClient) ⇒ tự ghi kết quả cho "kéo xuống làm mới" (RefreshOutcome).
        RefreshOutcome.record(reachedServer: true);
        return log;
      }
      throw Exception('Phản hồi server không đúng định dạng');
    } on DioException catch (e) {
      RefreshOutcome.record(reachedServer: false);
      _handleDioError(e);
      rethrow;
    } catch (_) {
      RefreshOutcome.record(reachedServer: false);
      rethrow;
    }
  }

  void _handleDioError(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;

    if (statusCode == 403) {
      throw const LocationPermissionDeniedException(
        'Tài khoản không có quyền theo dõi vị trí (/dms/location/ping hoặc /pending).',
      );
    }

    if (statusCode == 422 && data is Map<String, dynamic>) {
      final code = data['code'] ?? data['error_code'];
      final message = data['message'] as String? ?? 'Dữ liệu không hợp lệ';

      if (code == 'LOCATION_RULE') {
        throw LocationTrackingDisabledException(message);
      }
      if (code == 'VALIDATION_ERROR') {
        throw LocationValidationException(message);
      }
    }
  }
}
