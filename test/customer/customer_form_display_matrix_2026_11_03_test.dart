import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/matrix_photo_key.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';

/// Ô MA TRẬN TRƯNG BÀY ở form Thêm/Sửa điểm bán (#24773): schema mang `matrix`; form vẽ thẻ thương hiệu, giá trị
/// `{counts, photos}`, cùng luật server (ảnh tối thiểu chỉ khi loại có số > 0, số lẻ); ảnh trên máy đổi ra token trước khi gửi.
void main() {
  final json = {
    'kind': 'dynamic',
    'code': 'sos',
    'label': 'Số mặt trưng bày',
    'input_type': 'display_matrix',
    'required': true,
    'matrix': {
      'brands': [
        {'code': 'vthm', 'name': 'VTHM', 'is_own': true},
        {'code': 'other', 'name': 'Khác', 'is_own': false},
      ],
      'types': [
        {'code': 'ke', 'name': 'Kệ lật', 'unit': 'tấm', 'decimals': 0, 'face_factor': 1, 'min_photos': 1, 'max_photos': 2},
        {'code': 'op', 'name': 'Ốp mẫu', 'unit': 'm²', 'decimals': 1, 'face_factor': 1, 'min_photos': 0, 'max_photos': 0},
      ],
    },
  };

  test('schema ⇒ loại ô ma trận + danh mục', () {
    final f = DynamicFormField.fromJson(json);
    expect(f.type, DynamicFormFieldType.displayMatrix);
    expect((f.matrix!['brands'] as List).length, 2);
  });

  test('ảnh trên máy đổi ra token, giữ token + quy đường xem công khai về token, giữ counts', () async {
    final tok = 'a' * 32;
    final out = await resolveMatrixPhotos({
      'counts': {'vthm': {'ke': 2}},
      'photos': {'ke': ['/tmp/x.jpg', tok, '/crm/customer-photos/public/${'b' * 32}']},
    }, (p) async => 'c' * 32);
    expect(out['photos']['ke'], ['c' * 32, tok, 'b' * 32]);
    expect(out['counts'], {'vthm': {'ke': 2}});
    expect(await resolveMatrixPhotos('chuỗi', (p) async => null), 'chuỗi');
  });

  testWidgets('nhập số ⇒ formData {counts, photos}; thiếu ảnh của loại có số ⇒ chặn; ô bắt buộc trống ⇒ chặn', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final key = GlobalKey<DynamicFormBuilderState>();
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: DynamicFormBuilder(key: key, fields: [DynamicFormField.fromJson(json)])),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(key.currentState!.validate(focusFirstError: false), isFalse, reason: 'ô bắt buộc trống');

    await tester.enterText(find.byKey(const ValueKey('matrix_vthm_op')), '2,5');
    await tester.pump();
    expect(key.currentState!.validate(focusFirstError: false), isTrue, reason: 'Ốp mẫu không bắt ảnh');
    expect(key.currentState!.getFormData()['sos'], {
      'counts': {'vthm': {'op': 2.5}},
      'photos': <String, dynamic>{},
    });

    await tester.enterText(find.byKey(const ValueKey('matrix_vthm_ke')), '3');
    await tester.pump();
    expect(key.currentState!.validate(focusFirstError: false), isFalse, reason: 'Kệ lật có số mà chưa có ảnh');
  });
}
