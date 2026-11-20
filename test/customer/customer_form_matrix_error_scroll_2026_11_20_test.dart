import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';

/// Ca báo 20/11/2026 (form THÊM ĐIỂM BÁN): gõ số ma trận SOS, chưa chụp ảnh / chưa đủ số thương hiệu tối thiểu, bấm Lưu ⇒ màn
/// cuộn tới ĐẦU ô ma trận, còn câu báo đỏ nằm CUỐI ô (dưới bảng + các ô ảnh) ⇒ khuất, nhân viên không hiểu sao chưa lưu được.
void main() {
  DynamicFormField maTran({required int minPhotos, int minBrands = 0}) => DynamicFormField.fromJson({
        'kind': 'dynamic',
        'code': 'sos',
        'label': 'Số mặt trưng bày',
        'input_type': 'display_matrix',
        'matrix': {
          if (minBrands > 0) 'min_brands': minBrands,
          'brands': [
            {'code': 'vthm', 'name': 'VTHM', 'is_own': true},
            {'code': 'rival', 'name': 'Đối thủ', 'is_own': false},
          ],
          'types': [
            for (var i = 1; i <= 5; i++)
              {'code': 'l$i', 'name': 'Loại $i', 'unit': 'cái', 'decimals': 0, 'face_factor': 1, 'min_photos': minPhotos, 'max_photos': 3},
          ],
        },
      });

  Future<void> chay(WidgetTester tester, DynamicFormField f, String loi) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey<DynamicFormBuilderState>();
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicFormBuilder(
              key: key,
              keepFieldOrder: true,
              fields: [const DynamicFormField(code: 'ghi_chu', label: 'Ghi chú', type: DynamicFormFieldType.text), f],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    key.currentState!.updateFieldValue('sos', {
      'counts': {
        'vthm': {'l1': 3},
      },
      'photos': <String, dynamic>{},
    });
    await tester.pumpAndSettle();

    expect(key.currentState!.validate(), isFalse);
    await tester.pumpAndSettle();
    final o = find.textContaining(loi);
    expect(o, findsOneWidget);
    final r = tester.getRect(o);
    expect(r.top, greaterThanOrEqualTo(0));
    expect(r.bottom, lessThanOrEqualTo(700), reason: 'câu báo phải nằm trong màn hình sau khi bấm Lưu');
    expect(key.currentState!.firstErrorMessage, contains(loi), reason: 'thanh báo nói ĐÚNG lý do, không chỉ câu chung');
  }

  testWidgets('thiếu ảnh ⇒ cuộn tới đúng câu báo', (tester) => chay(tester, maTran(minPhotos: 1), 'Loại 1: cần ít nhất 1 ảnh'));

  testWidgets('chưa đủ số thương hiệu tối thiểu ⇒ có câu báo và cuộn tới nó',
      (tester) => chay(tester, maTran(minPhotos: 0, minBrands: 2), 'ít nhất 2 thương hiệu'));
}
