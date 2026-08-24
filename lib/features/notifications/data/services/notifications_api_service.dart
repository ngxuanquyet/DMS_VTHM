import '../../../../core/network/api_client.dart';
import '../models/notification_model.dart';

class NotificationsApiService {
  final ApiClient _apiClient;

  NotificationsApiService(this._apiClient);

  Future<NotificationDataModel> getNotifications() async {
    final response = await _apiClient.get('/notifications');
    return NotificationDataModel.fromJson(response as Map<String, dynamic>);
  }
}
