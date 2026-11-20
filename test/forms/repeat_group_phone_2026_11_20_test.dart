import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/core/dynamic_form/repeat_group.dart';
import 'package:vthm_dms/core/utils/phone_utils.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';

/// Ô con `phone` trong nhóm trường lặp (20/11/2026): chuẩn hoá + kiểm như ô SĐT đơn, lỗi hiện ở ô của dòng.
final _group = {
  'columns': [
    {'code': 'ten', 'label': 'Tên', 'input_type': 'text'},
    {'code': 'sdt', 'label': 'SĐT', 'input_type': 'phone', 'phone_pattern': r'/^0(?:[35789][0-9]{8}|2[0-9]{9})$/'},
  ],
};

DynamicFormField get _groupField => DynamicFormField.fromJson({
      'code': 'nlh',
      'label': 'Người liên hệ',
      'input_type': 'group_table',
      'group': _group,
    });

void main() {
  test('đặc tả: kiểm + chuẩn hoá SĐT từng dòng; màn sửa bỏ qua ô còn y giá trị đang lưu', () {
    final spec = RepeatGroupSpec.fromCustomerSchema(_group)!;
    expect(spec.columns[1].type, DynamicFormFieldType.phone);

    final rows = [
      {'line_id': 'a', 'ten': 'A', 'sdt': '+84 912 345 678'},
      {'line_id': 'b', 'ten': 'B'},
    ];
    expect(spec.validate(rows, label: 'NLH', isRequired: false), isNull);
    final chuan = spec.normalizePhones(rows);
    expect(chuan[0]['sdt'], '0912345678');
    expect(identical(chuan[1], rows[1]), isTrue);
    final daChuan = [
      {'line_id': 'a', 'sdt': '0912345678'},
    ];
    expect(identical(spec.normalizePhones(daChuan), daChuan), isTrue, reason: 'không đổi gì ⇒ chính danh sách cũ');

    final sai = [
      {'line_id': 'a', 'sdt': '12345'},
    ];
    expect(spec.validate(sai, label: 'NLH', isRequired: false), 'NLH, dòng 1: SĐT: ${PhoneUtils.invalidMessage}');
    // Màn sửa: dòng cùng line_id còn y số đang lưu (dù sai dạng) ⇒ không chặn, không đổi.
    expect(spec.validate(sai, label: 'NLH', isRequired: false, saved: sai), isNull);
    expect(spec.normalizePhones(sai, saved: sai)[0]['sdt'], '12345');
    // Sửa sang số sai khác ⇒ chặn.
    expect(
      spec.validate([{'line_id': 'a', 'sdt': '123'}], label: 'NLH', isRequired: false, saved: sai),
      isNotNull,
    );
  });

  testWidgets('form điểm bán: số sai báo ngay ở ô của dòng, số đúng gửi đã chuẩn hoá', (tester) async {
    final key = GlobalKey<DynamicFormBuilderState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFormBuilder(
            key: key,
            fields: [_groupField],
            initialData: const {
              'nlh': [
                {'line_id': 'a', 'ten': 'A'},
              ],
            },
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final oSdt = find.byType(TextField).at(1);
    expect(tester.widget<TextField>(oSdt).keyboardType, TextInputType.phone);
    await tester.enterText(oSdt, '0123 456 789');
    await tester.pumpAndSettle();
    expect(key.currentState!.validate(focusFirstError: false), isFalse);
    await tester.pumpAndSettle();
    expect(find.text(PhoneUtils.invalidMessage), findsOneWidget, reason: 'câu báo dưới ô SĐT của dòng');

    await tester.enterText(oSdt, '0084 365 920 961');
    await tester.pumpAndSettle();
    expect(key.currentState!.validate(focusFirstError: false), isTrue);
    final rows = key.currentState!.getFormData()['nlh'] as List;
    expect((rows.first as Map)['sdt'], '0365920961');
    expect((rows.first as Map)['line_id'], 'a');
  });

  testWidgets('form điểm bán (sửa): số cũ sai dạng trong dòng không đụng tới thì không chặn khi sửa dòng khác', (tester) async {
    final luu = [
      {'line_id': 'a', 'ten': 'A', 'sdt': '12345'},
    ];
    final key = GlobalKey<DynamicFormBuilderState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DynamicFormBuilder(
            key: key,
            fields: [_groupField],
            initialData: {'nlh': luu},
            savedData: {'nlh': luu},
            editing: true,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'A sửa');
    await tester.pumpAndSettle();
    expect(key.currentState!.validate(focusFirstError: false), isTrue);
    expect(((key.currentState!.getFormData()['nlh'] as List).first as Map)['sdt'], '12345');
  });

  testWidgets('biểu mẫu thị trường: SĐT trong dòng gửi đã chuẩn hoá, số sai chặn nộp', (tester) async {
    const blocks = [
      MarketFormBlockEntity(
        ref: 'nlh',
        type: 'group',
        required: false,
        colSpan: 12,
        resolved: MarketFormResolvedEntity(
          code: 'nlh',
          label: 'Người liên hệ',
          inputType: 'group_table',
          groupItems: [
            {
              'ref': 'sdt',
              'required': true,
              'resolved': {
                'code': 'sdt',
                'label': 'SĐT',
                'input_type': 'phone',
                'config': {
                  'validation': {'format_pattern': r'/^0(?:[35789][0-9]{8}|2[0-9]{9})$/'},
                },
              },
            },
          ],
        ),
      ),
    ];
    final key = GlobalKey<MarketFormRendererState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MarketFormRenderer(
            key: key,
            blocks: blocks,
            initialAnswers: const {
              'nlh': [
                {'line_id': 'x'},
              ],
            },
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final o = find.byType(TextField).first;
    await tester.enterText(o, '0912');
    await tester.pumpAndSettle();
    expect(key.currentState!.validateAndGetAnswers(), isNull);
    await tester.pumpAndSettle();
    expect(find.text(PhoneUtils.invalidMessage), findsOneWidget);

    await tester.enterText(o, '+84 (24) 3826-1234');
    await tester.pumpAndSettle();
    final ans = key.currentState!.validateAndGetAnswers()!;
    expect(((ans['nlh'] as List).first as Map)['sdt'], '02438261234');
  });
}
