import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';

/// Ca báo 20/11/2026: phiếu viếng thăm gõ số ma trận SOS, không chụp ảnh, bấm Nộp ⇒ màn cuộn tới ĐẦU ô ma trận, còn câu
/// "cần ít nhất N ảnh" nằm cuối ô (dưới bảng + các ô ảnh) — ô cao hơn màn hình nên câu cảnh báo khuất.
void main() {
  final types = [
    for (var i = 1; i <= 5; i++)
      {'code': 'loai$i', 'name': 'Loại $i', 'unit': 'cái', 'decimals': 0, 'face_factor': 1, 'min_photos': 1, 'max_photos': 3},
  ];
  final block = MarketFormBlockEntity(
    ref: 'sos',
    type: 'field',
    required: true,
    resolved: MarketFormResolvedEntity(
      code: 'sos',
      label: 'Số mặt trưng bày',
      inputType: 'display_matrix',
      config: {
        'matrix': {
          'brands': [
            {'code': 'vthm', 'name': 'VTHM', 'is_own': true},
          ],
          'types': types,
        },
      },
    ),
  );
  const truoc = MarketFormBlockEntity(
    ref: 'ghi_chu',
    type: 'field',
    required: false,
    resolved: MarketFormResolvedEntity(code: 'ghi_chu', label: 'Ghi chú', inputType: 'textarea'),
  );

  testWidgets('nộp thiếu ảnh ⇒ cuộn tới đúng dòng cảnh báo của ô ma trận, dòng đó nằm trong màn hình', (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey<MarketFormRendererState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: MarketFormRenderer(key: key, blocks: const [truoc] + [block]))),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('matrix_vthm_loai1')), '3');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();

    expect(key.currentState!.validateAndGetAnswers(), isNull);
    await tester.pumpAndSettle();

    final loi = find.textContaining('Loại 1: cần ít nhất 1 ảnh');
    expect(loi, findsOneWidget);
    final r = tester.getRect(loi);
    expect(r.top, greaterThanOrEqualTo(0));
    expect(r.bottom, lessThanOrEqualTo(700));
  });
}
