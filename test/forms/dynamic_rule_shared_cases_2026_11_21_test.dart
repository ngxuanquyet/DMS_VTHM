import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/list_field.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/domain/services/dynamic_rule_evaluator.dart';

/// #24038: bảng ca CHUNG với server `RuleEvaluator` và SPA `dynamicRule.ts` — chép từ repo One
/// `vn.vthmgroup.one/src/lib/dynamicRule.cases.json` (sửa luật ở một phía ⇒ chép lại file này, các phía cùng đỏ/xanh).
void main() {
  final data = jsonDecode(File('test/fixtures/dynamicRule.cases.json').readAsStringSync()) as Map<String, dynamic>;
  for (final c in (data['cases'] as List).cast<Map<String, dynamic>>()) {
    test(c['name'], () {
      final vars = Map<String, dynamic>.from(c['vars'] as Map);
      final lists = {for (final x in c['lists'] as List) '$x'};
      expect(DynamicRuleEvaluator.evalRule(c['rule'], (f) => vars[f], lists), c['expect']);
    });
  }

  test('ô chọn nhiều của biểu mẫu thị trường đọc như danh sách', () {
    expect(isListFieldType('multiselect'), isTrue);
    expect(isListFieldType('checkbox'), isFalse);
    expect(isListFieldType('checkbox', hasOptions: true), isTrue);
    expect(isListFieldType('ref_customer', multiple: true), isTrue);
    expect(isListFieldType('select', hasOptions: true), isFalse);
  });

  test('review vòng 1: between đúng 2 phần tử; so thứ tự chỉ số–số hoặc chuỗi–chuỗi (như RuleEvaluator::compare)', () {
    bool e(Map r, dynamic v, [Set<String> l = const {}]) => DynamicRuleEvaluator.evalRule(r, (_) => v, l);
    expect(e({'field': 'x', 'op': 'between', 'value': [1, 10, 99]}, 5), isFalse);
    expect(e({'field': 'x', 'op': 'between', 'value': [1, 10]}, 5), isTrue);
    expect(e({'field': 'x', 'op': '>', 'value': 'a'}, ['b'], {'x'}), isFalse);
    expect(e({'field': 'x', 'op': '>=', 'value': 'false'}, true), isFalse);
    expect(e({'field': 'x', 'op': '>', 'value': '2026-01-01'}, '2026-02-01'), isTrue);
  });

  test('review vòng 1: isListValued theo !empty() của server', () {
    MarketFormResolvedEntity f(String t, Map c) => MarketFormResolvedEntity(code: 'x', label: 'x', inputType: t, config: c);
    expect(f('ref_customer', {'multiple': 1}).isListValued, isTrue);
    expect(f('checkbox', {'catalog': false}).isListValued, isFalse);
    expect(f('checkbox', {'catalog': 'brand'}).isListValued, isTrue);
  });
}
