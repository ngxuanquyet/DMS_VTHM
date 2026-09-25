import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vthm_dms/core/router/branch_animated_slide_container.dart';
import 'package:vthm_dms/core/router/page_transitions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Screen Transitions Tests', () {
    testWidgets('ZoomPageTransition animates scale and fade on route push',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('btn_open_sub'),
                  onPressed: () => context.push('/sub-screen'),
                  child: const Text('Open Sub Screen'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/sub-screen',
            pageBuilder: (context, state) => ZoomPageTransition(
              key: state.pageKey,
              child: const Scaffold(
                body: Center(child: Text('Sub Screen Content')),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Open Sub Screen'), findsOneWidget);

      // Tap button to push sub-screen with ZoomPageTransition
      await tester.tap(find.byKey(const Key('btn_open_sub')));
      await tester.pump(); // Frame 0 of animation

      // Should have ScaleTransition and FadeTransition during transition
      expect(find.byType(ScaleTransition), findsWidgets);
      expect(find.byType(FadeTransition), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.text('Sub Screen Content'), findsOneWidget);
    });

    testWidgets('BranchAnimatedSlideContainer preserves state and switches tabs',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/tab0',
        routes: [
          StatefulShellRoute(
            navigatorContainerBuilder: (context, navigationShell, children) =>
                BranchAnimatedSlideContainer(
              navigationShell: navigationShell,
              children: children,
            ),
            builder: (context, state, navigationShell) => Scaffold(
              body: navigationShell,
              bottomNavigationBar: Row(
                children: [
                  ElevatedButton(
                    key: const Key('btn_tab_0'),
                    onPressed: () => navigationShell.goBranch(0),
                    child: const Text('Tab 0'),
                  ),
                  ElevatedButton(
                    key: const Key('btn_tab_1'),
                    onPressed: () => navigationShell.goBranch(1),
                    child: const Text('Tab 1'),
                  ),
                ],
              ),
            ),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/tab0',
                    builder: (context, state) =>
                        const Center(child: Text('Screen 0 Content')),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/tab1',
                    builder: (context, state) =>
                        const Center(child: Text('Screen 1 Content')),
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      // Initially Tab 0 is displayed
      expect(find.text('Screen 0 Content'), findsOneWidget);

      // Tap Tab 1 to trigger slide transition
      await tester.tap(find.byKey(const Key('btn_tab_1')));
      await tester.pump(); // Start transition

      // While animating, SlideTransition should exist
      expect(find.byType(SlideTransition), findsWidgets);

      // Finish animation
      await tester.pumpAndSettle();
      expect(find.text('Screen 1 Content'), findsOneWidget);

      // Tap Tab 0 to trigger slide backwards
      await tester.tap(find.byKey(const Key('btn_tab_0')));
      await tester.pump();
      expect(find.byType(SlideTransition), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.text('Screen 0 Content'), findsOneWidget);
    });
  });
}
