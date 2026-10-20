import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/customer/data/models/customer_dto.dart';
import 'package:vthm_dms/features/customer/data/utils/customer_payload_helper.dart';
import 'package:vthm_dms/features/forms/presentation/screens/market_form_fill_screen.dart';

void main() {
  group('Spec 20/10/2026 - Kênh và Tuyến điểm bán theo Bravo', () {
    test('§1.2: Phân tích JSON mẫu thật từ API GET /crm/customers/mine', () {
      final sampleJson3108 = {
        'id': 3108,
        'code': '02950076',
        'name': 'Đại lý 3108',
        'address': 'Địa chỉ 3108',
        'phone': '0900000001',
        'erp_linked': true,
        'erp_channels': [
          {'id': 4, 'code': 'KBL', 'name': 'Kênh bán lẻ'}
        ],
        'territories': ['MN2'],
        'territory_code': 'MN2',
        'own_channel_ids': [4]
      };

      final sampleJson1132 = {
        'id': 1132,
        'code': '08660056',
        'name': 'Đại lý 1132',
        'address': 'Địa chỉ 1132',
        'phone': '0900000002',
        'erp_linked': false,
        'erp_channels': [
          {'id': 1, 'code': 'KPP', 'name': 'Kênh phân phối'},
          {'id': 4, 'code': 'KBL', 'name': 'Kênh bán lẻ'}
        ],
        'territories': ['MN2'],
        'territory_code': 'MN2',
        'own_channel_ids': [1, 4],
        'channel_id': 8,
        'channel_name': 'MN2, CN Cần Thơ'
      };

      final sampleJson1895 = {
        'id': 1895,
        'code': '08880188',
        'name': 'Đại lý 1895',
        'address': 'Địa chỉ 1895',
        'phone': '0900000003',
        'erp_linked': false,
        'erp_channels': [
          {'id': 6, 'code': 'KNB', 'name': 'Kênh nội bộ'}
        ],
        'territories': <String>[],
        'territory_code': null,
        'own_channel_ids': [6]
      };

      final dto3108 = CustomerDto.fromJson(sampleJson3108);
      final entity3108 = dto3108.toEntity();
      expect(entity3108.erpLinked, isTrue);
      expect(entity3108.erpChannels.length, 1);
      expect(entity3108.erpChannels.first.code, 'KBL');
      expect(entity3108.territories, ['MN2']);
      expect(entity3108.channelTerritoryDisplay, 'KBL · MN2');

      final dto1132 = CustomerDto.fromJson(sampleJson1132);
      final entity1132 = dto1132.toEntity();
      expect(entity1132.erpLinked, isFalse);
      expect(entity1132.erpChannels.length, 2);
      expect(entity1132.erpChannels.map((c) => c.code).toList(), ['KPP', 'KBL']);
      expect(entity1132.territories, ['MN2']);
      expect(entity1132.channelTerritoryDisplay, 'KPP, KBL · MN2');

      final dto1895 = CustomerDto.fromJson(sampleJson1895);
      final entity1895 = dto1895.toEntity();
      expect(entity1895.erpLinked, isFalse);
      expect(entity1895.erpChannels.length, 1);
      expect(entity1895.erpChannels.first.code, 'KNB');
      expect(entity1895.territories, isEmpty);
      // Mảng territories rỗng => chỉ hiện kênh, không có dấu · thừa
      expect(entity1895.channelTerritoryDisplay, 'KNB');
    });

    test('§2: Dựng đúng ngữ cảnh @customer.channel_ids và @customer.territory_codes', () {
      final context = MarketFormFillArgs.buildCustomerContext(
        typeId: 2,
        channelIds: [1, 4],
        territoryCodes: ['MN2'],
        regionId: 8,
        groupId: 3,
      );

      final customerMap = context['@customer'] as Map<String, dynamic>;
      expect(customerMap.containsKey('channel_id'), isFalse);
      expect(customerMap['channel_ids'], [1, 4]);
      expect(customerMap['territory_codes'], ['MN2']);
      expect(customerMap['type_id'], 2);
      expect(customerMap['region_id'], 8);
      expect(customerMap['group_id'], 3);

      // Khi không truyền channelIds và territoryCodes thì mặc định là mảng rỗng []
      final defaultContext = MarketFormFillArgs.buildCustomerContext();
      final defaultMap = defaultContext['@customer'] as Map<String, dynamic>;
      expect(defaultMap['channel_ids'], isEmpty);
      expect(defaultMap['territory_codes'], isEmpty);
    });

    test('§3: CustomerPayloadHelper không gửi channel_id lên server', () {
      final payload = CustomerPayloadHelper.buildCustomerApiPayload(
        sourceData: {
          'name': 'Điểm bán mới',
          'phone': '0912345678',
          'address': 'Hà Nội',
          'region_id': 1,
          'customer_type_id': 2,
          'channel_id': 8, // Kênh MobiWork cũ do form cũ hoặc dữ liệu cũ gửi vào
        },
        clientUuid: 'test-uuid-channel',
      );

      expect(payload.containsKey('channel_id'), isFalse, reason: 'channel_id phải bị loại bỏ hoàn toàn theo §3');
    });
  });
}
