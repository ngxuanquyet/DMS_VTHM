import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/forms/data/models/market_form_model.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';

/// Biểu mẫu THỊ TRƯỜNG có ô CÔNG THỨC (`input_type: formula`, cấu hình ở `config.formula|format|decimals`) — chỉ đọc,
/// tự tính lại ngay khi ô tham chiếu đổi, không nằm trong câu trả lời gửi lên.
void main() {
  MarketFormBlockEntity o(String code, String label, String type, {dynamic config, dynamic showIf}) =>
      MarketFormBlockEntity(
        ref: code,
        type: 'field',
        required: false,
        colSpan: 12,
        showIf: showIf,
        resolved: MarketFormResolvedEntity(code: code, label: label, inputType: type, config: config),
      );

  final blocks = [
    o('so_luong', 'Số lượng', 'number'),
    o('gia_tri', 'Giá trị', 'number'),
    o('tong', 'Tổng', 'formula', config: {'formula': '= so_luong * gia_tri', 'format': 'currency', 'decimals': 0}),
    o('binh_quan', 'Bình quân', 'formula', config: {'formula': 'tong / 3', 'decimals': 2}),
    o('ly_do', 'Lý do đơn lớn', 'text', showIf: {'field': 'tong', 'op': '>=', 'value': 1000}),
  ];

  test('đọc cấu hình công thức từ schema (config Map hoặc chuỗi JSON); ô khác ⇒ null', () {
    final m = MarketFormBlockModel.fromJson({
      'ref': 'tong',
      'resolved': {
        'code': 'tong',
        'label': 'Tổng',
        'input_type': 'formula',
        'config': '{"formula":"a*b","format":"currency","decimals":1}',
      },
    }).toEntity();
    final f = m.resolved.formula!;
    expect([f.expr, f.format, f.decimals], ['a*b', 'currency', 1]);
    expect(blocks.first.resolved.formula, isNull);
  });

  testWidgets('gõ vào ô số ⇒ ô công thức cập nhật ngay; không gửi giá trị công thức', (tester) async {
    final key = GlobalKey<MarketFormRendererState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: MarketFormRenderer(key: key, blocks: blocks))),
    ));
    await tester.pumpAndSettle();

    String giaTri(int i) => tester.widgetList<Text>(find.byKey(const ValueKey('formula-value'))).elementAt(i).data!;
    final oSo = find.byType(TextFormField);

    expect(giaTri(0), '—');
    await tester.enterText(oSo.at(0), '5');
    await tester.pump();
    expect(giaTri(0), '—'); // gia_tri còn trống ⇒ rỗng, không coi là 0

    await tester.enterText(oSo.at(1), '6');
    await tester.pump();
    expect(giaTri(0), '30 đ');
    expect(giaTri(1), '10,00');
    expect(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Lý do đơn lớn')), findsNothing);

    await tester.enterText(oSo.at(1), '60000');
    await tester.pump();
    expect(giaTri(0), '300.000 đ');
    expect(giaTri(1), '100.000,00');
    expect(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Lý do đơn lớn')), findsOneWidget);

    final gui = key.currentState!.validateAndGetAnswers()!;
    expect(gui.containsKey('tong'), isFalse);
    expect(gui.containsKey('binh_quan'), isFalse);
    expect(gui['so_luong'], 5);
    expect(gui['gia_tri'], 60000);
  });
}
