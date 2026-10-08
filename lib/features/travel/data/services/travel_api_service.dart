import '../../../../core/network/api_client.dart';
import '../models/travel_day_model.dart';
import '../models/travel_leg_model.dart';

/// Service gọi API module Quãng đường di chuyển
/// Host: https://api-app.vthmgroup.vn
/// Theo đặc tả API-QUANG-DUONG-MOBILE-2026-10-08.md
class TravelApiService {
  final ApiClient _apiClient;

  TravelApiService(this._apiClient);

  /// Lấy danh sách quãng đường của chính mình theo ngày (§4.1)
  /// GET /dms/travel/mine
  /// Ép lọc theo tài khoản đang đăng nhập; không xem được của người khác
  Future<List<TravelDayModel>> getMyTravel({
    String? from,
    String? to,
    int page = 1,
    int perPage = 50,
    String sort = '-work_date',
  }) async {
    final Map<String, dynamic> params = {
      'page': page,
      'per-page': perPage,
      'sort': sort,
    };
    if (from != null && from.isNotEmpty) params['from'] = from;
    if (to != null && to.isNotEmpty) params['to'] = to;

    final response = await _apiClient.get(
      '/dms/travel/mine',
      queryParameters: params,
    );

    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map((item) => TravelDayModel.fromJson(item))
            .toList();
      }
    }

    return const [];
  }

  /// Lấy chi tiết từng chặng của một ngày công (§4.2)
  /// GET /dms/travel/legs/{userId}/{workDate}
  /// Sắp xếp theo seq tăng dần
  Future<List<TravelLegModel>> getTravelLegs({
    required dynamic userId,
    required String workDate,
  }) async {
    final response = await _apiClient.get(
      '/dms/travel/legs/$userId/$workDate',
    );

    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is List) {
        final list = data
            .whereType<Map<String, dynamic>>()
            .map((item) => TravelLegModel.fromJson(item))
            .toList();
        list.sort((a, b) => a.seq.compareTo(b.seq));
        return list;
      }
    }

    return const [];
  }
}
