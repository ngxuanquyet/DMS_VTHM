import '../entities/notification_entity.dart';

abstract class NotificationsRepository {
  Future<NotificationDataEntity> getNotifications();
  Future<void> markAllAsRead();
}
