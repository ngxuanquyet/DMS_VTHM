import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/features/customer/data/utils/customer_payload_helper.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_meta_entity.dart';
import 'package:vthm_dms/features/customer/presentation/screens/add_customer_screen.dart';

/// Màn tạo điểm bán: hai ô Kênh / Tuyến tự khai chọn trong cặp phòng người đăng nhập (chốt 21/10/2026).
void main() {
  Map<String, dynamic> metaJson(Object? createChoices) => {
        'data': {
          'salesChannels': [
            {'id': 1, 'code': 'KPP', 'name': 'Kênh phân phối'},
            {'id': 4, 'code': 'KBL', 'name': 'Kênh bán lẻ'},
            {'id': 7, 'code': 'KDA', 'name': 'Kênh dự án'},
          ],
          'territories': [
            {'code': 'MB1', 'name': 'Miền Bắc 1'},
            {'code': 'MN2', 'name': 'Miền Nam 2'},
          ],
          if (createChoices != null) 'createChoices': createChoices,
        },
      };

  test('cặp phòng cụ thể ⇒ chỉ kênh/tuyến của phòng, điền sẵn mặc định', () {
    final meta = CustomerMetaData.fromJson(metaJson({
      'pairs': [
        {'channel_id': 4, 'territory_code': 'MN2'},
      ],
      'default_channel_ids': [4],
      'default_territory_code': 'MN2',
    }));
    final fields = ownChannelTerritoryFields(meta);
    expect(fields.map((f) => f.code), ['own_channel_ids', 'territory_code']);
    expect(fields[0].type, DynamicFormFieldType.multipleChoice);
    expect(fields[0].options.map((o) => o.value), [4]);
    expect(fields[0].initialValue, [4]);
    expect(fields[1].options.map((o) => o.value), ['MN2']);
    expect(fields[1].initialValue, 'MN2');
  });

  test('cặp "toàn kênh" ⇒ mọi tuyến; toàn quyền (pairs null) ⇒ mọi kênh', () {
    final toanKenh = CustomerMetaData.fromJson(metaJson({
      'pairs': [
        {'channel_id': 7, 'territory_code': null},
      ],
      'default_channel_ids': [7],
      'default_territory_code': null,
    }));
    final f1 = ownChannelTerritoryFields(toanKenh);
    expect(f1[0].options.map((o) => o.value), [7]);
    expect(f1[1].options.map((o) => o.value), ['MB1', 'MN2']);
    expect(f1[1].initialValue, isNull);

    final admin = CustomerMetaData.fromJson(metaJson({'pairs': null, 'default_channel_ids': [], 'default_territory_code': null}));
    expect(ownChannelTerritoryFields(admin)[0].options.map((o) => o.value), [1, 4, 7]);
  });

  test('không cặp nào / server cũ chưa trả createChoices ⇒ không vẽ ô (server tự gán)', () {
    final rong = CustomerMetaData.fromJson(metaJson({'pairs': [], 'default_channel_ids': [], 'default_territory_code': null}));
    expect(ownChannelTerritoryFields(rong), isEmpty);
    expect(ownChannelTerritoryFields(CustomerMetaData.fromJson(metaJson(null))), isEmpty);
  });

  test('meta lưu máy giữ nguyên createChoices qua toJson/fromJson', () {
    final meta = CustomerMetaData.fromJson(metaJson({
      'pairs': [
        {'channel_id': 4, 'territory_code': 'MN2'},
      ],
      'default_channel_ids': [4],
      'default_territory_code': 'MN2',
    }));
    final back = CustomerMetaData.fromJson(meta.toJson());
    expect(back.createChoices?.pairs?.single.territoryCode, 'MN2');
    expect(back.createChoices?.defaultChannelIds, [4]);
    expect(back.salesChannels.length, 3);
    expect(back.territories.map((t) => t.code), ['MB1', 'MN2']);
  });

  test('allows(): cùng luật khớp cặp server; bộ trùng mặc định luôn qua (phòng nhiều tuyến)', () {
    const nhieuTuyen = CustomerCreateChoices(
      pairs: [CustomerScopePair(channelId: 4, territoryCode: 'MB1'), CustomerScopePair(channelId: 4, territoryCode: 'MB2')],
      defaultChannelIds: [4],
    );
    expect(nhieuTuyen.allows([4], null), isTrue, reason: 'bộ mặc định (kênh của phòng, tuyến trống) — server tự gán y vậy');
    expect(nhieuTuyen.allows([4], 'MB2'), isTrue);
    expect(nhieuTuyen.allows([4], 'MN2'), isFalse);

    const tron = CustomerCreateChoices(
      pairs: [CustomerScopePair(channelId: 4, territoryCode: 'MB1'), CustomerScopePair(channelId: 7)],
      defaultChannelIds: [4, 7],
      defaultTerritoryCode: 'MB1',
    );
    expect(tron.allows([4, 7], 'MB2'), isFalse, reason: 'KBL chỉ ở MB1 ⇒ cả bộ bị chặn');
    expect(tron.allows([7], 'MB2'), isTrue, reason: 'KDA toàn kênh ⇒ mọi tuyến');
    expect(tron.allows([], 'MB1'), isTrue);
    expect(tron.allows([4], null), isTrue, reason: 'tuyến trống ⇒ server thay tuyến mặc định MB1 trước khi kiểm');
    expect(tron.allows([4], ''), isTrue);
    expect(tron.allows([1], 'MB1'), isFalse, reason: 'kênh ngoài phòng');
    expect(const CustomerCreateChoices(pairs: null).allows([1], 'ZZ'), isTrue, reason: 'toàn quyền');
  });

  test('payload POST /crm/customers mang own_channel_ids + territory_code ở GỐC, không lọt vào data', () {
    final payload = CustomerPayloadHelper.buildCustomerApiPayload(
      sourceData: {
        'name': 'Điểm bán mới',
        'region_id': 1,
        'own_channel_ids': [4, '4'],
        'territory_code': ' MN2 ',
      },
      clientUuid: 'test-uuid-pick',
    );
    expect(payload['own_channel_ids'], [4]);
    expect(payload['territory_code'], 'MN2');
    expect((payload['data'] as Map?)?.containsKey('own_channel_ids') ?? false, isFalse);

    final trong = CustomerPayloadHelper.buildCustomerApiPayload(
      sourceData: {'name': 'Điểm bán mới', 'region_id': 1, 'own_channel_ids': <int>[], 'territory_code': null},
      clientUuid: 'test-uuid-pick-2',
    );
    expect(trong.containsKey('own_channel_ids'), isFalse, reason: 'bỏ trống ⇒ server gán theo phòng');
    expect(trong.containsKey('territory_code'), isFalse);
  });
}
