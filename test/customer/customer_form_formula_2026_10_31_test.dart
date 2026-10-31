import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_meta_entity.dart';
import 'package:vthm_dms/features/customer/presentation/screens/add_customer_screen.dart';

/// Form THÊM/SỬA điểm bán có ô CÔNG THỨC (31/10/2026): schema `GET /crm/customer-form/schema` gửi khoá `formula`
/// `{expr, format, decimals, blank}`; ô chỉ đọc, tự tính lại ngay khi ô tham chiếu đổi, không gửi lên. Tính như server:
/// trên TOÀN BỘ giá trị (kể cả ô ẩn, giá trị đang lưu), số đã làm tròn mới đem dùng tiếp.
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
      'formula': {'expr': 'so_luong * gia_tri', 'format': 'currency', 'decimals': 0, 'blank': true},
    },
    {
      'code': 'gom_vat',
      'label': 'Gồm VAT',
      'input_type': 'formula',
      'kind': 'dynamic',
      'formula': {'expr': 'thanh_tien * 1.1', 'format': 'number', 'decimals': 2, 'blank': true},
    },
    {
      'code': 'ghi_chu_don_lon',
      'label': 'Ghi chú đơn lớn',
      'input_type': 'text',
      'kind': 'dynamic',
      'show_if': {'field': 'thanh_tien', 'op': '>=', 'value': 100},
    },
  ];

  Widget khung(DynamicFormBuilder form) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: form)));

  test('schema đọc khoá formula (cả cờ blank); server cũ / bản lưu máy không có khoá ⇒ không có ô công thức', () {
    final f = build(schema(dong));
    final tt = f.firstWhere((x) => x.code == 'thanh_tien');
    expect(tt.type, DynamicFormFieldType.formula);
    expect([tt.formula!.expr, tt.formula!.format, tt.formula!.decimals, tt.formula!.blankIfMissing],
        ['so_luong * gia_tri', 'currency', 0, true]);
    expect(f.firstWhere((x) => x.code == 'so_luong').formula, isNull);

    final cu = build(schema([
      {'code': 'so_luong', 'label': 'Số lượng', 'input_type': 'number', 'kind': 'dynamic'},
    ]));
    expect(cu.any((x) => x.type == DynamicFormFieldType.formula), isFalse);
  });

  testWidgets('gõ vào ô số ⇒ ô công thức cập nhật ngay; show_if so với số đã tính; ô công thức không gửi lên',
      (tester) async {
    final f = build(schema(dong));
    final key = GlobalKey<DynamicFormBuilderState>();
    await tester.pumpWidget(khung(DynamicFormBuilder(
      key: key,
      fields: f,
      keepFieldOrder: true,
      initialData: const {'thanh_tien': 999},
      hiddenFieldsOf: (data) => customerHiddenFieldCodes(f, data),
    )));
    await tester.pumpAndSettle();

    String giaTriCongThuc(int i) =>
        (tester.widgetList<Text>(find.byKey(const ValueKey('formula-value'))).elementAt(i)).data!;

    expect(find.byKey(const ValueKey('formula-value')), findsNWidgets(2));
    expect(giaTriCongThuc(0), '—'); // blank = true: ô tham chiếu còn trống ⇒ rỗng

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
    expect(find.textContaining('Ghi chú đơn lớn'), findsNothing);

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

  testWidgets('mục 1: show_if và công thức sau đọc số ĐÃ làm tròn', (tester) async {
    final f = build(schema([
      {'code': 'x', 'label': 'X', 'input_type': 'number', 'kind': 'dynamic'},
      {'code': 'a', 'label': 'A', 'input_type': 'formula', 'kind': 'dynamic', 'formula': {'expr': 'x / 3', 'decimals': 2}},
      {'code': 'b', 'label': 'B', 'input_type': 'formula', 'kind': 'dynamic', 'formula': {'expr': 'a * 3', 'decimals': 2}},
      {
        'code': 'chi_hien_khi_du_10',
        'label': 'Chỉ hiện khi B đủ 10',
        'input_type': 'text',
        'kind': 'dynamic',
        'show_if': {'field': 'b', 'op': '>=', 'value': 10},
      },
    ]));
    final key = GlobalKey<DynamicFormBuilderState>();
    await tester.pumpWidget(khung(DynamicFormBuilder(
      key: key,
      fields: f,
      keepFieldOrder: true,
      initialData: const {'x': 10},
      hiddenFieldsOf: (data) => customerHiddenFieldCodes(f, data),
    )));
    await tester.pumpAndSettle();
    expect(key.currentState!.formulaValues['b'], closeTo(9.99, 1e-9)); // server: 3.33 × 3 = 9.99, không phải 10
    expect(find.text('9,99'), findsOneWidget);
    expect(key.currentState!.hiddenFieldCodes, {'chi_hien_khi_du_10'});
  });

  testWidgets('mục 2: ô ẩn vẫn mang giá trị cho công thức; màn sửa đọc giá trị đang lưu của ô không có trên form',
      (tester) async {
    final f = build(schema([
      {'code': 'co_gia', 'label': 'Có giá', 'input_type': 'select', 'kind': 'dynamic', 'options': ['co', 'khong']},
      {
        'code': 'gia',
        'label': 'Giá',
        'input_type': 'number',
        'kind': 'dynamic',
        'show_if': {'field': 'co_gia', 'op': '=', 'value': 'co'},
      },
      {
        'code': 'tong',
        'label': 'Tổng',
        'input_type': 'formula',
        'kind': 'dynamic',
        'formula': {'expr': 'gia * he_so_luu', 'decimals': 0, 'blank': true},
        // Ô công thức bị ẩn vẫn có giá trị
        'show_if': {'field': 'co_gia', 'op': '=', 'value': 'co'},
      },
    ]));
    final key = GlobalKey<DynamicFormBuilderState>();
    await tester.pumpWidget(khung(DynamicFormBuilder(
      key: key,
      fields: f,
      keepFieldOrder: true,
      initialData: const {'co_gia': 'khong', 'gia': 7},
      // `he_so_luu` là ô động đang lưu của điểm bán nhưng không có trên form
      formulaBaseData: const {'he_so_luu': 3, 'gia': 1},
      hiddenFieldsOf: (data) => customerHiddenFieldCodes(f, data),
    )));
    await tester.pumpAndSettle();
    expect(key.currentState!.hiddenFieldCodes, containsAll(['gia', 'tong']));
    expect(key.currentState!.formulaValues['tong'], 21); // giá trị trên form (7) đè nền (1); ô ẩn vẫn được đọc
  });
}
