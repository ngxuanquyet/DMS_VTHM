import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_meta_entity.dart';
import 'package:vthm_dms/features/customer/presentation/screens/add_customer_screen.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/domain/services/dynamic_rule_evaluator.dart';

/// Bắt buộc THEO ĐIỀU KIỆN (`required_if`, #25067, 10/11/2026): ô luôn hiện, chỉ đòi điền khi điều kiện đúng — cùng luật
/// server `FormValidator::conditionallyRequiredCodes()`: ô ẩn không đòi (đọc rỗng), ô chỉ đọc không đòi, `null` = không.
void main() {
  Map<String, dynamic> schema(List<Map<String, dynamic>> extra) => {
        'data': {
          'scope_fields': true,
          'fields': [
            {'code': 'name', 'label': 'Tên điểm bán', 'input_type': 'text', 'kind': 'fixed'},
            {'code': 'customer_type_id', 'label': 'Loại', 'input_type': 'select', 'kind': 'fixed'},
            ...extra,
          ],
        },
      };
  const routes = [DynamicFormOption(label: 'Tuyến A', value: 5)];
  List<DynamicFormField> build(Map<String, dynamic> s) =>
      buildCustomerFormFields(s, meta: const CustomerMetaData(), routeOptions: routes, defaultRouteId: 5);

  final dong = [
    {'code': 'mw_quy_mo', 'label': 'Quy mô', 'input_type': 'select', 'kind': 'dynamic', 'options': ['nho', 'lon']},
    {
      'code': 'mw_sdt_chu',
      'label': 'SĐT chủ',
      'input_type': 'text',
      'kind': 'dynamic',
      'required_if': {
        'any': [
          {'field': 'mw_quy_mo', 'op': '=', 'value': 'lon'},
          {'field': '@customer.type_id', 'op': 'in', 'value': [3]},
        ],
      },
    },
  ];

  test('đòi khi điều kiện đúng (ô động hoặc @customer), không đòi khi sai; schema cũ không có khoá ⇒ rỗng', () {
    final f = build(schema(dong));
    expect(f.firstWhere((x) => x.code == 'mw_sdt_chu').requiredIf, isNotNull);
    expect(customerRequiredIfCodes(f, {'mw_quy_mo': 'lon'}), {'mw_sdt_chu'});
    expect(customerRequiredIfCodes(f, {'mw_quy_mo': 'nho', 'customer_type_id': 3}), {'mw_sdt_chu'});
    expect(customerRequiredIfCodes(f, {'mw_quy_mo': 'nho', 'customer_type_id': 1}), isEmpty);
    expect(customerRequiredIfCodes(build(schema([dong.first])), {'mw_quy_mo': 'lon'}), isEmpty);
  });

  test('ô đang ẩn và ô chỉ đọc không bao giờ bắt buộc theo điều kiện', () {
    final an = [
      dong.first,
      {...dong[1], 'show_if': {'field': 'mw_quy_mo', 'op': '=', 'value': 'nho'}},
    ];
    expect(customerRequiredIfCodes(build(schema(an)), {'mw_quy_mo': 'lon'}), isEmpty);
    final chiDoc = [dong.first, {...dong[1], 'read_only': true}];
    expect(customerRequiredIfCodes(build(schema(chiDoc)), {'mw_quy_mo': 'lon'}), isEmpty);
     final congThuc = [
      dong.first,
      {...dong[1], 'input_type': 'formula', 'config': {'formula': '1'}},
    ];
    expect(customerRequiredIfCodes(build(schema(congThuc)), {'mw_quy_mo': 'lon'}), isEmpty, reason: 'ô công thức không có *');
  });

  test('biểu mẫu thị trường: computeRequiredOf — điều kiện null KHÔNG phải luôn đúng; ô ẩn đọc rỗng', () {
    MarketFormBlockEntity khoi(String code, {dynamic requiredIf}) => MarketFormBlockEntity(
          ref: code,
          type: 'field',
          required: false,
          requiredIf: requiredIf,
          resolved: MarketFormResolvedEntity(code: code, label: code, inputType: 'text'),
        );
    final blocks = [
      khoi('a'),
      khoi('b', requiredIf: {'field': 'a', 'op': 'not_empty'}),
    ];
    Set<String> req(Map<String, dynamic> ans, Map<String, bool> vis) => DynamicRuleEvaluator.computeRequiredOf<MarketFormBlockEntity>(
          items: blocks,
          requiredIfOf: (b) => b.requiredIf,
          keysOf: (b) => [b.resolved.code, b.ref],
          visibility: vis,
          answers: ans,
        );
    expect(req({'a': 'x'}, const {}), {'b'});
    expect(req({}, const {}), isEmpty);
    expect(req({'a': 'x'}, const {'a': false}), isEmpty, reason: 'ô a ẩn ⇒ đọc rỗng');
    expect(req({'a': 'x'}, const {'b': false}), isEmpty, reason: 'ô b ẩn ⇒ không đòi');
  });

  testWidgets('form điểm bán: dấu * + lỗi bắt buộc chỉ khi điều kiện đúng', (tester) async {
    final f = build(schema(dong));
    final key = GlobalKey<DynamicFormBuilderState>();
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFormBuilder(
            key: key,
            fields: f,
            keepFieldOrder: true,
            initialData: const {'name': 'A', 'mw_quy_mo': 'nho'},
            hiddenFieldsOf: (data) => customerHiddenFieldCodes(f, data),
            requiredFieldsOf: (data) => customerRequiredIfCodes(f, data),
          ),
        ),
      ),
    )));
    await tester.pumpAndSettle();

    key.currentState!.validate(focusFirstError: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('SĐT chủ là bắt buộc'), findsNothing);

    key.currentState!.updateFieldValue('mw_quy_mo', 'lon');
    await tester.pumpAndSettle();
    key.currentState!.validate(focusFirstError: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('SĐT chủ là bắt buộc'), findsOneWidget);

    // Điều kiện thôi đúng ⇒ lỗi đang treo của ô đó tự gỡ (không chờ bấm Lưu lần nữa).
    key.currentState!.updateFieldValue('mw_quy_mo', 'nho');
    await tester.pumpAndSettle();
    expect(find.textContaining('SĐT chủ là bắt buộc'), findsNothing);
    key.currentState!.updateFieldValue('mw_quy_mo', 'lon');
    await tester.pumpAndSettle();
    key.currentState!.updateFieldValue('mw_sdt_chu', '0909');
    await tester.pumpAndSettle();
    key.currentState!.validate(focusFirstError: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('SĐT chủ là bắt buộc'), findsNothing);
  });
}
