import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/localization/app_language.dart';
import 'package:vthm_dms/core/localization/app_strings.dart';
import 'package:vthm_dms/features/visit/data/models/visit_material_model.dart';
import 'package:vthm_dms/features/visit/presentation/widgets/material_card.dart';

/// Thẻ vật tư ở mục Vật tư của lượt viếng thăm: mở ra dạng thu gọn, nút mũi tên xuống để xem đủ.
void main() {
  const strings = AppStrings(AppLanguage.vi);
  const type = OutletMaterialType(id: 1, name: 'Kệ trưng bày', unit: 'cái');
  const conditions = [
    MaterialCondition(code: 'good', name: 'Tốt', color: 'success'),
    MaterialCondition(code: 'broken', name: 'Hỏng nhẹ', color: 'warning'),
  ];

  Widget host({required bool collapsible, Map<String, int>? counts = const {'good': 4, 'broken': 1}}) => MaterialApp(
        home: Scaffold(
          body: MaterialCard(
            strings: strings,
            type: type,
            conditions: conditions,
            counts: counts,
            status: MaterialCardStatus.pending,
            footer: 'Kiểm 30/10 12:10 · Nguyễn A',
            collapsible: collapsible,
            onTap: () {},
          ),
        ),
      );

  testWidgets('collapsible: thu gọn mặc định — chỉ tên + tổng, bấm mũi tên mới hiện chi tiết', (tester) async {
    await tester.pumpWidget(host(collapsible: true));

    expect(find.text('Kệ trưng bày'), findsOneWidget);
    expect(find.text('5 cái'), findsOneWidget);
    expect(find.text('Tốt 4'), findsNothing);
    expect(find.text('Kiểm 30/10 12:10 · Nguyễn A'), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

    await tester.tap(find.byTooltip(strings.materialsExpand));
    await tester.pumpAndSettle();
    expect(find.text('Tốt 4'), findsOneWidget);
    expect(find.text('Kiểm 30/10 12:10 · Nguyễn A'), findsOneWidget);

    await tester.tap(find.byTooltip(strings.materialsCollapse));
    await tester.pumpAndSettle();
    expect(find.text('Tốt 4'), findsNothing);
  });

  testWidgets('không collapsible (màn tạo điểm bán): hiện đủ, không có mũi tên', (tester) async {
    await tester.pumpWidget(host(collapsible: false));
    expect(find.text('Tốt 4'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
  });

  testWidgets('collapsible + chưa khai, không chân thẻ: không cần mũi tên', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MaterialCard(
          strings: strings,
          type: type,
          conditions: conditions,
          counts: null,
          status: MaterialCardStatus.required,
          collapsible: true,
          onTap: () {},
        ),
      ),
    ));
    expect(find.text(strings.materialsTapToDeclare), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
  });
}
