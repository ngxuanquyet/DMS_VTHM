import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/home/presentation/widgets/home_quick_actions.dart';

void main() {
  group('HomeQuickActions Widget Tests', () {
    testWidgets(
      'Renders Chấm công, Khai báo vị trí, and Báo cáo cards with proper styling and layout',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: HomeQuickActions())),
        );

        // 1. Verify "Chấm công" card
        expect(find.text('Chấm công'), findsOneWidget);
        expect(find.byIcon(Icons.access_time_filled_rounded), findsOneWidget);

        // 2. Verify "Khai báo vị trí" card
        expect(find.text('Khai báo vị trí'), findsOneWidget);
        expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);

        // 3. Verify "Báo cáo" card
        expect(find.text('Báo cáo'), findsOneWidget);
        expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);

        // 4. Verify background colors (pastel nhạt thanh lịch)
        final containerWidgets = tester
            .widgetList<Container>(find.byType(Container))
            .toList();
        final hasAmberCard = containerWidgets.any((c) {
          final decoration = c.decoration;
          return decoration is BoxDecoration &&
              decoration.color == const Color(0xFFFEF3C7);
        });
        final hasTealCard = containerWidgets.any((c) {
          final decoration = c.decoration;
          return decoration is BoxDecoration &&
              decoration.color == const Color(0xFFCCFBF1);
        });
        final hasIndigoCard = containerWidgets.any((c) {
          final decoration = c.decoration;
          return decoration is BoxDecoration &&
              decoration.color == const Color(0xFFEEF2FF);
        });

        expect(
          hasAmberCard,
          isTrue,
          reason: 'Chấm công card must have soft amber pastel color (0xFFFEF3C7)',
        );
        expect(
          hasTealCard,
          isTrue,
          reason: 'Khai báo vị trí card must have soft teal pastel color (0xFFCCFBF1)',
        );
        expect(
          hasIndigoCard,
          isTrue,
          reason: 'Báo cáo card must have soft indigo pastel color (0xFFEEF2FF)',
        );

        // 5. Verify layout: Báo cáo is below Chấm công (higher Y position)
        final chamCongCard = find.ancestor(of: find.text('Chấm công'), matching: find.byType(InkWell));
        final baoCaoCard = find.ancestor(of: find.text('Báo cáo'), matching: find.byType(InkWell));
        final khaiBaoViTriCard = find.ancestor(of: find.text('Khai báo vị trí'), matching: find.byType(InkWell));
        final dongBoCard = find.ancestor(of: find.text('Đồng bộ'), matching: find.byType(InkWell));

        final chamCongOffset = tester.getTopLeft(chamCongCard);
        final baoCaoOffset = tester.getTopLeft(baoCaoCard);
        final khaiBaoViTriOffset = tester.getTopLeft(khaiBaoViTriCard);
        final dongBoOffset = tester.getTopLeft(dongBoCard);

        expect(baoCaoOffset.dy > chamCongOffset.dy, isTrue,
            reason: 'Báo cáo must be positioned vertically below Chấm công');
        expect((baoCaoOffset.dx - chamCongOffset.dx).abs() < 5, isTrue,
            reason: 'Báo cáo and Chấm công must be in the same left column');
        expect(khaiBaoViTriOffset.dx > chamCongOffset.dx, isTrue,
            reason: 'Khai báo vị trí must be on the right column');

        // 6. Verify "Đồng bộ" card layout
        expect(find.text('Đồng bộ'), findsOneWidget);
        expect(find.byIcon(Icons.sync_rounded), findsOneWidget);

        expect(dongBoOffset.dy > khaiBaoViTriOffset.dy, isTrue,
            reason: 'Đồng bộ must be positioned vertically below Khai báo vị trí');
        expect((dongBoOffset.dx - khaiBaoViTriOffset.dx).abs() < 5, isTrue,
            reason: 'Đồng bộ and Khai báo vị trí must be in the same right column');
      },
    );

    testWidgets('Tapping Đồng bộ card triggers onSync callback', (tester) async {
      var syncTriggered = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeQuickActions(
              onSync: () => syncTriggered = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Đồng bộ'));
      await tester.pump();

      expect(syncTriggered, isTrue);
    });

    testWidgets('Shows loading indicator and disabled tap when isSyncing is true', (tester) async {
      var syncTriggered = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeQuickActions(
              isSyncing: true,
              onSync: () => syncTriggered = true,
            ),
          ),
        ),
      );

      expect(find.text('Đang đồng bộ...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Đang đồng bộ...'));
      await tester.pump();

      expect(syncTriggered, isFalse);
    });

    testWidgets(
      'Tapping Báo cáo card opens modal bottom sheet with 4 report items',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: HomeQuickActions())),
        );

        // Tap "Báo cáo"
        await tester.tap(find.text('Báo cáo'));
        await tester.pumpAndSettle();

        // Verify bottom sheet title
        expect(find.text('Báo cáo & Lịch sử'), findsOneWidget);

        // Verify the 4 requested items
        expect(find.text('Báo cáo viếng thăm'), findsOneWidget);
        expect(find.text('Lịch sử chấm công'), findsOneWidget);
        expect(find.text('Lịch sử khai báo vị trí'), findsOneWidget);
        expect(find.text('Nghi vấn gian lận'), findsOneWidget);

        // Test tapping "Nghi vấn gian lận" opens fraud check dialog
        await tester.tap(find.text('Nghi vấn gian lận'));
        await tester.pumpAndSettle();

        expect(find.text('Kiểm tra gian lận'), findsOneWidget);
        expect(find.text('Toạ độ giả lập (Mock GPS)'), findsOneWidget);
        expect(find.text('Đồng hồ thiết bị (Clock Skew)'), findsOneWidget);
        expect(find.text('Bán kính viếng thăm (Geofence)'), findsOneWidget);
      },
    );
  });
}
