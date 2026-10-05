import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/router/app_router.dart';
import 'package:vthm_dms/core/widgets/offline_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Dialog Single-View & Splash Deferral Tests', () {
    testWidgets('Offline dialog is deferred while splash is active and only shows after splash finishes', (tester) async {
      final container = ProviderContainer();
      final notifier = container.read(connectivityProvider.notifier);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: const Scaffold(
              body: Text('Home Screen'),
            ),
          ),
        ),
      );

      // 1. Notify splash has started
      notifier.notifySplashStarted();

      // Trigger offline while splash is active
      notifier.handleNetworkDisconnection();
      await tester.pump();

      // Dialog should NOT be visible during splash
      expect(find.byType(OfflineDisconnectDialog), findsNothing);
      expect(OfflineDisconnectDialog.isShowing, isFalse);

      // 2. Splash finishes
      notifier.notifySplashFinished();
      // Wait for the 500ms delay in notifySplashFinished
      await tester.pump(const Duration(milliseconds: 600));

      // Now dialog should be displayed once entering main screen
      expect(find.byType(OfflineDisconnectDialog), findsOneWidget);
      expect(OfflineDisconnectDialog.isShowing, isTrue);

      // Dismiss dialog
      OfflineDisconnectDialog.dismiss();
      await tester.pumpAndSettle();
      expect(find.byType(OfflineDisconnectDialog), findsNothing);

      // 3. User navigates between screens, API calls fail and trigger handleNetworkDisconnection
      notifier.handleNetworkDisconnection();
      await tester.pump();
      expect(find.byType(OfflineDisconnectDialog), findsNothing);

      notifier.handleNetworkDisconnection();
      await tester.pump();
      expect(find.byType(OfflineDisconnectDialog), findsNothing);

      // Explicit call to showOfflineDialog should also be ignored
      notifier.showOfflineDialog();
      await tester.pump();
      expect(find.byType(OfflineDisconnectDialog), findsNothing);
    });

    testWidgets('Offline dialog is reset when connection is restored, allowing 1 prompt on next disconnection', (tester) async {
      final container = ProviderContainer();
      final notifier = container.read(connectivityProvider.notifier);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: const Scaffold(
              body: Text('Main Screen'),
            ),
          ),
        ),
      );

      notifier.notifySplashFinished();

      // 1. Disconnect
      notifier.handleNetworkDisconnection();
      await tester.pump();
      expect(find.byType(OfflineDisconnectDialog), findsOneWidget);

      OfflineDisconnectDialog.dismiss();
      await tester.pumpAndSettle();
      expect(find.byType(OfflineDisconnectDialog), findsNothing);

      // Subsequent disconnect events during same offline period are blocked
      notifier.handleNetworkDisconnection();
      await tester.pump();
      expect(find.byType(OfflineDisconnectDialog), findsNothing);

      // 2. Reconnect
      notifier.checkConnectivity(); // or manually reset flag / status
      notifier.resetOfflineDialogFlag();

      // 3. Next disconnection event triggers dialog once again
      notifier.showOfflineDialog();
      await tester.pump();
      expect(find.byType(OfflineDisconnectDialog), findsOneWidget);

      OfflineDisconnectDialog.dismiss();
      await tester.pumpAndSettle();
    });
  });
}
