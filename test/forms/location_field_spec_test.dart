import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/core/widgets/location_field_widget.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_dynamic_column.dart';
import 'package:vthm_dms/features/forms/data/models/market_form_submission_model.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/domain/services/dynamic_rule_evaluator.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';

void main() {
  group('Location Field Specification 13/10/2026 Tests', () {
    test('Schema Recognizer & Enum Mapping', () {
      // 1. DynamicFormFieldType mapping
      expect(DynamicFormFieldType.fromString('location'), DynamicFormFieldType.location);
      expect(DynamicFormFieldType.fromString('LOCATION'), DynamicFormFieldType.location);

      // 2. MarketFormResolvedEntity and MarketFormBlockEntity isLocation getter
      const block = MarketFormBlockEntity(
        ref: 'dms_vi_tri',
        type: 'field',
        required: true,
        resolved: MarketFormResolvedEntity(
          code: 'dms_vi_tri',
          label: 'Vị trí kho',
          inputType: 'location',
        ),
      );
      expect(block.resolved.isLocation, isTrue);
      expect(block.isLocation, isTrue);

      // 3. CustomerDynamicColumn isLocation getter
      const col = CustomerDynamicColumn(
        code: 'crm_vi_tri',
        label: 'Vị trí điểm bán',
        inputType: 'location',
        source: 'own',
      );
      expect(col.isLocation, isTrue);
    });

    test('DynamicRuleEvaluator.isEmptyValue for Location maps (§3)', () {
      // Null / empty
      expect(DynamicRuleEvaluator.isEmptyValue(null), isTrue);
      expect(DynamicRuleEvaluator.isEmptyValue({}), isTrue);
      expect(DynamicRuleEvaluator.isEmptyValue({'address': '', 'lat': null, 'lng': null}), isTrue);
      expect(DynamicRuleEvaluator.isEmptyValue({'address': '   ', 'lat': null, 'lng': null}), isTrue);

      // Non-empty location
      expect(
        DynamicRuleEvaluator.isEmptyValue({
          'address': '12 Lý Thường Kiệt',
          'lat': 21.0285123,
          'lng': 105.8542,
          'accuracy': 8.3,
          'mock': false,
        }),
        isFalse,
      );
      expect(
        DynamicRuleEvaluator.isEmptyValue({
          'lat': 21.0285123,
          'lng': 105.8542,
        }),
        isFalse,
      );
    });

    test('MarketFormSubmissionModel.sanitizeAnswers normalizes location (§3)', () {
      final raw = {
        'muc_a': {
          'address': '  12 Lý Thường Kiệt, Hoàn Kiếm  ',
          'lat': 21.0285123456,
          'lng': 105.85420001,
          'accuracy': 8.26,
          'mock': false,
          'extra_key_altitude': 100, // Thừa theo §3, phải bỏ
        },
        'empty_loc': {
          'address': '',
          'lat': null,
          'lng': null,
        },
      };

      final sanitized = MarketFormSubmissionModel.sanitizeAnswers(raw);

      // Empty loc is removed
      expect(sanitized.containsKey('empty_loc'), isFalse);

      // Valid loc is normalized
      expect(sanitized.containsKey('muc_a'), isTrue);
      final loc = sanitized['muc_a'] as Map<String, dynamic>;
      expect(loc['address'], '12 Lý Thường Kiệt, Hoàn Kiếm');
      expect(loc['lat'], 21.0285123); // Rounded to 7 decimal places
      expect(loc['lng'], 105.8542);
      expect(loc['accuracy'], 8.3); // Rounded to 1 decimal place
      expect(loc['mock'], isFalse);
      expect(loc.containsKey('extra_key_altitude'), isFalse); // Stripped extra keys
    });

    testWidgets('LocationFieldWidget UI rendering & ReadOnly mode (§2, §5)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LocationFieldWidget(
                label: 'Vị trí cửa hàng',
                isRequired: true,
                value: const {
                  'address': '12 Lý Thường Kiệt',
                  'lat': 21.0285123,
                  'lng': 105.8542,
                  'accuracy': 8.3,
                  'mock': true,
                },
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Verify label with RichText
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Vị trí cửa hàng'),
        ),
        findsOneWidget,
      );
      expect(find.text('Vị trí & GPS'), findsOneWidget);

      // Verify address text field
      expect(find.text('12 Lý Thường Kiệt'), findsOneWidget);

      // Verify coordinates displayed with ±accuracy m (GPS giả badge removed for silent fraud check)
      expect(find.textContaining('21.028512, 105.854200'), findsOneWidget);
      expect(find.text('(±8.3 m)'), findsOneWidget);
      expect(find.text('GPS giả'), findsNothing);

      // Button says "Lấy lại vị trí" when coordinates already exist
      expect(find.text('Lấy lại vị trí'), findsOneWidget);

      // Test ReadOnly mode
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LocationFieldWidget(
                label: 'Vị trí kho',
                isReadOnly: true,
                value: const {
                  'address': '12 Lý Thường Kiệt',
                  'lat': 21.0285123,
                  'lng': 105.8542,
                },
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // In readOnly mode, "Lấy vị trí" button is hidden
      expect(find.text('Lấy vị trí'), findsNothing);
      expect(find.text('Lấy lại vị trí'), findsNothing);
    });

    testWidgets('MarketFormRenderer: empty required location fails validation (§4)', (tester) async {
      final key = GlobalKey<MarketFormRendererState>();
      final blocks = [
        const MarketFormBlockEntity(
          ref: 'loc_field',
          type: 'field',
          required: true,
          resolved: MarketFormResolvedEntity(
            code: 'loc_field',
            label: 'Toạ độ kho hàng',
            inputType: 'location',
          ),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MarketFormRenderer(
                key: key,
                blocks: blocks,
                initialAnswers: const {},
              ),
            ),
          ),
        ),
      );

      final answers = key.currentState!.validateAndGetAnswers();
      await tester.pumpAndSettle();
      expect(answers, isNull);
      expect(find.text('Toạ độ kho hàng không được để trống.'), findsOneWidget);
    });

    testWidgets('MarketFormRenderer: only address fails validation (§4)', (tester) async {
      final key = GlobalKey<MarketFormRendererState>();
      final blocks = [
        const MarketFormBlockEntity(
          ref: 'loc_field',
          type: 'field',
          required: true,
          resolved: MarketFormResolvedEntity(
            code: 'loc_field',
            label: 'Toạ độ kho hàng',
            inputType: 'location',
          ),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MarketFormRenderer(
                key: key,
                blocks: blocks,
                initialAnswers: const {
                  'loc_field': {
                    'address': '12 Lý Thường Kiệt',
                    'lat': null,
                    'lng': null,
                  },
                },
              ),
            ),
          ),
        ),
      );

      final answers = key.currentState!.validateAndGetAnswers();
      await tester.pumpAndSettle();
      expect(answers, isNull);
      expect(find.text('Toạ độ kho hàng cần có toạ độ GPS — bấm "Lấy vị trí".'), findsOneWidget);
    });

    testWidgets('MarketFormRenderer: out of bounds coordinates fails validation (§4)', (tester) async {
      final key = GlobalKey<MarketFormRendererState>();
      final blocks = [
        const MarketFormBlockEntity(
          ref: 'loc_field',
          type: 'field',
          required: true,
          resolved: MarketFormResolvedEntity(
            code: 'loc_field',
            label: 'Toạ độ kho hàng',
            inputType: 'location',
          ),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MarketFormRenderer(
                key: key,
                blocks: blocks,
                initialAnswers: const {
                  'loc_field': {
                    'address': '12 Lý Thường Kiệt',
                    'lat': 121.0, // Invalid latitude > 90
                    'lng': 105.8542,
                  },
                },
              ),
            ),
          ),
        ),
      );

      final answers = key.currentState!.validateAndGetAnswers();
      await tester.pumpAndSettle();
      expect(answers, isNull);
      expect(find.text('Toạ độ kho hàng có giá trị không hợp lệ.'), findsOneWidget);
    });

    testWidgets('MarketFormRenderer: valid location succeeds (§4)', (tester) async {
      final key = GlobalKey<MarketFormRendererState>();
      final blocks = [
        const MarketFormBlockEntity(
          ref: 'loc_field',
          type: 'field',
          required: true,
          resolved: MarketFormResolvedEntity(
            code: 'loc_field',
            label: 'Toạ độ kho hàng',
            inputType: 'location',
          ),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MarketFormRenderer(
                key: key,
                blocks: blocks,
                initialAnswers: const {
                  'loc_field': {
                    'address': '12 Lý Thường Kiệt',
                    'lat': 21.0285123,
                    'lng': 105.8542,
                    'accuracy': 8.3,
                    'mock': false,
                  },
                },
              ),
            ),
          ),
        ),
      );

      final answers = key.currentState!.validateAndGetAnswers();
      expect(answers, isNotNull);
      expect(answers!['loc_field']['lat'], 21.0285123);
      expect(answers['loc_field']['lng'], 105.8542);
    });
  });
}
