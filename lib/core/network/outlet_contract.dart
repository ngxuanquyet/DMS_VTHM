/// Hợp đồng API ĐIỂM BÁN mới (One #25946 bước 2 — tài liệu `docs/reference/internal-api/API-DIEM-BAN-OUTLET-2026-11-26.md`
/// của repo One).
///
/// Trên dây: đường `/dms/outlets*` thay `/crm/customers*`, mọi khoá `customer…` của điểm bán thành `outlet…`
/// (`customer_id` → `outlet_id`, `customer_type_id` → `outlet_type_id`, `customerTypes` → `outletTypes`…). Máy chủ chỉ đổi
/// tên khi app gửi header [header] = `1` (route dùng chung `/dms/visits*`, `/dms/forms*`, `/dms/form-submissions*`,
/// `/dms/routes*`) hoặc gọi đường mới. Route KHÁC (`/dms/travel*`, `/dms/mobile-rules`…) giữ tên cũ dù có header.
///
/// Trong app vẫn gọi là `customer` (lớp, bảng máy, hàng đợi) — chỉ đổi ở ranh giới gửi/nhận:
/// * Đọc phản hồi: [read] lấy tên mới, lùi về tên cũ (bộ đệm máy / hàng đợi ghi từ bản trước còn tên cũ).
/// * Gửi lên route điểm bán: [toWire] đổi khoá tầng trên cùng `customer…` → `outlet…`.
/// * Schema biểu mẫu điểm bán: [internalFieldCode] đưa mã ô cứng mới về mã app đang dùng.
abstract final class OutletContract {
  /// Header bật hợp đồng mới trên route dùng chung — gửi MỌI request (route ngoài điểm bán bỏ qua).
  static const String header = 'X-Outlet-Contract';

  /// Header số build app — máy chủ đo ai còn dùng hợp đồng cũ (cổng gỡ đường cũ).
  static const String buildHeader = 'X-App-Build';

  /// Đọc trường điểm bán `outlet<suffix>`, lùi về `customer<suffix>` (vd `read(json, '_id')`).
  static dynamic read(Map json, String suffix) => json['outlet$suffix'] ?? json['customer$suffix'];

  /// Mã ô cứng trong schema `/dms/outlet-form/schema` (tên mới) → mã app đang dùng nội bộ.
  static const Map<String, String> _fieldCodes = {'outlet_type_id': 'customer_type_id', 'outlet_type': 'customer_type'};

  /// Đưa mã ô / mã danh mục CỨNG của schema về tên nội bộ; mã ô động giữ nguyên.
  static String internalFieldCode(String code) => _fieldCodes[code] ?? code;

  /// Payload gửi route điểm bán: đổi khoá TẦNG TRÊN CÙNG `customer…` → `outlet…` (bên trong `data`/`answers` là mã ô
  /// biểu mẫu, giữ nguyên). Có cả hai tên thì giữ tên mới — máy chủ từ chối (422) hai tên khác giá trị.
  /// Dùng cho payload dựng mới lẫn payload hàng đợi ngoại tuyến ghi từ bản trước.
  static Map<String, dynamic> toWire(Map<String, dynamic> payload) {
    final out = <String, dynamic>{};
    payload.forEach((key, value) {
      final renamed = _wireKey(key);
      if (renamed != key && payload.containsKey(renamed)) return; // đã có tên mới
      out[renamed] = value;
    });
    return out;
  }

  static final RegExp _legacyKey = RegExp(r'^customer(s?)(_[a-z0-9_]+|[A-Z][A-Za-z0-9]*)?$');

  static String _wireKey(String key) {
    final m = _legacyKey.firstMatch(key);
    return m == null ? key : 'outlet${m.group(1) ?? ''}${m.group(2) ?? ''}';
  }
}
