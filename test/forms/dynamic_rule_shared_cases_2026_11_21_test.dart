import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
    expect(DynamicRuleEvaluator.isListType('multiselect'), isTrue);
    expect(DynamicRuleEvaluator.isListType('checkbox'), isFalse);
    expect(DynamicRuleEvaluator.isListType('checkbox', hasOptions: true), isTrue);
    expect(DynamicRuleEvaluator.isListType('ref_customer', multiple: true), isTrue);
    expect(DynamicRuleEvaluator.isListType('select', hasOptions: true), isFalse);
  });
}
