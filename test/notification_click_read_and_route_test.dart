import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/services/app_notification_service.dart';
import 'package:vthm_dms/features/notifications/domain/entities/notification_entity.dart';
import 'package:vthm_dms/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:vthm_dms/features/notifications/presentation/viewmodels/notifications_view_model.dart';
import 'package:vthm_dms/features/notifications/presentation/widgets/notification_item_card.dart';

class FakeNotificationsRepository implements NotificationsRepository {
  NotificationDataEntity _data;
  FakeNotificationsRepository(this._data);

  @override
  Future<NotificationDataEntity> getNotifications() async => _data;

  @override
  Future<void> markAllAsRead() async {
    _data = NotificationDataEntity(
      today: _data.today.map((e) => e.copyWith(isRead: true)).toList(),
      earlier: _data.earlier.map((e) => e.copyWith(isRead: true)).toList(),
    );
  }

  @override
  Future<void> markAsRead(String id) async {
    _data = NotificationDataEntity(
      today: _data.today.map((e) => e.id == id ? e.copyWith(isRead: true) : e).toList(),
      earlier: _data.earlier.map((e) => e.id == id ? e.copyWith(isRead: true) : e).toList(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Notification Route Resolver Tests', () {
    test('Route notifications correctly map to /routes', () {
      const notif1 = NotificationEntity(
        id: '1',
        type: 'route_briefing',
        title: 'Lộ trình hôm nay',
        message: 'Hôm nay bạn có 8 điểm bán cần viếng thăm trên tuyến Tuyến 1.',
        timeAgo: 'Vừa xong',
        isRead: false,
        category: 'work',
        routePath: '/route',
      );
      expect(NotificationItemCard.resolveNotificationRoute(notif1), '/routes');

      const notif2 = NotificationEntity(
        id: '2',
        type: 'route_progress',
        title: 'Cảnh báo tiến độ tuyến (Trưa)',
        message: 'Bạn đã hoàn thành 4/8 điểm bán.',
        timeAgo: '1 giờ trước',
        isRead: false,
        category: 'work',
      );
      expect(NotificationItemCard.resolveNotificationRoute(notif2), '/routes');

      const notif3 = NotificationEntity(
        id: '3',
        type: 'nearby_suggestion',
        title: 'Gợi ý điểm bán lân cận',
        message: 'Bạn đang ở gần Đại lý A.',
        timeAgo: '10 phút trước',
        isRead: false,
        category: 'work',
      );
      expect(NotificationItemCard.resolveNotificationRoute(notif3), '/routes');
    });

    test('Attendance and other notification types map accurately', () {
      const notifAtt = NotificationEntity(
        id: '4',
        type: 'attendance_checkin',
        title: 'Nhắc chấm công vào ca',
        message: 'Sắp đến giờ vào ca (08:00).',
        timeAgo: 'Vừa xong',
        isRead: false,
        category: 'work',
        routePath: '/attendance',
      );
      expect(NotificationItemCard.resolveNotificationRoute(notifAtt), '/attendance');

      const notifForm = NotificationEntity(
        id: '5',
        type: 'form',
        title: 'Biểu mẫu khảo sát mới',
        message: 'Có biểu mẫu mới cần hoàn thiện.',
        timeAgo: '2 giờ trước',
        isRead: false,
        category: 'work',
      );
      expect(NotificationItemCard.resolveNotificationRoute(notifForm), '/forms');

      const notifSys = NotificationEntity(
        id: '6',
        type: 'system',
        title: 'Bảo trì hệ thống',
        message: 'Hệ thống bảo trì lúc 23h đêm nay.',
        timeAgo: 'Hôm qua',
        isRead: true,
        category: 'system',
      );
      expect(NotificationItemCard.resolveNotificationRoute(notifSys), isNull);
    });
  });

  group('Notification Read Status & Blue Dot Widget Tests', () {
    testWidgets('Unread notification displays blue dot; clicking marks read and hides dot', (tester) async {
      final notif = const NotificationEntity(
        id: 'notif_test_1',
        type: 'route_briefing',
        title: 'Lộ trình bán hàng hôm nay',
        message: 'Bạn có 10 điểm bán trên tuyến.',
        timeAgo: 'Vừa xong',
        isRead: false,
        category: 'work',
      );

      final fakeRepo = FakeNotificationsRepository(
        NotificationDataEntity(today: [notif], earlier: []),
      );

      final container = ProviderContainer(
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      bool tapped = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  final state = ref.watch(notificationsViewModelProvider);
                  final currentNotif = state.data?.today.firstOrNull ?? notif;
                  return NotificationItemCard(
                    notification: currentNotif,
                    onTap: () {
                      tapped = true;
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that unread dot (chấm xanh) is visible initially
      final dotFinder = find.byWidgetPredicate((widget) {
        if (widget is Container && widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          return box.shape == BoxShape.circle && box.color != null && widget.constraints?.maxWidth == 9;
        }
        return false;
      });
      expect(dotFinder, findsOneWidget);

      // Verify bold font for unread title
      final titleText = tester.widget<Text>(find.text('Lộ trình bán hàng hôm nay'));
      expect(titleText.style?.fontWeight, FontWeight.w700);

      // Click the notification
      await tester.tap(find.byType(NotificationItemCard));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);

      // The notification is now marked as read
      final updatedState = container.read(notificationsViewModelProvider);
      expect(updatedState.data?.today.first.isRead, isTrue);

      // Blue dot is now GONE (bỏ chấm xanh)
      expect(dotFinder, findsNothing);

      // Title font weight is normal (FontWeight.w500)
      final titleTextAfter = tester.widget<Text>(find.text('Lộ trình bán hàng hôm nay'));
      expect(titleTextAfter.style?.fontWeight, FontWeight.w500);

      container.dispose();
    });

    testWidgets('AppNotificationService marks individual notification as read in persistent store', (tester) async {
      final notifService = AppNotificationService();
      await notifService.init();

      await notifService.sendNotification(
        id: 111,
        title: 'Thông báo tuyến số 1',
        message: 'Lộ trình tuyến thứ 2',
        type: 'route',
        showSystemTray: false,
      );

      final initial = await notifService.getSavedNotifications();
      expect(initial.today.isNotEmpty, isTrue);
      final notifId = initial.today.first.id;
      expect(initial.today.first.isRead, isFalse);

      // Mark single notification as read
      await notifService.markAsRead(notifId);

      final after = await notifService.getSavedNotifications();
      final readNotif = after.today.firstWhere((e) => e.id == notifId);
      expect(readNotif.isRead, isTrue);

      final readIds = await notifService.getReadNotificationIds();
      expect(readIds.contains(notifId), isTrue);
    });
  });
}
