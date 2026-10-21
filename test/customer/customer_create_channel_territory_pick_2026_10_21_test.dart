import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/features/customer/data/utils/customer_payload_helper.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_meta_entity.dart';
import 'package:vthm_dms/features/customer/presentation/screens/add_customer_screen.dart';

/// Màn tạo điểm bán: hai ô Kênh / Tuyến tự khai chọn tuỳ ý toàn danh mục, điền sẵn theo phòng (chốt 21/10/2026).
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

  test('có phòng ⇒ toàn danh mục, điền sẵn mặc định theo phòng', () {
    final meta = CustomerMetaData.fromJson(metaJson({
      'pairs': null,
      'default_channel_ids': [4],
      'default_territory_code': 'MN2',
    }));
    final fields = ownChannelTerritoryFields(meta, schema: kScopeFieldStubs);
    expect(fields.map((f) => f.code), ['own_channel_ids', 'territory_code']);
    expect(fields[0].type, DynamicFormFieldType.multipleChoice);
    expect(fields[0].options.map((o) => o.value), [1, 4, 7]);
    expect(fields[0].initialValue, [4]);
    expect(fields[1].options.map((o) => o.value), ['MB1', 'MN2']);
    expect(fields[1].initialValue, 'MN2');
  });

  test('không thuộc phòng nào ⇒ toàn danh mục, hai ô trống, chọn được (không khoá)', () {
    final rong = CustomerMetaData.fromJson(metaJson({'pairs': null, 'default_channel_ids': [], 'default_territory_code': null}));
    final f = ownChannelTerritoryFields(rong, schema: kScopeFieldStubs);
    expect(f[0].options.map((o) => o.value), [1, 4, 7]);
    expect(f[0].initialValue, isEmpty);
    expect(f[1].options.map((o) => o.value), ['MB1', 'MN2']);
    expect(f[1].initialValue, isNull);
    expect(f.any((x) => x.isReadOnly), isFalse);
  });

  test('chưa có createChoices (chưa tải được danh mục) ⇒ vẫn hiện hai ô nhưng KHOÁ + ghi chú (server tự gán)', () {
    final f = ownChannelTerritoryFields(CustomerMetaData.fromJson(metaJson(null)), schema: kScopeFieldStubs);
    expect(f.map((x) => x.code), ['own_channel_ids', 'territory_code']);
    expect(f.every((x) => x.isReadOnly && !x.isRequired && x.options.isEmpty && x.initialValue == null), isTrue);
  });

  test('meta lưu máy giữ nguyên createChoices qua toJson/fromJson', () {
    final meta = CustomerMetaData.fromJson(metaJson({
      'pairs': null,
      'default_channel_ids': [4],
      'default_territory_code': 'MN2',
    }));
    final back = CustomerMetaData.fromJson(meta.toJson());
    expect(back.createChoices?.defaultTerritoryCode, 'MN2');
    expect(back.createChoices?.defaultChannelIds, [4]);
    expect(back.salesChannels.length, 3);
    expect(back.territories.map((t) => t.code), ['MB1', 'MN2']);
  });

  test('nhãn / bắt buộc / ẩn theo dòng cấu hình trong schema (ô cứng ở Cấu hình trường điểm bán)', () {
    final meta = CustomerMetaData.fromJson(metaJson({
      'pairs': null,
      'default_channel_ids': [4],
      'default_territory_code': 'MN2',
    }));
    final f = ownChannelTerritoryFields(meta, schema: const [
      DynamicFormField(code: 'territory_code', label: 'Tuyến bán hàng', type: DynamicFormFieldType.singleChoice, isRequired: true),
    ]);
    expect(f.map((x) => x.code), ['territory_code'], reason: 'admin ẩn Kênh ⇒ schema không gửi ⇒ không vẽ');
    expect(f.single.label, 'Tuyến bán hàng');
    expect(f.single.isRequired, isTrue);
    expect(f.single.options.map((o) => o.value), ['MB1', 'MN2'], reason: 'lựa chọn = toàn danh mục, không theo schema');
    expect(ownChannelTerritoryFields(meta, schema: const []), isEmpty, reason: 'ẩn cả hai / server cũ');
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
