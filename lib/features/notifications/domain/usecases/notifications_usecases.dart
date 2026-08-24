import '../entities/notification_entity.dart';
import '../repositories/notifications_repository.dart';

class GetNotificationsUseCase {
  final NotificationsRepository _repository;

  GetNotificationsUseCase(this._repository);

  Future<NotificationDataEntity> call() {
    return _repository.getNotifications();
  }
}

class MarkAllReadUseCase {
  final NotificationsRepository _repository;

  MarkAllReadUseCase(this._repository);

  Future<void> call() {
    return _repository.markAllAsRead();
  }
}
