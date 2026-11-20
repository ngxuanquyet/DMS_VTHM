import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/rules/mobile_rules_model.dart';
import 'package:vthm_dms/features/home/presentation/widgets/home_quick_actions.dart';

/// Trang chủ (20/11/2026): hàng 2 mới «Thêm mới NPP · Thêm mới điểm bán» nằm GIỮA «Chấm công · Viếng thăm» và «Báo cáo ·
/// Đồng bộ». `flutter test … --dart-define=SHOT=1` xuất ảnh vào docs/shots/debug/20261120-dms-home-quick-actions/.
const _shot = bool.fromEnvironment('SHOT');

Future<void> _loadFonts() async {
  Future<void> load(String family, String path) async {
    if (!File(path).existsSync()) return;
    final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
    await loader.load();
  }

  await load('Roboto', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf');
  await load('MaterialIcons', '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('3 hàng × 2 ô, hàng NPP · điểm bán ở giữa; bấm NPP gọi callback; đang mở thì hiện vòng quay', (tester) async {
    tester.view.physicalSize = const Size(400 * 2, 520 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    var npp = 0;
    final boundary = GlobalKey();
    Widget app({bool opening = false}) => MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: HomeQuickActions(onAddNpp: () => npp++, isOpeningNpp: opening),
              ),
            ),
          ),
        );
    await tester.pumpWidget(app());

    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    double x(String t) => tester.getTopLeft(find.byKey(ValueKey(t))).dx;
    expect(y('Chấm công'), lessThan(y('Thêm mới NPP')));
    expect(y('Thêm mới NPP'), lessThan(y('Báo cáo')));
    expect(tester.getTopLeft(find.byKey(const ValueKey('home_add_npp'))).dy,
        tester.getTopLeft(find.byKey(const ValueKey('home_add_outlet'))).dy);
    expect(x('home_add_npp'), lessThan(x('home_add_outlet')), reason: 'NPP bên trái, điểm bán bên phải');

    if (_shot) {
      await tester.runAsync(() async {
        final ro = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await ro.toImage(pixelRatio: 2);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('../docs/shots/debug/20261120-dms-home-quick-actions/home_quick_actions.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    await tester.tap(find.text('Thêm mới NPP'));
    expect(npp, 1);

    await tester.pumpWidget(app(opening: true));
    expect(find.descendant(of: find.byKey(const ValueKey('home_add_npp')), matching: find.byType(CircularProgressIndicator)),
        findsOneWidget);
  });

  test('mobile-rules: đọc mã biểu mẫu nút NPP; server cũ không gửi ⇒ create_npp', () {
    expect(FormsRules.fromJson({'home_npp_form_code': ' khac '}).homeNppFormCode, 'khac');
    expect(FormsRules.fromJson({'home_npp_form_code': ''}).homeNppFormCode, '');
    expect(FormsRules.fromJson({}).homeNppFormCode, 'create_npp');
  });
}
