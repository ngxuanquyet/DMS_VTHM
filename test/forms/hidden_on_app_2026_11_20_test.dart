import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_meta_entity.dart';
import 'package:vthm_dms/features/customer/presentation/screens/add_customer_screen.dart';
import 'package:vthm_dms/features/forms/data/models/market_form_model.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';

/// «Ẩn trên app (vẫn gửi dữ liệu)» (`hidden_on_app`, chốt 20/11/2026): app KHÔNG vẽ ô nhưng vẫn gửi giá trị điền sẵn / đang
/// lưu, không kiểm ô đó; ô «Tuyến bán hàng» (`route_ids`) theo Cấu hình trường điểm bán khi server có cờ `route_fields`.
void main() {
  const routes = [DynamicFormOption(label: 'Tuyến A', value: 5)];
  List<DynamicFormField> dung(Map<String, dynamic> data) =>
      buildCustomerFormFields({'data': data}, meta: const CustomerMetaData(), routeOptions: routes, defaultRouteId: 5);

  group('ô Tuyến bán hàng theo cấu hình', () {
    const ten = {'code': 'name', 'label': 'Tên', 'input_type': 'text', 'kind': 'fixed', 'required': true};

    test('server có cờ + có dòng ⇒ ô chọn tuyến theo cấu hình (nhãn, ẩn trên app), điền sẵn tuyến mặc định', () {
      final f = dung({
        'route_fields': true,
        'fields': [
          ten,
          {'code': 'route_ids', 'label': 'Tuyến viếng thăm', 'input_type': 'ref_dms_route', 'kind': 'fixed', 'required': true, 'hidden_on_app': true},
        ],
      }).firstWhere((x) => x.code == 'route_ids');
      expect(f.type, DynamicFormFieldType.singleChoice);
      expect(f.label, 'Tuyến viếng thăm');
      expect(f.hiddenOnApp, isTrue);
      expect(f.initialValue, 5);
    });

    test('server có cờ, admin ẩn hẳn (vắng dòng) ⇒ KHÔNG tự chèn; server cũ (không cờ) ⇒ chèn như trước', () {
      expect(dung({'route_fields': true, 'fields': [ten]}).any((x) => x.code == 'route_ids'), isFalse);
      expect(dung({'fields': [ten]}).any((x) => x.code == 'route_ids'), isTrue);
    });
  });

  testWidgets('form điểm bán: ô ẩn có giá trị không vẽ, giá trị vẫn gửi; ô ẩn bắt buộc mà TRỐNG hiện ra lúc Lưu', (tester) async {
    const fields = [
      DynamicFormField(code: 'name', label: 'Tên điểm bán', type: DynamicFormFieldType.text, isRequired: true),
      DynamicFormField(code: 'ghi_chu', label: 'Ghi chú ẩn', type: DynamicFormFieldType.text, isRequired: true, hiddenOnApp: true),
      DynamicFormField(code: 'kenh', label: 'Kênh ẩn', type: DynamicFormFieldType.singleChoice, hiddenOnApp: true, initialValue: 3,
          options: [DynamicFormOption(label: 'K3', value: 3)]),
    ];
    final key = GlobalKey<DynamicFormBuilderState>();
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: DynamicFormBuilder(key: key, fields: fields, initialData: const {'name': 'A'}))),
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ghi chú ẩn'), findsNothing);
    expect(find.textContaining('Kênh ẩn'), findsNothing);
    expect(key.currentState!.getFormData(), containsPair('kenh', 3));

    // Bắt buộc mà nguồn tự điền không ra giá trị ⇒ không để một ô vô hình chặn Lưu: hiện ra + báo lỗi như ô thường.
    expect(key.currentState!.validate(focusFirstError: false), isFalse);
    await tester.pumpAndSettle();
    expect(find.textContaining('Ghi chú ẩn'), findsWidgets);
    expect(find.textContaining('Kênh ẩn'), findsNothing, reason: 'ô ẩn đã có giá trị vẫn ẩn');
    key.currentState!.updateFieldValue('ghi_chu', 'x');
    await tester.pumpAndSettle();
    expect(find.textContaining('Ghi chú ẩn'), findsWidgets, reason: 'đã hiện thì giữ hiện, không biến mất khi gõ');
    expect(key.currentState!.validate(focusFirstError: false), isTrue);
  });

  testWidgets('biểu mẫu thị trường: ô ẩn trên app không vẽ, không kiểm, giá trị điền sẵn vẫn gửi', (tester) async {
    final an = MarketFormBlockModel.fromJson(const {
      'ref': 'kenh',
      'type': 'field',
      'required': true,
      'hidden_on_app': true,
      'resolved': {'code': 'kenh', 'label': 'Kênh ẩn', 'input_type': 'text', 'config': {'default': 'K3'}},
    }).toEntity();
    expect(an.hiddenOnApp, isTrue);
    expect(MarketFormBlockModel.fromJson(const {
      'ref': 'kenh',
      'type': 'field',
      'resolved': {'code': 'kenh', 'label': 'x', 'input_type': 'text'},
    }).toJson().containsKey('hidden_on_app'), isFalse);
    const hien = MarketFormBlockEntity(
      ref: 'ten',
      type: 'field',
      required: false,
      resolved: MarketFormResolvedEntity(code: 'ten', label: 'Tên', inputType: 'text'),
    );
    final key = GlobalKey<MarketFormRendererState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: MarketFormRenderer(key: key, blocks: [hien, an]))),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kênh ẩn'), findsNothing);
    expect(find.byType(TextFormField), findsOneWidget, reason: 'chỉ ô Tên hiện; ô ẩn nằm ngoài màn hình');
    expect(find.byType(TextFormField, skipOffstage: false), findsNWidgets(2), reason: 'ô ẩn vẫn sống để tự điền');
    expect(key.currentState!.validateAndGetAnswers(), containsPair('kenh', 'K3'));
  });

  testWidgets('biểu mẫu thị trường: mục mà mọi ô nhập đều ẩn ⇒ không vẽ tiêu đề mục trơ', (tester) async {
    MarketFormBlockEntity o(String code, String type, {bool an = false}) => MarketFormBlockEntity(
          ref: code,
          type: 'field',
          required: false,
          hiddenOnApp: an,
          resolved: MarketFormResolvedEntity(code: code, label: code, inputType: type),
        );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MarketFormRenderer(blocks: [
            o('Muc An', 'heading'),
            o('o_an', 'text', an: true),
            o('Muc Hien', 'heading'),
            o('o_hien', 'text'),
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Muc An'), findsNothing);
    expect(find.textContaining('Muc Hien'), findsWidgets);
  });
}
