import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/update/app_update_logic.dart';
import 'package:vthm_dms/core/update/app_update_overlay.dart';

/// Hộp cập nhật app (25/11/2026, review vòng 2): gỡ hộp GIỮA LÚC đang tải (mạng chập chờn / bản mới thay khoá) không được
/// ném lỗi «setState() called during build», và lớp phủ phải nhận lại tín hiệu «thôi tải».
void main() {
  const offer = AppUpdateOffer(
    forced: true,
    latestBuild: 16,
    url: 'https://one.vthmgroup.vn/dl/vthm-dms.apk',
    sha256: 'e07f7f227a7ab20d3c41ff3897835e9085902048aabaf848516c95b8e838d548',
  );

  testWidgets('bấm Cập nhật rồi gỡ hộp ⇒ không lỗi, cha nhận busy true rồi false', (tester) async {
    // Kênh native của ota_update: luồng tải MỞ mãi (không sự kiện cuối) ⇒ chỉ dispose() mới báo «thôi tải» — đúng nhánh cần đo.
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockStreamHandler(
      const EventChannel('sk.fourq.ota_update/stream'),
      MockStreamHandler.inline(onListen: (_, __) {}),
    );
    var cancelled = 0;
    messenger.setMockMethodCallHandler(const MethodChannel('sk.fourq.ota_update/method'), (call) async {
      if (call.method == 'cancel') cancelled++;
      return null;
    });
    addTearDown(() {
      messenger.setMockStreamHandler(const EventChannel('sk.fourq.ota_update/stream'), null);
      messenger.setMockMethodCallHandler(const MethodChannel('sk.fourq.ota_update/method'), null);
    });
    final busy = <bool>[];
    final show = ValueNotifier<bool>(true);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: show,
            builder: (_, visible, __) => Stack(
              children: [
                const SizedBox.expand(),
                if (visible) Positioned.fill(child: AppUpdatePanel(offer: offer, onActiveChanged: busy.add)),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Cập nhật'));
    await tester.pump();
    expect(busy, [true]);

    show.value = false;
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(busy, [true, false]);
    // Gỡ hộp giữa lượt tải ⇒ huỷ lượt native (không thì lượt mồ côi tự mở màn cài sau này).
    expect(cancelled, 1);
  });
}
