import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';

/// #23819 — renderer biểu mẫu điền sẵn ô Kênh/Tuyến từ `config.default` (server tính theo phòng ban người đăng nhập).
void main() {
  MarketFormBlockEntity block(String code, String type, dynamic def, List<MarketFormOptionEntity> opts) =>
      MarketFormBlockEntity(
        ref: code,
        type: 'field',
        required: false,
        resolved: MarketFormResolvedEntity(
          code: code,
          label: code,
          inputType: type,
          config: {'catalog': 'x', 'default': def},
          options: opts,
        ),
      );

  final blocks = [
    block('tuyen', 'select', 'MN2', const [
      MarketFormOptionEntity(value: 'MN2', label: 'MN2'),
      MarketFormOptionEntity(value: '_ALL', label: 'Toàn kênh'),
    ]),
    block('kenh', 'multiselect', [1], const [
      MarketFormOptionEntity(value: '1', label: 'KPP — Kênh phân phối'),
      MarketFormOptionEntity(value: '4', label: 'KBL — Kênh bán lẻ'),
    ]),
  ];

  Future<MarketFormRendererState> dung(WidgetTester tester, Map<String, dynamic> nhap) async {
    final key = GlobalKey<MarketFormRendererState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: MarketFormRenderer(key: key, blocks: blocks, initialAnswers: nhap))),
    ));

    return key.currentState!;
  }

  testWidgets('ô trống ⇒ điền sẵn, giá trị về CHUỖI cho khớp lựa chọn; ô chọn nhiều ⇒ mảng', (tester) async {
    final st = await dung(tester, const {});
    expect(st.currentAnswers['tuyen'], 'MN2');
    expect(st.currentAnswers['kenh'], ['1']);
  });

  testWidgets('câu trả lời nháp đã có ⇒ GIỮ, không đè', (tester) async {
    final st = await dung(tester, const {'tuyen': '_ALL'});
    expect(st.currentAnswers['tuyen'], '_ALL');
  });
}
