import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';

void main() {
  group('DynamicFormBuilder Unwrap Dynamic Section Tests', () {
    testWidgets('Dynamic fields in "Thông tin mở rộng (Động)" do NOT render Card header and render fields directly', (tester) async {
      final fields = [
        const DynamicFormField(
          code: 'name',
          label: 'Tên điểm bán',
          type: DynamicFormFieldType.text,
          isRequired: true,
          section: 'Thông tin chung',
        ),
        const DynamicFormField(
          code: 'mw_dientich',
          label: 'Diện tích mặt bằng',
          type: DynamicFormFieldType.number,
          section: 'Thông tin mở rộng (Động)',
        ),
        const DynamicFormField(
          code: 'mw_soke',
          label: 'Số lượng kệ trưng bày',
          type: DynamicFormFieldType.text,
          section: 'Thông tin mở rộng (Động)',
        ),
        const DynamicFormField(
          code: 'phone',
          label: 'Số điện thoại',
          type: DynamicFormFieldType.text,
          section: 'Thông tin liên hệ',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicFormBuilder(
                fields: fields,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Header card của section Thông tin chung và Thông tin liên hệ vẫn hiển thị bình thường
      expect(find.text('Thông tin chung'), findsOneWidget);
      expect(find.text('Thông tin liên hệ'), findsOneWidget);

      // 2. Card header của "Thông tin mở rộng (Động)" bị BỎ HẲN, không hiển thị
      expect(find.text('Thông tin mở rộng (Động)'), findsNothing);
      expect(find.text('Thông tin mở rộng'), findsNothing);

      // 3. Các trường động vẫn được vẽ trực tiếp ra ngoài giao diện
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Diện tích mặt bằng'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Số lượng kệ trưng bày'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Tên điểm bán *'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Số điện thoại'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Fields with dynamic section alias or empty section render directly outside card', (tester) async {
      final fields = [
        const DynamicFormField(
          code: 'custom_attr',
          label: 'Đặc điểm nhận diện',
          type: DynamicFormFieldType.text,
          section: 'Trường mở rộng',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicFormBuilder(
                fields: fields,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Card header "Trường mở rộng" không hiển thị
      expect(find.text('Trường mở rộng'), findsNothing);

      // Field vẽ trực tiếp ra ngoài
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Đặc điểm nhận diện'),
        ),
        findsOneWidget,
      );
    });
  });
}
