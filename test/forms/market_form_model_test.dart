import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/forms/data/models/market_form_model.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';

void main() {
  group('MarketFormConfigModel Parsing Tests (§1 Spec 23/09/2026)', () {
    final sampleJson = {
      'config_id': 174,
      'form_id': 9809,
      'code': 'ks_gia_thang_9',
      'name': 'Khảo sát giá tháng 9',
      'kind': 'survey',
      'is_required': true,
      'sort_order': 1,
      'schema': {
        'blocks': [
          {
            'ref': 'muc_a',
            'type': 'field',
            'required': false,
            'col_span': 12,
            'resolved': {
              'code': 'muc_a',
              'label': 'A. Thông tin trưng bày',
              'input_type': 'heading',
              'config': [],
              'description': null,
            }
          },
          {
            'ref': 'gia_ban',
            'type': 'field',
            'required': true,
            'col_span': 12,
            'resolved': {
              'code': 'gia_ban',
              'label': 'Giá bán',
              'input_type': 'currency',
              'config': {'validation': {'min': 0, 'max': 500000}},
              'description': 'Đơn vị tính VNĐ',
            }
          },
          {
            'ref': 'vi_tri',
            'type': 'field',
            'required': false,
            'col_span': 12,
            'resolved': {
              'code': 'vi_tri',
              'label': 'Vị trí trưng bày',
              'input_type': 'select',
              'config': {
                'options': [
                  {'value': 'quay', 'label': 'Quầy chính'},
                  {'value': 'cua', 'label': 'Cửa ra vào'},
                ]
              }
            }
          }
        ]
      }
    };

    test('Parses complete form configuration accurately', () {
      final model = MarketFormConfigModel.fromJson(sampleJson);

      expect(model.configId, 174);
      expect(model.formId, 9809);
      expect(model.code, 'ks_gia_thang_9');
      expect(model.name, 'Khảo sát giá tháng 9');
      expect(model.kind, 'survey');
      expect(model.isRequired, isTrue);
      expect(model.sortOrder, 1);
      expect(model.schema.blocks.length, 3);

      // Block 0: Heading
      final b0 = model.schema.blocks[0];
      expect(b0.ref, 'muc_a');
      expect(b0.required, isFalse);
      expect(b0.resolved.inputType, 'heading');
      expect(b0.resolved.label, 'A. Thông tin trưng bày');

      // Block 1: Currency with validation
      final b1 = model.schema.blocks[1];
      expect(b1.ref, 'gia_ban');
      expect(b1.required, isTrue);
      expect(b1.resolved.inputType, 'currency');
      expect(b1.resolved.description, 'Đơn vị tính VNĐ');

      // Block 2: Select with options
      final b2 = model.schema.blocks[2];
      expect(b2.ref, 'vi_tri');
      expect(b2.resolved.inputType, 'select');
    });

    test('Converts to MarketFormConfigEntity properly', () {
      final model = MarketFormConfigModel.fromJson(sampleJson);
      final entity = model.toEntity();

      expect(entity.isSurvey, isTrue);
      expect(entity.isCollect, isFalse);
      expect(entity.blocksCount, 3);

      final headingBlock = entity.schema.blocks[0];
      expect(headingBlock.isPresentation, isTrue);

      final currencyBlock = entity.schema.blocks[1];
      expect(currencyBlock.isPresentation, isFalse);
      expect(currencyBlock.resolved.validation?.min, 0);
      expect(currencyBlock.resolved.validation?.max, 500000);

      final selectBlock = entity.schema.blocks[2];
      expect(selectBlock.resolved.options.length, 2);
      expect(selectBlock.resolved.options[0].value, 'quay');
      expect(selectBlock.resolved.options[0].label, 'Quầy chính');
    });
  });
}

extension on MarketFormConfigEntity {
  int get blocksCount => schema.blocks.length;
}
