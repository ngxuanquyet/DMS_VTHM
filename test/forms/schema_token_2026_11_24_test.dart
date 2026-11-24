import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/forms/data/models/market_form_model.dart';
import 'package:vthm_dms/features/forms/data/models/market_form_submission_model.dart';

/// #25869 (chủ hệ thống chốt 24/11/2026): `/dms/forms/available` phát `schema_token` (mốc tải biểu mẫu có chữ ký); app giữ nó
/// cùng bản biểu mẫu (kể cả bản lưu máy) và gửi lại khi nộp phiếu — phiếu ngoại tuyến được server kiểm theo bản lúc điền.
void main() {
  test('cấu hình biểu mẫu: đọc schema_token, giữ qua bản lưu máy (toJson → fromJson) và sang entity', () {
    final m = MarketFormConfigModel.fromJson({
      'config_id': 1,
      'form_id': 914,
      'code': 'create_npp',
      'name': 'NPP',
      'kind': 'collect',
      'is_required': false,
      'sort_order': 1,
      'schema': {'blocks': []},
      'schema_token': '914.1795518673.abc',
    });
    final cached = MarketFormConfigModel.fromJson(m.toJson());
    expect(cached.schemaToken, '914.1795518673.abc');
    expect(cached.toEntity().schemaToken, '914.1795518673.abc');
  });

  test('phiếu: gửi schema_token (cả bản lưu hàng đợi); null thì không gửi', () {
    MarketFormSubmissionModel p(String? token) => MarketFormSubmissionModel(
          configId: 1,
          answers: const {'ten': 'A'},
          clientUuid: 'u',
          clientTime: '2026-11-24T10:00:00+07:00',
          schemaToken: token,
        );
    final json = p('914.1.abc').toJson(includeInternal: true);
    expect(json['schema_token'], '914.1.abc');
    expect(MarketFormSubmissionModel.fromJson(json).schemaToken, '914.1.abc');
    expect(p(null).toJson().containsKey('schema_token'), isFalse);
  });
}
