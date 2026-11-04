import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/widgets/display_matrix_field_widget.dart';
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

  testWidgets('#24698 vòng 4 C3: ô ma trận trùng giá trị đang lưu ⇒ không chặn lưu; số thương hiệu đã tắt không tính',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    // Như màn sửa: initialData là bản nháp CÓ THỂ ĐỔI (onChanged chép giá trị form vào), savedData là bản đang lưu.
    Future<GlobalKey<DynamicFormBuilderState>> dung(Map<String, dynamic> initial) async {
      final key = GlobalKey<DynamicFormBuilderState>();
      final nhap = Map<String, dynamic>.from(initial);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicFormBuilder(
                key: key,
                fields: [DynamicFormField.fromJson(json)],
                initialData: nhap,
                savedData: initial,
                onChanged: nhap.addAll,
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return key;
    }

    // Phiếu khảo sát áp hiện trạng: Kệ lật có số mà không ảnh (ô điểm bán đòi ≥1 ảnh).
    var key = await dung({
      'sos': {'counts': {'vthm': {'ke': 3}}, 'photos': <String, dynamic>{}},
    });
    expect(key.currentState!.validate(focusFirstError: false), isTrue, reason: 'lỗi cũ: sửa SĐT bị chặn "cần ít nhất 1 ảnh"');

    // Đụng vào ô ⇒ kiểm như thường.
    await tester.enterText(find.byKey(const ValueKey('matrix_vthm_ke')), '4');
    await tester.pump();
    expect(key.currentState!.validate(focusFirstError: false), isFalse);

    // Thương hiệu đã tắt (không còn trong danh mục) mang số Kệ lật ⇒ không đòi ảnh khi sửa loại khác.
    key = await dung({
      'sos': {'counts': {'cu': {'ke': 5}}, 'photos': <String, dynamic>{}},
    });
    await tester.enterText(find.byKey(const ValueKey('matrix_vthm_op')), '1,5');
    await tester.pump();
    expect(key.currentState!.validate(focusFirstError: false), isTrue);
  });

  test('#24698 vòng 4 C3: so giá trị ô ma trận theo nội dung (thứ tự khoá, 2 = 2.0)', () {
    final a = {
      'counts': {'vthm': {'ke': 2, 'op': 1.5}},
      'photos': {'ke': ['t1']},
    };
    final b = {
      'photos': {'ke': ['t1'], 'op': <String>[]},
      'counts': {'vthm': {'op': 1.5, 'ke': 2.0}},
    };
    expect(DisplayMatrixFieldWidget.sameValue(a, b), isTrue);
    expect(DisplayMatrixFieldWidget.sameValue(a, {...b, 'photos': {'ke': ['t2']}}), isFalse);
    expect(DisplayMatrixFieldWidget.sameValue(a, null), isFalse);
    expect(
      DisplayMatrixFieldWidget.sameValue({'lat': 10.1, 'lng': 106.2}, {'lat': 10.5, 'lng': 106.9}),
      isFalse,
      reason: 'ô vị trí (map không phải ma trận) đổi giá trị phải được gửi',
    );
  });
}
