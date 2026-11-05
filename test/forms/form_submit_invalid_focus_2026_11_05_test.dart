import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/widgets/app_snackbar.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';

/// Bấm Nộp khi còn ô bắt buộc trống (05/11/2026): cuộn tới ô lỗi ĐẦU TIÊN (ô gõ chữ thì focus), và bấm liên tục chỉ có
/// MỘT thông báo — SnackBar thô xếp hàng nên trước đây hiện nối đuôi mãi.
MarketFormBlockEntity _b(String code, String type, {bool required = false}) => MarketFormBlockEntity(
      ref: code,
      type: 'field',
      required: required,
      colSpan: 12,
      resolved: MarketFormResolvedEntity(code: code, label: 'Ô $code', inputType: type),
    );

void main() {
  testWidgets('ô lỗi đầu tiên nằm dưới màn hình ⇒ cuộn tới và focus ô gõ chữ', (tester) async {
    final key = GlobalKey<MarketFormRendererState>();
    final blocks = [
      for (var i = 0; i < 15; i++) _b('ghi_chu_$i', 'text'),
      _b('ten', 'text', required: true),
      _b('so_luong', 'number', required: true),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: MarketFormRenderer(key: key, blocks: blocks))),
    ));

    final ten = find.byType(TextFormField).at(15);
    expect(tester.getTopLeft(ten).dy, greaterThan(600), reason: 'ô lỗi ban đầu ở ngoài màn hình');

    expect(key.currentState!.validateAndGetAnswers(), isNull);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(ten).dy, lessThan(600), reason: 'đã cuộn tới ô lỗi đầu tiên');
    final editable = tester.widget<EditableText>(find.descendant(of: ten, matching: find.byType(EditableText)));
    expect(editable.focusNode.hasFocus, isTrue, reason: 'ô gõ chữ lỗi đầu tiên được focus');
  });

  testWidgets('ô lỗi đầu tiên không gõ chữ (ngày) ⇒ vẫn cuộn tới', (tester) async {
    final key = GlobalKey<MarketFormRendererState>();
    final blocks = [
      _b('ghi_chu', 'text'),
      for (var i = 0; i < 15; i++) _b('khoang_$i', 'text'),
      _b('co_kho', 'date', required: true),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: MarketFormRenderer(key: key, blocks: blocks))),
    ));

    expect(key.currentState!.validateAndGetAnswers(), isNull);
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.textContaining('Ô co_kho không được để trống.')).dy, lessThan(600));
  });

  testWidgets('bấm liên tục ⇒ chỉ một thông báo, không xếp hàng', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => AppSnackBar.showInvalid(context, 'Thiếu ô bắt buộc'),
            child: const Text('Nộp'),
          ),
        ),
      ),
    ));

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Nộp'));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(find.text('Thiếu ô bắt buộc'), findsOneWidget);

    // Hết 3 giây là tắt hẳn — không còn 4 cái chờ hiện nối đuôi.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Thiếu ô bắt buộc'), findsNothing);
  });
}
