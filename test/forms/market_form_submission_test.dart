import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/forms/data/models/market_form_submission_model.dart';

void main() {
  group('MarketFormSubmissionModel Tests (§2 Spec 23/09/2026)', () {
    test('sanitizeAnswers removes nulls, empty values and presentation codes', () {
      final raw = {
        'muc_a': 'Heading value that should not be sent',
        'gia_ban': 185000,
        'vi_tri': 'quay',
        'ghi_chu': '',
        'khong_dien': null,
        'danh_sach_rong': [],
        'lua_chon': ['opt1', 'opt2'],
        'co_trung_bay': true,
      };

      final sanitized = MarketFormSubmissionModel.sanitizeAnswers(
        raw,
        presentationCodes: {'muc_a'},
      );

      // muc_a bị loại vì là trường trình bày
      expect(sanitized.containsKey('muc_a'), isFalse);
      // ghi_chu bị loại vì rỗng
      expect(sanitized.containsKey('ghi_chu'), isFalse);
      // khong_dien bị loại vì null
      expect(sanitized.containsKey('khong_dien'), isFalse);
      // danh_sach_rong bị loại vì rỗng
      expect(sanitized.containsKey('danh_sach_rong'), isFalse);

      // Các trường hợp lệ được giữ lại
      expect(sanitized['gia_ban'], 185000);
      expect(sanitized['vi_tri'], 'quay');
      expect(sanitized['lua_chon'], ['opt1', 'opt2']);
      expect(sanitized['co_trung_bay'], isTrue);
    });

    test('toJson excludes visit_id for kind=collect', () {
      final submission = MarketFormSubmissionModel(
        configId: 174,
        visitId: null, // collect không gửi visit_id
        customerId: null,
        answers: {'gia_ban': 185000},
        submitLat: 16.0678,
        submitLng: 108.2208,
        submitAddress: '12 Nguyễn Văn Linh, Đà Nẵng',
      );

      final json = submission.toJson();

      expect(json['config_id'], 174);
      expect(json.containsKey('visit_id'), isFalse);
      expect(json['answers'], {'gia_ban': 185000});
      expect(json['client_uuid'], isNotEmpty);
      expect(json['client_time'], isNotEmpty);
      expect(json['is_offline_sync'], isFalse);
    });

    test('toJson includes visit_id and customer_id for kind=survey', () {
      final submission = MarketFormSubmissionModel(
        configId: 174,
        visitId: 41066,
        customerId: 8338,
        answers: {'gia_ban': 185000, 'vi_tri': 'quay'},
        isOfflineSync: true,
      );

      final json = submission.toJson();

      expect(json['config_id'], 174);
      expect(json['visit_id'], 41066);
      expect(json['customer_id'], 8338);
      expect(json['is_offline_sync'], isTrue);
      expect(json['client_uuid'], isNotEmpty);
    });
  });
}
