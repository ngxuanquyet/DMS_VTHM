import 'package:vthm_dms/core/services/erp_link_request_service.dart';

/// Service nối khách ERP GIẢ cho test màn hình (#24327): mục "Khách hàng ERP" trên màn sửa gọi API khi mở — trả trạng thái rỗng
/// ngay, không chạm mạng (gọi thật thì để lại hẹn giờ ⇒ test đỏ "A Timer is still pending").
class FakeErpLinkRequestService implements ErpLinkRequestService {
  @override
  Future<ErpLinkStateOfStore> stateOf(int customerId) async =>
      const ErpLinkStateOfStore(links: [], pending: [], unknown: false);

  @override
  Future<List<ErpLinkSuggestion>> suggest({String? name, String? phone, String? taxCode, String? address}) async => const [];

  @override
  Future<void> propose({required int customerId, required String erpPartnerCode, required String role, String? matchReason}) async {}
}
