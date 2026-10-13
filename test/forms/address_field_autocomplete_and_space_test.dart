import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/core/dynamic_form/widgets/long_text_field_widget.dart';
import 'package:vthm_dms/core/dynamic_form/widgets/text_field_widget.dart';
import 'package:vthm_dms/core/widgets/location_field_widget.dart';

void main() {
  group('Address field space typing & Goong Autocomplete tests', () {
    testWidgets('LocationFieldWidget allows typing spaces naturally without stripping', (tester) async {
      Map<String, dynamic>? updatedValue;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return LocationFieldWidget(
                    label: 'Địa chỉ kho',
                    isRequired: true,
                    value: updatedValue,
                    onChanged: (val) {
                      setState(() {
                        updatedValue = val;
                      });
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      // Nhập '12 ' (có khoảng trắng)
      await tester.enterText(textFieldFinder, '12 ');
      await tester.pump();

      // Kiểm tra controller vẫn giữ nguyên khoảng trắng
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.controller?.text, '12 ');
      expect(updatedValue?['address'], '12 ');

      // Nhập tiếp '12 Lý Thường Kiệt '
      await tester.enterText(textFieldFinder, '12 Lý Thường Kiệt ');
      await tester.pump();

      final updatedTextField = tester.widget<TextField>(textFieldFinder);
      expect(updatedTextField.controller?.text, '12 Lý Thường Kiệt ');
      expect(updatedValue?['address'], '12 Lý Thường Kiệt ');
    });

    testWidgets('DynamicLongTextFieldWidget allows typing spaces naturally without stripping', (tester) async {
      String? currentValue;

      const field = DynamicFormField(
        code: 'address',
        label: 'Địa chỉ giao dịch',
        type: DynamicFormFieldType.longText,
        isRequired: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return DynamicLongTextFieldWidget(
                  field: field,
                  value: currentValue,
                  onChanged: (val) {
                    setState(() {
                      currentValue = val;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      // Nhập 'Số 10 ' có dấu space
      await tester.enterText(textFieldFinder, 'Số 10 ');
      await tester.pump();

      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.controller?.text, 'Số 10 ');
      expect(currentValue, 'Số 10 ');
    });

    testWidgets('DynamicTextFieldWidget allows typing spaces naturally without stripping', (tester) async {
      String? currentValue;

      const field = DynamicFormField(
        code: 'name',
        label: 'Tên điểm bán',
        type: DynamicFormFieldType.text,
        isRequired: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return DynamicTextFieldWidget(
                  field: field,
                  value: currentValue,
                  onChanged: (val) {
                    setState(() {
                      currentValue = val;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      // Nhập 'Cửa hàng ' có space
      await tester.enterText(textFieldFinder, 'Cửa hàng ');
      await tester.pump();

      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.controller?.text, 'Cửa hàng ');
      expect(currentValue, 'Cửa hàng ');
    });

    testWidgets('DynamicFormBuilder does NOT render "Có trường bắt buộc" badge in section headers', (tester) async {
      const fields = [
        DynamicFormField(
          code: 'name',
          label: 'Tên điểm bán',
          type: DynamicFormFieldType.text,
          isRequired: true,
          section: 'Thông tin chung',
        ),
        DynamicFormField(
          code: 'address',
          label: 'Địa chỉ giao dịch',
          type: DynamicFormFieldType.longText,
          isRequired: false,
          section: 'Địa chỉ & Vị trí',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicFormBuilder(
              fields: fields,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Không còn hiển thị nhãn 'Có trường bắt buộc'
      expect(find.text('Có trường bắt buộc'), findsNothing);

      // Trường bắt buộc vẫn có dấu * đỏ
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Tên điểm bán *'),
        ),
        findsOneWidget,
      );
    });
  });
}
