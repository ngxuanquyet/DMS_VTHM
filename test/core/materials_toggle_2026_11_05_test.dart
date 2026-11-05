import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/rules/mobile_rules_model.dart';
import 'package:vthm_dms/features/customer/presentation/screens/add_customer_screen.dart';

/// Bật/tắt khai vật tư (chốt 05/11/2026): công tắc "Cập nhật vật tư khi viếng thăm" (luật di động) và ô ảo "Vật tư tại điểm"
/// ở Cấu hình trường điểm bán (bước vật tư lúc tạo).
void main() {
  group('công tắc vật tư khi viếng thăm (mobile-rules)', () {
    test('server gửi false ⇒ tắt; lưu máy rồi đọc lại giữ nguyên', () {
      final r = VisitRules.fromJson({'materials_enabled': false});
      expect(r.materialsEnabled, isFalse);
      expect(VisitRules.fromJson(r.toJson()).materialsEnabled, isFalse);
    });

    test('server cũ không gửi khoá ⇒ coi như bật (giữ hành vi trước)', () {
      expect(VisitRules.fromJson(const {}).materialsEnabled, isTrue);
    });
  });

  group('ô "Vật tư tại điểm" ở form tạo điểm bán', () {
    test('schema mang cờ materials_fields mà KHÔNG có ô ⇒ không có bước vật tư', () {
      expect(
        customerCreateMaterialsEnabled({
          'data': {'materials_fields': true, 'fields': [{'code': 'name'}]},
        }),
        isFalse,
      );
    });

    test('admin bỏ ẩn ô ⇒ có bước vật tư', () {
      expect(
        customerCreateMaterialsEnabled({
          'data': {
            'materials_fields': true,
            'fields': [{'code': 'name'}, {'code': 'materials'}],
          },
        }),
        isTrue,
      );
    });

    test('schema không mang cờ (bản lưu máy từ app cũ) ⇒ coi là ẩn như mặc định của server', () {
      expect(customerCreateMaterialsEnabled({'data': {'fields': [{'code': 'materials'}]}}), isFalse);
      expect(customerCreateMaterialsEnabled(null), isFalse);
    });
  });
}
