import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/home/presentation/widgets/home_quick_actions.dart';

void main() {
  group('HomeQuickActions Widget Tests', () {
    testWidgets('Renders both Chấm công and Khai báo vị trí cards with proper styling',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomeQuickActions(),
          ),
        ),
      );

      // Verify "Chấm công" card
      expect(find.text('Chấm công'), findsOneWidget);
      expect(find.byIcon(Icons.access_time_filled_rounded), findsOneWidget);

      // Verify "Khai báo vị trí" card
      expect(find.text('Khai báo vị trí'), findsOneWidget);
      expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);

      // Verify background colors
      final containerWidgets = tester.widgetList<Container>(find.byType(Container)).toList();
      final hasAmberCard = containerWidgets.any((c) {
        final decoration = c.decoration;
        return decoration is BoxDecoration && decoration.color == const Color(0xFFE59819);
      });
      final hasTealCard = containerWidgets.any((c) {
        final decoration = c.decoration;
        return decoration is BoxDecoration && decoration.color == const Color(0xFF1EA1A1);
      });

      expect(hasAmberCard, isTrue, reason: 'Chấm công card must have amber/warm yellow color');
      expect(hasTealCard, isTrue, reason: 'Khai báo vị trí card must have teal/turquoise color');
    });
  });
}
