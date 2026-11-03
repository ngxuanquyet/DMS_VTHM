import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/core/services/erp_link_request_service.dart';
import 'package:vthm_dms/features/customer/data/repositories/customer_repository_impl.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_meta_entity.dart';
import 'package:vthm_dms/features/customer/presentation/screens/add_customer_screen.dart';
import 'package:vthm_dms/features/customer/presentation/screens/edit_customer_screen.dart';

import '../edit_customer_screen_test.dart' show MockCustomerRepository;
import '../helpers/fake_erp_link_request_service.dart';

/// Ô TRÌNH BÀY của form Thêm/Sửa điểm bán (#24753, chốt 03/11/2026): `heading` (cấp 1/2) và `note` (Ghi chú hướng dẫn)
/// được vẽ nhưng KHÔNG thu giá trị — không vào formData, không bắt buộc, không làm màn Sửa báo "có thay đổi".
void main() {
  const routes = [DynamicFormOption(label: 'Tuyến A', value: 5)];

  final schemaFields = <Map<String, dynamic>>[
    {'code': 'name', 'label': 'Tên điểm bán', 'input_type': 'text', 'kind': 'fixed', 'required': true},
    {
      'code': 'h_lh',
      'label': 'Liên hệ',
      'input_type': 'heading',
      'kind': 'dynamic',
      'level': 1,
      'description': 'Người phụ trách điểm bán',
    },
    {'code': 'phone', 'label': 'SĐT', 'input_type': 'text', 'kind': 'fixed'},
    {'code': 'h_con', 'label': 'Giờ mở cửa', 'input_type': 'heading', 'kind': 'dynamic', 'level': 2, 'required': true},
    {
      'code': 'hd_anh',
      'label': 'Hướng dẫn chụp ảnh',
      'input_type': 'note',
      'kind': 'dynamic',
      'required': true,
      'description': '<p>Chụp <strong>toàn cảnh</strong> mặt tiền</p>',
    },
    {'code': 'mw_ghi', 'label': 'Ghi chú thêm', 'input_type': 'text', 'kind': 'dynamic'},
  ];
  final schema = {
    'data': {'fields': schemaFields},
  };

  Widget wrap(Widget child) => ProviderScope(
        child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
      );

  group('model', () {
    test('heading / note thành loại riêng, không bắt buộc; level + description đi qua bộ đệm JSON', () {
      // Bộ đệm schema trong máy lưu nguyên JSON ⇒ đọc lại sau jsonEncode/jsonDecode phải còn level + mô tả.
      final cached = jsonDecode(jsonEncode(schema)) as Map<String, dynamic>;
      final f = ((cached['data'] as Map)['fields'] as List)
          .map((e) => DynamicFormField.fromJson(e as Map<String, dynamic>))
          .toList();
      final h1 = f.firstWhere((x) => x.code == 'h_lh');
      final h2 = f.firstWhere((x) => x.code == 'h_con');
      final note = f.firstWhere((x) => x.code == 'hd_anh');
      expect(h1.type, DynamicFormFieldType.heading);
      expect(h1.level, 1);
      expect(h1.helperText, 'Người phụ trách điểm bán');
      expect(h2.level, 2);
      expect(h2.isRequired, isFalse);
      expect(note.type, DynamicFormFieldType.note);
      expect(note.isRequired, isFalse);
      expect(note.helperText, contains('<strong>toàn cảnh</strong>'));
      expect(h1.isDisplayOnly && note.isDisplayOnly, isTrue);
      expect(DynamicFormField.fromJson(const {'code': 'x', 'input_type': 'heading', 'config': {'level': '2'}}).level, 2);
    });

    test('buildCustomerFormFields: tiêu đề cấp 1 mở mục (mô tả ở lại đầu mục, không nhãn); cấp 2 + note vẽ tại chỗ', () {
      final f = buildCustomerFormFields(schema, meta: const CustomerMetaData(), routeOptions: routes, defaultRouteId: 5);
      final h1 = f.firstWhere((x) => x.code == 'h_lh');
      expect(h1.isSectionDescription, isTrue);
      expect(h1.section, 'Liên hệ');
      expect(f.firstWhere((x) => x.code == 'phone').section, 'Liên hệ');
      expect(f.firstWhere((x) => x.code == 'h_con').section, 'Liên hệ', reason: 'tiêu đề con không mở mục');
      expect(f.firstWhere((x) => x.code == 'hd_anh').type, DynamicFormFieldType.note);
      expect(f.firstWhere((x) => x.code == 'mw_ghi').section, 'Liên hệ');
    });
  });

  test('loại ô theo kiểu đã phân giải (`Heading` hoa thường vẫn là tiêu đề); nhãn ô trình bày không bị làm sạch', () {
    final f = buildCustomerFormFields({
      'data': {
        'fields': [
          {'code': 'name', 'label': 'Tên', 'input_type': 'text'},
          {'code': 'h_x', 'label': 'Mục X', 'input_type': 'Heading'},
          {'code': 'mw_a', 'label': 'Ô A', 'input_type': 'text', 'kind': 'dynamic'},
          {'code': 'n_bb', 'label': 'Ô có dấu (bắt buộc)', 'input_type': 'note', 'description': 'x'},
        ],
      },
    }, meta: const CustomerMetaData(), routeOptions: routes, defaultRouteId: 5);
    expect(f.map((x) => x.code), isNot(contains('h_x')));
    expect(f.firstWhere((x) => x.code == 'mw_a').section, 'Mục X');
    expect(f.firstWhere((x) => x.code == 'mw_a').sectionKey, 'h_x');
    expect(f.firstWhere((x) => x.code == 'n_bb').label, 'Ô có dấu (bắt buộc)');
  });

  test("'note' là ô trình bày CHỈ khi đến từ `input_type`; khoá cũ `type`/`data_type` = 'note' vẫn là ô chữ dài", () {
    expect(DynamicFormField.fromJson(const {'code': 'a', 'input_type': 'note'}).type, DynamicFormFieldType.note);
    final cu1 = DynamicFormField.fromJson(const {'code': 'b', 'type': 'note', 'required': true});
    expect(cu1.type, DynamicFormFieldType.longText);
    expect(cu1.isRequired, isTrue);
    expect(DynamicFormField.fromJson(const {'code': 'c', 'data_type': 'note'}).type, DynamicFormFieldType.longText);
    expect(DynamicFormField.fromJson(const {'code': 'd', 'type': 'note', 'input_type': 'note'}).type,
        DynamicFormFieldType.longText);
  });

  test('nhãn tiêu đề được trim trước khi làm tên mục; nhãn toàn khoảng trắng không mở mục', () {
    final f = sectionsFromConfig(const [
      DynamicFormField(code: 'h1', label: '  Mục A  ', type: DynamicFormFieldType.heading),
      DynamicFormField(code: 'a', label: 'A', type: DynamicFormFieldType.text),
      DynamicFormField(code: 'h2', label: '   ', type: DynamicFormFieldType.heading),
      DynamicFormField(code: 'b', label: 'B', type: DynamicFormFieldType.text),
    ]);
    expect(f.where((x) => x.code != 'h2').map((x) => x.section), ['Mục A', 'Mục A']);
  });

  group('vẽ', () {
    double y(WidgetTester t, String s) => t.getTopLeft(find.text(s).first).dy;

    testWidgets('bản đồ chen giữa: đúng thứ tự cấu hình — khung + mô tả + tiêu đề con TRƯỚC bản đồ, phần sau nối tiếp',
        (tester) async {
      final fields = sectionsFromConfig(const [
        DynamicFormField(code: 'h1', label: 'Mục A', type: DynamicFormFieldType.heading, helperText: 'Mô tả A'),
        DynamicFormField(code: 'hc', label: 'Con A', type: DynamicFormFieldType.heading, level: 2),
        DynamicFormField(code: 'coords', label: 'Toạ độ', type: DynamicFormFieldType.location),
        DynamicFormField(code: 'b', label: 'Ô B', type: DynamicFormFieldType.text),
      ]);
      await tester.pumpWidget(wrap(DynamicFormBuilder(fields: fields, keepFieldOrder: true)));
      await tester.pumpAndSettle();
      expect(find.text('Mục A'), findsOneWidget, reason: 'thanh tiêu đề chỉ ở khúc đầu, phần sau bản đồ không lặp');
      expect(find.text('Mô tả A'), findsOneWidget);
      expect(find.text('Con A'), findsOneWidget);
      final banDo = y(tester, 'Vị trí trên bản đồ');
      expect(y(tester, 'Mục A') < y(tester, 'Mô tả A'), isTrue);
      expect(y(tester, 'Mô tả A') < y(tester, 'Con A'), isTrue);
      expect(y(tester, 'Con A') < banDo, isTrue);
      expect(banDo < y(tester, 'Ô B'), isTrue);
    });

    testWidgets('mục tiêu đề chỉ có bản đồ: vẫn giữ tiêu đề + mô tả', (tester) async {
      final fields = sectionsFromConfig(const [
        DynamicFormField(code: 'name', label: 'Tên', type: DynamicFormFieldType.text),
        DynamicFormField(code: 'h1', label: 'Mục bản đồ', type: DynamicFormFieldType.heading, helperText: 'Mô tả bản đồ'),
        DynamicFormField(code: 'coords', label: 'Toạ độ', type: DynamicFormFieldType.location),
      ]);
      await tester.pumpWidget(wrap(DynamicFormBuilder(fields: fields, keepFieldOrder: true)));
      await tester.pumpAndSettle();
      expect(find.text('Mục bản đồ'), findsOneWidget);
      expect(find.text('Mô tả bản đồ'), findsOneWidget);
      expect(y(tester, 'Mô tả bản đồ') < y(tester, 'Vị trí trên bản đồ'), isTrue);
    });

    testWidgets('tiêu đề cấp 1 nhãn rỗng: không mở mục, vẽ tại chỗ chỉ dòng mô tả', (tester) async {
      final fields = sectionsFromConfig(const [
        DynamicFormField(code: 'h1', label: 'Mục A', type: DynamicFormFieldType.heading),
        DynamicFormField(code: 'a', label: 'Ô A', type: DynamicFormFieldType.text),
        DynamicFormField(code: 'h2', label: '  ', type: DynamicFormFieldType.heading, helperText: 'Chỉ mô tả'),
        DynamicFormField(code: 'b', label: 'Ô B', type: DynamicFormFieldType.text),
      ]);
      final rong = fields.firstWhere((x) => x.code == 'h2');
      expect(rong.isSectionDescription, isFalse);
      expect(rong.sectionKey, 'h1');
      expect(fields.firstWhere((x) => x.code == 'b').sectionKey, 'h1');
      await tester.pumpWidget(wrap(DynamicFormBuilder(fields: fields, keepFieldOrder: true)));
      await tester.pumpAndSettle();
      expect(find.text('Chỉ mô tả'), findsOneWidget);
      expect(find.byKey(const ValueKey('heading_h2')), findsNothing);
      expect(y(tester, 'Ô A') < y(tester, 'Chỉ mô tả') && y(tester, 'Chỉ mô tả') < y(tester, 'Ô B'), isTrue);
    });

    testWidgets('hai tiêu đề cùng nhãn là hai mục khác nhau (mỗi mục một thanh tiêu đề)', (tester) async {
      final fields = sectionsFromConfig(const [
        DynamicFormField(code: 'h1', label: 'Trùng', type: DynamicFormFieldType.heading),
        DynamicFormField(code: 'a', label: 'Ô A', type: DynamicFormFieldType.text),
        DynamicFormField(code: 'h2', label: 'Trùng', type: DynamicFormFieldType.heading),
        DynamicFormField(code: 'b', label: 'Ô B', type: DynamicFormFieldType.text),
      ]);
      await tester.pumpWidget(wrap(DynamicFormBuilder(fields: fields, keepFieldOrder: true)));
      await tester.pumpAndSettle();
      expect(find.text('Trùng'), findsNWidgets(2));
    });

    testWidgets('mục tiêu đề chỉ có lat/lng + dòng mô tả vẫn vẽ thành khối vị trí', (tester) async {
      final fields = sectionsFromConfig(const [
        DynamicFormField(code: 'name', label: 'Tên', type: DynamicFormFieldType.text),
        DynamicFormField(code: 'h1', label: 'Toạ độ cửa hàng', type: DynamicFormFieldType.heading, helperText: 'Đứng trước cửa'),
        DynamicFormField(code: 'lat', label: 'Vĩ độ', type: DynamicFormFieldType.number),
        DynamicFormField(code: 'lng', label: 'Kinh độ', type: DynamicFormFieldType.number),
      ]);
      await tester.pumpWidget(wrap(DynamicFormBuilder(fields: fields, keepFieldOrder: true)));
      await tester.pumpAndSettle();
      expect(find.text('Có thể sửa'), findsOneWidget, reason: 'nhãn của khối vị trí');
      expect(find.text('Đứng trước cửa'), findsOneWidget);
    });

    testWidgets('tiêu đề cấp 2 nhãn rỗng vẫn vẽ kiểu tiêu đề con', (tester) async {
      await tester.pumpWidget(wrap(const DynamicFormBuilder(keepFieldOrder: true, fields: [
        DynamicFormField(code: 'h2', label: '', type: DynamicFormFieldType.heading, level: 2, helperText: 'Mô tả con', section: 'X'),
        DynamicFormField(code: 'x', label: 'Ô X', type: DynamicFormFieldType.text, section: 'X'),
      ])));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('subheading_h2')), findsOneWidget);
      expect(find.text('Mô tả con'), findsOneWidget);
    });

    testWidgets('mục mở bởi tiêu đề tên chứa "động" / "vị trí" vẫn là khung mục có tiêu đề (không đoán theo tên)',
        (tester) async {
      final fields = sectionsFromConfig(const [
        DynamicFormField(code: 'h1', label: 'Thông tin mở rộng (Động)', type: DynamicFormFieldType.heading),
        DynamicFormField(code: 'a', label: 'Ô A', type: DynamicFormFieldType.text),
        DynamicFormField(code: 'h2', label: 'Vị trí kệ hàng', type: DynamicFormFieldType.heading),
        DynamicFormField(code: 'b', label: 'Ô B', type: DynamicFormFieldType.text),
      ]);
      await tester.pumpWidget(wrap(DynamicFormBuilder(fields: fields, keepFieldOrder: true)));
      await tester.pumpAndSettle();
      expect(find.text('Thông tin mở rộng (Động)'), findsOneWidget);
      expect(find.text('Vị trí kệ hàng'), findsOneWidget);
      expect(find.text('Có thể sửa'), findsNothing, reason: 'không bị vẽ thành khối bản đồ');
    });

    testWidgets('mục không còn ô nhập nào (mọi ô khác ẩn) không vẽ — kể cả mục chỉ có ghi chú', (tester) async {
      final fields = sectionsFromConfig(const [
        DynamicFormField(code: 'h1', label: 'Mục rỗng', type: DynamicFormFieldType.heading, helperText: 'Mô tả rỗng'),
        DynamicFormField(code: 'h1c', label: 'Con', type: DynamicFormFieldType.heading, level: 2),
        DynamicFormField(code: 'a', label: 'Ô A', type: DynamicFormFieldType.text),
        DynamicFormField(code: 'h2', label: 'Mục hướng dẫn', type: DynamicFormFieldType.heading),
        DynamicFormField(code: 'n', label: 'Ghi chú', type: DynamicFormFieldType.note, helperText: 'abc'),
      ]);
      await tester.pumpWidget(wrap(DynamicFormBuilder(
        fields: fields,
        keepFieldOrder: true,
        hiddenFieldsOf: (_) => {'a'},
      )));
      await tester.pumpAndSettle();
      expect(find.text('Mục rỗng'), findsNothing);
      expect(find.text('Mô tả rỗng'), findsNothing);
      expect(find.text('Con'), findsNothing);
      expect(find.text('Mục hướng dẫn'), findsNothing, reason: 'mục không có ô nhập nào ⇒ bỏ cả ghi chú');
      expect(find.text('Ghi chú'), findsNothing);
    });

    testWidgets('tiêu đề cấp 1 / cấp 2: cấp 2 chữ nhỏ hơn và thụt vào', (tester) async {
      await tester.pumpWidget(wrap(const DynamicFormBuilder(keepFieldOrder: true, fields: [
        DynamicFormField(
            code: 'h1', label: 'Tiêu đề lớn', type: DynamicFormFieldType.heading, helperText: 'Mô tả lớn', section: 'X'),
        DynamicFormField(code: 'x', label: 'Ô X', type: DynamicFormFieldType.text, section: 'X'),
        DynamicFormField(code: 'h2', label: 'Tiêu đề con', type: DynamicFormFieldType.heading, level: 2, section: 'X'),
      ])));
      await tester.pumpAndSettle();
      expect(find.text('Mô tả lớn'), findsOneWidget);
      expect(find.byKey(const ValueKey('heading_h1')), findsOneWidget);
      expect(find.byKey(const ValueKey('subheading_h2')), findsOneWidget);
      final lon = tester.widget<Text>(find.text('Tiêu đề lớn')).style!.fontSize!;
      final con = tester.widget<Text>(find.text('Tiêu đề con')).style!.fontSize!;
      expect(con < lon, isTrue);
      expect(tester.getTopLeft(find.text('Tiêu đề con')).dx > tester.getTopLeft(find.text('Tiêu đề lớn')).dx, isTrue);
    });

    testWidgets('note: bấm mở / thu nội dung HTML và chữ thường', (tester) async {
      await tester.pumpWidget(wrap(const DynamicFormBuilder(keepFieldOrder: true, fields: [
        DynamicFormField(
          code: 'n1',
          label: 'Hướng dẫn chụp ảnh',
          type: DynamicFormFieldType.note,
          helperText: '<p>Chụp <strong>toàn cảnh</strong> mặt tiền</p>',
          section: 'X',
        ),
        DynamicFormField(code: 'x', label: 'Ô X', type: DynamicFormFieldType.text, section: 'X'),
      ])));
      await tester.pumpAndSettle();
      expect(find.text('Hướng dẫn chụp ảnh'), findsOneWidget);
      expect(find.textContaining('toàn cảnh', findRichText: true), findsNothing);
      await tester.tap(find.byKey(const ValueKey('note_toggle')));
      await tester.pumpAndSettle();
      expect(find.textContaining('toàn cảnh', findRichText: true), findsOneWidget);
      expect(find.textContaining('<strong>', findRichText: true), findsNothing);
      await tester.tap(find.byKey(const ValueKey('note_toggle')));
      await tester.pumpAndSettle();
      expect(find.textContaining('toàn cảnh', findRichText: true), findsNothing);

      await tester.pumpWidget(wrap(const DynamicFormBuilder(keepFieldOrder: true, fields: [
        DynamicFormField(
            code: 'n2', label: 'Lưu ý', type: DynamicFormFieldType.note, helperText: 'Hỏi chủ <2 thùng>', section: 'X'),
        DynamicFormField(code: 'x', label: 'Ô X', type: DynamicFormFieldType.text, section: 'X'),
      ])));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note_toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Hỏi chủ <2 thùng>'), findsOneWidget);
    });
  });

  testWidgets('form Thêm điểm bán: formData gửi đi / bản lưu nháp KHÔNG có khoá heading / note', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final fields = buildCustomerFormFields(schema, meta: const CustomerMetaData(), routeOptions: routes, defaultRouteId: 5)
        // Bản đồ / ảnh cần nền tảng thật — không liên quan việc loại ô trình bày.
        .where((f) => f.code != 'coords' && f.code != 'photo_file_id')
        .toList();
    final key = GlobalKey<DynamicFormBuilderState>();
    Map<String, dynamic>? submitted;
    final nhap = <String, dynamic>{};
    await tester.pumpWidget(wrap(DynamicFormBuilder(
      key: key,
      fields: fields,
      keepFieldOrder: true,
      // Bản lưu nháp CŨ (trước bản app này) có thể mang khoá trùng mã ô trình bày — vẫn không được lọt ra.
      initialData: const {'name': 'Tạp hoá A', 'hd_anh': 'rác cũ', 'h_con': null, 'customer_type_id': 1, 'region_id': 8},
      onChanged: nhap.addAll,
      onSubmit: (d) async => submitted = d,
      submitButtonText: 'Lưu',
    )));
    await tester.pumpAndSettle();
    expect(find.text('Hướng dẫn chụp ảnh'), findsOneWidget);
    expect(find.text('Giờ mở cửa'), findsOneWidget);
    expect(find.text('Người phụ trách điểm bán'), findsOneWidget);

    key.currentState!.updateFieldValue('mw_ghi', 'abc');
    await tester.pump();
    expect(nhap.keys, containsAll(['name', 'mw_ghi']));
    for (final code in ['h_lh', 'h_con', 'hd_anh']) {
      expect(nhap.containsKey(code), isFalse, reason: 'bản lưu nháp không có $code');
      expect(key.currentState!.getFormData().containsKey(code), isFalse, reason: 'formData không có $code');
    }

    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(submitted, isNotNull, reason: 'ô trình bày (server gửi required) không chặn lưu');
    expect(submitted!.keys, isNot(anyOf(contains('h_lh'), contains('h_con'), contains('hd_anh'))));
    expect(submitted!['mw_ghi'], 'abc');
  });

  testWidgets('màn Sửa: ô trình bày không làm báo "có thay đổi" khi bấm HỦY BỎ', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    const c = CustomerEntity(
      id: 101,
      code: 'VTHM-001',
      name: 'Đại lý Minh Anh',
      type: 'Đại lý',
      route: 'Tuyến A',
      address: 'Hà Nội',
      phone: '0987654321',
      contactPerson: 'A',
      lat: 21.01,
      lng: 105.81,
      // Có ảnh: điểm bán chưa ảnh vốn đã báo thay đổi ([] ≠ null) — không thuộc việc này.
      photoUrl: '/crm/customer-photos/public/53e96e0b',
      photoUrls: ['/crm/customer-photos/public/53e96e0b'],
      // Dữ liệu điểm bán mang trùng mã ô trình bày (cấu hình đổi loại ô sau khi đã có dữ liệu).
      dynamicFields: {'hd_anh': 'giá trị cũ', 'mw_ghi': 'x'},
    );
    final repo = _SchemaRepo(c, schema);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        customerRepositoryProvider.overrideWithValue(repo),
        erpLinkRequestServiceProvider.overrideWithValue(FakeErpLinkRequestService()),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const EditCustomerScreen(customer: c))),
                child: const Text('mở'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    expect(find.text('Hướng dẫn chụp ảnh'), findsOneWidget);
    expect(find.text('Giờ mở cửa'), findsOneWidget);

    await tester.ensureVisible(find.text('HỦY BỎ'));
    await tester.tap(find.text('HỦY BỎ'));
    await tester.pumpAndSettle();
    expect(find.text('Rời khỏi màn hình?'), findsNothing);
    expect(find.text('mở'), findsOneWidget, reason: 'không thay đổi ⇒ rời màn ngay');
  });
}

class _SchemaRepo extends MockCustomerRepository {
  final Map<String, dynamic> schema;

  _SchemaRepo(super.mockCustomer, this.schema);

  @override
  Future<Map<String, dynamic>> getCustomerFormSchema({bool forceRefresh = false}) async => schema;
}
