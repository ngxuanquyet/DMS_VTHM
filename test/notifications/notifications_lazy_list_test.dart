import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/features/notifications/domain/entities/notification_entity.dart';
import 'package:vthm_dms/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:vthm_dms/features/notifications/domain/usecases/notifications_usecases.dart';
import 'package:vthm_dms/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:vthm_dms/features/notifications/presentation/viewmodels/notifications_view_model.dart';
import 'package:vthm_dms/features/notifications/presentation/widgets/notification_item_card.dart';

/// Màn Thông báo (29/10/2026): danh sách dựng LƯỜI (SliverList) — hàng trăm thông báo không dựng hết một lượt.
class _FakeRepo implements NotificationsRepository {
  NotificationEntity n(int i) => NotificationEntity(
        id: '$i',
        type: 'system',
        title: 'Thông báo $i',
        message: 'Nội dung $i',
        timeAgo: '1 phút',
        isRead: false,
        category: 'system',
      );

  @override
  Future<NotificationDataEntity> getNotifications() async =>
      NotificationDataEntity(today: List.generate(300, n), earlier: List.generate(300, (i) => n(1000 + i)));

  @override
  Future<void> markAllAsRead() async {}

  @override
  Future<void> markAsRead(String id) async {}
}

void main() {
  testWidgets('600 thông báo ⇒ chỉ dựng thẻ trong khung nhìn; cuộn tới được mục "Trước đó"', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [getNotificationsUseCaseProvider.overrideWithValue(GetNotificationsUseCase(_FakeRepo()))],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final built = find.byType(NotificationItemCard, skipOffstage: false).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(40));

    // Kéo xuống nhiều lần tới phần "Trước đó" (300 thông báo đầu là "Hôm nay").
    for (var i = 0; i < 40; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pump();
    }
    final ids = tester
        .widgetList<NotificationItemCard>(find.byType(NotificationItemCard))
        .map((c) => int.parse(c.notification.id));
    expect(ids.any((id) => id >= 1000), isTrue);
    await tester.pump(const Duration(minutes: 1)); // Timer còn chờ của màn (hiệu ứng/làm mới)
  });
}
