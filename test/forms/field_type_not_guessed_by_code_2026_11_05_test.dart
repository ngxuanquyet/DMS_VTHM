import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';
import 'package:vthm_dms/core/widgets/location_field_widget.dart';

/// Ô biểu mẫu thị trường vẽ theo LOẠI Ô server gửi, không đoán theo mã ô (rà soát 05/11/2026): ô CHỮ mã `dia_chi` từng bị
/// vẽ thành ô Lấy vị trí ⇒ giá trị thành object {address, lat, lng} trong khi server đòi chuỗi.
void main() {
  testWidgets('ô chữ mã dia_chi vẫn là ô chữ, nộp giá trị chuỗi', (tester) async {
    final key = GlobalKey<MarketFormRendererState>();
    const blocks = [
      MarketFormBlockEntity(
        ref: 'dia_chi',
        type: 'field',
        required: false,
        resolved: MarketFormResolvedEntity(code: 'dia_chi', inputType: 'text', label: 'Địa chỉ'),
      ),
    ];

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarketFormRenderer(key: key, blocks: blocks, initialAnswers: const {'dia_chi': '12 Lê Lợi'}),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(LocationFieldWidget), findsNothing);
    final answers = key.currentState!.validateAndGetAnswers();
    expect(answers, isNotNull);
    expect(answers!['dia_chi'], '12 Lê Lợi');
  });
}
