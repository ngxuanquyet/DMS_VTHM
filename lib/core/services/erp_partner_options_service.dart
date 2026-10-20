import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';

/// Một khách hàng pháp nhân (khách ERP Bravo) cho ô biểu mẫu `ref_erp_partner`.
/// 🔴 [code] là MÃ dạng CHUỖI, thường có số 0 đầu (`"01200001"`) — tuyệt đối không parse sang số.
class ErpPartnerOption {
  final String code;
  final String name;
  final String? address;
  final String? channelName;

  const ErpPartnerOption({
    required this.code,
    required this.name,
    this.address,
    this.channelName,
  });

  /// Nhãn hiển thị chuẩn: `"<tên> (<mã>)"`
  String get displayLabel => name.isNotEmpty ? '$name ($code)' : code;

  factory ErpPartnerOption.fromJson(Map<String, dynamic> json) {
    final address = json['address']?.toString();
    final channelName = json['channel_name']?.toString();
    return ErpPartnerOption(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: (address != null && address.trim().isNotEmpty) ? address : null,
      channelName: (channelName != null && channelName.trim().isNotEmpty) ? channelName : null,
    );
  }
}

/// Một trang kết quả của GET /dms/erp-partner-options
class ErpPartnerOptionsPage {
  final List<ErpPartnerOption> items;
  final int page;
  final bool hasMore;

  const ErpPartnerOptionsPage({
    required this.items,
    required this.page,
    required this.hasMore,
  });

  factory ErpPartnerOptionsPage.fromResponse(dynamic response, {int requestedPage = 1}) {
    final data = response is Map ? response['data'] : null;
    if (data is! Map) {
      return ErpPartnerOptionsPage(items: const [], page: requestedPage, hasMore: false);
    }
    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) => ErpPartnerOption.fromJson(Map<String, dynamic>.from(e)))
            .where((e) => e.code.isNotEmpty)
            .toList()
        : <ErpPartnerOption>[];
    final rawPage = data['page'];
    return ErpPartnerOptionsPage(
      items: items,
      page: rawPage is int ? rawPage : (int.tryParse(rawPage?.toString() ?? '') ?? requestedPage),
      hasMore: data['has_more'] == true,
    );
  }
}

final erpPartnerOptionsServiceProvider = Provider<ErpPartnerOptionsService>((ref) {
  return ErpPartnerOptionsService(ref.watch(apiClientProvider));
});

/// Gọi API tìm khách hàng pháp nhân cho ô `ref_erp_partner` (phiếu thị trường + hồ sơ điểm bán).
/// Danh sách có hàng nghìn khách nên LUÔN tìm trên server (mỗi trang 50 dòng), không cache offline.
/// Server tự lọc theo kênh admin cấu hình cho ô [field] — app không tự lọc.
class ErpPartnerOptionsService {
  final ApiClient _apiClient;

  ErpPartnerOptionsService(this._apiClient);

  /// GET /dms/erp-partner-options?field=&q=&page= — tìm theo tên/mã/tên viết tắt/địa chỉ (gõ không dấu được).
  /// Lỗi mạng / server ném [AppException] (thông báo tiếng Việt) để ô chọn hiện cho người dùng.
  Future<ErpPartnerOptionsPage> search({
    required String field,
    String query = '',
    int page = 1,
  }) async {
    final q = query.trim();
    final response = await _apiClient.get(
      '/dms/erp-partner-options',
      queryParameters: {
        'field': field,
        if (q.isNotEmpty) 'q': q,
        'page': page,
      },
    );
    return ErpPartnerOptionsPage.fromResponse(response, requestedPage: page);
  }

  /// GET /dms/erp-partner-options?field=&ids=<mã1,mã2> — tra nhãn cho các MÃ đang lưu (mở lại phiếu/hồ sơ).
  Future<List<ErpPartnerOption>> lookup({
    required String field,
    required List<String> codes,
  }) async {
    if (codes.isEmpty) return const [];
    final response = await _apiClient.get(
      '/dms/erp-partner-options',
      queryParameters: {
        'field': field,
        'ids': codes.join(','),
      },
    );
    return ErpPartnerOptionsPage.fromResponse(response).items;
  }
}
