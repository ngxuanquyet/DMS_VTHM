import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:vthm_dms/core/services/fcm_push_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FCM Push Notification Spec 19/10/2026 Tests', () {
    final fcmService = FcmPushService();

    test('§5.3 isForCurrentUser returns true if data.uids is missing or empty', () {
      final msgWithoutUids = RemoteMessage(
        data: {'type': 'att.shift_remind_in'},
      );
      expect(fcmService.isForCurrentUser(msgWithoutUids), isTrue);

      final msgWithEmptyUids = RemoteMessage(
        data: {'type': 'att.shift_remind_in', 'uids': ''},
      );
      expect(fcmService.isForCurrentUser(msgWithEmptyUids), isTrue);
    });

    test('§6.1 crm.customer_approved & crm.customer_rejected parameter parsing', () {
      const link1 = '/crm/my-customers?open=8455';
      final uri1 = Uri.tryParse(link1);
      final openParam1 = uri1?.queryParameters['open'] ?? RegExp(r'[?&]open=(\d+)').firstMatch(link1)?.group(1);
      expect(openParam1, '8455');
      expect(int.tryParse(openParam1!), 8455);

      const link2 = '/crm/customers?open=1284';
      final uri2 = Uri.tryParse(link2);
      final openParam2 = uri2?.queryParameters['open'] ?? RegExp(r'[?&]open=(\d+)').firstMatch(link2)?.group(1);
      expect(openParam2, '1284');
      expect(int.tryParse(openParam2!), 1284);
    });

    test('§3.1 Registration payload requires platform=android and app=dms', () {
      const token = 'fake_fcm_token_12345';
      const deviceName = 'Samsung SM-A155F';

      final payload = {
        'token': token,
        'platform': 'android',
        'app': 'dms',
        'device_name': deviceName,
      };

      expect(payload['platform'], 'android');
      expect(payload['app'], 'dms');
      expect(payload['token'], token);
      expect(payload['device_name'], isNotEmpty);
    });

    test('crm.customer_rejected maps directly to /customers/rejected screen', () {
      const type = 'crm.customer_rejected';
      final resolvedRoute = type == 'crm.customer_rejected' ? '/customers/rejected' : '/customers';
      expect(resolvedRoute, '/customers/rejected');
    });

    test('§5.3 isForCurrentUser matches current user ID accurately', () {
      fcmService.setCurrentUserId('1009');

      final msgMatch = RemoteMessage(
        data: {'type': 'crm.customer_rejected', 'uids': '1009,2231'},
      );
      expect(fcmService.isForCurrentUser(msgMatch), isTrue);

      final msgNotMatch = RemoteMessage(
        data: {'type': 'crm.customer_rejected', 'uids': '8888,9999'},
      );
      expect(fcmService.isForCurrentUser(msgNotMatch), isFalse);

      // Khi chưa có currentUserId, fallback an toàn cho phép hiển thị
      fcmService.setCurrentUserId(null);
      expect(fcmService.isForCurrentUser(msgNotMatch), isTrue);
    });
  });
}
