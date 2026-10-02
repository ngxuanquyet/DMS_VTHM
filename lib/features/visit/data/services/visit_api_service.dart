import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/image_upload_helper.dart';
import '../../domain/entities/visit_entity.dart';
import '../../domain/entities/visit_photo_entity.dart';
import '../../domain/entities/visit_requirements_entity.dart';
import '../models/checkin_request_model.dart';
import '../models/checkout_request_model.dart';

class VisitApiService {
  final ApiClient _apiClient;

  VisitApiService(this._apiClient);

  /// Lấy danh sách lượt viếng thăm của tôi (§2.3)
  /// Thường dùng: date_from=hôm_nay&date_to=hôm_nay để soi điểm bán đã ghé hoặc đang ghé
  Future<List<VisitEntity>> getMyVisits({
    String? dateFrom,
    String? dateTo,
    int perPage = 100,
    int? customerId,
    int? routeId,
    bool? openOnly,
  }) async {
    final Map<String, dynamic> queryParams = {
      'per-page': perPage,
    };
    if (dateFrom != null) queryParams['date_from'] = dateFrom;
    if (dateTo != null) queryParams['date_to'] = dateTo;
    if (customerId != null) queryParams['customer_id'] = customerId;
    if (routeId != null) queryParams['route_id'] = routeId;
    if (openOnly == true) queryParams['open_only'] = 1;

    final queryStr = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');

    final response = await _apiClient.get('/dms/visits/mine?$queryStr');

    List<dynamic> items = [];
    if (response is Map<String, dynamic>) {
      if (response['data'] is List) {
        items = response['data'] as List;
      }
    } else if (response is List) {
      items = response;
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map((item) => VisitEntity.fromJson(item))
        .toList();
  }

  /// Check-in mở một lượt viếng thăm (§3)
  Future<VisitEntity> checkin(CheckinRequestModel request) async {
    final response = await _apiClient.post(
      '/dms/visits',
      data: request.toJson(),
    );

    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return VisitEntity.fromJson(data);
      }
    }

    throw Exception('Phản hồi check-in không hợp lệ từ máy chủ');
  }

  /// Soi điều kiện check-out (§6)
  Future<VisitRequirementsEntity> getRequirements(
    int visitId, {
    String? visitResult,
  }) async {
    String path = '/dms/visits/$visitId/requirements';
    if (visitResult != null && visitResult.isNotEmpty) {
      path += '?visit_result=${Uri.encodeComponent(visitResult)}';
    }

    final response = await _apiClient.get(path);

    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return VisitRequirementsEntity.fromJson(data);
      }
    }

    return const VisitRequirementsEntity();
  }

  /// Tải 1 tấm ảnh lên cho lượt viếng thăm (§4.1)
  /// Nhận jpg, jpeg, png, gif, webp, bmp (tối đa 10MB)
  Future<VisitPhotoEntity> uploadPhoto({
    required int visitId,
    required File file,
    String photoType = 'other',
    DateTime? takenAt,
    double? lat,
    double? lng,
  }) async {
    final preparedFile = await ImageUploadHelper.prepareImageForUpload(file);
    final fileName = ImageUploadHelper.getValidFileName(preparedFile.path);

    final Map<String, dynamic> formMap = {
      'file': await MultipartFile.fromFile(preparedFile.path, filename: fileName),
      'photo_type': photoType,
    };
    if (takenAt != null) {
      formMap['taken_at'] = takenAt.toIso8601String();
    }
    if (lat != null) formMap['lat'] = lat;
    if (lng != null) formMap['lng'] = lng;

    final formData = FormData.fromMap(formMap);

    final response = await _apiClient.postMultipart(
      '/dms/visits/$visitId/photos',
      formData: formData,
    );

    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return VisitPhotoEntity.fromJson(data).copyWith(localPath: file.path);
      }
    }

    throw Exception('Không nhận được phản hồi hợp lệ sau khi tải ảnh lên');
  }

  /// Xoá một tấm ảnh chụp lỗi (§4.2)
  /// Chỉ xoá được khi lượt chưa check-out
  Future<VisitRequirementsEntity> deletePhoto({
    required int visitId,
    required int photoId,
  }) async {
    final response = await _apiClient.delete('/dms/visits/$visitId/photos/$photoId');

    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic> && data['requirements'] is Map<String, dynamic>) {
        return VisitRequirementsEntity.fromJson(data['requirements'] as Map<String, dynamic>);
      }
    }

    return const VisitRequirementsEntity();
  }

  /// Check-out đóng lượt viếng thăm (§7)
  Future<VisitEntity> checkout({
    required int visitId,
    required CheckoutRequestModel request,
  }) async {
    final response = await _apiClient.post(
      '/dms/visits/$visitId/checkout',
      data: request.toJson(),
    );

    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return VisitEntity.fromJson(data);
      }
    }

    throw Exception('Không nhận được phản hồi hợp lệ sau khi check-out');
  }

  /// Huỷ lượt viếng thăm (§3.4 HUY-LUOT-VIENG-THAM-2026-09-30.md)
  /// POST /dms/visits/{id}/cancel
  Future<Map<String, dynamic>> cancelVisit(int visitId) async {
    final response = await _apiClient.post('/dms/visits/$visitId/cancel');
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      return response;
    }
    return {'id': visitId};
  }
}
