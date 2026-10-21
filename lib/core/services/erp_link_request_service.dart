import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';

/// Vai trò của điểm bán với khách ERP trên đề xuất nối — khớp `ErpLinkRole` phía server.
class ErpLinkRole {
  /// Điểm bán CHÍNH LÀ khách ERP đó.
  static const String owner = 'owner';

  /// Điểm bán là đại lý cấp 2 lấy hàng của khách ERP (nhà phân phối).
  static const String c2 = 'c2';
}

/// Một khách ERP trùng/gần trùng với điểm bán đang tạo (`GET /crm/customer-erp-link-requests/suggest`).
/// Server KHÔNG trả SĐT/MST của khách ERP — chỉ mã, tên, địa chỉ, kênh và lý do khớp.
class ErpLinkSuggestion {
  /// Mã khách ERP — CHUỖI, có thể có số 0 đầu.
  final String code;
  final String name;
  final String? address;
  final String? channelName;

  /// MÃ lý do khớp (`phone` · `tax_code` · `name_address`) — gửi NGUYÊN mã kèm đề xuất (server chỉ nhận đúng các mã
  /// này); hiển thị qua [matchReasonLabel].
  final String matchReason;

  /// Nhãn tiếng Việt của [matchReason].
  String get matchReasonLabel => switch (matchReason) {
        'phone' => 'Trùng SĐT',
        'tax_code' => 'Trùng mã số thuế',
        'name_address' => 'Tên / địa chỉ gần giống',
        _ => '',
      };

  const ErpLinkSuggestion({
    required this.code,
    required this.name,
    this.address,
    this.channelName,
    this.matchReason = '',
  });

  factory ErpLinkSuggestion.fromJson(Map<String, dynamic> json) => ErpLinkSuggestion(
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        address: json['address']?.toString(),
        channelName: json['channel_name']?.toString(),
        matchReason: json['match_reason']?.toString() ?? '',
      );
}

final erpLinkRequestServiceProvider = Provider<ErpLinkRequestService>((ref) {
  return ErpLinkRequestService(ref.watch(apiClientProvider));
});

/// Gợi ý + đề xuất nối điểm bán mới ↔ khách ERP (#23709, chốt 21/10/2026). Đề xuất chỉ có hiệu lực khi quản lý DUYỆT
/// trên web. Chỉ dùng khi CÓ MẠNG — mất mạng thì bỏ qua (quản lý nối sau), không xếp hàng đồng bộ.
class ErpLinkRequestService {
  final ApiClient _apiClient;

  ErpLinkRequestService(this._apiClient);

  /// Khách ERP khớp theo SĐT / MST trước, rồi tên (+ địa chỉ) gần giống.
  Future<List<ErpLinkSuggestion>> suggest({
    String? name,
    String? phone,
    String? taxCode,
    String? address,
  }) async {
    String? sach(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
    final params = {
      if (sach(name) != null) 'name': sach(name),
      if (sach(phone) != null) 'phone': sach(phone),
      if (sach(taxCode) != null) 'tax_code': sach(taxCode),
      if (sach(address) != null) 'address': sach(address),
    };
    if (params.isEmpty) return const [];
    final response = await _apiClient.get('/crm/customer-erp-link-requests/suggest', queryParameters: params);
    final data = response is Map ? response['data'] : null;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => ErpLinkSuggestion.fromJson(Map<String, dynamic>.from(e)))
        .where((s) => s.code.isNotEmpty)
        .toList();
  }

  /// Gửi một đề xuất nối (chờ quản lý duyệt).
  Future<void> propose({
    required int customerId,
    required String erpPartnerCode,
    required String role,
    String? matchReason,
  }) async {
    await _apiClient.post('/crm/customer-erp-link-requests', data: {
      'customer_id': customerId,
      'erp_partner_code': erpPartnerCode,
      'role': role,
      if (matchReason != null && matchReason.isNotEmpty) 'match_reason': matchReason,
    });
  }
}
