import '../../../../core/network/api_client.dart';
import '../models/customer_dto.dart';

class CustomerApiService {
  final ApiClient _apiClient;

  CustomerApiService(this._apiClient);

  /// Lấy danh sách điểm bán do người dùng phụ trách hoặc tự tạo
  /// GET /crm/customers/mine?context=mobile&per-page=200
  Future<CustomerApiResponse> getMineCustomers({
    int page = 1,
    int perPage = 200,
    String? q,
    String context = 'mobile',
    String? status,
    String? approvalStatus,
    int? hasCoords,
    int? customerTypeId,
    int? channelId,
    int? regionId,
    String? provinceName,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'per-page': perPage,
      'context': context,
    };

    if (q != null && q.trim().isNotEmpty) {
      queryParams['q'] = q.trim();
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    if (approvalStatus != null && approvalStatus.isNotEmpty) {
      queryParams['approval_status'] = approvalStatus;
    }
    if (hasCoords != null) {
      queryParams['has_coords'] = hasCoords;
    }
    if (customerTypeId != null) {
      queryParams['customer_type_id'] = customerTypeId;
    }
    if (channelId != null) {
      queryParams['channel_id'] = channelId;
    }
    if (regionId != null) {
      queryParams['region_id'] = regionId;
    }
    if (provinceName != null && provinceName.isNotEmpty) {
      queryParams['province_name'] = provinceName;
    }

    final response = await _apiClient.get(
      '/crm/customers/mine',
      queryParameters: queryParams,
    );

    if (response is Map<String, dynamic>) {
      return CustomerApiResponse.fromJson(response);
    }
    throw Exception('Phản hồi API khách hàng không đúng định dạng');
  }

  /// Lấy chi tiết một điểm bán
  /// GET /crm/customers/{id}
  Future<CustomerDto> getCustomerDetail(int id) async {
    final response = await _apiClient.get('/crm/customers/$id');
    if (response is Map<String, dynamic>) {
      if (response['data'] is Map<String, dynamic>) {
        return CustomerDto.fromJson(response['data'] as Map<String, dynamic>);
      }
      return CustomerDto.fromJson(response);
    }
    throw Exception('Không thể tải chi tiết điểm bán ID: $id');
  }

  /// Cập nhật thông tin điểm bán (chỉ gửi các trường muốn đổi)
  /// PATCH /crm/customers/{id}
  Future<Map<String, dynamic>> updateCustomer(
    int id,
    Map<String, dynamic> changes,
  ) async {
    final response = await _apiClient.patch(
      '/crm/customers/$id',
      data: changes,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }
    throw Exception('Lỗi khi cập nhật điểm bán ID: $id');
  }

  /// Xóa mềm điểm bán (vào thùng rác)
  /// DELETE /crm/customers/{id}
  Future<bool> deleteCustomer(int id) async {
    try {
      final response = await _apiClient.delete('/crm/customers/$id');
      return response is Map && response['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Lấy danh mục lọc và đặc tả cột động
  /// GET /crm/customers/meta?context=mobile
  Future<Map<String, dynamic>> getCustomerMeta({String context = 'mobile'}) async {
    final response = await _apiClient.get(
      '/crm/customers/meta',
      queryParameters: {'context': context},
    );
    if (response is Map<String, dynamic>) {
      return response;
    }
    return {};
  }

  /// Lấy cấu hình schema form nhập liệu khách hàng động
  /// GET /crm/customer-form/schema
  Future<Map<String, dynamic>> getCustomerFormSchema() async {
    final response = await _apiClient.get('/crm/customer-form/schema');
    if (response is Map<String, dynamic>) {
      return response;
    }
    throw Exception('Phản hồi schema form khách hàng không đúng định dạng');
  }

  /// Thêm mới điểm bán
  /// POST /crm/customers
  Future<CustomerDto> createCustomer(Map<String, dynamic> data) async {
    final response = await _apiClient.post(
      '/crm/customers',
      data: data,
    );
    if (response is Map<String, dynamic>) {
      if (response['data'] is Map<String, dynamic>) {
        return CustomerDto.fromJson(response['data'] as Map<String, dynamic>);
      }
      return CustomerDto.fromJson(response);
    }
    throw Exception('Không thể tạo mới điểm bán');
  }
}
