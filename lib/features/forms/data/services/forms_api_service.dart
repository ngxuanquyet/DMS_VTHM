import '../../../../core/network/api_client.dart';
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
}
