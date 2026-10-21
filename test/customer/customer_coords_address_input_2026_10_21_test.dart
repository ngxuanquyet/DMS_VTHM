import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/core/dynamic_form/widgets/long_text_field_widget.dart';
import 'package:vthm_dms/core/map/app_map_location_card.dart';

/// Ô Vị trí (bản đồ + toạ độ) lưu CẢ địa chỉ: schema không có ô Địa chỉ riêng (admin ẩn) thì vẽ ô chữ Địa chỉ ngay dưới
/// bản đồ, sửa được, ghi vào khoá gốc `address` (chủ hệ thống 21/10/2026).
void main() {
  const coords = DynamicFormField(
    code: 'coords',
    label: 'Toạ độ',
    type: DynamicFormFieldType.location,
    isRequired: true,
  );

  Future<GlobalKey<DynamicFormBuilderState>> dung(
    WidgetTester tester,
    List<DynamicFormField> fields, {
    Map<String, dynamic> initialData = const {},
    GlobalKey<DynamicFormBuilderState>? giuKey,
  }) async {
    final key = giuKey ?? GlobalKey<DynamicFormBuilderState>();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicFormBuilder(key: key, fields: fields, initialData: initialData),
            ),
          ),
        ),
      ),
    );
    return key;
  }

  testWidgets('không có ô Địa chỉ riêng ⇒ ô Địa chỉ nằm dưới bản đồ, gõ được, vào formData[address]', (tester) async {
    final key = await dung(tester, [
      const DynamicFormField(code: 'name', label: 'Tên', type: DynamicFormFieldType.text),
      coords,
    ]);

    expect(find.byType(AppMapLocationCard), findsOneWidget);
    final o = find.byWidgetPredicate((w) => w is DynamicLongTextFieldWidget && w.field.code == 'address');
    expect(o, findsOneWidget);

    await tester.enterText(find.descendant(of: o, matching: find.byType(TextField)), '12 Nguyễn Huệ, Q1');
    await tester.pump();
    expect(key.currentState!.getFormData()['address'], '12 Nguyễn Huệ, Q1');
  });

  testWidgets('địa chỉ có sẵn được giữ qua lần dựng lại form (ô không thuộc danh sách field)', (tester) async {
    final fields = [coords];
    final key = await dung(tester, fields, initialData: {'address': 'Địa chỉ cũ'});
    expect(key.currentState!.getFormData()['address'], 'Địa chỉ cũ');

    // Dựng lại CÙNG form (cùng key, initialData trống) ⇒ didUpdateWidget ⇒ _initializeData(preserveExisting: true).
    await dung(tester, [...fields], giuKey: key);
    expect(key.currentState!.getFormData()['address'], 'Địa chỉ cũ');
  });

  testWidgets('schema đã có ô Địa chỉ riêng ⇒ không vẽ thêm ô thứ hai dưới bản đồ', (tester) async {
    await dung(tester, [
      const DynamicFormField(code: 'address', label: 'Địa chỉ', type: DynamicFormFieldType.longText),
      coords,
    ]);
    expect(
      find.byWidgetPredicate((w) => w is DynamicLongTextFieldWidget && w.field.code == 'address'),
      findsOneWidget,
    );
  });
}
