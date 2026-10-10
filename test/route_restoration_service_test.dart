import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/services/route_restoration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RouteRestorationService Tests', () {
    test('savePendingRoute and getAndClearPendingRestoreRoute restores correctly', () async {
      await RouteRestorationService.savePendingRoute('/attendance');

      final restored = await RouteRestorationService.getAndClearPendingRestoreRoute();
      expect(restored, equals('/attendance'));

      // Calling again should return null because pending route was cleared
      final secondCall = await RouteRestorationService.getAndClearPendingRestoreRoute();
      expect(secondCall, isNull);
    });

    test('ignores splash, login and root routes', () async {
      await RouteRestorationService.savePendingRoute('/splash');
      var restored = await RouteRestorationService.getAndClearPendingRestoreRoute();
      expect(restored, isNull);

      await RouteRestorationService.savePendingRoute('/login');
      restored = await RouteRestorationService.getAndClearPendingRestoreRoute();
      expect(restored, isNull);

      await RouteRestorationService.savePendingRoute('');
      restored = await RouteRestorationService.getAndClearPendingRestoreRoute();
      expect(restored, isNull);
    });

    test('falls back to lastActiveRoute when pendingRoute is not set', () async {
      await RouteRestorationService.saveLastActiveRoute('/check-in');

      final restored = await RouteRestorationService.getAndClearPendingRestoreRoute();
      expect(restored, equals('/check-in'));
    });

    test('ignores /home fallback as lastActiveRoute', () async {
      await RouteRestorationService.saveLastActiveRoute('/home');

      final restored = await RouteRestorationService.getAndClearPendingRestoreRoute();
      expect(restored, isNull);
    });
  });
}
