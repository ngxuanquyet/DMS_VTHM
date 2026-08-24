import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../services/notifications_api_service.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsApiService _apiService;
  NotificationDataEntity? _cachedData;

  NotificationsRepositoryImpl(this._apiService);

  @override
  Future<NotificationDataEntity> getNotifications() async {
    final model = await _apiService.getNotifications();
    _cachedData = model.toEntity();
    return _cachedData!;
  }

  @override
  Future<void> markAllAsRead() async {
    if (_cachedData != null) {
      _cachedData = NotificationDataEntity(
        today: _cachedData!.today.map((e) => e.copyWith(isRead: true)).toList(),
        earlier: _cachedData!.earlier.map((e) => e.copyWith(isRead: true)).toList(),
      );
    }
  }
}
