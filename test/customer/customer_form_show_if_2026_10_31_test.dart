import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_meta_entity.dart';
import 'package:vthm_dms/features/customer/presentation/screens/add_customer_screen.dart';

/// Form THÊM/SỬA điểm bán tôn trọng điều kiện hiển thị `show_if` của ô ĐỘNG (31/10/2026) — cùng bộ đánh giá với biểu mẫu
/// thị trường; biến `@customer.*` lấy từ ô cứng Loại / Khu vực / Tỉnh đang nhập.
void main() {
  Map<String, dynamic> schema(List<Map<String, dynamic>> extra) => {
        'data': {
          'scope_fields': true,
          'fields': [
            {'code': 'name', 'label': 'Tên điểm bán', 'input_type': 'text', 'required': true, 'kind': 'fixed', 'show_if': null},
            {'code': 'customer_type_id', 'label': 'Loại', 'input_type': 'select', 'kind': 'fixed', 'show_if': null},
            {'code': 'region_id', 'label': 'Khu vực', 'input_type': 'select', 'kind': 'fixed'},
            ...extra,
          ],
        },
      };
  const routes = [DynamicFormOption(label: 'Tuyến A', value: 5)];
  List<DynamicFormField> build(Map<String, dynamic> s, {CustomerEntity? editing}) =>
      buildCustomerFormFields(s, meta: const CustomerMetaData(), routeOptions: routes, defaultRouteId: 5, editing: editing);

  final dong = [
    {
      'code': 'mw_co_tu',
      'label': 'Có tủ đông',
      'input_type': 'select',
      'kind': 'dynamic',
      'options': ['co', 'khong'],
    },
    {
      'code': 'mw_so_tu',
      'label': 'Số tủ',
      'input_type': 'number',
      'kind': 'dynamic',
      'required': true,
      'show_if': {'field': 'mw_co_tu', 'op': '=', 'value': 'co'},
    },
    {
      'code': 'mw_hang_tu',
      'label': 'Hãng tủ',
      'input_type': 'text',
      'kind': 'dynamic',
      // Phụ thuộc ô ĐỘNG đứng trước (mw_so_tu) ⇒ mw_so_tu ẩn thì ô này ẩn theo tầng.
      'show_if': {
        'all': [
          {'field': 'mw_so_tu', 'op': 'not_empty'},
          {'field': '@customer.type_id', 'op': 'in', 'value': [2, 3]},
        ],
      },
    },
  ];

  test('schema cũ / bản lưu máy không có khoá show_if ⇒ không ô nào ẩn', () {
    final f = build(schema([
      {'code': 'mw_a', 'label': 'A', 'input_type': 'text', 'kind': 'dynamic'},
    ]));
    expect(f.firstWhere((x) => x.code == 'mw_a').showIf, isNull);
    expect(customerHiddenFieldCodes(f, {'mw_a': 'x'}), isEmpty);
  });

  test('ẩn theo giá trị ô động đứng trước + ẩn theo TẦNG + ngữ cảnh @customer.type_id từ ô cứng đang nhập', () {
    final f = build(schema(dong));
    expect(customerHiddenFieldCodes(f, {'mw_co_tu': 'khong', 'mw_so_tu': 3, 'customer_type_id': 2}),
        {'mw_so_tu', 'mw_hang_tu'});
    expect(customerHiddenFieldCodes(f, {'mw_co_tu': 'co', 'mw_so_tu': 3, 'customer_type_id': 2}), isEmpty);
    // Loại đổi sang 7 ⇒ ô hãng tủ ẩn ngay
    expect(customerHiddenFieldCodes(f, {'mw_co_tu': 'co', 'mw_so_tu': 3, 'customer_type_id': 7}), {'mw_hang_tu'});
  });

  test('ô cứng KHÔNG bao giờ bị ẩn kể cả khi schema lỡ gửi show_if', () {
    final f = build(schema([
      {
        'code': 'phone',
        'label': 'SĐT',
        'input_type': 'text',
        'kind': 'fixed',
        'show_if': {'field': 'x', 'op': '=', 'value': 1},
      },
    ]));
    expect(customerHiddenFieldCodes(f, {}), isEmpty);
  });

  test('sửa: ô Khu vực/Tỉnh vắng trên form ⇒ lấy giá trị đang lưu của điểm bán', () {
    final s = {
      'data': {
        'scope_fields': true,
        'fields': [
          {'code': 'name', 'label': 'Tên', 'input_type': 'text', 'kind': 'fixed'},
          {
            'code': 'mw_mien_nam',
            'label': 'Ghi chú miền Nam',
            'input_type': 'text',
            'kind': 'dynamic',
            'show_if': [
              {'field': '@customer.province_id', 'op': '=', 'value': 79},
            ],
          },
        ],
      },
    };
    const c = CustomerEntity(
      id: 1,
      code: 'DMS0800001',
      name: 'Tạp hoá A',
      type: 'Đại lý',
      route: 'Tuyến A',
      address: 'HN',
      phone: '0900000000',
      contactPerson: 'A',
      customerTypeId: 2,
      regionId: 8,
      dynamicFields: {'province_id': 79},
    );
    final f = build(s, editing: c);
    expect(f.any((x) => x.code == 'province_id'), isFalse);
    expect(customerHiddenFieldCodes(f, {'name': 'A'}, editing: c), isEmpty);
    expect(customerHiddenFieldCodes(f, {'name': 'A'}), {'mw_mien_nam'});
  });

  testWidgets('form: ô ẩn không vẽ, miễn bắt buộc, không có trong dữ liệu gửi; đổi giá trị ⇒ hiện lại ngay', (tester) async {
    final f = build(schema(dong));
    final key = GlobalKey<DynamicFormBuilderState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFormBuilder(
            key: key,
            fields: f,
            keepFieldOrder: true,
            initialData: const {'mw_co_tu': 'khong', 'mw_so_tu': 4, 'customer_type_id': 2},
            hiddenFieldsOf: (data) => customerHiddenFieldCodes(f, data),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    bool hienNhan(String nhan) => find
        .byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains(nhan))
        .evaluate()
        .isNotEmpty;

    expect(hienNhan('Số tủ'), isFalse);
    expect(hienNhan('Hãng tủ'), isFalse);
    expect(key.currentState!.getFormData().containsKey('mw_so_tu'), isFalse);
    expect(key.currentState!.getFormData().containsKey('mw_hang_tu'), isFalse);

    key.currentState!.updateFieldValue('mw_co_tu', 'co');
    await tester.pumpAndSettle();
    expect(hienNhan('Số tủ'), isTrue);
    expect(hienNhan('Hãng tủ'), isTrue);
    // Giá trị đã gõ trước khi ẩn vẫn còn khi hiện lại
    expect(key.currentState!.getFormData()['mw_so_tu'], 4);

    // Ô bắt buộc đang HIỆN mà rỗng ⇒ lỗi; ẩn lại ⇒ miễn
    key.currentState!.updateFieldValue('mw_so_tu', null);
    await tester.pumpAndSettle();
    key.currentState!.validate(focusFirstError: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('Số tủ là bắt buộc'), findsOneWidget);

    key.currentState!.updateFieldValue('mw_co_tu', 'khong');
    await tester.pumpAndSettle();
    final hopLe = key.currentState!.validate(focusFirstError: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('Số tủ là bắt buộc'), findsNothing);
    // `name` bắt buộc chưa nhập vẫn lỗi — chỉ ô ẩn được miễn
    expect(hopLe, isFalse);
    expect(key.currentState!.getFormData().containsKey('mw_so_tu'), isFalse);
  });
}
