import '../../../../core/network/api_client.dart';
import '../models/notification_model.dart';

class NotificationsApiService {
  final ApiClient _apiClient;

  NotificationsApiService(this._apiClient);

  Future<NotificationDataModel> getNotifications({int page = 1, int perPage = 20}) async {
    final response = await _apiClient.get(
      '/notification/notifications',
      queryParameters: {
        'page': page,
        'per-page': perPage,
      },
    );
    return NotificationDataModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> markAsRead(String id) async {
    try {
      await _apiClient.post('/notification/notifications/$id/read');
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await _apiClient.post('/notification/notifications/read-all');
    } catch (_) {}
  }

  Future<int?> getUnreadCount() async {
    try {
      final response = await _apiClient.get('/notification/notifications/unread-count');
      if (response is Map<String, dynamic>) {
        final data = response['data'] ?? response;
        return data['unread_count'] as int? ?? data['count'] as int?;
      }
    } catch (_) {}
    return null;
  }
}
