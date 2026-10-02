import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/position_reason_entity.dart';
import '../models/position_declaration_request_model.dart';
import '../models/position_photo_response_model.dart';

import '../../../../core/utils/image_upload_helper.dart';

/// Service gọi API module Khai báo vị trí
/// Host: https://api-app.vthmgroup.vn
/// Theo đặc tả API-KHAI-BAO-VI-TRI-MOBILE-2026-10-01.md
class PositionDeclarationApiService {
  final ApiClient _apiClient;

  PositionDeclarationApiService(this._apiClient);

  /// Lấy danh mục lý do đang bật (§2)
  /// GET /dms/position-reasons/active
  Future<List<PositionReasonEntity>> getActiveReasons() async {
    final response = await _apiClient.get('/dms/position-reasons/active');

    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((item) => PositionReasonEntity.fromJson(item))
            .toList();
      }
    }

    return const [];
  }

  /// Tải 1 tấm ảnh lên nhận token 32-hex (§3)
  /// POST /dms/position-photos
  /// Chỉ nhận jpg, jpeg, png, gif, webp, bmp (tối đa 10MB) - KHÔNG nhận heic/heif
  Future<PositionPhotoResponseModel> uploadPhoto(File file) async {
    final preparedFile = await ImageUploadHelper.prepareImageForUpload(file);
    final fileName = ImageUploadHelper.getValidFileName(preparedFile.path);

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        preparedFile.path,
        filename: fileName,
      ),
    });

    final response = await _apiClient.postMultipart(
      '/dms/position-photos',
      formData: formData,
    );

    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return PositionPhotoResponseModel.fromJson(data);
      }
    }

    throw Exception('Phản hồi tải ảnh không hợp lệ từ máy chủ');
  }

  /// Gửi khai báo vị trí (§4)
  /// POST /dms/position-declarations
  /// Phản hồi 201 trả về id, declared_at, declared_date
  Future<Map<String, dynamic>> createDeclaration(
    PositionDeclarationRequestModel request,
  ) async {
    final response = await _apiClient.post(
      '/dms/position-declarations',
      data: request.toJson(),
    );

    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      return response;
    }

    throw Exception('Phản hồi khai báo vị trí không hợp lệ từ máy chủ');
  }
}
