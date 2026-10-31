import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/localization/app_language.dart';
import 'package:vthm_dms/core/localization/app_strings.dart';
import 'package:vthm_dms/features/visit/data/models/visit_material_model.dart';
import 'package:vthm_dms/features/visit/presentation/widgets/material_type_picker_sheet.dart';

/// Sheet "Chọn loại vật tư" dùng chung (tạo điểm bán + lượt viếng thăm).
void main() {
  const strings = AppStrings(AppLanguage.vi);

  Future<OutletMaterialType?> open(WidgetTester tester, List<OutletMaterialType> types) async {
    OutletMaterialType? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async => picked = await showMaterialTypePicker(ctx, types: types, strings: strings),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets('mỗi loại một thẻ: tên + đơn vị; bấm thẻ trả đúng loại', (tester) async {
    const types = [
      OutletMaterialType(id: 1, name: 'Kệ trưng bày', unit: 'cái'),
      OutletMaterialType(id: 2, name: 'Biển hiệu'),
    ];
    OutletMaterialType? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async => picked = await showMaterialTypePicker(ctx, types: types, strings: strings),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(strings.materialsChooseType), findsOneWidget);
    expect(find.text(strings.materialsTypesAvailable(2)), findsOneWidget);
    expect(find.text('Đơn vị: cái'), findsOneWidget);
    expect(find.byType(TextField), findsNothing); // danh mục ngắn ⇒ không ô tìm

    await tester.tap(find.text('Biển hiệu'));
    await tester.pumpAndSettle();
    expect(picked?.id, 2);
  });

  testWidgets('danh mục dài ⇒ ô tìm không dấu', (tester) async {
    final types = [
      for (var i = 1; i <= 6; i++) OutletMaterialType(id: i, name: 'Loại $i'),
      const OutletMaterialType(id: 99, name: 'Tủ đông Sanaky'),
    ];
    await open(tester, types);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'tu dong');
    await tester.pumpAndSettle();
    expect(find.text('Tủ đông Sanaky'), findsOneWidget);
    expect(find.text('Loại 1'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text(strings.materialsNoTypeMatch), findsOneWidget);
  });
}
