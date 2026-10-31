import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_meta_entity.dart';
import 'package:vthm_dms/features/customer/presentation/screens/add_customer_screen.dart';

/// Form THÊM/SỬA điểm bán có ô CÔNG THỨC (31/10/2026): schema `GET /crm/customer-form/schema` gửi khoá `formula`
/// `{expr, format, decimals}`; ô chỉ đọc, tự tính lại ngay khi ô tham chiếu đổi, không gửi lên.
void main() {
  Map<String, dynamic> schema(List<Map<String, dynamic>> extra) => {
        'data': {
          'scope_fields': true,
          'fields': [
            {'code': 'name', 'label': 'Tên điểm bán', 'input_type': 'text', 'kind': 'fixed', 'formula': null},
            ...extra,
          ],
        },
      };
  const routes = [DynamicFormOption(label: 'Tuyến A', value: 5)];
  List<DynamicFormField> build(Map<String, dynamic> s) =>
      buildCustomerFormFields(s, meta: const CustomerMetaData(), routeOptions: routes, defaultRouteId: 5);

  final dong = [
    {'code': 'so_luong', 'label': 'Số lượng', 'input_type': 'number', 'kind': 'dynamic', 'formula': null},
    {'code': 'gia_tri', 'label': 'Giá trị', 'input_type': 'number', 'kind': 'dynamic', 'formula': null},
    {
      'code': 'thanh_tien',
      'label': 'Thành tiền',
      'input_type': 'formula',
      'kind': 'dynamic',
      'formula': {'expr': 'so_luong * gia_tri', 'format': 'currency', 'decimals': 0},
    },
    {
      'code': 'gom_vat',
      'label': 'Gồm VAT',
      'input_type': 'formula',
      'kind': 'dynamic',
      'formula': {'expr': 'thanh_tien * 1.1', 'format': 'number', 'decimals': 2},
    },
    {
      'code': 'ghi_chu_don_lon',
      'label': 'Ghi chú đơn lớn',
      'input_type': 'text',
      'kind': 'dynamic',
      'show_if': {'field': 'thanh_tien', 'op': '>=', 'value': 100},
    },
  ];

  test('schema đọc khoá formula; server cũ / bản lưu máy không có khoá ⇒ không có ô công thức', () {
    final f = build(schema(dong));
    final tt = f.firstWhere((x) => x.code == 'thanh_tien');
    expect(tt.type, DynamicFormFieldType.formula);
    expect([tt.formula!.expr, tt.formula!.format, tt.formula!.decimals], ['so_luong * gia_tri', 'currency', 0]);
    expect(f.firstWhere((x) => x.code == 'so_luong').formula, isNull);

    final cu = build(schema([
      {'code': 'so_luong', 'label': 'Số lượng', 'input_type': 'number', 'kind': 'dynamic'},
    ]));
    expect(cu.any((x) => x.type == DynamicFormFieldType.formula), isFalse);
    expect(customerFormulaValues(cu, {'so_luong': 3}), isEmpty);
  });

  test('customerFormRules: công thức theo thứ tự, ô sau dùng kết quả trong show_if', () {
    final f = build(schema(dong));
    final r = customerFormRules(f, {'so_luong': 5, 'gia_tri': 6});
    expect(r.formulas['thanh_tien'], 30);
    expect(r.formulas['gom_vat'], closeTo(33, 1e-9));
    expect(r.hidden, {'ghi_chu_don_lon'});
    expect(customerHiddenFieldCodes(f, {'so_luong': 5, 'gia_tri': 60}), isEmpty);
    expect(customerFormulaValues(f, {'so_luong': 5}), {'thanh_tien': null, 'gom_vat': null});
  });

  testWidgets('gõ vào ô số ⇒ ô công thức cập nhật ngay; ô công thức không có trong dữ liệu gửi', (tester) async {
    final f = build(schema(dong));
    final key = GlobalKey<DynamicFormBuilderState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFormBuilder(
            key: key,
            fields: f,
            keepFieldOrder: true,
            initialData: const {'thanh_tien': 999},
            hiddenFieldsOf: (data) => customerHiddenFieldCodes(f, data),
            formulaValuesOf: (data) => customerFormulaValues(f, data),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    String giaTriCongThuc(int i) =>
        (tester.widgetList<Text>(find.byKey(const ValueKey('formula-value'))).elementAt(i)).data!;

    expect(find.byKey(const ValueKey('formula-value')), findsNWidgets(2));
    expect(giaTriCongThuc(0), '—'); // ô tham chiếu còn trống ⇒ rỗng (không coi là 0)

    Finder oNhap(String nhan) => find.descendant(
          of: find.ancestor(of: find.text(nhan), matching: find.byType(Column)).first,
          matching: find.byType(TextField),
        );
    await tester.enterText(oNhap('Số lượng'), '5');
    await tester.pump();
    expect(giaTriCongThuc(0), '—');

    await tester.enterText(oNhap('Giá trị'), '6');
    await tester.pump();
    expect(giaTriCongThuc(0), '30 đ');
    expect(giaTriCongThuc(1), '33,00');
    expect(find.text('Ghi chú đơn lớn'), findsNothing);

    await tester.enterText(oNhap('Giá trị'), '60000');
    await tester.pump();
    expect(giaTriCongThuc(0), '300.000 đ');
    expect(giaTriCongThuc(1), '330.000,00');
    expect(find.textContaining('Ghi chú đơn lớn'), findsOneWidget);

    final gui = key.currentState!.getFormData();
    expect(gui.containsKey('thanh_tien'), isFalse);
    expect(gui.containsKey('gom_vat'), isFalse);
    expect(gui['so_luong'], 5);
  });

  testWidgets('không truyền formulaValuesOf ⇒ form tự tính theo thứ tự ô', (tester) async {
    final f = build(schema(dong));
    final key = GlobalKey<DynamicFormBuilderState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFormBuilder(key: key, fields: f, keepFieldOrder: true),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    key.currentState!.updateFieldValue('so_luong', 5);
    key.currentState!.updateFieldValue('gia_tri', 6);
    await tester.pump();
    expect(key.currentState!.formulaValues, {'thanh_tien': 30, 'gom_vat': closeTo(33, 1e-9)});
    expect(find.text('30 đ'), findsOneWidget);
  });
}
