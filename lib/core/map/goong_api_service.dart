import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../errors/app_exceptions.dart';
import 'goong_config.dart';
import 'goong_models.dart';

/// Gọi Goong Maps REST API v2: đổi toạ độ ↔ địa chỉ, gợi ý địa chỉ, đo khoảng cách, chỉ đường.
///
/// 🔴 **Dùng `Dio` RIÊNG, không dùng `dioProvider` của app.** `dioProvider` gắn `AuthInterceptor`, nó
/// đính Bearer token của One vào MỌI request không phải login/refresh — dùng chung là **gửi token nội bộ
/// của công ty sang máy chủ Goong**. Nó còn gắn `MockBackendInterceptor`, thứ chặn theo đường dẫn và có
/// thể nuốt luôn lời gọi Goong. Hai lý do đó đều đủ để tách riêng.
///
/// ⚠️ Mọi endpoint v2 đều trả HTTP 200 kèm `status` trong thân phản hồi. `ZERO_RESULTS` **không phải lỗi**
/// — là "không tìm thấy", trả rỗng. Ném ngoại lệ ở ca này thì ô tìm kiếm sẽ đỏ lòm mỗi lần gõ dở chừng.
class GoongApiService {
  final Dio _dio;

  GoongApiService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: GoongConfig.baseUrl,
                connectTimeout:
                    const Duration(milliseconds: AppConstants.connectTimeout),
                receiveTimeout:
                    const Duration(milliseconds: AppConstants.receiveTimeout),
                headers: {'Accept': 'application/json'},
              ),
            );

  /// Toạ độ → địa chỉ (reverse geocoding).
  ///
  /// Dùng lúc check-in để điền địa chỉ nơi nhân viên đang đứng.
  /// Trả `null` khi Goong không biết điểm đó — gọi bên ngoài phải chịu được `null`, **không** được chặn
  /// việc check-in chỉ vì thiếu địa chỉ: toạ độ mới là bằng chứng, địa chỉ chỉ để người đọc dễ hiểu.
  Future<GoongPlace?> reverseGeocode(double lat, double lng) async {
    final data = await _get('/v2/geocode', {'latlng': '$lat,$lng'});
    final results = data['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      return null;
    }

    return GoongPlace.fromJson(results.first as Map<String, dynamic>);
  }

  /// Địa chỉ → toạ độ (forward geocoding).
  Future<GoongPlace?> geocodeAddress(String address) async {
    final query = address.trim();
    if (query.isEmpty) {
      return null;
    }

    final data = await _get('/v2/geocode', {'address': query});
    final results = data['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      return null;
    }

    return GoongPlace.fromJson(results.first as Map<String, dynamic>);
  }

  /// Gợi ý địa chỉ trong lúc gõ.
  ///
  /// [near] là điểm neo để xếp kết quả theo khoảng cách — truyền vị trí hiện tại của nhân viên. Thiếu nó
  /// thì gõ "Vitto" ở Cần Thơ vẫn có thể ra cửa hàng ngoài Hà Nội đứng đầu danh sách.
  Future<List<GoongPrediction>> autocomplete(
    String input, {
    GoongLatLng? near,
    int limit = 8,
  }) async {
    final query = input.trim();
    if (query.isEmpty) {
      return const [];
    }

    final anchor = near ??
        const GoongLatLng(GoongConfig.fallbackLat, GoongConfig.fallbackLng);
    final data = await _get('/v2/place/autocomplete', {
      'input': query,
      'location': anchor.toString(),
      'limit': '$limit',
    });

    final predictions = data['predictions'] as List<dynamic>?;
    if (predictions == null) {
      return const [];
    }

    return predictions
        .whereType<Map<String, dynamic>>()
        .map(GoongPrediction.fromJson)
        .where((p) => p.placeId.isNotEmpty)
        .toList();
  }

  /// Lấy chi tiết (kèm toạ độ) của một gợi ý.
  ///
  /// Bắt buộc gọi sau [autocomplete] nếu cần lat/lng — gợi ý không mang toạ độ.
  Future<GoongPlace?> placeDetail(String placeId) async {
    if (placeId.isEmpty) {
      return null;
    }

    final data = await _get('/v2/place/detail', {'place_id': placeId});
    final result = data['result'] as Map<String, dynamic>?;

    return result == null ? null : GoongPlace.fromJson(result);
  }

  /// Khoảng cách + thời gian đi theo ĐƯỜNG THẬT giữa hai điểm.
  ///
  /// ⚠️ Khác hẳn khoảng cách đường chim bay. Đừng dùng con số này để kiểm tra nhân viên có đứng trong
  /// bán kính điểm bán hay không — vòng geofence là đường chim bay, tính cục bộ, không tốn lượt gọi API.
  Future<GoongDistance?> distance(
    GoongLatLng from,
    GoongLatLng to, {
    String vehicle = 'bike',
  }) async {
    final data = await _get('/v2/distancematrix', {
      'origins': from.toString(),
      'destinations': to.toString(),
      'vehicle': vehicle,
    });

    final rows = data['rows'] as List<dynamic>?;
    if (rows == null || rows.isEmpty) {
      return null;
    }
    final elements = (rows.first as Map<String, dynamic>?)?['elements'] as List<dynamic>?;
    if (elements == null || elements.isEmpty) {
      return null;
    }
    final element = elements.first as Map<String, dynamic>?;
    if (element == null || element['status'] != 'OK') {
      return null;
    }

    return GoongDistance.fromJson(element);
  }

  /// Đường đi từ [from] tới [to], trả về chuỗi polyline đã mã hoá để vẽ lên bản đồ.
  Future<String?> directionPolyline(
    GoongLatLng from,
    GoongLatLng to, {
    String vehicle = 'bike',
  }) async {
    final data = await _get('/v2/direction', {
      'origin': from.toString(),
      'destination': to.toString(),
      'vehicle': vehicle,
    });

    final routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      return null;
    }
    final route = routes.first as Map<String, dynamic>?;
    final overview = route?['overview_polyline'] as Map<String, dynamic>?;

    return overview?['points'] as String?;
  }

  /// Đường dẫn ảnh **bản đồ tĩnh** — dùng thẳng cho `Image.network`, không phải gọi qua [_get].
  ///
  /// 🔴 Goong chỉ có MỘT endpoint ảnh tĩnh: `/staticmap/route`, và nó vẽ TUYẾN. Muốn bản đồ một điểm thì
  /// truyền [to] = `null`, hàm sẽ đặt điểm đến trùng điểm đi — Goong trả về bản đồ sạch có ghim đỏ ở
  /// giữa, đúng thứ cần cho thẻ xem trước. (Đo 12/09/2026: `/staticmap`, `/staticmap/center`,
  /// `/staticmap/marker` và 4 dạng tileserver chuẩn đều 404 — endpoint đó không tồn tại.)
  ///
  /// ⚠️ Dùng **khoá REST** ([GoongConfig.apiKey]), không phải khoá Maptiles — khoá Maptiles trả 403.
  /// ⚠️ Goong chỉ nhận `width`/`height`; `size=600x400` bị bỏ qua im lặng.
  /// ⚠️ Header trả về ghi `image/png` nhưng thân ảnh là **JPEG**. Flutter tự nhận dạng nên không sao;
  /// chỗ nào tự đặt đuôi tệp theo `Content-Type` thì sẽ đặt sai.
  String staticMapUrl(
    GoongLatLng from, {
    GoongLatLng? to,
    int? width,
    int? height,
    String vehicle = 'bike',
  }) {
    final destination = to ?? from;
    final query = <String, String>{
      'origin': from.toString(),
      'destination': destination.toString(),
      'vehicle': vehicle,
      'width': '${width ?? GoongConfig.staticMapWidth}',
      'height': '${height ?? GoongConfig.staticMapHeight}',
      'api_key': GoongConfig.apiKey,
    };
    final qs = query.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    return '${GoongConfig.baseUrl}/staticmap/route?$qs';
  }

  /// Gọi một endpoint và trả thân phản hồi đã kiểm `status`.
  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> query,
  ) async {
    if (!GoongConfig.hasKey) {
      throw const AppException('Chưa cấu hình khoá Goong Maps.');
    }

    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: {...query, 'api_key': GoongConfig.apiKey},
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const ServerException('Goong trả về dữ liệu không đọc được.');
      }

      final status = data['status'] as String?;
      // ZERO_RESULTS / NOT_FOUND là KẾT QUẢ RỖNG, không phải lỗi — trả về để nơi gọi tự hiểu là "không có".
      if (status != null &&
          status != 'OK' &&
          status != 'ZERO_RESULTS' &&
          status != 'NOT_FOUND') {
        throw ServerException(_messageOf(status), response.statusCode);
      }

      return data;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const NetworkException();
      }
      // 400 kèm NOT_FOUND là "không tìm thấy", không phải hỏng.
      final body = e.response?.data;
      if (body is Map && body['status'] == 'NOT_FOUND') {
        return {'status': 'NOT_FOUND'};
      }

      throw ServerException(
        'Không gọi được dịch vụ bản đồ.',
        e.response?.statusCode,
      );
    }
  }

  String _messageOf(String status) => switch (status) {
        'INVALID_REQUEST' => 'Yêu cầu bản đồ không hợp lệ.',
        'OVER_QUERY_LIMIT' =>
          'Đã hết hạn mức Goong Maps của công ty trong hôm nay.',
        'REQUEST_DENIED' => 'Khoá Goong Maps bị từ chối.',
        _ => 'Dịch vụ bản đồ đang lỗi ($status).',
      };
}
