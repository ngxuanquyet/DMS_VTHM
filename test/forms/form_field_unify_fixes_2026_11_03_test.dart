import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/theme/app_colors.dart';
import 'package:vthm_dms/core/dynamic_form/widgets/single_choice_field_widget.dart';
import 'package:flutter/rendering.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/core/dynamic_form/widgets/boolean_field_widget.dart';
import 'package:vthm_dms/core/dynamic_form/widgets/long_text_field_widget.dart';
import 'package:vthm_dms/core/dynamic_form/widgets/number_field_widget.dart';
import 'package:vthm_dms/core/dynamic_form/widgets/photo_field_widget.dart';
import 'package:vthm_dms/core/dynamic_form/widgets/text_field_widget.dart';
import 'package:vthm_dms/core/widgets/form_fields/form_field_parts.dart';

/// Vá sau review #24756: đổi focusNode không sập; ô số không ghi đè chữ gõ dở; viền lỗi giữ hình; huy hiệu ô.
void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));
  const so = DynamicFormField(code: 'n', label: 'Số', type: DynamicFormFieldType.number);
  const chu = DynamicFormField(code: 't', label: 'Chữ', type: DynamicFormFieldType.text);
  const dai = DynamicFormField(code: 'l', label: 'Dài', type: DynamicFormFieldType.longText);

  testWidgets('đổi focusNode của ô chữ / chữ dài / số ⇒ không LateInitializationError', (tester) async {
    Widget ve(FocusNode? a, FocusNode? b, FocusNode? c) => wrap(Column(children: [
          DynamicTextFieldWidget(field: chu, value: null, onChanged: (_) {}, focusNode: a),
          DynamicLongTextFieldWidget(field: dai, value: null, onChanged: (_) {}, focusNode: b),
          DynamicNumberFieldWidget(field: so, value: null, onChanged: (_) {}, focusNode: c),
        ]));
    final n1 = FocusNode(), n2 = FocusNode(), n3 = FocusNode();
    addTearDown(() {
      n1.dispose();
      n2.dispose();
      n3.dispose();
    });
    await tester.pumpWidget(ve(null, null, null));
    await tester.pumpWidget(ve(n1, n2, n3));
    await tester.pumpWidget(ve(null, null, null));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ô số: chữ gõ dở ("1," / "1.") không bị ghi đè; giá trị đổi từ ngoài thì đồng bộ', (tester) async {
    num? giaTri;
    late StateSetter dat;
    await tester.pumpWidget(wrap(StatefulBuilder(builder: (ctx, set) {
      dat = set;
      return DynamicNumberFieldWidget(field: so, value: giaTri, onChanged: (v) => set(() => giaTri = v));
    })));
    for (final go in ['1', '1.', '1.5', '1,']) {
      await tester.enterText(find.byType(TextField), go);
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, go);
    }
    dat(() => giaTri = 42);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '42');
  });

  test('viền ô: lỗi / khoá cùng bo góc, lỗi xuống dòng tối đa 3', () {
    final d = formFieldDecoration(isDark: false, hintText: '', errorText: 'x');
    final thuong = d.enabledBorder! as OutlineInputBorder;
    for (final b in [d.errorBorder, d.focusedErrorBorder, d.disabledBorder, d.focusedBorder]) {
      expect((b! as OutlineInputBorder).borderRadius, thuong.borderRadius);
    }
    expect((d.errorBorder! as OutlineInputBorder).borderSide.width, thuong.borderSide.width);
    expect(d.errorMaxLines, 3);
  });

  testWidgets('ô Có/Không và ô ảnh giữ huy hiệu badge; ô khoá KHÔNG còn tag "Chỉ đọc" (09/11/2026)', (tester) async {
    await tester.pumpWidget(wrap(Column(children: [
      DynamicBooleanFieldWidget(
        field: const DynamicFormField(code: 'b', label: 'Có kho', type: DynamicFormFieldType.boolean, isReadOnly: true),
        value: false,
        onChanged: (_) {},
      ),
      DynamicPhotoFieldWidget(
        field: const DynamicFormField(code: 'p', label: 'Ảnh', type: DynamicFormFieldType.photo, badge: 'Bắt buộc chụp'),
        photoPaths: const [],
        onChanged: (_) {},
      ),
    ])));
    expect(find.text('Chỉ đọc'), findsNothing);
    expect(find.text('Bắt buộc chụp'), findsOneWidget);
  });

  testWidgets('tag số ảnh nằm NGAY SAU tên ô, không bị đẩy ra mép phải (09/11/2026)', (tester) async {
    await tester.pumpWidget(wrap(DynamicPhotoFieldWidget(
      field: const DynamicFormField(code: 'p', label: 'Ảnh mặt tiền', type: DynamicFormFieldType.photo, maxPhotos: 5),
      photoPaths: const [],
      onChanged: (_) {},
    )));
    final ten = tester.getTopRight(find.text('Ảnh mặt tiền'));
    final tag = tester.getTopLeft(find.byType(FormPhotoCountBadge));
    final rong = tester.getSize(find.byType(Scaffold)).width;
    expect(tag.dx - ten.dx, inInclusiveRange(0, 20), reason: 'tag phải kề tên ô');
    expect(tag.dx, lessThan(rong / 2), reason: 'tag không còn ở mép phải');
  });

  testWidgets('ô chọn xổ xuống CHỈ ĐỌC: chữ giá trị đậm như ô thường, không mờ 38% (09/11/2026)', (tester) async {
    await tester.pumpWidget(wrap(DynamicSingleChoiceFieldWidget(
      field: const DynamicFormField(
        code: 't',
        label: 'Tuyến',
        type: DynamicFormFieldType.singleChoice,
        catalog: 'dropdown',
        isReadOnly: true,
        options: [DynamicFormOption(label: 'KA', value: 'KA'), DynamicFormOption(label: 'MB2', value: 'MB2')],
      ),
      value: 'KA',
      onChanged: (_) {},
    )));
    final p = tester.renderObject<RenderParagraph>(find.text('KA'));
    expect(p.text.style?.color, AppColors.onSurface);
  });
}
