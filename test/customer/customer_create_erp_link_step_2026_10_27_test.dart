import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/services/erp_catalog_service.dart';
import 'package:vthm_dms/core/services/erp_link_request_service.dart';
import 'package:vthm_dms/features/customer/data/utils/customer_payload_helper.dart';
import 'package:vthm_dms/features/customer/presentation/screens/add_customer_screen.dart';

/// Bước nối khách ERP khi tạo điểm bán (#23709, làm lại #24327): lựa chọn đi KÈM payload tạo (không còn vai — bỏ
/// 05/11/2026); danh mục lưu máy lọc khách theo kênh được nối.
void main() {
  test('payload tạo mang erp_links (không role) + erp_link_unknown ở gốc (không lọt vào data); không có bước nối thì không gửi khoá', () {
    final p = CustomerPayloadHelper.buildCustomerApiPayload(sourceData: {
      'name': 'Cửa hàng A',
      'region_id': 3,
      'erp_links': [
        {'code': ' 01200001 ', 'match_reason': 'manual'},
        {'code': ''},
        // Bản nháp đời cũ trong máy còn `role` — không gửi lên nữa.
        {'code': '01200009', 'role': 'owner', 'match_reason': 'phone'},
      ],
      'erp_link_unknown': false,
    }, clientUuid: '11111111-1111-4111-8111-111111111111');
    expect(p['erp_links'], [
      {'code': '01200001', 'match_reason': 'manual'},
      {'code': '01200009', 'match_reason': 'phone'},
    ]);
    expect(p['erp_link_unknown'], false);
    expect((p['data'] as Map?)?.containsKey('erp_links') ?? false, isFalse);

    final tick = CustomerPayloadHelper.buildCustomerApiPayload(sourceData: {'name': 'B', 'erp_links': [], 'erp_link_unknown': true});
    expect(tick['erp_links'], isEmpty);
    expect(tick['erp_link_unknown'], true);

    final cu = CustomerPayloadHelper.buildCustomerApiPayload(sourceData: {'name': 'C'});
    expect(cu.containsKey('erp_links'), isFalse, reason: 'app đời cũ / luồng khác không gửi ⇒ server không bắt buộc');
    expect(cu.containsKey('erp_link_unknown'), isFalse);
  });

  test('danh mục: kênh rỗng = mọi kênh, tìm không dấu theo tên/mã/địa chỉ, khớp mã đứng đầu', () {
    final c = ErpCatalog.fromJson({
      'channels': [],
      'items': [
        {'code': '02700019', 'name': 'CỬA HÀNG MINH PHÁT', 'address': 'Tây Ninh', 'channel_id': 2},
        {'code': '01380001', 'name': 'NPP Hoàng Long', 'address': 'Hà Nội', 'channel_id': 1},
        {'code': '01380002', 'name': 'Minh Phát Phân Phối', 'address': 'Hải Phòng', 'channel_id': 1},
      ],
    });
    expect(c.allowsChannel(2), isTrue);
    expect(c.allowsChannel(null), isTrue);
    expect(c.search('minh phat').map((i) => i.code), ['01380002', '02700019'], reason: 'khớp đầu tên trước');
    expect(c.search('01380001').first.code, '01380001');
    expect(c.search('ha noi').map((i) => i.code), ['01380001']);
    expect(c.search('m'), isEmpty, reason: 'dưới 2 ký tự');
  });

  test('danh mục mới {channels, items}: chỉ khách thuộc kênh được nối mới tìm/gợi ý được; khứ hồi tệp lưu máy', () {
    final c = ErpCatalog.fromJson({
      'channels': [1, 3],
      'items': [
        {'code': '02700019', 'name': 'CỬA HÀNG MINH PHÁT', 'channel_id': 2},
        {'code': '01380002', 'name': 'Minh Phát Phân Phối', 'channel_id': 1},
        {'code': '01380003', 'name': 'Minh Phát Không Kênh'},
      ],
    });
    expect(c.channels, [1, 3]);
    expect(c.allowsChannel(1), isTrue);
    expect(c.allowsChannel(2), isFalse);
    expect(c.allowsChannel(null), isFalse, reason: 'có danh sách kênh mà khách không rõ kênh ⇒ không nối');
    expect(c.search('minh phat').map((i) => i.code), ['01380002']);
    expect(c.suggestByName('Cửa hàng Minh Phát').map((i) => i.code), ['01380002']);
    expect(c.byCode('02700019'), isNotNull, reason: 'byCode vẫn tra được để hiện tên');
  });

  test('bộ đệm danh mục đời cũ (khoá roles, không có channels) đọc không lỗi ⇒ coi như mọi kênh', () {
    final c = ErpCatalog.fromJson({
      'roles': {'owner': [], 'showroom': [1], 'c2': [1]},
      'items': [
        {'code': 'A', 'name': 'NPP A', 'channel_id': 2},
      ],
    });
    expect(c.channels, isEmpty);
    expect(c.items.map((i) => i.code), ['A']);
    expect(c.search('npp a').map((i) => i.code), ['A']);
    // Khoá lạ / sai kiểu cũng không làm vỡ.
    expect(ErpCatalog.fromJson(const {'channels': 'x', 'items': 'y'}).items, isEmpty);
  });

  test('gợi ý dự phòng trên máy theo tên điểm bán: bỏ từ chung, cần khớp ≥ nửa số từ riêng, nhiều từ khớp xếp trước', () {
    final c = ErpCatalog.fromJson({
      'channels': [],
      'items': [
        {'code': 'A', 'name': 'CỬA HÀNG MINH PHÁT', 'channel_id': 2},
        {'code': 'B', 'name': 'VLXD HUY MINH PHÁT', 'channel_id': 2},
        {'code': 'C', 'name': 'Công ty TNHH Thành Công', 'channel_id': 1},
        {'code': 'D', 'name': 'Cửa hàng Minh Tâm', 'channel_id': 2},
      ],
    });
    expect(c.suggestByName('Cửa hàng VLXD Huy Minh Phát').map((i) => i.code), ['B', 'A'],
        reason: 'B khớp 3 từ riêng, A khớp 2; D chỉ khớp "minh" (< nửa)');
    expect(c.suggestByName('Cửa hàng VLXD'), isEmpty, reason: 'toàn từ chung ⇒ không đoán');
    expect(c.suggestByName(null), isEmpty);
  });

  test('thông báo sau khi tạo nói số đề xuất đã gửi', () {
    expect(addCustomerSuccessMessage(hasPending: false), 'Đã tạo điểm bán và ghi nhận lượt viếng thăm.');
    expect(addCustomerSuccessMessage(hasPending: false, linkProposals: 2), contains('Đã chọn 2 khách hàng để đề xuất nối'));
    expect(addCustomerSuccessMessage(hasPending: true, linkProposals: 2), contains('sẽ được đề xuất nối khi đồng bộ'),
        reason: 'ngoại tuyến chưa gửi gì');
  });

  test('gợi ý đọc đúng khoá server (kể cả kênh), mã giữ nguyên số 0 đầu', () {
    final s = ErpLinkSuggestion.fromJson({
      'code': '01200001',
      'name': 'NPP Minh Phát',
      'address': 'Hà Nội',
      'channel_id': 1,
      'channel_name': 'Kênh phân phối',
      'match_reason': 'phone',
    });
    expect(s.code, '01200001');
    expect(s.channelId, 1);
    expect(s.matchReasonLabel, 'Trùng SĐT');
  });
}
