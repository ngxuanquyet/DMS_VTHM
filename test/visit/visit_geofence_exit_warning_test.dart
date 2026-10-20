import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/services/app_notification_service.dart';
import 'package:vthm_dms/features/route/presentation/states/route_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Visit Geofence Exit Warning Tests', () {
    test('CheckInState default geofence values and copyWith work properly', () {
      const state = CheckInState();
      expect(state.isOutOfGeofence, isFalse);
      expect(state.currentDistanceToDealerM, isNull);
      expect(state.allowedGeofenceRadiusM, isNull);

      final updatedState = state.copyWith(
        isOutOfGeofence: true,
        currentDistanceToDealerM: 250.5,
        allowedGeofenceRadiusM: 100.0,
      );

      expect(updatedState.isOutOfGeofence, isTrue);
      expect(updatedState.currentDistanceToDealerM, 250.5);
      expect(updatedState.allowedGeofenceRadiusM, 100.0);

      final resetState = updatedState.copyWith(
        isOutOfGeofence: false,
      );
      expect(resetState.isOutOfGeofence, isFalse);
    });

    test('AppNotificationService triggers visit_geofence_exit with formatted distance', () async {
      final notifService = AppNotificationService();

      await notifService.notifyVisitGeofenceExit(
        dealerName: 'Cửa hàng Tạp hóa Hồng Phát',
        distanceMeters: 350,
        allowedRadiusMeters: 100,
      );

      final notifs = await notifService.getSavedNotifications();
      expect(notifs.today.isNotEmpty, isTrue);

      final alert = notifs.today.firstWhere((n) => n.type == 'visit_geofence_exit');
      expect(alert.title, contains('Cảnh báo rời xa điểm bán'));
      expect(alert.message, contains('350m'));
      expect(alert.message, contains('100m'));
      expect(alert.message, contains('Cửa hàng Tạp hóa Hồng Phát'));

      // Test cancel notification
      await notifService.cancelVisitGeofenceExitNotification();
    });

    test('AppNotificationService formats kilometer distance correctly when > 1000m', () async {
      final notifService = AppNotificationService();

      await notifService.notifyVisitGeofenceExit(
        dealerName: 'Đại lý Toàn Thắng',
        distanceMeters: 1500,
        allowedRadiusMeters: 200,
      );

      final notifs = await notifService.getSavedNotifications();
      final alert = notifs.today.firstWhere((n) => n.message.contains('Đại lý Toàn Thắng'));

      expect(alert.message, contains('1.5km'));
      expect(alert.message, contains('200m'));
    });
  });
}
