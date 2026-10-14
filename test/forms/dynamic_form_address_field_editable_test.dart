import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';

void main() {
  group('Dynamic Form Address Field Editable Tests', () {
    testWidgets('DynamicFormBuilder allows editing address field without requiring GPS coordinates', (tester) async {
      final formKey = GlobalKey<DynamicFormBuilderState>();
      final fields = [
        const DynamicFormField(
          code: 'address',
          label: 'Địa chỉ cửa hàng',
          type: DynamicFormFieldType.location,
          isRequired: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicFormBuilder(
                key: formKey,
                fields: fields,
                initialData: const {
                  'address': {
                    'address': 'Số 15 Lê Lợi, TP Huế',
                    'lat': null,
                    'lng': null,
                  },
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra ô địa chỉ hiển thị giá trị khởi tạo
      expect(find.text('Số 15 Lê Lợi, TP Huế'), findsOneWidget);

      // Validate form
      final isValid = formKey.currentState!.validate();
      expect(isValid, isTrue);

      final data = formKey.currentState!.getFormData();
      expect((data['address'] as Map)['address'], 'Số 15 Lê Lợi, TP Huế');
      expect(find.textContaining('cần có toạ độ GPS'), findsNothing);
    });

    testWidgets('MarketFormRenderer allows editing pure address block without requiring GPS coordinates', (tester) async {
      final key = GlobalKey<MarketFormRendererState>();
      const blocks = [
        MarketFormBlockEntity(
          ref: 'dia_chi_kho',
          type: 'field',
          required: true,
          resolved: MarketFormResolvedEntity(
            code: 'dia_chi_kho',
            inputType: 'address',
            label: 'Địa chỉ giao hàng',
          ),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MarketFormRenderer(
                  key: key,
                  blocks: blocks,
                  initialAnswers: const {
                    'dia_chi_kho': {
                      'address': '28 Hoàng Diệu, Đà Nẵng',
                      'lat': null,
                      'lng': null,
                    },
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra validate không bị chặn toạ độ GPS
      final answers = key.currentState!.validateAndGetAnswers();
      await tester.pumpAndSettle();

      expect(answers, isNotNull);
      expect((answers!['dia_chi_kho'] as Map)['address'], '28 Hoàng Diệu, Đà Nẵng');
      expect(find.textContaining('cần có toạ độ GPS'), findsNothing);
    });
  });
}
