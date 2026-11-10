import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';

/// Bắt buộc THEO ĐIỀU KIỆN dựa vào ô ẢNH (#25067, 10/11/2026): thêm/xoá ảnh tính lại ngay dấu * của ô phụ thuộc — trước bản vá
/// đổi ảnh không tính lại, dấu * chỉ đổi khi chạm sang ô khác.
void main() {
  const blocks = [
    MarketFormBlockEntity(
      ref: 'anh_ke',
      type: 'field',
      required: false,
      resolved: MarketFormResolvedEntity(code: 'anh_ke', label: 'Ảnh kệ hàng', inputType: 'image', maxFiles: 3),
    ),
    MarketFormBlockEntity(
      ref: 'ghi_chu',
      type: 'field',
      required: false,
      requiredIf: {'field': 'anh_ke', 'op': 'not_empty'},
      resolved: MarketFormResolvedEntity(code: 'ghi_chu', label: 'Ghi chú', inputType: 'text'),
    ),
  ];

  bool coSao(String nhan) => find
      .byWidgetPredicate((w) => w is RichText && w.text.toPlainText() == '$nhan *')
      .evaluate()
      .isNotEmpty;

  testWidgets('xoá ảnh ⇒ dấu * của ô bắt buộc theo ảnh mất NGAY', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MarketFormRenderer(blocks: blocks, initialAnswers: {
            'anh_ke': ['token_1'],
          }),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(coSao('Ghi chú'), isTrue, reason: 'có ảnh ⇒ Ghi chú bắt buộc');

    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();
    expect(coSao('Ghi chú'), isFalse, reason: 'hết ảnh ⇒ Ghi chú thôi bắt buộc ngay');
  });
}
