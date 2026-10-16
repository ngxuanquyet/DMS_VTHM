import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/widgets/app_fullscreen_image_viewer.dart';

void main() {
  group('AppFullScreenImageViewer Tests', () {
    testWidgets('1. Renders single photo with close button and title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppFullScreenImageViewer.openSingle(
                    context,
                    url: 'https://example.com/test.jpg',
                    title: 'Ảnh chụp mặt tiền',
                    subtitle: 'Chụp lúc 08:30',
                  );
                },
                child: const Text('Mở ảnh'),
              ),
            ),
          ),
        ),
      );

      // Tap to open full screen
      await tester.tap(find.text('Mở ảnh'));
      await tester.pumpAndSettle();

      // Verify full-screen elements
      expect(find.byType(AppFullScreenImageViewer), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('Ảnh chụp mặt tiền'), findsWidgets);
      expect(find.text('Chụp lúc 08:30'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Close the viewer
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(AppFullScreenImageViewer), findsNothing);
    });

    testWidgets('2. Renders multi photos list with counter indicator and swiping', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppFullScreenImageViewer.openUrls(
                    context,
                    urls: [
                      'https://example.com/photo1.jpg',
                      'https://example.com/photo2.jpg',
                      'https://example.com/photo3.jpg',
                    ],
                    titles: [
                      'Ảnh 1',
                      'Ảnh 2',
                      'Ảnh 3',
                    ],
                    initialIndex: 0,
                  );
                },
                child: const Text('Mở nhiều ảnh'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở nhiều ảnh'));
      await tester.pumpAndSettle();

      expect(find.byType(AppFullScreenImageViewer), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('Ảnh 1'), findsWidgets);

      // Swipe to next image
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Ảnh 2'), findsWidgets);

      // Close with back button
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(AppFullScreenImageViewer), findsNothing);
    });
  });
}
