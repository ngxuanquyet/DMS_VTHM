import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/image_upload_helper.dart';
import '../models/form_photo_model.dart';
import '../models/market_form_model.dart';
import '../models/market_form_submission_model.dart';

class FormsApiService {
  final ApiClient _apiClient;

  FormsApiService(this._apiClient);

  /// Lấy danh sách biểu mẫu còn hiệu lực theo đặc tả §1:
  /// GET /dms/forms/available?kind=survey&customer_id=8338
  /// GET /dms/forms/available?kind=collect
  Future<List<MarketFormConfigModel>> getAvailableForms({
    required String kind,
    int? customerId,
  }) async {
    final Map<String, dynamic> queryParams = {
      'kind': kind,
    };
    if (customerId != null) {
      queryParams['customer_id'] = customerId;
    }

    final queryStr = queryParams.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');

    final response = await _apiClient.get('/dms/forms/available?$queryStr');

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
        .map((item) => MarketFormConfigModel.fromJson(item))
        .toList();
  }

  /// Tải 1 tấm ảnh lên nhận token 32-hex theo đặc tả §2:
  /// POST /dms/form-photos
  /// Header: Authorization: Bearer `<token>`
  /// Multipart: file, tối đa 10 MB, định dạng jpg, jpeg, png, gif, webp, bmp
  Future<FormPhotoModel> uploadPhoto(File file) async {
    final preparedFile = await ImageUploadHelper.prepareImageForUpload(file);
    final fileName = ImageUploadHelper.getValidFileName(preparedFile.path);

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        preparedFile.path,
        filename: fileName,
      ),
    });

    final response = await _apiClient.postMultipart(
      '/dms/form-photos',
      formData: formData,
    );

    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return FormPhotoModel.fromJson(data);
      }
    }

    throw AppException('Phản hồi tải ảnh biểu mẫu không hợp lệ từ máy chủ');
  }

  /// Nộp phiếu biểu mẫu thị trường theo đặc tả §2:
  /// POST /dms/form-submissions
  Future<MarketFormSubmitResult> submitForm(MarketFormSubmissionModel submission) async {
    final response = await _apiClient.post(
      '/dms/form-submissions',
      data: submission.toJson(),
    );

    if (response is Map<String, dynamic>) {
      return MarketFormSubmitResult.fromJson(response);
    }

    return const MarketFormSubmitResult(
      success: true,
      message: 'Đã nộp phiếu biểu mẫu thành công.',
    );
  }

  /// Xem lại chi tiết phiếu đã nộp kèm khoá answer_photos theo đặc tả §4.3:
  /// GET /dms/form-submissions/{id}
  Future<MarketFormSubmissionDetailModel> getSubmissionDetail(int id) async {
    final response = await _apiClient.get('/dms/form-submissions/$id');

    if (response is Map<String, dynamic>) {
      final data = response['data'] ?? response;
      if (data is Map<String, dynamic>) {
        return MarketFormSubmissionDetailModel.fromJson(data);
      }
    }

    throw AppException('Không tìm thấy thông tin phiếu');
  }
}
