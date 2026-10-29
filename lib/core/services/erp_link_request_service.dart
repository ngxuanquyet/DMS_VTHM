import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';

/// Vai trò của điểm bán với khách ERP trên đề xuất nối — khớp `ErpLinkRole` phía server.
class ErpLinkRole {
  /// Điểm bán CHÍNH LÀ khách ERP đó.
  static const String owner = 'owner';

  /// Điểm bán là đại lý cấp 2 lấy hàng của khách ERP (nhà phân phối).
  static const String c2 = 'c2';

  /// Điểm bán là showroom của khách ERP.
  static const String showroom = 'showroom';

  /// Mọi vai — thứ tự hiện trên nút chọn vai.
  static const List<String> all = [owner, showroom, c2];

  /// Nhãn tiếng Việt của vai.
  static String label(String role) => switch (role) {
        owner => 'Chính khách hàng',
        showroom => 'Showroom',
        c2 => 'Đại lý C2',
        _ => role,
      };
}

/// Một khách ERP trùng/gần trùng với điểm bán đang tạo (`GET /crm/customer-erp-link-requests/suggest`).
/// Server KHÔNG trả SĐT/MST của khách ERP — chỉ mã, tên, địa chỉ, kênh và lý do khớp.
class ErpLinkSuggestion {
  /// Mã khách ERP — CHUỖI, có thể có số 0 đầu.
  final String code;
  final String name;
  final String? address;

  /// Kênh bán hàng Bravo — quyết vai nào chọn được khách này (#24327).
  final int? channelId;
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
    this.channelId,
    this.channelName,
    this.matchReason = '',
  });

  factory ErpLinkSuggestion.fromJson(Map<String, dynamic> json) => ErpLinkSuggestion(
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        address: json['address']?.toString(),
        channelId: (json['channel_id'] as num?)?.toInt(),
        channelName: json['channel_name']?.toString(),
        matchReason: json['match_reason']?.toString() ?? '',
      );
}

/// Loại đề xuất nối — khớp `ErpLinkRequestAction` phía server (#24331).
class ErpLinkAction {
  static const String add = 'add';
  static const String changeRole = 'change_role';
  static const String remove = 'remove';
}

/// Một mối nối (đã duyệt) hoặc một đề xuất (chờ / bị từ chối) của điểm bán — ô "Khách hàng ERP" (#24327, #24331).
class ErpLinkState {
  /// Id đề xuất; `null` với mối nối đã duyệt.
  final int? id;
  final String code;
  final String? name;
  final int? channelId;
  final String? channelName;

  /// Vai SAU khi sửa (gỡ nối: vai đang bị gỡ); với mối nối đã duyệt: vai hiện tại.
  final String role;
  final String roleLabel;

  /// Loại đề xuất ([ErpLinkAction]); `null` với mối nối đã duyệt.
  final String? action;
  final String? actionLabel;

  /// Vai TRƯỚC khi sửa (đổi vai / gỡ nối).
  final String? beforeRole;
  final String? beforeRoleLabel;

  /// Lý do quản lý từ chối.
  final String? decisionNote;

  const ErpLinkState({
    required this.code,
    required this.role,
    required this.roleLabel,
    this.id,
    this.name,
    this.channelId,
    this.channelName,
    this.action,
    this.actionLabel,
    this.beforeRole,
    this.beforeRoleLabel,
    this.decisionNote,
  });

  factory ErpLinkState.fromJson(Map<String, dynamic> json) => ErpLinkState(
        id: (json['id'] as num?)?.toInt(),
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString(),
        channelId: (json['channel_id'] as num?)?.toInt(),
        channelName: json['channel_name']?.toString(),
        role: json['role']?.toString() ?? '',
        roleLabel: json['role_label']?.toString() ?? '',
        action: json['action']?.toString(),
        actionLabel: json['action_label']?.toString(),
        beforeRole: json['before_role']?.toString(),
        beforeRoleLabel: json['before_role_label']?.toString(),
        decisionNote: json['decision_note']?.toString(),
      );
}

/// Trạng thái nối khách ERP của một điểm bán (`GET /crm/customers/{id}`: `erp_links`, `erp_link_pending`, `erp_link_rejected`,
/// `erp_link_unknown`).
class ErpLinkStateOfStore {
  final List<ErpLinkState> links;
  final List<ErpLinkState> pending;
  final List<ErpLinkState> rejected;
  final bool unknown;

  const ErpLinkStateOfStore({required this.links, required this.pending, required this.unknown, this.rejected = const []});

  /// Điểm bán đã có chính khách (mối nối hoặc đề xuất chờ cho ra chính khách) — không thêm vai đó nữa.
  bool get ownerTaken =>
      links.any((l) => l.role == ErpLinkRole.owner) ||
      pending.any((l) => l.action != ErpLinkAction.remove && l.role == ErpLinkRole.owner);

  /// Khách đã nối / đang có đề xuất chờ — không thêm lại, không sửa thêm cho tới khi duyệt xong.
  Set<String> get codes => {...links.map((l) => l.code), ...pending.map((l) => l.code)};
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

  /// Trạng thái nối của một điểm bán đã có trên server.
  Future<ErpLinkStateOfStore> stateOf(int customerId) async {
    final response = await _apiClient.get('/crm/customers/$customerId');
    final data = response is Map && response['data'] is Map ? Map<String, dynamic>.from(response['data'] as Map) : const {};
    List<ErpLinkState> list(dynamic raw) => raw is List
        ? raw.whereType<Map>().map((e) => ErpLinkState.fromJson(Map<String, dynamic>.from(e))).toList()
        : const [];
    return ErpLinkStateOfStore(
      links: list(data['erp_links']),
      pending: list(data['erp_link_pending']),
      rejected: list(data['erp_link_rejected']),
      unknown: data['erp_link_unknown'] == true,
    );
  }

  /// Gửi thay đổi mối nối của một điểm bán đã có (màn chi tiết, #24331) — `PATCH /crm/customers/{id}` chỉ kèm
  /// `erp_link_changes`; mỗi mục thành một đề xuất chờ duyệt. Cần mạng.
  /// @return Số đề xuất server đã ghi.
  Future<int> sendChanges(int customerId, List<Map<String, dynamic>> changes) async {
    final response = await _apiClient.patch('/crm/customers/$customerId', data: {'erp_link_changes': changes});
    final data = response is Map ? response['data'] : null;
    return data is Map ? (data['erp_link_requests'] as num?)?.toInt() ?? 0 : 0;
  }
}
