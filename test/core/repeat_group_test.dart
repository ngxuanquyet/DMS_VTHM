import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/core/dynamic_form/repeat_group.dart';
import 'package:vthm_dms/core/dynamic_form/widgets/repeat_group_field_widget.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_dynamic_column.dart';
import 'package:vthm_dms/features/forms/data/models/market_form_model.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';

/// NHÓM TRƯỜNG LẶP (`group_table`, 19/11/2026) — hợp đồng `API-NHOM-TRUONG-LAP-2026-11-19.md` (repo appnew).
void main() {
  /// Khoá `group` của schema điểm bán: "Người liên hệ" = Tên (bắt buộc) + SĐT + Vai (chọn), 1–2 dòng.
  final customerGroup = {
    'min_rows': 1,
    'max_rows': 2,
    'columns': [
      {'code': 'ho_ten', 'label': 'Tên', 'input_type': 'text', 'required': true, 'options': []},
      {'code': 'sdt', 'label': 'SĐT', 'input_type': 'text', 'required': false, 'options': []},
      {
        'code': 'vai',
        'label': 'Vai',
        'input_type': 'select',
        'required': false,
        'options': [
          {'value': 'cs', 'label': 'Chủ shop'},
        ],
      },
    ],
  };

  /// Khối nhóm của biểu mẫu thị trường (engine): `type: group`, `resolved.kind = table`, ô con ở `items`.
  final marketBlock = {
    'type': 'group',
    'ref': 'dms_lien_he',
    'required': false,
    'resolved': {
      'code': 'dms_lien_he',
      'name': 'Người liên hệ',
      'kind': 'table',
      'config': {'min_rows': 1, 'max_rows': 3},
      'items': [
        {
          'ref': 'dms_ten',
          'required': true,
          'resolved': {'code': 'dms_ten', 'label': 'Tên', 'input_type': 'text', 'config': {}},
        },
        {
          'ref': 'dms_so_luong',
          'required': false,
          'resolved': {
            'code': 'dms_so_luong',
            'label': 'Số lượng',
            'input_type': 'number',
            'config': {
              'validation': {'min': 1, 'max': 9},
            },
          },
        },
      ],
    },
  };

  test('schema điểm bán: ô group_table thành repeatGroup, khoá group KHÔNG bị đọc làm tên mục', () {
    final f = DynamicFormField.fromJson({
      'kind': 'dynamic',
      'code': 'nguoi_lien_he',
      'label': 'Người liên hệ',
      'input_type': 'group_table',
      'required': true,
      'group': customerGroup,
    });
    expect(f.type, DynamicFormFieldType.repeatGroup);
    expect(f.group, isNotNull);
    expect(f.section, isNot(contains('min_rows')));
    final spec = RepeatGroupSpec.fromCustomerSchema(f.group)!;
    expect(spec.columns.map((c) => c.label), ['Tên', 'SĐT', 'Vai']);
    expect(spec.columns.first.isRequired, isTrue);
    expect(spec.maxRows, 2);
  });

  test('kiểm lỗi cùng luật server: thiếu dòng, thừa dòng, ô con bắt buộc, số ngoài khoảng', () {
    final spec = RepeatGroupSpec.fromCustomerSchema(customerGroup)!;
    expect(spec.validate(null, label: 'Người liên hệ', isRequired: false), contains('cần ít nhất 1 dòng'));
    expect(
      spec.validate([
        {'line_id': 'a', 'ho_ten': 'A'},
        {'line_id': 'b', 'ho_ten': 'B'},
        {'line_id': 'c', 'ho_ten': 'C'},
      ], label: 'Người liên hệ', isRequired: false),
      contains('tối đa 2 dòng'),
    );
    expect(
      spec.validate([
        {'line_id': 'a', 'sdt': '0912'},
      ], label: 'Người liên hệ', isRequired: false),
      'Người liên hệ, dòng 1: Tên không được để trống',
    );
    expect(
      spec.validate([
        {'line_id': 'a', 'ho_ten': 'A'},
      ], label: 'Người liên hệ', isRequired: false),
      isNull,
    );
    // Màn sửa so NỘI DUNG: thứ tự khoá, ô trống, null/[] không làm nhóm "đổi".
    expect(RepeatGroupSpec.sameRows([{'line_id': 'a', 'ho_ten': 'A', 'sdt': null}], [{'ho_ten': 'A', 'line_id': 'a'}]), isTrue);
    expect(RepeatGroupSpec.sameRows([{'line_id': 'a', 'ho_ten': 'A', 'sdt': ''}], [{'line_id': 'a', 'ho_ten': 'A'}]), isTrue);
    expect(RepeatGroupSpec.sameRows(null, const []), isTrue);
    expect(RepeatGroupSpec.sameRows([{'line_id': 'a', 'ho_ten': 'A'}], [{'line_id': 'a', 'ho_ten': 'B'}]), isFalse);
    expect(RepeatGroupSpec.sameRows([{'line_id': 'a', 'sl': '5', 'co': false}], [{'line_id': 'a', 'sl': 5}]), isTrue,
        reason: 'số dạng chuỗi vs số, công tắc false = chưa điền');

    final market = RepeatGroupSpec.fromEngineItems(
      (marketBlock['resolved'] as Map)['items'],
      (marketBlock['resolved'] as Map)['config'],
    );
    expect(market.minRows, 1);
    expect(market.maxRows, 3);
    expect(
      market.validate([
        {'line_id': 'a', 'dms_ten': 'A', 'dms_so_luong': 12},
      ], label: 'Nhóm', isRequired: false),
      contains('Số lượng phải ≤ 9'),
    );
  });

  test('gộp chữ như server/web: dòng cách "; ", ô cách " – ", nhãn lựa chọn, bỏ ô trống', () {
    final spec = RepeatGroupSpec.fromCustomerSchema(customerGroup)!;
    final rows = [
      {'line_id': 'a', 'ho_ten': 'Nguyễn Văn A', 'sdt': '0912', 'vai': 'cs'},
      {'line_id': 'b', 'ho_ten': 'Trần Thị B'},
    ];
    expect(rows.map(spec.rowText).join('; '), 'Nguyễn Văn A – 0912 – Chủ shop; Trần Thị B');
    expect(RepeatGroupSpec.looksLikeRows(rows), isTrue);
    expect(RepeatGroupSpec.looksLikeRows([{'id': 5, 'name': 'a.pdf'}]), isFalse, reason: 'tham chiếu tệp không phải dòng nhóm');
    // Không có định nghĩa ô con ⇒ lấy khoá của dòng (bỏ line_id).
    expect(const RepeatGroupSpec().rowText({'line_id': 'x', 'ten': 'A', 'ok': true}), 'A – Có');
    expect(RepeatGroupSpec.newLineId(), matches(RegExp(r'^[0-9a-f]{16}$')));
  });

  test('biểu mẫu thị trường: khối nhóm thành group_table và GIỮ ô con qua bản lưu máy (toJson → fromJson)', () {
    final block = MarketFormBlockModel.fromJson(Map<String, dynamic>.from(marketBlock));
    expect(block.resolved.inputType, 'group_table');
    expect(block.resolved.label, 'Người liên hệ');

    // Bản lưu máy cho chạy offline đi qua toJson — mất `items` là nhóm mất hết ô con khi mở từ cache.
    final cached = MarketFormBlockModel.fromJson(jsonDecode(jsonEncode(block.toJson())) as Map<String, dynamic>);
    final entity = cached.toEntity().resolved;
    expect(entity.isRepeatGroup, isTrue);
    expect(entity.repeatGroup.columns.map((c) => c.code), ['dms_ten', 'dms_so_luong']);
    expect(entity.repeatGroup.minRows, 1);
  });

  test('cột động điểm bán: `items` của cột nhóm là ô con, KHÔNG phải danh sách lựa chọn', () {
    final col = CustomerDynamicColumn.fromJson({
      'code': 'dms_lien_he',
      'label': 'Người liên hệ',
      'input_type': 'group_table',
      'items': (marketBlock['resolved'] as Map)['items'],
    });
    expect(col.options, isEmpty);
    expect(col.isRepeatGroup, isTrue);
    expect(col.repeatGroup.rowText({'line_id': 'a', 'dms_ten': 'A', 'dms_so_luong': 2}), 'A – 2');
    expect(CustomerDynamicColumn.fromJson(col.toJson()).groupItems, hasLength(2));
  });

  testWidgets('widget: thêm thẻ (có line_id), gõ, xoá thẻ; đủ max_rows thì ẩn nút thêm', (tester) async {
    final spec = RepeatGroupSpec.fromCustomerSchema(customerGroup)!;
    var rows = <Map<String, dynamic>>[];
    const field = DynamicFormField(code: 'nlh', label: 'Người liên hệ', type: DynamicFormFieldType.repeatGroup);

    Widget build() => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => RepeatGroupFieldWidget(
                  field: field,
                  spec: spec,
                  value: rows,
                  onChanged: (v) => setState(() => rows = v),
                ),
              ),
            ),
          ),
        );

    await tester.pumpWidget(build());
    await tester.tap(find.text('Thêm Người liên hệ'));
    await tester.pumpAndSettle();
    expect(rows, hasLength(1));
    expect(rows.first['line_id'], matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(find.text('#1'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Nguyễn Văn A');
    await tester.pumpAndSettle();
    expect(rows.first['ho_ten'], 'Nguyễn Văn A');

    await tester.tap(find.text('Thêm Người liên hệ'));
    await tester.pumpAndSettle();
    expect(rows, hasLength(2));
    // Đủ max_rows = 2 ⇒ không còn nút thêm.
    expect(find.text('Thêm Người liên hệ'), findsNothing);

    await tester.tap(find.text('Xoá').first);
    await tester.pumpAndSettle();
    expect(rows, hasLength(1));
    expect(rows.first['ho_ten'], isNull, reason: 'xoá thẻ #1 thì còn lại thẻ #2 (chưa gõ gì)');
  });

  /// Schema THẬT lấy từ API app_test 19/11/2026 (TEST001): `GET /crm/customer-form/schema` + `GET /dms/forms/available`.
  final server = jsonDecode(File('test/core/repeat_group_server_fixture.json').readAsStringSync()) as Map<String, dynamic>;

  testWidgets('server thật — form điểm bán: DynamicFormBuilder vẽ thẻ, kiểm ô con bắt buộc, trả mảng dòng', (tester) async {
    final field = DynamicFormField.fromJson(Map<String, dynamic>.from(server['customer_group_field'] as Map));
    expect(field.type, DynamicFormFieldType.repeatGroup);
    final key = GlobalKey<DynamicFormBuilderState>();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DynamicFormBuilder(key: key, fields: [field]))));
    await tester.pumpAndSettle();

    // Nhóm bắt buộc mà chưa có dòng nào ⇒ không hợp lệ.
    expect(key.currentState!.validate(focusFirstError: false), isFalse);

    await tester.tap(find.text('Thêm ${field.label}'));
    await tester.pumpAndSettle();
    // Có dòng nhưng thiếu Họ tên (bắt buộc) ⇒ vẫn không hợp lệ.
    expect(key.currentState!.validate(focusFirstError: false), isFalse);

    await tester.enterText(find.byType(TextField).first, 'Nguyễn Văn A');
    await tester.pumpAndSettle();
    expect(key.currentState!.validate(focusFirstError: false), isTrue);
    final rows = key.currentState!.getFormData()[field.code] as List;
    expect(rows.single['tcc_ho_ten'], 'Nguyễn Văn A');
    expect(rows.single['line_id'], isNotNull);
  });

  testWidgets('server thật — biểu mẫu thị trường: MarketFormRenderer vẽ thẻ và nộp mảng dòng', (tester) async {
    final cfg = MarketFormConfigModel.fromJson(Map<String, dynamic>.from(server['market_form'] as Map)).toEntity();
    final nhom = cfg.schema.blocks.firstWhere((b) => b.resolved.isRepeatGroup);
    expect(nhom.resolved.repeatGroup.columns.map((c) => c.label), ['Họ tên', 'SĐT', 'Vai trò']);
    expect(nhom.resolved.repeatGroup.maxRows, 3);

    final key = GlobalKey<MarketFormRendererState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: MarketFormRenderer(key: key, blocks: cfg.schema.blocks))),
    ));
    await tester.pumpAndSettle();
    expect(key.currentState!.validateAndGetAnswers(), isNull, reason: 'nhóm bắt buộc, chưa có dòng');

    await tester.tap(find.text('Thêm ${nhom.resolved.label}'));
    await tester.pumpAndSettle();
    final o = find.descendant(of: find.byType(RepeatGroupFieldWidget), matching: find.byType(TextField));
    await tester.enterText(o.first, 'Trần Thị B');
    await tester.pumpAndSettle();
    final answers = key.currentState!.validateAndGetAnswers();
    expect(answers, isNotNull);
    final rows = answers![nhom.resolved.code] as List;
    expect(rows.single['dms_tcc_mf_ho_ten'], 'Trần Thị B');
  });

  test('độ dài ô con, nhãn ghi đè của nhóm, bỏ dòng không điền gì', () {
    final spec = RepeatGroupSpec.fromEngineItems([
      {
        'ref': 'sdt',
        'required': false,
        'overrides': {'label': 'Số ĐT liên hệ'},
        'resolved': {
          'code': 'sdt',
          'label': 'SĐT',
          'input_type': 'text',
          'config': {
            'validation': {'max_length': 5},
          },
        },
      },
      {
        'ref': 'ok',
        'required': false,
        'resolved': {'code': 'ok', 'label': 'Đồng ý', 'input_type': 'boolean', 'config': []},
      },
    ], const {});
    expect(spec.columns.first.label, 'Số ĐT liên hệ');
    expect(
      spec.validate([
        {'line_id': 'a', 'sdt': '0912345'},
      ], label: 'N', isRequired: false),
      'N, dòng 1: Số ĐT liên hệ tối đa 5 ký tự',
    );
    final rows = [
      {'line_id': 'a', 'ok': false},
      {'line_id': 'b', 'sdt': '091'},
    ];
    expect(spec.pruneEmpty(rows).map((r) => r['line_id']), ['b'], reason: 'dòng chỉ có công tắc "Không" = chưa điền');
    final du = [
      {'line_id': 'b', 'sdt': '091'},
    ];
    expect(identical(spec.pruneEmpty(du), du), isTrue, reason: 'không bỏ dòng nào ⇒ giữ nguyên tham chiếu');
  });

  /// Form điểm bán dựng trên một nhóm có ô con bắt buộc, có ô có/không và ô chọn có «Khác…».
  final nhomDayDu = DynamicFormField.fromJson({
    'kind': 'dynamic',
    'code': 'nlh',
    'label': 'Người liên hệ',
    'input_type': 'group_table',
    'required': true,
    'group': {
      'min_rows': null,
      'max_rows': 2,
      'columns': [
        {'code': 'ten', 'label': 'Tên', 'input_type': 'text', 'required': true, 'options': []},
        {'code': 'sdt', 'label': 'SĐT', 'input_type': 'text', 'required': false, 'options': []},
        {'code': 'dong_y', 'label': 'Đồng ý', 'input_type': 'boolean', 'required': true, 'options': []},
      ],
    },
  });

  testWidgets('màn sửa: nhóm TRÙNG giá trị đang lưu không bị kiểm (PATCH) dù luật đã siết', (tester) async {
    // Đang lưu 3 dòng, admin vừa hạ max_rows = 2 ⇒ nhóm không đổi thì vẫn lưu được ô khác.
    final luu = [
      for (final x in ['a', 'b', 'c']) {'line_id': x, 'ten': x, 'dong_y': true},
    ];
    final key = GlobalKey<DynamicFormBuilderState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFormBuilder(key: key, fields: [nhomDayDu], initialData: {'nlh': luu}, savedData: {'nlh': luu}, editing: true),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(key.currentState!.validate(focusFirstError: false), isTrue);

    // Màn sửa, nhóm bắt buộc nhưng đang RỖNG và chưa chạm ⇒ không chặn (bản ghi có trước khi admin thêm nhóm).
    final key2 = GlobalKey<DynamicFormBuilderState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFormBuilder(key: key2, fields: [nhomDayDu], savedData: const {}, editing: true),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(key2.currentState!.validate(focusFirstError: false), isTrue);
  });

  testWidgets('thẻ mới: ô có/không mang sẵn false (bắt buộc vẫn qua); gõ ô A rồi ô B không mất chữ ô A', (tester) async {
    final key = GlobalKey<DynamicFormBuilderState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: DynamicFormBuilder(key: key, fields: [nhomDayDu]))),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm Người liên hệ'));
    await tester.pumpAndSettle();
    final o = find.byType(TextField);
    await tester.enterText(o.at(0), 'Nguyễn Văn A');
    await tester.enterText(o.at(1), '0912');
    await tester.pumpAndSettle();
    expect(key.currentState!.validate(focusFirstError: false), isTrue);
    final rows = key.currentState!.getFormData()['nlh'] as List;
    expect(rows.single['ten'], 'Nguyễn Văn A');
    expect(rows.single['sdt'], '0912');
    expect(rows.single['dong_y'], isFalse);
  });

  testWidgets('ô con chọn có «Khác…»: giá trị gõ tay đã lưu hiện lại ở ô gõ', (tester) async {
    final spec = RepeatGroupSpec.fromCustomerSchema({
      'columns': [
        {
          'code': 'vai',
          'label': 'Vai',
          'input_type': 'select',
          'allow_other': true,
          'options': [
            {'value': 'Chủ shop', 'label': 'Chủ shop'},
          ],
        },
      ],
    })!;
    expect(spec.columns.single.allowOther, isTrue);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: RepeatGroupFieldWidget(
            field: const DynamicFormField(code: 'g', label: 'G', type: DynamicFormFieldType.repeatGroup),
            spec: spec,
            value: const [
              {'line_id': 'a', 'vai': 'Quản lý ca'},
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Quản lý ca'), findsOneWidget);
  });

  testWidgets('màn sửa: thêm thẻ rồi để trống thì nhóm KHÔNG coi là đổi; nhóm chỉ đọc không bị đòi số dòng', (tester) async {
    final key = GlobalKey<DynamicFormBuilderState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFormBuilder(key: key, fields: [nhomDayDu], savedData: const {}, editing: true),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm Người liên hệ'));
    await tester.pumpAndSettle();
    // Thẻ chỉ có công tắc "Không" = chưa điền ⇒ dữ liệu gửi đi bỏ thẻ, nội dung trùng "chưa có" đang lưu.
    final data = key.currentState!.getFormData();
    expect(RepeatGroupSpec.sameRows(data['nlh'], null), isTrue);
    expect(key.currentState!.isRepeatGroup('nlh'), isTrue);
    expect(find.text('#1'), findsOneWidget, reason: 'thẻ vừa thêm vẫn còn trên màn hình');

    final key2 = GlobalKey<DynamicFormBuilderState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFormBuilder(key: key2, fields: [nhomDayDu.copyWith(isReadOnly: true)]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Thêm Người liên hệ'), findsNothing);
    expect(key2.currentState!.validate(focusFirstError: false), isTrue);
  });

  testWidgets('màn sửa: luật đã siết + bấm nhầm thêm thẻ trống ⇒ vẫn lưu được (so bản đã bỏ dòng trống)', (tester) async {
    final luu = [
      for (final x in ['a', 'b', 'c']) {'line_id': x, 'ten': x, 'dong_y': true},
    ];
    // max_rows = 2 < 3 dòng đang lưu: nhóm không đổi thì không kiểm. Bấm "+ Thêm" bị ẩn vì đã quá trần — thử bằng
    // giá trị nạp sẵn có thêm một dòng trống.
    final key = GlobalKey<DynamicFormBuilderState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFormBuilder(
            key: key,
            fields: [nhomDayDu],
            initialData: {
              'nlh': [
                ...luu,
                {'line_id': 'moi', 'dong_y': false},
              ],
            },
            savedData: {'nlh': luu},
            editing: true,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(key.currentState!.validate(focusFirstError: false), isTrue);
    expect(RepeatGroupSpec.sameRows(key.currentState!.getFormData()['nlh'], luu), isTrue);
  });
}
