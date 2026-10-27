import 'package:vthm_dms/core/services/erp_link_request_service.dart';

/// Service nối khách ERP GIẢ cho test màn hình (#24327): mục "Khách hàng ERP" trên màn sửa gọi API khi mở — trả trạng thái rỗng
/// ngay, không chạm mạng (gọi thật thì để lại hẹn giờ ⇒ test đỏ "A Timer is still pending").
class FakeErpLinkRequestService implements ErpLinkRequestService {
  /// Trạng thái trả về cho mọi điểm bán (mặc định rỗng).
  ErpLinkStateOfStore state;

  /// Các lượt `sendChanges` đã nhận.
  final List<List<Map<String, dynamic>>> sent = [];

  FakeErpLinkRequestService({this.state = const ErpLinkStateOfStore(links: [], pending: [], unknown: false)});

  @override
  Future<ErpLinkStateOfStore> stateOf(int customerId) async => state;

  @override
  Future<int> sendChanges(int customerId, List<Map<String, dynamic>> changes) async {
    sent.add(changes);
    return changes.length;
  }

  @override
  Future<List<ErpLinkSuggestion>> suggest({String? name, String? phone, String? taxCode, String? address}) async => const [];
}
