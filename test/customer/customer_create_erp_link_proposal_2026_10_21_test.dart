import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/services/erp_link_request_service.dart';
import 'package:vthm_dms/features/customer/presentation/screens/add_customer_screen.dart';

/// Dịch vụ giả: ghi lại đề xuất, mã '_LOI' thì ném lỗi như server từ chối.
class _FakeLinkSvc implements ErpLinkRequestService {
  final List<(int, String, String, String?)> sent = [];

  @override
  Future<void> propose({required int customerId, required String erpPartnerCode, required String role, String? matchReason}) async {
    if (erpPartnerCode == '_LOI') throw ApiClientTestError();
    sent.add((customerId, erpPartnerCode, role, matchReason));
  }

  @override
  Future<List<ErpLinkSuggestion>> suggest({String? name, String? phone, String? taxCode, String? address}) async => const [];
}

class ApiClientTestError implements Exception {}

/// #23709: tạo điểm bán ⇒ đề xuất nối khách ERP (chính khách từ gợi ý; C2 / Showroom NV chọn cho khách ở ô khách hàng pháp nhân).
void main() {
  test('khách lấy từ mọi ô ref_erp_partner kèm mã ô; bỏ giá trị ngoại lệ, mã rỗng, mã trùng', () {
    final schema = [
      {'code': 'name', 'input_type': 'text'},
      {'code': 'nha_phan_phoi', 'input_type': 'ref_erp_partner'},
      {'code': 'npp_phu', 'input_type': 'ref_erp_partner'},
    ];
    final picks = erpPartnerPicks(schema, {
      'name': 'Cửa hàng A',
      'nha_phan_phoi': ['01200001', '_:Chưa xác định', '', '01200002'],
      'npp_phu': ['01200001', '01200003'],
    });
    expect(picks, [('nha_phan_phoi', '01200001'), ('nha_phan_phoi', '01200002'), ('npp_phu', '01200003')]);
    expect(erpPartnerPicks(schema, {'nha_phan_phoi': null}), isEmpty);
    expect(erpPartnerPicks(const [], {'nha_phan_phoi': ['01200001']}), isEmpty, reason: 'không có ô ⇒ không đề xuất');
  });

  test('gửi đề xuất: chính khách + vai NV chọn (C2 / Showroom), bỏ trùng mã chính khách, lượt lỗi không làm hỏng lượt khác', () async {
    final svc = _FakeLinkSvc();
    const chinh = ErpLinkSuggestion(code: '01200009', name: 'Cửa hàng A', matchReason: 'phone');
    final n = await guiDeXuatNoiErp(svc, 77, chinh, {
      '01200001': ErpLinkRole.c2,
      '01200002': ErpLinkRole.showroom,
      '01200009': ErpLinkRole.c2,
      '_LOI': ErpLinkRole.c2,
    });
    expect(n, 3);
    expect(svc.sent, containsAll([
      (77, '01200009', ErpLinkRole.owner, 'phone'),
      (77, '01200001', ErpLinkRole.c2, null),
      (77, '01200002', ErpLinkRole.showroom, null),
    ]));
    expect(svc.sent.where((d) => d.$2 == '01200009').length, 1, reason: 'mã chính khách không gửi thêm vai C2');
    expect(await guiDeXuatNoiErp(_FakeLinkSvc(), 77, null, const {}), 0);
  });

  test('khoá gợi ý đổi khi sửa tên/SĐT/MST/địa chỉ, không đổi khi sửa ô khác', () {
    final a = erpSuggestKey({'name': 'Cửa hàng A', 'phone': '0901', 'ghi_chu': 'x'});
    expect(erpSuggestKey({'name': 'Cửa hàng A ', 'phone': '0901', 'ghi_chu': 'y'}), a);
    expect(erpSuggestKey({'name': 'Cửa hàng B', 'phone': '0901'}), isNot(a));
    expect(erpSuggestKey({'name': 'Cửa hàng A', 'phone': '0902'}), isNot(a));
  });

  test('thông báo sau khi tạo nói số đề xuất đã gửi', () {
    expect(addCustomerSuccessMessage(hasPending: false), 'Đã tạo điểm bán và ghi nhận lượt viếng thăm.');
    expect(addCustomerSuccessMessage(hasPending: false, linkProposals: 2), contains('Đã gửi 2 đề xuất nối khách ERP'));
  });

  test('gợi ý đọc đúng khoá server, mã giữ nguyên số 0 đầu', () {
    final s = ErpLinkSuggestion.fromJson({
      'code': '01200001',
      'name': 'NPP Minh Phát',
      'address': 'Hà Nội',
      'channel_name': 'Kênh phân phối',
      'match_reason': 'phone',
    });
    expect(s.code, '01200001');
    expect(s.matchReason, 'phone', reason: 'gửi nguyên mã cho server');
    expect(s.matchReasonLabel, 'Trùng SĐT');
    expect(ErpLinkRole.owner, 'owner');
    expect(ErpLinkRole.c2, 'c2');
    expect(ErpLinkRole.showroom, 'showroom', reason: 'khớp ErpLinkRole::Showroom phía server');
  });
}
