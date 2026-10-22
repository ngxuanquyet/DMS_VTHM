import '../../../../core/network/api_client.dart';
import '../models/notification_model.dart';

class NotificationsApiService {
  final ApiClient _apiClient;

  /// Chuông app DMS chỉ hiện tin thị trường (nhắc ca, duyệt/từ chối điểm bán) — server lọc theo `?app=dms`
  /// (22/10/2026). Thiếu tham số thì server trả cả tin việc/phản hồi của One, và "đọc tất cả" đánh dấu cả chúng.
  static const Map<String, dynamic> _appQuery = {'app': 'dms'};

  NotificationsApiService(this._apiClient);

  Future<NotificationDataModel> getNotifications({int page = 1, int perPage = 20}) async {
    final response = await _apiClient.get(
      '/notification/notifications',
      queryParameters: {
        ..._appQuery,
        'page': page,
        'per-page': perPage,
      },
    );
    return NotificationDataModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> markAsRead(String id) async {
    try {
      await _apiClient.post('/notification/notifications/$id/read', queryParameters: _appQuery);
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await _apiClient.post('/notification/notifications/read-all', queryParameters: _appQuery);
    } catch (_) {}
  }

  Future<int?> getUnreadCount() async {
    try {
      final response = await _apiClient.get('/notification/notifications/unread-count', queryParameters: _appQuery);
      if (response is Map<String, dynamic>) {
        final data = response['data'] ?? response;
        return data['unread'] as int?;
      }
    } catch (_) {}
    return null;
  }
}
