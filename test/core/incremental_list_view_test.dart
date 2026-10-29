import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/widgets/incremental_list_view.dart';

/// Tuyến 1.090 điểm bán (tài khoản anv, 29/10/2026): hiện 12 điểm đầu, cuộn gần cuối hiện thêm 12, đổi bộ lọc về 12.
void main() {
  /// Dòng cao 200px — cỡ thẻ điểm bán thật: 12 dòng dài hơn màn thử (600px) + khoảng hiện thêm (800px).
  Future<ScrollController> pump(
    WidgetTester tester, {
    required int count,
    Object? resetKey,
    ScrollController? reuse,
    double loadMoreExtent = 800,
  }) async {
    final controller = reuse ?? ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IncrementalListView(
            controller: controller,
            resetKey: resetKey,
            loadMoreExtent: loadMoreExtent,
            itemCount: count,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => SizedBox(height: 200, child: Text('Điểm ${i + 1}')),
          ),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  /// Số dòng danh sách đang nhận (gồm dòng cuối "cuộn để xem thêm" nếu còn) — `separated` có 2n−1 con.
  int rows(WidgetTester tester) {
    final d = tester.widget<ListView>(find.byType(ListView)).childrenDelegate as SliverChildBuilderDelegate;
    return (d.childCount! + 1) ~/ 2;
  }

  Future<void> scrollToEnd(WidgetTester tester, ScrollController c) async {
    c.jumpTo(c.position.maxScrollExtent);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('1.090 điểm: nhận 12 (+ dòng cuối), cuộn cuối thêm từng 12, tới hết thì không còn dòng cuối', (tester) async {
    final c = await pump(tester, count: 1090);
    expect(rows(tester), 13);

    await scrollToEnd(tester, c);
    expect(rows(tester), 25);

    while (rows(tester) < 1090) {
      await scrollToEnd(tester, c);
    }
    expect(rows(tester), 1090);
    await scrollToEnd(tester, c);
    expect(find.text('Điểm 1090'), findsOneWidget);
    expect(find.textContaining('Đang hiện'), findsNothing);
  });

  testWidgets('màn cao (máy tính bảng): 12 dòng không đầy màn ⇒ TỰ hiện thêm, không chờ cú cuộn', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pump(tester, count: 1090);
    expect(rows(tester), greaterThan(13));
  });

  testWidgets('đổi resetKey (bộ lọc/từ khoá) ⇒ về lại 12 điểm đầu và cuộn về đầu', (tester) async {
    final c = await pump(tester, count: 1090, resetKey: 'a');
    await scrollToEnd(tester, c);
    expect(rows(tester), 25);

    final c2 = await pump(tester, count: 1090, resetKey: 'b', reuse: c);
    expect(rows(tester), 13);
    expect(c2.offset, 0); // không kẹt ở dòng "cuộn để xem thêm"
  });

  testWidgets('dòng cuối ghi rõ đang hiện bao nhiêu / tổng', (tester) async {
    final c = await pump(tester, count: 150, loadMoreExtent: -1); // tắt hiện thêm để nhìn dòng cuối
    await scrollToEnd(tester, c);
    expect(find.text('Đang hiện 12/150 điểm bán — cuộn để xem thêm'), findsOneWidget);
  });

  testWidgets('ít hơn 12 điểm thì không có dòng cuối', (tester) async {
    await pump(tester, count: 10);
    expect(rows(tester), 10);
  });
}
