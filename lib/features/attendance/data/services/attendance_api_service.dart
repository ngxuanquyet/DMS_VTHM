import '../../../../core/network/api_client.dart';
import '../models/attendance_model.dart';

class AttendanceApiService {
  final ApiClient _apiClient;

  AttendanceApiService(this._apiClient);

  Future<AttendanceDetailModel> getAttendanceDetail() async {
    final response = await _apiClient.get('/attendance');
    return AttendanceDetailModel.fromJson(response as Map<String, dynamic>);
  }
}
