import '../../../../core/services/app_notification_service.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../services/notifications_api_service.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsApiService _apiService;
  final AppNotificationService _localService;
  NotificationDataEntity? _cachedData;

  NotificationsRepositoryImpl(
    this._apiService, [
    AppNotificationService? localService,
  ]) : _localService = localService ?? AppNotificationService();

  @override
  Future<NotificationDataEntity> getNotifications() async {
    // 1. Đọc danh sách thông báo đã lưu trên máy
    final localData = await _localService.getSavedNotifications();

    // 2. Thử lấy từ server nếu online
    NotificationDataEntity? remoteData;
    try {
      final model = await _apiService.getNotifications();
      remoteData = model.toEntity();
    } catch (_) {}

    // 3. Kết hợp thông báo local và remote
    final combinedToday = <NotificationEntity>[...localData.today];
    final combinedEarlier = <NotificationEntity>[...localData.earlier];

    if (remoteData != null) {
      for (final r in remoteData.today) {
        if (!combinedToday.any((e) => e.id == r.id)) {
          combinedToday.add(r);
        }
      }
      for (final r in remoteData.earlier) {
        if (!combinedEarlier.any((e) => e.id == r.id)) {
          combinedEarlier.add(r);
        }
      }
    }

    _cachedData = NotificationDataEntity(
      today: combinedToday,
      earlier: combinedEarlier,
    );
    return _cachedData!;
  }

  @override
  Future<void> markAllAsRead() async {
    await _localService.markAllAsRead();
    if (_cachedData != null) {
      _cachedData = NotificationDataEntity(
        today: _cachedData!.today.map((e) => e.copyWith(isRead: true)).toList(),
        earlier: _cachedData!.earlier.map((e) => e.copyWith(isRead: true)).toList(),
      );
    }
  }
}
