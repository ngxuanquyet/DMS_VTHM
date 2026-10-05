import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/image_upload_helper.dart';
import '../models/attendance_model.dart';

class AttendanceApiService {
  final ApiClient _apiClient;

  AttendanceApiService(this._apiClient);

  /// Lấy cấu hình chấm công và danh sách địa điểm (§2 API-CHAM-CONG-MOBILE-2026-10-05.md)
  /// GET /attendance/mobile/config?lat={lat}&lng={lng}
  Future<AttendanceConfigModel> getConfig({double? lat, double? lng}) async {
    final queryParams = <String, dynamic>{};
    if (lat != null && lng != null) {
      queryParams['lat'] = lat;
      queryParams['lng'] = lng;
    }

    final response = await _apiClient.get(
      '/attendance/mobile/config',
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    if (response is Map<String, dynamic> && response['data'] is Map<String, dynamic>) {
      return AttendanceConfigModel.fromJson(response['data'] as Map<String, dynamic>);
    } else if (response is Map<String, dynamic>) {
      return AttendanceConfigModel.fromJson(response);
    }
    throw Exception('Dữ liệu cấu hình chấm công không hợp lệ.');
  }

  /// Gửi một lượt chấm công (§3 API-CHAM-CONG-MOBILE-2026-10-05.md)
  /// POST /attendance/mobile/punch
  Future<AttendancePunchModel> punch(AttendancePunchRequestModel request) async {
    final response = await _apiClient.post(
      '/attendance/mobile/punch',
      data: request.toJson(),
    );

    if (response is Map<String, dynamic> && response['data'] is Map<String, dynamic>) {
      return AttendancePunchModel.fromJson(response['data'] as Map<String, dynamic>);
    } else if (response is Map<String, dynamic>) {
      return AttendancePunchModel.fromJson(response);
    }
    throw Exception('Dữ liệu phản hồi lượt chấm công không hợp lệ.');
  }

  /// Tải ảnh của lượt chấm (§4 API-CHAM-CONG-MOBILE-2026-10-05.md)
  /// POST /attendance/mobile/punches/{id}/photos
  Future<AttendancePhotoItemModel> uploadPunchPhoto(
    int punchId, {
    required File file,
    required String photoType,
    DateTime? takenAt,
    double? lat,
    double? lng,
  }) async {
    final preparedFile = await ImageUploadHelper.prepareImageForUpload(file);
    final fileName = ImageUploadHelper.getValidFileName(preparedFile.path);

    final formMap = <String, dynamic>{
      'file': await MultipartFile.fromFile(preparedFile.path, filename: fileName),
      'photo_type': photoType,
    };

    if (takenAt != null) {
      formMap['taken_at'] = takenAt.toIso8601String();
    }
    if (lat != null && lng != null) {
      formMap['lat'] = lat;
      formMap['lng'] = lng;
    }

    final formData = FormData.fromMap(formMap);

    final response = await _apiClient.postMultipart(
      '/attendance/mobile/punches/$punchId/photos',
      formData: formData,
    );

    if (response is Map<String, dynamic> && response['data'] is Map<String, dynamic>) {
      return AttendancePhotoItemModel.fromJson(response['data'] as Map<String, dynamic>);
    } else if (response is Map<String, dynamic>) {
      return AttendancePhotoItemModel.fromJson(response);
    }
    throw Exception('Dữ liệu ảnh trả về không hợp lệ.');
  }

  /// Lấy lịch sử chấm công của chính mình (§5 API-CHAM-CONG-MOBILE-2026-10-05.md)
  /// GET /attendance/mobile/history?days=7
  Future<List<AttendancePunchModel>> getHistory({int days = 7}) async {
    final safeDays = days.clamp(1, 31);
    final response = await _apiClient.get(
      '/attendance/mobile/history',
      queryParameters: {'days': safeDays},
    );

    if (response is Map<String, dynamic> && response['data'] is List) {
      final list = response['data'] as List<dynamic>;
      return list
          .map((item) => AttendancePunchModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Phương thức cũ hỗ trợ tương thích ngược (không gọi mạng vì backend dùng spec /attendance/mobile/*)
  Future<AttendanceDetailModel> getAttendanceDetail() async {
    return AttendanceDetailModel(
      isWorking: false,
      currentTime: '00:00:00',
      currentDateFormatted: '',
      checkInTime: '--:--',
      workDurationSeconds: 0,
      location: const AttendanceLocationModel(
        address: '',
        gpsAccuracy: '',
        latitude: 0,
        longitude: 0,
      ),
      monthlyStats: const MonthlyAttendanceStatsModel(
        monthLabel: '',
        workingDays: 0,
        lateDays: 0,
      ),
      history: [],
    );
  }
}
