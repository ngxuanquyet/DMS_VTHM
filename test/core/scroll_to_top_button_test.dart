import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/widgets/scroll_to_top_button.dart';

void main() {
  testWidgets('Ẩn ở đầu danh sách, hiện khi cuộn sâu, bấm thì về đầu', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          ListView.builder(
            controller: controller,
            itemCount: 200,
            itemBuilder: (_, i) => SizedBox(height: 50, child: Text('row $i')),
          ),
          Positioned(right: 16, bottom: 16, child: ScrollToTopButton(controller: controller, label: 'Lên đầu danh sách')),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    AnimatedScale scale() => tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale().scale, 0);

    controller.jumpTo(2000);
    await tester.pumpAndSettle();
    expect(scale().scale, 1);

    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    expect(scale().scale, 0);
  });

  testWidgets('Danh sách bị thay bằng màn trống khi đang cuộn sâu ⇒ nút ẩn đi', (tester) async {
    final controller = ScrollController();
    var empty = false;
    late StateSetter rebuild;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          rebuild = setState;
          return Stack(children: [
            empty
                ? ListView(controller: controller, children: const [Text('Không tìm thấy')])
                : ListView.builder(
                    controller: controller,
                    itemCount: 200,
                    itemBuilder: (_, i) => SizedBox(height: 50, child: Text('row $i')),
                  ),
            Positioned(right: 16, bottom: 16, child: ScrollToTopButton(controller: controller, label: 'Lên đầu danh sách')),
          ]);
        }),
      ),
    ));
    controller.jumpTo(2000);
    await tester.pumpAndSettle();
    AnimatedScale scale() => tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale().scale, 1);

    rebuild(() => empty = true);
    await tester.pumpAndSettle();
    expect(scale().scale, 0);
  });
}
