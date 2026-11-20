import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/localization/app_language.dart';
import 'package:vthm_dms/core/localization/app_strings.dart';
import 'package:vthm_dms/core/theme/app_colors.dart';
import 'package:vthm_dms/core/widgets/voice_input_mic_button.dart';

/// Thẻ ghi âm (bấm mic nói) theo chế độ sáng / tối của app (20/11/2026: thẻ đen cứng lạc tone ở chế độ sáng).
/// `--dart-define=SHOT=true` xuất ảnh vào docs/shots/debug/20261120-dms-voice-overlay/.
const _shot = bool.fromEnvironment('SHOT');

Future<void> _loadFonts() async {
  Future<void> load(String family, String path) async {
    if (!File(path).existsSync()) return;
    final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
    await loader.load();
  }

  await load('Roboto', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
  await load('MaterialIcons', '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
}

void main() {
  setUpAll(_loadFonts);

  for (final dark in [false, true]) {
    for (final chu in ['', 'Đại lý Hùng Phát, ngã ba Phú Lâm']) {
      testWidgets('thẻ ghi âm ${dark ? 'tối' : 'sáng'}${chu.isEmpty ? ' (chưa có chữ)' : ''} — nền theo token màu của app', (tester) async {
        tester.view.physicalSize = const Size(400 * 2, 420 * 2);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        final b = GlobalKey();
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
          home: RepaintBoundary(
            key: b,
            child: Scaffold(
              backgroundColor: dark ? AppColors.darkBackground : AppColors.surface,
              body: VoiceRecordingOverlay(
                strings: const AppStrings(AppLanguage.vi),
                fieldName: 'Tên ứng viên NPP',
                recognizedText: chu,
                soundLevel: 4,
                isFinalizing: false,
                isTapMode: true,
                waveAnimation: const AlwaysStoppedAnimation(0.7),
                onDonePressed: () {},
                onCancelPressed: () {},
              ),
            ),
          ),
        ));
        await tester.pump();

        // Thẻ dùng nền token của chế độ đang bật — không còn nền đen cứng ở chế độ sáng.
        final the = tester.widgetList<Container>(find.byType(Container)).map((c) => c.decoration).whereType<BoxDecoration>()
            .firstWhere((d) => d.borderRadius == BorderRadius.circular(20));
        expect(the.color, dark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest);

        if (_shot) {
          await tester.runAsync(() async {
            final ro = b.currentContext!.findRenderObject()! as RenderRepaintBoundary;
            final img = await ro.toImage(pixelRatio: 2);
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            File('../docs/shots/debug/20261120-dms-voice-overlay/${dark ? 'toi' : 'sang'}${chu.isEmpty ? '_trong' : ''}.png')
              ..parent.createSync(recursive: true)
              ..writeAsBytesSync(bytes!.buffer.asUint8List());
          });
        }
      });
    }
  }
}
