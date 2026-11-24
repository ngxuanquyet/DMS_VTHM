import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';

/// #25875 — màn THÊM điểm bán: nháp còn lựa chọn admin ĐÃ GỠ (ô không hiện lựa chọn đó, người dùng không bỏ được, server
/// từ chối «ngoài danh sách») ⇒ bỏ lúc bấm Lưu, báo nhãn ô, dừng để chọn lại. Màn sửa giữ nguyên (server bỏ qua ô không đổi).
void main() {
  DynamicFormField choice(String code, String inputType, {Map<String, dynamic> extra = const {}}) =>
      DynamicFormField.fromJson({
        'kind': 'dynamic',
        'code': code,
        'label': code,
        'input_type': inputType,
        'options': [
          {'value': 'a', 'label': 'A'},
          {'value': 'b', 'label': 'B'},
        ],
        ...extra,
      });

  Future<DynamicFormBuilderState> pump(
    WidgetTester tester,
    List<DynamicFormField> fields,
    Map<String, dynamic> data, {
    Set<String> Function(Map<String, dynamic>)? hiddenFieldsOf,
    bool editing = false,
  }) async {
    final key = GlobalKey<DynamicFormBuilderState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFormBuilder(
            key: key,
            fields: fields,
            initialData: data,
            savedData: editing ? data : const {},
            editing: editing,
            hiddenFieldsOf: hiddenFieldsOf,
          ),
        ),
      ),
    ));
    return key.currentState!;
  }

  group('withoutRemovedOptions', () {
    test('ô chọn một: lựa chọn đã gỡ ⇒ bỏ; còn trong danh sách ⇒ giữ nguyên', () {
      final f = choice('loai', 'select');
      expect(DynamicFormBuilderState.withoutRemovedOptions(f, 'x'), isNull);
      expect(DynamicFormBuilderState.withoutRemovedOptions(f, 'a'), 'a');
    });

    test('ô chọn nhiều: bỏ phần tử đã gỡ; không đổi ⇒ trả CHÍNH danh sách cũ', () {
      final f = choice('nhom', 'multiselect');
      expect(DynamicFormBuilderState.withoutRemovedOptions(f, ['a', 'x']), ['a']);
      final same = ['a', 'b'];
      expect(identical(DynamicFormBuilderState.withoutRemovedOptions(f, same), same), isTrue);
    });

    test('danh sách lựa chọn RỖNG (admin gỡ hết) ⇒ giá trị nào cũng là đã gỡ', () {
      final f = DynamicFormField.fromJson(
          {'kind': 'dynamic', 'code': 'loai', 'label': 'loai', 'input_type': 'select', 'options': const []});
      expect(DynamicFormBuilderState.withoutRemovedOptions(f, 'x'), isNull);
    });
  });

  testWidgets('màn thêm: dựng form KHÔNG lọc (danh sách có thể là danh sách tạm) — lọc lúc lưu, báo nhãn ô bị bỏ',
      (tester) async {
    final state = await pump(tester, [choice('loai', 'select'), choice('nhom', 'multiselect')], const {
      'loai': 'x',
      'nhom': ['b', 'y'],
    });
    expect(state.getFormData()['loai'], 'x', reason: 'không xoá oan lúc dựng');
    expect(state.dropRemovedOptionsBeforeSave(), ['loai', 'nhom']);
    final data = state.getFormData();
    expect(data['loai'], isNull);
    expect(data['nhom'], ['b']);
    expect(state.dropRemovedOptionsBeforeSave(), isEmpty, reason: 'lần bấm Lưu sau: đã sạch, lưu được');
  });

  testWidgets('lúc lưu KHÔNG xét: ô cố định, ô «Khác…», ô đang ẩn, ô chỉ đọc, ô danh mục; phần tử rỗng không tính',
      (tester) async {
    final coDinh = DynamicFormField.fromJson({
      'kind': 'fixed',
      'code': 'region_id',
      'label': 'Khu vực',
      'input_type': 'select',
      'options': [
        {'value': 8, 'label': '08'},
      ],
    });
    final state = await pump(
      tester,
      [
        coDinh,
        choice('khac', 'select', extra: {'config': {'allow_other': true}}),
        choice('an', 'select'),
        choice('chi_doc', 'select', extra: {'read_only': true}),
        choice('danh_muc', 'select', extra: {'catalog': 'sales_channel'}),
        choice('rong', 'multiselect'),
      ],
      const {
        'region_id': 12,
        'khac': 'gõ tay',
        'an': 'x',
        'chi_doc': 'x',
        'danh_muc': 'x',
        'rong': ['a', ''],
      },
      hiddenFieldsOf: (_) => {'an'},
    );
    expect(state.dropRemovedOptionsBeforeSave(), isEmpty);
    expect(state.getFormData()['region_id'], 12);
  });

  testWidgets('ô «Ẩn trên app» (vẫn gửi) bỏ âm thầm; ô bị ẩn SAU khi bỏ ô khác thì không báo', (tester) async {
    final state = await pump(
      tester,
      [
        choice('an_app', 'select', extra: {'hidden_on_app': true}),
        choice('dk', 'select'),
        choice('phu', 'select'),
      ],
      const {'an_app': 'x', 'dk': 'x', 'phu': 'x'},
      // 'phu' chỉ hiện khi 'dk' còn giá trị.
      hiddenFieldsOf: (d) => d['dk'] == null ? {'phu'} : {},
    );
    expect(state.dropRemovedOptionsBeforeSave(), ['dk']);
    expect(state.getFormData()['an_app'], isNull, reason: 'vẫn gửi ⇒ phải sạch');
  });

  testWidgets('bỏ ô đứng SAU làm hiện ô đứng TRƯỚC ⇒ ô trước cũng được bỏ và báo trong cùng một lần bấm', (tester) async {
    final state = await pump(
      tester,
      [
        choice('truoc', 'select'),
        choice('sau', 'select', extra: {'hidden_on_app': true}),
      ],
      const {'truoc': 'x', 'sau': 'y'},
      // 'truoc' chỉ hiện khi 'sau' trống.
      hiddenFieldsOf: (d) => d['sau'] != null ? {'truoc'} : {},
    );
    expect(state.dropRemovedOptionsBeforeSave(), ['truoc']);
    expect(state.getFormData()['truoc'], isNull);
  });

  testWidgets('ô bị ẩn bởi lần bỏ SAU nó thì không báo; báo theo thứ tự trên màn', (tester) async {
    final state = await pump(
      tester,
      [choice('a', 'select'), choice('b', 'select'), choice('c', 'select')],
      const {'a': 'p', 'b': 'x', 'c': 'q'},
      // 'a' chỉ hiện khi 'b' còn giá trị.
      hiddenFieldsOf: (d) => d['b'] == null ? {'a'} : {},
    );
    expect(state.dropRemovedOptionsBeforeSave(), ['b', 'c']);
  });

  testWidgets('màn sửa: form GIỮ giá trị đang lưu — ô không đụng không thành "đã đổi"', (tester) async {
    final state = await pump(
      tester,
      [choice('loai', 'select'), choice('nhom', 'multiselect')],
      const {
        'loai': 'x',
        'nhom': ['b', 'y'],
      },
      editing: true,
    );
    final data = state.getFormData();
    expect(data['loai'], 'x');
    expect(data['nhom'], ['b', 'y']);
  });
}
