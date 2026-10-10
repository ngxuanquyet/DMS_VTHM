import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';

void main() {
  group('Add Customer Keyboard Dismiss & Auto-Focus Tests', () {
    testWidgets('Tapping outside an active input dismisses keyboard focus', (tester) async {
      final fields = [
        const DynamicFormField(
          code: 'name',
          label: 'Tên điểm bán',
          type: DynamicFormFieldType.text,
          isRequired: true,
        ),
        const DynamicFormField(
          code: 'phone',
          label: 'Số điện thoại',
          type: DynamicFormFieldType.text,
        ),
      ];

      final formKey = GlobalKey<DynamicFormBuilderState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
              },
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: DynamicFormBuilder(
                        key: formKey,
                        fields: fields,
                      ),
                    ),
                  ),
                  Container(
                    key: const ValueKey('outside_tap_area'),
                    height: 80,
                    width: double.infinity,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Focus into first field 'name'
      final nameTextField = find.byType(TextField).first;
      await tester.tap(nameTextField);
      await tester.pump();

      // Ensure that a TextField has focus
      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);

      // Tap on outside tap area
      await tester.tap(find.byKey(const ValueKey('outside_tap_area')));
      await tester.pump();

      // Keyboard/focus should be unfocused
      final currentFocus = FocusManager.instance.primaryFocus;
      expect(currentFocus == null || !currentFocus.hasFocus || currentFocus is FocusScopeNode, isTrue);
    });

    testWidgets('DynamicFormBuilder validate() automatically focuses on the first invalid required field', (tester) async {
      final fields = [
        const DynamicFormField(
          code: 'name',
          label: 'Tên điểm bán',
          type: DynamicFormFieldType.text,
          isRequired: true,
        ),
        const DynamicFormField(
          code: 'phone',
          label: 'Số điện thoại',
          type: DynamicFormFieldType.text,
          isRequired: true,
        ),
      ];

      final formKey = GlobalKey<DynamicFormBuilderState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicFormBuilder(
                key: formKey,
                fields: fields,
              ),
            ),
          ),
        ),
      );

      // Initially, validate
      final isValid = formKey.currentState!.validate();
      expect(isValid, isFalse);

      await tester.pumpAndSettle();

      // Error messages visible
      expect(find.text('Tên điểm bán là bắt buộc'), findsOneWidget);
      expect(find.text('Số điện thoại là bắt buộc'), findsOneWidget);

      // First invalid field 'name' receives focus
      final nameTextField = tester.widget<TextField>(find.byType(TextField).first);
      expect(nameTextField.focusNode?.hasFocus, isTrue);

      // Fill 'name' field
      await tester.enterText(find.byType(TextField).first, 'Đại lý ABC');
      await tester.pumpAndSettle();

      // Validate again: now 'name' is filled, so first invalid field is 'phone'
      final isValid2 = formKey.currentState!.validate();
      expect(isValid2, isFalse);

      await tester.pumpAndSettle();

      final phoneTextField = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(phoneTextField.focusNode?.hasFocus, isTrue);
    });

    testWidgets('focusField() manually focuses and scrolls to field', (tester) async {
      final fields = [
        const DynamicFormField(
          code: 'name',
          label: 'Tên điểm bán',
          type: DynamicFormFieldType.text,
        ),
        const DynamicFormField(
          code: 'notes',
          label: 'Ghi chú',
          type: DynamicFormFieldType.longText,
        ),
      ];

      final formKey = GlobalKey<DynamicFormBuilderState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicFormBuilder(
                key: formKey,
                fields: fields,
              ),
            ),
          ),
        ),
      );

      // Request focus for notes field
      formKey.currentState!.focusField('notes');
      await tester.pumpAndSettle();

      // Check that the long text field (2nd TextField) has focus
      final notesTextField = tester.widget<TextField>(find.byType(TextField).at(1));
      expect(notesTextField.focusNode?.hasFocus, isTrue);
    });
  });
}
