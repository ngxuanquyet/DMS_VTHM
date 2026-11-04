import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';

/// #24698 vòng 4: ô động điểm bán CHƯA có giá trị nhận mặc định của form (có/không = false…) — màn sửa không được gửi mặc
/// định đó khi người dùng không đụng tới (trước đây mỗi lần sửa hồ sơ ghi `false` thật vào ô có/không).
void main() {
  testWidgets('ô mang giá trị mặc định chưa đụng tới ⇒ isUntouchedDefault; đụng tới / có giá trị nạp sẵn ⇒ không', (t) async {
    final key = GlobalKey<DynamicFormBuilderState>();
    await t.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicFormBuilder(
              key: key,
              fields: const [
                DynamicFormField(code: 'co_tu_lanh', label: 'Có tủ lạnh', type: DynamicFormFieldType.boolean),
                DynamicFormField(code: 'co_ke', label: 'Có kệ', type: DynamicFormFieldType.boolean),
                DynamicFormField(code: 'co_bien', label: 'Có biển', type: DynamicFormFieldType.boolean, initialValue: true),
              ],
              initialData: const {'co_ke': true},
            ),
          ),
        ),
      ),
    ));
    final s = key.currentState!;
    expect(s.isUntouchedDefault('co_tu_lanh'), isTrue);
    expect(s.getFormData()['co_tu_lanh'], false);
    expect(s.isUntouchedDefault('co_ke'), isFalse);
    expect(s.isUntouchedDefault('co_bien'), isFalse, reason: 'giá trị điền sẵn theo cấu hình là giá trị thật — gửi');

    s.updateFieldValue('co_tu_lanh', false);
    expect(s.isUntouchedDefault('co_tu_lanh'), isFalse, reason: 'người dùng chọn "Không" thật thì gửi');
  });
}
