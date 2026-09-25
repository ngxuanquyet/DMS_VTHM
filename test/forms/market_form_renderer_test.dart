import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';

void main() {
  group('MarketFormRenderer Widget Tests', () {
    final blocks = [
      const MarketFormBlockEntity(
        ref: 'muc_a',
        type: 'field',
        required: false,
        colSpan: 12,
        resolved: MarketFormResolvedEntity(
          code: 'muc_a',
          label: 'A. Thông tin trưng bày',
          inputType: 'heading',
        ),
      ),
      const MarketFormBlockEntity(
        ref: 'gia_ban',
        type: 'field',
        required: true,
        colSpan: 12,
        resolved: MarketFormResolvedEntity(
          code: 'gia_ban',
          label: 'Giá bán',
          inputType: 'currency',
          validation: MarketFormValidationEntity(min: 0, max: 500000),
        ),
      ),
      const MarketFormBlockEntity(
        ref: 'vi_tri',
        type: 'field',
        required: false,
        colSpan: 12,
        resolved: MarketFormResolvedEntity(
          code: 'vi_tri',
          label: 'Vị trí trưng bày',
          inputType: 'select',
          options: [
            MarketFormOptionEntity(value: 'quay', label: 'Quầy chính'),
            MarketFormOptionEntity(value: 'cua', label: 'Cửa ra vào'),
          ],
        ),
      ),
    ];

    testWidgets('Renders all block labels and inputs correctly', (tester) async {
      final key = GlobalKey<MarketFormRendererState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarketFormRenderer(
                key: key,
                blocks: blocks,
              ),
            ),
          ),
        ),
      );

      // Verify Heading is displayed
      expect(find.text('A. Thông tin trưng bày'), findsOneWidget);

      // Verify Currency label is displayed via RichText
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Giá bán'),
        ),
        findsOneWidget,
      );

      // Verify Select label is displayed via RichText
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Vị trí trưng bày'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Fails validation when required currency field is empty', (tester) async {
      final key = GlobalKey<MarketFormRendererState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarketFormRenderer(
                key: key,
                blocks: blocks,
              ),
            ),
          ),
        ),
      );

      final answers = key.currentState?.validateAndGetAnswers();
      await tester.pump();

      // Validation fails because gia_ban is required
      expect(answers, isNull);
      expect(find.text('Giá bán không được để trống.'), findsOneWidget);
    });

    testWidgets('Succeeds validation and omits presentation fields', (tester) async {
      final key = GlobalKey<MarketFormRendererState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarketFormRenderer(
                key: key,
                blocks: blocks,
                initialAnswers: const {
                  'gia_ban': 185000,
                  'vi_tri': 'quay',
                },
              ),
            ),
          ),
        ),
      );

      final answers = key.currentState?.validateAndGetAnswers();

      expect(answers, isNotNull);
      expect(answers!['gia_ban'], 185000);
      expect(answers['vi_tri'], 'quay');
      // Heading must never be in answers
      expect(answers.containsKey('muc_a'), isFalse);
    });

    testWidgets('show_if: Ô bắt buộc và Heading bị ẩn thì không hiển thị và được MIỄN required (§5, §6)', (tester) async {
      final conditionalBlocks = [
        const MarketFormBlockEntity(
          ref: 'dms_ly_do_vt',
          type: 'field',
          required: false,
          colSpan: 12,
          resolved: MarketFormResolvedEntity(
            code: 'dms_ly_do_vt',
            label: 'Lý do viếng thăm',
            inputType: 'select',
            options: [
              MarketFormOptionEntity(value: 'A', label: 'Lý do A'),
              MarketFormOptionEntity(value: 'B', label: 'Lý do B'),
            ],
          ),
        ),
        const MarketFormBlockEntity(
          ref: 'dms_muc_trung_bay',
          type: 'field',
          required: false,
          colSpan: 12,
          showIf: {
            'any': [
              {'field': 'dms_ly_do_vt', 'op': 'in', 'value': ['B', 'C']}
            ]
          },
          resolved: MarketFormResolvedEntity(
            code: 'dms_muc_trung_bay',
            label: 'Mục Trưng Bày',
            inputType: 'heading',
          ),
        ),
        const MarketFormBlockEntity(
          ref: 'dms_so_ke',
          type: 'field',
          required: true, // BẮT BUỘC
          colSpan: 12,
          showIf: {
            'any': [
              {'field': 'dms_ly_do_vt', 'op': 'in', 'value': ['B', 'C']}
            ]
          },
          resolved: MarketFormResolvedEntity(
            code: 'dms_so_ke',
            label: 'Số kệ',
            inputType: 'number',
          ),
        ),
      ];

      final key = GlobalKey<MarketFormRendererState>();

      // Ban đầu: dms_ly_do_vt = 'A' => Mục trưng bày và Số kệ ĐỀU ẨN
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarketFormRenderer(
                key: key,
                blocks: conditionalBlocks,
                initialAnswers: const {
                  'dms_ly_do_vt': 'A',
                  'dms_so_ke': 10, // Dù trước đó có gõ số 10 nhưng ô bị ẩn
                },
              ),
            ),
          ),
        ),
      );

      // Verify Mục Trưng Bày và Số kệ KHÔNG hiển thị trên giao diện (§6)
      expect(find.text('Mục Trưng Bày'), findsNothing);
      expect(find.text('Số kệ'), findsNothing);

      // Khi validate: Số kệ là required nhưng đang ẨN => form VẪN HỢP LỆ (§5)
      // Và giá trị 'dms_so_ke' KHÔNG được gửi lên (§5 & §9)
      final submittedAnswers = key.currentState?.validateAndGetAnswers();
      expect(submittedAnswers, isNotNull);
      expect(submittedAnswers!['dms_ly_do_vt'], 'A');
      expect(submittedAnswers.containsKey('dms_so_ke'), isFalse); // Không gửi ô ẩn!
    });
  });
}
