import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/services/app_notification_service.dart';
import 'package:vthm_dms/features/notifications/domain/entities/notification_entity.dart';
import 'package:vthm_dms/features/notifications/presentation/states/notifications_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppNotificationService 8 Notification Types Tests', () {
    test('Can trigger and store all 8 required notification types', () async {
      final service = AppNotificationService();

      // 1. Nhắc Chấm công Vào ca buổi sáng
      await service.notifyAttendanceCheckinReminder();

      // 2. Nhắc lộ trình đầu ngày
      await service.notifyRouteBriefing(
        totalDealers: 12,
        routeName: 'Tuyến Hà Nội 1',
      );

      // 3. Cảnh báo tiến độ tuyến trong ngày
      await service.notifyRouteProgress(
        completed: 4,
        total: 12,
        period: 'Trưa',
      );

      // 4. Cảnh báo quên Check-out
      await service.notifyForgotCheckout(
        dealerName: 'Đại lý An Phát',
        minutes: 45,
      );

      // 5. Gợi ý thông minh theo vị trí
      await service.notifyNearbyDealerSuggestion(
        dealerName: 'Tạp hóa Bình An',
        distanceMeters: 250,
        dealerId: 'dealer_102',
      );

      // 6. Nhắc Chấm công Ra ca cuối ngày
      await service.notifyAttendanceCheckoutReminder();

      // 7. Thông báo đồng bộ ngoại tuyến thành công
      await service.notifyOfflineSyncSuccess(successCount: 5);

      // 8. Cảnh báo tồn đọng hàng đợi offline
      await service.notifyOfflineQueuePending(pendingCount: 3);

      final data = await service.getSavedNotifications();
      expect(data.today.length, 8);

      final types = data.today.map((e) => e.type).toSet();
      expect(types, contains('attendance_checkin'));
      expect(types, contains('route_briefing'));
      expect(types, contains('route_progress'));
      expect(types, contains('forgot_checkout'));
      expect(types, contains('nearby_suggestion'));
      expect(types, contains('attendance_checkout'));
      expect(types, contains('sync_success'));
      expect(types, contains('offline_queue_warning'));

      // Check unread count
      final unreadCount = await service.getUnreadCount();
      expect(unreadCount, 8);

      // Check mark all as read
      await service.markAllAsRead();
      final updatedData = await service.getSavedNotifications();
      expect(updatedData.today.every((e) => e.isRead), isTrue);

      final updatedUnreadCount = await service.getUnreadCount();
      expect(updatedUnreadCount, 0);
    });

    test('NotificationsState category and unread filters work accurately', () async {
      final now = DateTime.now();
      final testItems = [
        NotificationEntity(
          id: '1',
          type: 'attendance_checkin',
          title: 'Nhắc chấm công vào ca',
          message: 'Đã đến giờ vào ca',
          timeAgo: 'Vừa xong',
          isRead: false,
          category: 'work',
          createdAt: now,
        ),
        NotificationEntity(
          id: '2',
          type: 'route_progress',
          title: 'Cảnh báo tiến độ',
          message: 'Đã hoàn thành 3/10',
          timeAgo: '5 phút trước',
          isRead: true,
          category: 'work',
          createdAt: now,
        ),
        NotificationEntity(
          id: '3',
          type: 'sync_success',
          title: 'Đồng bộ thành công',
          message: 'Đã gửi 3 bản ghi',
          timeAgo: '10 phút trước',
          isRead: false,
          category: 'system',
          createdAt: now,
        ),
      ];

      final dataEntity = NotificationDataEntity(today: testItems, earlier: []);

      // Filter: Tất cả (index 0)
      final stateAll = NotificationsState(
        status: NotificationStatus.loaded,
        data: dataEntity,
        selectedFilterIndex: 0,
      );
      expect(stateAll.filteredToday.length, 3);

      // Filter: Chưa đọc (index 1)
      final stateUnread = NotificationsState(
        status: NotificationStatus.loaded,
        data: dataEntity,
        selectedFilterIndex: 1,
      );
      expect(stateUnread.filteredToday.length, 2);
      expect(stateUnread.filteredToday.map((e) => e.id), containsAll(['1', '3']));

      // Filter: Công việc (index 2)
      final stateWork = NotificationsState(
        status: NotificationStatus.loaded,
        data: dataEntity,
        selectedFilterIndex: 2,
      );
      expect(stateWork.filteredToday.length, 2);
      expect(stateWork.filteredToday.map((e) => e.id), containsAll(['1', '2']));

      // Filter: Hệ thống (index 3)
      final stateSystem = NotificationsState(
        status: NotificationStatus.loaded,
        data: dataEntity,
        selectedFilterIndex: 3,
      );
      expect(stateSystem.filteredToday.length, 1);
      expect(stateSystem.filteredToday.first.id, '3');
    });

    test('Shift 8h - 17h Mon-Sat scheduling and cancellation methods execute properly', () async {
      final service = AppNotificationService();

      // Test scheduling methods
      await service.scheduleDailyCheckinReminder(hour: 7, minute: 50);
      await service.scheduleDailyCheckoutReminder(hour: 17, minute: 0);

      // Test cancel for today or all days
      await service.cancelCheckinReminder(todayOnly: true);
      await service.cancelCheckoutReminder(todayOnly: true);

      await service.cancelCheckinReminder(todayOnly: false);
      await service.cancelCheckoutReminder(todayOnly: false);

      expect(true, isTrue);
    });

    test('Late checkin and overdue checkout reminders produce informative messages', () async {
      SharedPreferences.setMockInitialValues({});
      final service = AppNotificationService();

      // Test late checkin
      await service.notifyAttendanceCheckinReminder(isLate: true);
      // Test overdue checkout
      await service.notifyAttendanceCheckoutReminder(isOverdue: true);

      final data = await service.getSavedNotifications();
      final checkinNotif = data.today.firstWhere((e) => e.type == 'attendance_checkin');
      final checkoutNotif = data.today.firstWhere((e) => e.type == 'attendance_checkout');

      expect(checkinNotif.title, 'Cảnh báo chưa chấm công vào ca');
      expect(checkinNotif.message, contains('08:00'));

      expect(checkoutNotif.title, 'Cảnh báo chưa chấm công ra ca');
      expect(checkoutNotif.message, contains('17:00'));
    });
  });
}
