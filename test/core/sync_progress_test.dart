import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/widgets/sync_progress.dart';

/// Thanh tiến trình đồng bộ 0→100% theo bước (10/11/2026): % tăng khi bước XONG (kể cả lỗi, lỗi ném tiếp), bước bỏ qua vẫn
/// tính, `finish` lên 100% rồi đóng, gọi lại không lỗi.
void main() {
  testWidgets('% theo bước, skip, lỗi vẫn tăng, finish đóng thanh', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })),
    ));

    final p = SyncProgress.show(ctx, total: 4);
    await tester.pump();
    expect(find.text('0%'), findsOneWidget);

    final cho = Completer<int>();
    final f = p.step('Tải điểm bán', () => cho.future);
    await tester.pump();
    expect(find.text('Tải điểm bán…'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget, reason: 'bước chưa xong thì chưa tăng');
    cho.complete(1);
    expect(await f, 1);
    await tester.pump();
    expect(find.text('25%'), findsOneWidget);

    p.skip();
    await tester.pump();
    expect(find.text('50%'), findsOneWidget);

    await expectLater(p.step('Lỗi', () => Future<void>.error(StateError('x'))), throwsStateError);
    await tester.pump();
    expect(find.text('75%'), findsOneWidget);

    final xong = p.finish();
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 450));
    await xong;
    await tester.pumpAndSettle();
    expect(find.byType(SyncProgressBar), findsNothing);
    await p.finish();
  });

  testWidgets('thanh bị snackbar khác đẩy đi ⇒ finish KHÔNG đóng nhầm snackbar đó', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })),
    ));

    final p = SyncProgress.show(ctx, total: 2);
    await tester.pump();
    // Toast hệ thống (vd "Đã có mạng lại") tự ẩn snackbar hiện tại rồi hiện mình.
    ScaffoldMessenger.of(ctx)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Đã có mạng lại'), duration: Duration(seconds: 30)));
    await tester.pumpAndSettle();
    expect(find.text('Đã có mạng lại'), findsOneWidget);

    final xong = p.finish();
    await tester.pump(const Duration(milliseconds: 450));
    await xong;
    await tester.pumpAndSettle();
    expect(find.text('Đã có mạng lại'), findsOneWidget, reason: 'không đóng snackbar của người khác');
  });
}
