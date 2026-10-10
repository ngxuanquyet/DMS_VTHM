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
    // 1. Đọc danh sách thông báo đã lưu trên máy và danh sách ID đã đọc
    final localData = await _localService.getSavedNotifications();
    final readIds = await _localService.getReadNotificationIds();

    // 2. Thử lấy từ server nếu online
    NotificationDataEntity? remoteData;
    try {
      final model = await _apiService.getNotifications();
      remoteData = model.toEntity();
    } catch (_) {}

    // 3. Kết hợp thông báo local và remote (áp dụng trạng thái đã đọc)
    final combinedToday = <NotificationEntity>[...localData.today];
    final combinedEarlier = <NotificationEntity>[...localData.earlier];

    if (remoteData != null) {
      for (final r in remoteData.today) {
        if (!combinedToday.any((e) => e.id == r.id)) {
          final isRead = r.isRead || readIds.contains(r.id);
          combinedToday.add(r.copyWith(isRead: isRead));
        }
      }
      for (final r in remoteData.earlier) {
        if (!combinedEarlier.any((e) => e.id == r.id)) {
          final isRead = r.isRead || readIds.contains(r.id);
          combinedEarlier.add(r.copyWith(isRead: isRead));
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
  Future<void> markAsRead(String id) async {
    await _localService.markAsRead(id);
    if (_cachedData != null) {
      _cachedData = NotificationDataEntity(
        today: _cachedData!.today.map((e) => e.id == id ? e.copyWith(isRead: true) : e).toList(),
        earlier: _cachedData!.earlier.map((e) => e.id == id ? e.copyWith(isRead: true) : e).toList(),
      );
    }
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
