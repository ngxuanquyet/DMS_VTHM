import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';

/// #25612: ô Ma trận trưng bày CHỈ ĐỌC ở form điểm bán — không gõ được số, không có nút chụp ảnh, không có trong dữ liệu gửi.
void main() {
  final json = {
    'kind': 'dynamic',
    'code': 'sos',
    'label': 'Số mặt trưng bày',
    'input_type': 'display_matrix',
    'required': true,
    'readonly': true,
    'matrix': {
      'brands': [
        {'code': 'vthm', 'name': 'VTHM', 'is_own': true},
      ],
      'types': [
        {'code': 'ke', 'name': 'Kệ lật', 'unit': 'tấm', 'decimals': 0, 'face_factor': 1, 'min_photos': 1, 'max_photos': 2},
      ],
    },
  };

  testWidgets('ô số chỉ đọc, không có trong getFormData, ô bắt buộc chỉ đọc không chặn lưu', (tester) async {
    final key = GlobalKey<DynamicFormBuilderState>();
    final dangLuu = {
      'counts': {'vthm': {'ke': 3}},
      'photos': {'ke': []},
    };
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicFormBuilder(key: key, fields: [DynamicFormField.fromJson(json)], initialData: {'sos': dangLuu}),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final o = find.byWidgetPredicate((w) => w is TextField && w.key is ValueKey && '${(w.key as ValueKey).value}'.endsWith('_vthm_ke'));
    expect(o, findsWidgets);
    for (final e in o.evaluate()) {
      expect((e.widget as TextField).readOnly, isTrue);
    }
    expect(find.text('Thêm ảnh'), findsNothing);

    expect(key.currentState!.getFormData().containsKey('sos'), isFalse);
    expect(key.currentState!.validate(), isTrue);
  });
}
