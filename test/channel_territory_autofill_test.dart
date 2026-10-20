import 'package:flutter_test/flutter_test.dart';

import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/features/customer/data/utils/customer_payload_helper.dart';
import 'package:vthm_dms/features/forms/domain/services/dynamic_rule_evaluator.dart';

/// #23819 (tự điền Kênh/Tuyến theo phòng ban) + #23682 (Kênh/Tuyến Bravo thay kênh MobiWork cũ) — phía app.
void main() {
  group('#23819 giá trị điền sẵn từ schema', () {
    test('DynamicFormField đọc khoá `default` vào defaultValue, KHÔNG vào initialValue', () {
      final f = DynamicFormField.fromJson({
        'code': 'dms_tuyen',
        'label': 'Tuyến',
        'input_type': 'select',
        'catalog': 'sales_territory',
        'options': [
          {'value': 'MN2', 'label': 'MN2'},
          {'value': '_ALL', 'label': 'Toàn kênh'},
        ],
        'default': 'MN2',
      });
      expect(f.defaultValue, 'MN2');
      // initialValue để trống: màn SỬA dùng chung builder, không được tự điền vào điểm bán đã có.
      expect(f.initialValue, isNull);
      expect(f.copyWith(label: 'x').defaultValue, 'MN2', reason: 'copyWith phải giữ defaultValue');
    });

    test('ô chọn nhiều: default là MẢNG', () {
      final f = DynamicFormField.fromJson({
        'code': 'dms_kenh',
        'label': 'Kênh',
        'input_type': 'multiselect',
        'catalog': 'sales_channel',
        'default': [1],
      });
      expect(f.defaultValue, [1]);
    });

    test('không có default ⇒ null', () {
      final f = DynamicFormField.fromJson({'code': 'x', 'label': 'X', 'input_type': 'select'});
      expect(f.defaultValue, isNull);
    });
  });

  group('#23682 kênh MobiWork cũ', () {
    test('channel_id KHÔNG còn trong danh sách khoá gửi lên', () {
      expect(kAllowedCustomerRootKeys.contains('channel_id'), isFalse);
      expect(kCustomerFixedKeys.contains('channel_id'), isFalse);
    });

    test('dữ liệu nguồn có channel_id ⇒ payload KHÔNG mang nó, kể cả trong `data` (agy review 20/10)', () {
      final payload = CustomerPayloadHelper.buildCustomerApiPayload(sourceData: {
        'name': 'Điểm bán thử',
        'region_id': 1,
        'channel_id': 8,
        'dms_ghi_chu': 'x',
      });
      expect(payload.containsKey('channel_id'), isFalse);
      final data = payload['data'] as Map? ?? const {};
      expect(data.containsKey('channel_id'), isFalse, reason: 'không được lọt vào ô động');
      expect(data['dms_ghi_chu'], 'x', reason: 'ô động thật vẫn đi');
    });

    test('điều kiện trên @customer.channel_ids / territory_codes (mảng) đánh giá như server', () {
      final ctx = {
        '@customer': {
          'channel_ids': [1, 4],
          'territory_codes': ['MN2'],
        },
      };
      dynamic read(String p) => DynamicRuleEvaluator.readPath(ctx, p);
      expect(DynamicRuleEvaluator.evalRule({'field': '@customer.channel_ids', 'op': 'in', 'value': [4, 9]}, read), isTrue);
      expect(DynamicRuleEvaluator.evalRule({'field': '@customer.channel_ids', 'op': 'not_in', 'value': [2]}, read), isTrue);
      expect(DynamicRuleEvaluator.evalRule({'field': '@customer.territory_codes', 'op': 'contains', 'value': 'MN2'}, read), isTrue);
      expect(DynamicRuleEvaluator.evalRule({'field': '@customer.territory_codes', 'op': 'contains', 'value': 'MB1'}, read), isFalse);

      final rong = {'@customer': {'channel_ids': <int>[], 'territory_codes': <String>[]}};
      dynamic readRong(String p) => DynamicRuleEvaluator.readPath(rong, p);
      expect(DynamicRuleEvaluator.evalRule({'field': '@customer.channel_ids', 'op': 'is_empty'}, readRong), isTrue);
      expect(DynamicRuleEvaluator.evalRule({'field': '@customer.channel_ids', 'op': 'in', 'value': [1]}, readRong), isFalse);
    });
  });
}
