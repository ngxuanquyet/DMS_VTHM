import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/forms/data/models/market_form_model.dart';

void main() {
  Map<String, dynamic> json({Object? description}) => {
        'config_id': 1,
        'form_id': 2,
        'code': 'ks',
        'name': 'Khảo sát',
        if (description != null) 'description': description,
        'kind': 'survey',
        'is_required': false,
        'sort_order': 0,
        'schema': {'blocks': []},
      };

  test('mô tả biểu mẫu từ API đi tới entity và giữ qua cache offline (toJson)', () {
    final model = MarketFormConfigModel.fromJson(json(description: '  Chụp kệ trước khi điền  '));
    expect(model.toEntity().descriptionText, 'Chụp kệ trước khi điền');

    final cached = MarketFormConfigModel.fromJson(model.toJson());
    expect(cached.toEntity().description, '  Chụp kệ trước khi điền  ');
  });

  test('không có / rỗng thì không hiện', () {
    expect(MarketFormConfigModel.fromJson(json()).toEntity().descriptionText, isNull);
    expect(MarketFormConfigModel.fromJson(json(description: '   ')).toEntity().descriptionText, isNull);
  });
}
