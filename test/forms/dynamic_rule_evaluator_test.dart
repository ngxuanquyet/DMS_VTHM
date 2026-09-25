import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/domain/services/dynamic_rule_evaluator.dart';

void main() {
  group('DynamicRuleEvaluator - Cây điều kiện và Cú pháp', () {
    test('null, vắng mặt, hoặc {} trả về true (luôn hiện)', () {
      expect(DynamicRuleEvaluator.evalRule(null, (_) => null), isTrue);
      expect(DynamicRuleEvaluator.evalRule({}, (_) => null), isTrue);
    });

    test('Mảng tuần tự không có all/any là AND ngầm', () {
      final answers = {'a': 1, 'b': 2};
      dynamic read(String path) => answers[path];

      final ruleSuccess = [
        {'field': 'a', 'op': '=', 'value': 1},
        {'field': 'b', 'op': '=', 'value': 2},
      ];
      expect(DynamicRuleEvaluator.evalRule(ruleSuccess, read), isTrue);

      final ruleFail = [
        {'field': 'a', 'op': '=', 'value': 1},
        {'field': 'b', 'op': '=', 'value': 99},
      ];
      expect(DynamicRuleEvaluator.evalRule(ruleFail, read), isFalse);
    });

    test('all (AND): mọi nhánh con phải đúng', () {
      final answers = {'role': 'admin', 'level': 3};
      dynamic read(String path) => answers[path];

      final ruleTrue = {
        'all': [
          {'field': 'role', 'op': '=', 'value': 'admin'},
          {'field': 'level', 'op': '>=', 'value': 2},
        ]
      };
      expect(DynamicRuleEvaluator.evalRule(ruleTrue, read), isTrue);

      final ruleFalse = {
        'all': [
          {'field': 'role', 'op': '=', 'value': 'admin'},
          {'field': 'level', 'op': '>', 'value': 5},
        ]
      };
      expect(DynamicRuleEvaluator.evalRule(ruleFalse, read), isFalse);
    });

    test('any (OR): chỉ cần một nhánh đúng', () {
      final answers = {'status': 'B'};
      dynamic read(String path) => answers[path];

      final ruleTrue = {
        'any': [
          {'field': 'status', 'op': '=', 'value': 'A'},
          {'field': 'status', 'op': '=', 'value': 'B'},
        ]
      };
      expect(DynamicRuleEvaluator.evalRule(ruleTrue, read), isTrue);

      final ruleFalse = {
        'any': [
          {'field': 'status', 'op': '=', 'value': 'X'},
          {'field': 'status', 'op': '=', 'value': 'Y'},
        ]
      };
      expect(DynamicRuleEvaluator.evalRule(ruleFalse, read), isFalse);
    });
  });

  group('DynamicRuleEvaluator - Bốn luật so sánh (§2)', () {
    test('Luật 1: 0, "0", false KHÔNG phải rỗng', () {
      expect(DynamicRuleEvaluator.isEmptyValue(0), isFalse);
      expect(DynamicRuleEvaluator.isEmptyValue('0'), isFalse);
      expect(DynamicRuleEvaluator.isEmptyValue(false), isFalse);
      expect(DynamicRuleEvaluator.isEmptyValue(true), isFalse);

      // Những thứ này mới là rỗng
      expect(DynamicRuleEvaluator.isEmptyValue(null), isTrue);
      expect(DynamicRuleEvaluator.isEmptyValue(''), isTrue);
      expect(DynamicRuleEvaluator.isEmptyValue('   '), isTrue);
      expect(DynamicRuleEvaluator.isEmptyValue([]), isTrue);
      expect(DynamicRuleEvaluator.isEmptyValue({}), isTrue);
    });

    test('Luật 2: So bằng nới lỏng kiểu số <-> chuỗi ("2" và 2 bằng nhau)', () {
      expect(DynamicRuleEvaluator.looseEquals('2', 2), isTrue);
      expect(DynamicRuleEvaluator.looseEquals(2, '2'), isTrue);
      expect(DynamicRuleEvaluator.looseEquals('02', 2), isTrue);
      expect(DynamicRuleEvaluator.looseEquals(2.0, 2), isTrue);
      expect(DynamicRuleEvaluator.looseEquals('A', 'A'), isTrue);
      expect(DynamicRuleEvaluator.looseEquals('A', 'B'), isFalse);
    });

    test('Luật 2: So thứ tự ưu tiên số; không phải số thì so chuỗi ISO', () {
      expect(DynamicRuleEvaluator.compareOrder('10', 2)! > 0, isTrue); // số: 10 > 2
      expect(DynamicRuleEvaluator.compareOrder('2026-09-25', '2026-09-23')! > 0, isTrue);
      expect(DynamicRuleEvaluator.compareOrder('2026-01-01', '2026-09-25')! < 0, isTrue);
    });

    test('Luật 3: op lạ, thiếu field, hoặc object rỗng không all/any/field trả false, không ném lỗi', () {
      final answers = {'foo': 'bar'};
      dynamic read(String path) => answers[path];

      // op lạ
      expect(DynamicRuleEvaluator.evalRule({'field': 'foo', 'op': 'unknown_op', 'value': 1}, read), isFalse);
      // thiếu field
      expect(DynamicRuleEvaluator.evalRule({'op': '=', 'value': 1}, read), isFalse);
      // object không có all/any/field
      expect(DynamicRuleEvaluator.evalRule({'random_key': 123}, read), isFalse);
    });

    test('Luật 4: Biến không tồn tại => RỖNG (null), không gây lỗi', () {
      dynamic read(String path) => null;

      expect(DynamicRuleEvaluator.evalRule({'field': 'non_existent', 'op': 'is_empty'}, read), isTrue);
      expect(DynamicRuleEvaluator.evalRule({'field': 'non_existent', 'op': 'not_empty'}, read), isFalse);
      expect(DynamicRuleEvaluator.evalRule({'field': 'non_existent', 'op': '=', 'value': 'something'}, read), isFalse);
    });
  });

  group('DynamicRuleEvaluator - Toán tử chi tiết (§2)', () {
    test('in & not_in với mảng và nới lỏng số-chuỗi', () {
      dynamic read(String path) => 2;

      final ruleIn = {'field': 'type', 'op': 'in', 'value': ['1', '2', '3']};
      expect(DynamicRuleEvaluator.evalRule(ruleIn, read), isTrue);

      final ruleNotIn = {'field': 'type', 'op': 'not_in', 'value': ['4', '5']};
      expect(DynamicRuleEvaluator.evalRule(ruleNotIn, read), isTrue);

      final ruleInFail = {'field': 'type', 'op': 'in', 'value': ['4', '5']};
      expect(DynamicRuleEvaluator.evalRule(ruleInFail, read), isFalse);
    });

    test('contains cho chuỗi và cho mảng', () {
      // Chuỗi chứa
      expect(DynamicRuleEvaluator.evalRule({'field': 's', 'op': 'contains', 'value': 'apple'}, (_) => 'green apple tree'), isTrue);
      expect(DynamicRuleEvaluator.evalRule({'field': 's', 'op': 'contains', 'value': 'banana'}, (_) => 'green apple tree'), isFalse);

      // Mảng chứa phần tử
      expect(DynamicRuleEvaluator.evalRule({'field': 'arr', 'op': 'contains', 'value': 'B'}, (_) => ['A', 'B', 'C']), isTrue);
      expect(DynamicRuleEvaluator.evalRule({'field': 'arr', 'op': 'contains', 'value': 2}, (_) => ['1', '2', '3']), isTrue);
      expect(DynamicRuleEvaluator.evalRule({'field': 'arr', 'op': 'contains', 'value': 'D'}, (_) => ['A', 'B', 'C']), isFalse);
    });

    test('between trong khoảng đóng [a, b]', () {
      expect(DynamicRuleEvaluator.evalRule({'field': 'num', 'op': 'between', 'value': [10, 20]}, (_) => 10), isTrue);
      expect(DynamicRuleEvaluator.evalRule({'field': 'num', 'op': 'between', 'value': [10, 20]}, (_) => 15), isTrue);
      expect(DynamicRuleEvaluator.evalRule({'field': 'num', 'op': 'between', 'value': [10, 20]}, (_) => 20), isTrue);
      expect(DynamicRuleEvaluator.evalRule({'field': 'num', 'op': 'between', 'value': [10, 20]}, (_) => 9), isFalse);
      expect(DynamicRuleEvaluator.evalRule({'field': 'num', 'op': 'between', 'value': [10, 20]}, (_) => 21), isFalse);

      // Between với ngày ISO
      expect(
        DynamicRuleEvaluator.evalRule(
          {'field': 'date', 'op': 'between', 'value': ['2026-09-01', '2026-09-30']},
          (_) => '2026-09-25',
        ),
        isTrue,
      );
    });
  });

  group('DynamicRuleEvaluator - Hiệu ứng dây chuyền ô ẩn đứng trước (§3)', () {
    test('A đổi => B ẩn => B coi như rỗng => C cũng ẩn theo dù B còn dữ liệu', () {
      final blocks = [
        const MarketFormBlockEntity(
          ref: 'A',
          type: 'field',
          required: false,
          colSpan: 12,
          resolved: MarketFormResolvedEntity(code: 'A', label: 'Ô A', inputType: 'select'),
        ),
        const MarketFormBlockEntity(
          ref: 'B',
          type: 'field',
          required: false,
          colSpan: 12,
          showIf: {
            'field': 'A',
            'op': '=',
            'value': 'co',
          },
          resolved: MarketFormResolvedEntity(code: 'B', label: 'Ô B', inputType: 'text'),
        ),
        const MarketFormBlockEntity(
          ref: 'C',
          type: 'field',
          required: false,
          colSpan: 12,
          showIf: {
            'field': 'B',
            'op': 'not_empty',
          },
          resolved: MarketFormResolvedEntity(code: 'C', label: 'Ô C', inputType: 'text'),
        ),
      ];

      // Trường hợp 1: A = 'co', B có dữ liệu 'Hello' => cả B và C đều hiện
      final answers1 = {'A': 'co', 'B': 'Hello'};
      final vis1 = DynamicRuleEvaluator.computeVisibility(blocks: blocks, answers: answers1);
      expect(vis1['A'], isTrue);
      expect(vis1['B'], isTrue);
      expect(vis1['C'], isTrue);

      // Trường hợp 2: Người dùng quay lại đổi A = 'khong', B vẫn còn giá trị 'Hello' trong state
      // B ẩn => B phải coi như rỗng => C cũng phải ẩn theo! (§3)
      final answers2 = {'A': 'khong', 'B': 'Hello'};
      final vis2 = DynamicRuleEvaluator.computeVisibility(blocks: blocks, answers: answers2);
      expect(vis2['A'], isTrue);
      expect(vis2['B'], isFalse);
      expect(vis2['C'], isFalse); // C ẩn vì B đang ẩn (coi như rỗng)
    });
  });

  group('DynamicRuleEvaluator - Ngữ cảnh điểm bán @customer.* (§4)', () {
    test('Dựng đúng và khớp @customer.type_id', () {
      final blocks = [
        const MarketFormBlockEntity(
          ref: 'dms_ton_kho',
          type: 'field',
          required: true,
          colSpan: 12,
          showIf: {
            'all': [
              {
                'field': '@customer.type_id',
                'op': 'in',
                'value': [2]
              }
            ]
          },
          resolved: MarketFormResolvedEntity(code: 'dms_ton_kho', label: 'Tồn kho', inputType: 'number'),
        ),
      ];

      // Khách hàng có type_id = 2 => Tồn kho hiện
      final visCustomer2 = DynamicRuleEvaluator.computeVisibility(
        blocks: blocks,
        answers: {},
        customerContext: {
          '@customer': {
            'type_id': 2,
            'channel_id': 10,
            'region_id': 1,
            'group_id': 3,
          }
        },
      );
      expect(visCustomer2['dms_ton_kho'], isTrue);

      // Khách hàng có type_id = 1 => Tồn kho ẩn
      final visCustomer1 = DynamicRuleEvaluator.computeVisibility(
        blocks: blocks,
        answers: {},
        customerContext: {
          '@customer': {
            'type_id': 1,
            'channel_id': 10,
            'region_id': 1,
            'group_id': 3,
          }
        },
      );
      expect(visCustomer1['dms_ton_kho'], isFalse);

      // Phiếu collect (không có điểm bán) => 4 biến là null => Tồn kho ẩn
      final visNoCustomer = DynamicRuleEvaluator.computeVisibility(
        blocks: blocks,
        answers: {},
        customerContext: {},
      );
      expect(visNoCustomer['dms_ton_kho'], isFalse);
    });
  });
}
