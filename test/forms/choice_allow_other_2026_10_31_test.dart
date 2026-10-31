import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/choice_other.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_meta_entity.dart';
import 'package:vthm_dms/features/customer/presentation/screens/add_customer_screen.dart';
import 'package:vthm_dms/features/forms/data/models/market_form_model.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';

/// «Cho phép nhập giá trị khác» của ô chọn một / chọn nhiều (chốt 31/10/2026): ô có cờ `allow_other` hiện thêm mục
/// «Khác…»; chuỗi gõ tay (đã trim) đặt THẲNG làm giá trị — chọn nhiều thì tối đa một chuỗi; không bao giờ gửi mã giả.
void main() {
  group('ChoiceOther (hàm thuần)', () {
    test('đọc cờ ở khoá phẳng (schema điểm bán) hoặc config (biểu mẫu thị trường); vắng / false ⇒ tắt', () {
      expect(ChoiceOther.enabledIn({'allow_other': true}), isTrue);
      expect(ChoiceOther.enabledIn({'config': {'allow_other': true}}), isTrue);
      expect(ChoiceOther.enabledIn({'allow_other': false}), isFalse);
      expect(ChoiceOther.enabledIn({'config': {'allow_other': 'true'}}), isFalse);
      expect(ChoiceOther.enabledIn({}), isFalse);
    });

    test('giá trị ngoài danh sách; ghép chọn nhiều giữ tối đa MỘT chuỗi gõ tay', () {
      const opts = ['A', 'B'];
      expect(ChoiceOther.foreignSingle('A', opts), isNull);
      expect(ChoiceOther.foreignSingle('  ', opts), isNull);
      expect(ChoiceOther.foreignSingle('Lạ', opts), 'Lạ');
      expect(ChoiceOther.foreignMulti(['A', 'Lạ', 'Lạ 2'], opts), 'Lạ');
      expect(ChoiceOther.composeMulti(['B', 'Lạ', 'A', 'Lạ 2'], opts, '  Mới '), ['B', 'A', 'Mới']);
      expect(ChoiceOther.composeMulti(['B', 'Lạ'], opts, null), ['B']);
      expect(ChoiceOther.composeMulti(['B'], opts, ''), ['B']);
      // Chữ gõ trùng một lựa chọn (value hoặc nhãn, so chính xác) KHÔNG vào giá trị — muốn chọn thì tự tích.
      expect(ChoiceOther.composeMulti(['B'], opts, 'A'), ['B']);
      expect(ChoiceOther.composeMulti(['B'], opts, 'Nhãn A', optionLabels: ['Nhãn A', 'Nhãn B']), ['B']);
      expect(ChoiceOther.composeMulti(['B'], opts, 'a'), ['B', 'a']);
    });

    test('kiểm khi lưu: bắt buộc mà trống ⇒ lỗi; không bắt buộc mà trống ⇒ hợp lệ; quá 255 ⇒ lỗi', () {
      expect(ChoiceOther.validate(active: true, required: true, other: ' '), ChoiceOther.emptyError);
      expect(ChoiceOther.validate(active: true, required: false, other: ''), isNull);
      expect(ChoiceOther.validate(active: false, required: true, other: null), isNull);
      expect(ChoiceOther.validate(active: true, required: false, other: 'x' * 256), ChoiceOther.tooLongError);
      expect(ChoiceOther.validate(active: true, required: true, other: 'x' * 255), isNull);
    });
  });

  group('Biểu mẫu thị trường (config.allow_other)', () {
    MarketFormBlockEntity o(String code, String type,
            {bool allowOther = true, bool required = false, List<String> opts = const ['Có', 'Không']}) =>
        MarketFormBlockEntity(
          ref: code,
          type: 'field',
          required: required,
          resolved: MarketFormResolvedEntity(
            code: code,
            label: 'Ô $code',
            inputType: type,
            config: {'allow_other': allowOther},
            options: [for (final v in opts) MarketFormOptionEntity(value: v, label: v)],
          ),
        );

    Future<GlobalKey<MarketFormRendererState>> dung(
      WidgetTester tester,
      List<MarketFormBlockEntity> blocks, {
      Map<String, dynamic> initial = const {},
      List<Map<String, dynamic>>? changes,
    }) async {
      final key = GlobalKey<MarketFormRendererState>();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarketFormRenderer(
              key: key,
              blocks: blocks,
              initialAnswers: initial,
              onChanged: changes == null ? null : (a) => changes.add(Map<String, dynamic>.from(a)),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return key;
    }

    test('schema: cờ trong config (Map hoặc chuỗi JSON) chỉ có hiệu lực khi ô có lựa chọn', () {
      MarketFormResolvedEntity doc(dynamic config) => MarketFormBlockModel.fromJson({
            'ref': 'a',
            'resolved': {'code': 'a', 'label': 'A', 'input_type': 'select', 'config': config},
          }).toEntity().resolved;
      const x = {'value': 'x', 'label': 'x'};
      expect(doc({'options': [x], 'allow_other': true}).allowOther, isTrue);
      expect(doc('{"options":[{"value":"x","label":"x"}],"allow_other":true}').allowOther, isTrue);
      expect(doc({'options': [x]}).allowOther, isFalse);
      expect(doc({'allow_other': true}).allowOther, isFalse);
    });

    testWidgets('ô KHÔNG có cờ ⇒ không có «Khác…»', (tester) async {
      await dung(tester, [o('r', 'radio', allowOther: false), o('m', 'multiselect', allowOther: false)]);
      expect(find.text(ChoiceOther.label), findsNothing);
    });

    testWidgets('nháp cũ có giá trị ngoài danh sách ⇒ chọn sẵn «Khác…» + điền chuỗi; gửi lại nguyên chuỗi', (tester) async {
      final key = await dung(tester, [o('r', 'radio'), o('c', 'checkbox')], initial: {
        'r': 'Ý kiến riêng',
        'c': ['Có', 'Hàng lạ'],
      });
      expect(find.widgetWithText(TextField, 'Ý kiến riêng'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Hàng lạ'), findsOneWidget);
      final radioKhac = tester.widget<RadioListTile<String>>(find.widgetWithText(RadioListTile<String>, ChoiceOther.label));
      // ignore: deprecated_member_use
      expect(radioKhac.value, radioKhac.groupValue); // đang chọn
      expect(tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, ChoiceOther.label)).value, isTrue);
      expect(key.currentState!.validateAndGetAnswers(), {
        'r': 'Ý kiến riêng',
        'c': ['Có', 'Hàng lạ'],
      });
    });

    testWidgets('chọn «Khác…» rồi gõ ⇒ chọn một gửi chuỗi đã trim, chọn nhiều gửi lựa chọn + một chuỗi; không lộ mã giả',
        (tester) async {
      final changes = <Map<String, dynamic>>[];
      final key = await dung(tester, [o('r', 'radio'), o('m', 'multiselect')], changes: changes);

      await tester.tap(find.widgetWithText(RadioListTile<String>, ChoiceOther.label));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '  Tự gõ  ');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilterChip, 'Không'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, ChoiceOther.label));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Thêm ');
      await tester.pump();

      expect(key.currentState!.validateAndGetAnswers(), {
        'r': 'Tự gõ',
        'm': ['Không', 'Thêm'],
      });
      expect(changes.toString().contains(ChoiceOther.key), isFalse);

      // Bỏ «Khác…» ở ô chọn nhiều ⇒ bỏ luôn chuỗi gõ tay; chọn lựa chọn thường ở ô chọn một ⇒ thay chuỗi gõ.
      await tester.tap(find.widgetWithText(FilterChip, ChoiceOther.label));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(RadioListTile<String>, 'Có'));
      await tester.pumpAndSettle();
      expect(key.currentState!.validateAndGetAnswers(), {
        'r': 'Có',
        'm': ['Không'],
      });
    });

    testWidgets('chọn nhiều: gõ dần qua đúng một lựa chọn ("Siêu thị" → "Siêu thị mini") ⇒ KHÔNG tự tích lựa chọn đó',
        (tester) async {
      final changes = <Map<String, dynamic>>[];
      final key = await dung(tester, [o('m', 'multiselect', opts: ['Siêu thị', 'Tạp hoá'])], changes: changes);
      await tester.tap(find.widgetWithText(FilterChip, ChoiceOther.label));
      await tester.pumpAndSettle();
      for (final t in ['Siêu', 'Siêu thị', 'Siêu thị ', 'Siêu thị mini']) {
        await tester.enterText(find.byType(TextField).last, t);
        await tester.pump();
      }
      expect(changes.any((a) => (a['m'] as List?)?.contains('Siêu thị') == true), isFalse);
      expect(key.currentState!.validateAndGetAnswers(), {
        'm': ['Siêu thị mini'],
      });
    });

    testWidgets('chọn «Khác…» để trống: bắt buộc ⇒ lỗi; không bắt buộc ⇒ coi như không chọn', (tester) async {
      final key = await dung(tester, [o('r', 'select', required: true), o('c', 'checkbox')]);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ChoiceOther.label).last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, ChoiceOther.label));
      await tester.pumpAndSettle();

      expect(key.currentState!.validateAndGetAnswers(), isNull);
      await tester.pump();
      expect(find.text(ChoiceOther.emptyError), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Gõ tay');
      await tester.pump();
      final a = key.currentState!.validateAndGetAnswers();
      expect(a?['r'], 'Gõ tay');
      expect(a?.containsKey('c') == true ? a!['c'] : const [], isEmpty);
    });
  });

  group('Form điểm bán (khoá phẳng allow_other)', () {
    Map<String, dynamic> schema(List<Map<String, dynamic>> extra) => {
          'data': {
            'scope_fields': true,
            'fields': [
              {'code': 'name', 'label': 'Tên điểm bán', 'input_type': 'text', 'kind': 'fixed'},
              ...extra,
            ],
          },
        };
    List<DynamicFormField> build(List<Map<String, dynamic>> extra) => buildCustomerFormFields(schema(extra),
        meta: const CustomerMetaData(), routeOptions: const [DynamicFormOption(label: 'Tuyến A', value: 5)]);
    Map<String, dynamic> o(String code, String type, {bool allowOther = true, bool required = false}) => {
          'code': code,
          'label': 'Ô $code',
          'input_type': type,
          'kind': 'dynamic',
          'required': required,
          'options': ['Có', 'Không'],
          if (allowOther) 'allow_other': true,
        };

    /// Chỉ dựng các ô động đang thử (ô cứng bắt buộc của form điểm bán không liên quan).
    Future<GlobalKey<DynamicFormBuilderState>> dung(WidgetTester tester, List<DynamicFormField> all,
        {Map<String, dynamic> initial = const {}}) async {
      final f = all.where((x) => x.code.startsWith('mw_')).toList();
      final key = GlobalKey<DynamicFormBuilderState>();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicFormBuilder(key: key, fields: f, keepFieldOrder: true, initialData: initial),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return key;
    }

    test('schema: khoá phẳng allow_other (hoặc config.allow_other) đi qua buildCustomerFormFields', () {
      final f = build([
        o('mw_a', 'select'),
        o('mw_b', 'multiselect', allowOther: false),
        {...o('mw_c', 'radio', allowOther: false), 'config': {'allow_other': true}},
      ]);
      bool co(String c) => f.firstWhere((x) => x.code == c).allowOther;
      expect([co('mw_a'), co('mw_b'), co('mw_c')], [true, false, true]);
    });

    testWidgets('ô KHÔNG có cờ ⇒ không có «Khác…»', (tester) async {
      await dung(tester, build([o('mw_a', 'select', allowOther: false), o('mw_b', 'checkbox', allowOther: false)]));
      expect(find.text(ChoiceOther.label), findsNothing);
    });

    testWidgets('bản ghi cũ có giá trị ngoài danh sách ⇒ chọn sẵn «Khác…» + điền chuỗi', (tester) async {
      final key = await dung(tester, build([o('mw_a', 'select'), o('mw_b', 'multiselect')]), initial: {
        'mw_a': 'Giá trị cũ',
        'mw_b': ['Có', 'Hàng lạ'],
      });
      expect(find.widgetWithText(TextField, 'Giá trị cũ'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Hàng lạ'), findsOneWidget);
      final ok = key.currentState!.validate(focusFirstError: false);
      expect(ok, isTrue);
      final d = key.currentState!.getFormData();
      expect(d['mw_a'], 'Giá trị cũ');
      expect(d['mw_b'], ['Có', 'Hàng lạ']);
    });

    testWidgets('chọn nhiều: gõ dần qua đúng một lựa chọn ("Có" → "Có hàng") ⇒ KHÔNG tự tích lựa chọn đó',
        (tester) async {
      final key = await dung(tester, build([o('mw_b', 'multiselect')]));
      await tester.tap(find.text(ChoiceOther.label));
      await tester.pumpAndSettle();
      final seen = <dynamic>[];
      for (final t in ['C', 'Có', 'Có ', 'Có hàng']) {
        await tester.enterText(find.byType(TextField).last, t);
        await tester.pump();
        seen.add(List.of(key.currentState!.getFormData()['mw_b'] as List));
      }
      expect(seen, [
        ['C'],
        <dynamic>[],
        <dynamic>[],
        ['Có hàng'],
      ]);
      expect(key.currentState!.validate(focusFirstError: false), isTrue);
      expect(key.currentState!.getFormData()['mw_b'], ['Có hàng']);
    });

    testWidgets('chọn «Khác…» rồi gõ ⇒ giá trị THẬT đã trim; bắt buộc mà trống ⇒ lỗi', (tester) async {
      final key = await dung(tester, build([o('mw_a', 'radio', required: true), o('mw_b', 'checkbox')]));

      await tester.tap(find.text(ChoiceOther.label).first);
      await tester.pumpAndSettle();
      expect(key.currentState!.validate(focusFirstError: false), isFalse);
      await tester.pump();
      expect(find.text(ChoiceOther.emptyError), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, '  Tự gõ ');
      await tester.pump();
      await tester.tap(find.text('Không').last);
      await tester.tap(find.text(ChoiceOther.label).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Thêm');
      await tester.pumpAndSettle();

      expect(key.currentState!.validate(focusFirstError: false), isTrue);
      final d = key.currentState!.getFormData();
      expect(d['mw_a'], 'Tự gõ');
      expect(d['mw_b'], ['Không', 'Thêm']);
      expect(d.toString().contains(ChoiceOther.key), isFalse);

      // Chọn lựa chọn thường ⇒ bỏ «Khác…», ô gõ biến mất.
      await tester.tap(find.text('Có').first);
      await tester.pumpAndSettle();
      expect(key.currentState!.getFormData()['mw_a'], 'Có');
      expect(find.widgetWithText(TextField, 'Tự gõ'), findsNothing);
    });
  });
}
