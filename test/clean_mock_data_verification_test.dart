import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/network/api_logger_interceptor.dart';
import 'package:vthm_dms/core/network/mock_backend.dart';
import 'package:vthm_dms/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:vthm_dms/features/attendance/data/services/attendance_api_service.dart';
import 'package:vthm_dms/features/customer/data/models/customer_model.dart';
import 'package:vthm_dms/features/home/data/repositories/home_repository_impl.dart';
import 'package:vthm_dms/features/home/data/services/home_api_service.dart';
import 'package:vthm_dms/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:vthm_dms/features/notifications/data/services/notifications_api_service.dart';
import 'package:vthm_dms/features/profile/data/services/profile_api_service.dart';
import 'package:vthm_dms/features/route/data/services/route_api_service.dart';

class FailingApiClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw Exception('Network offline / Endpoint not found');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kiểm tra loại bỏ hoàn toàn mock data trong dự án', () {
    test('1. kMockCustomers trong customer_model.dart đã được làm rỗng', () {
      expect(kMockCustomers, isEmpty);
    });

    test('2. MockBackendInterceptor không còn trong dioProvider', () {
      final dio = Dio();
      dio.interceptors.addAll([
        AuthInterceptor(dio),
        AppApiLoggerInterceptor(),
      ]);
      expect(dio.interceptors.any((i) => i is MockBackendInterceptor), isFalse);
    });

    test('3. HomeRepositoryImpl dựng DashboardEntity từ dữ liệu thực tế, không dùng mock', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.keyUserData: jsonEncode({
          'id': '101',
          'username': 'quyetnx',
          'display_name': 'Nguyễn Xuân Quyết',
          'job_title': 'Chuyên viên DMS',
        }),
      });

      final failingApiClient = FailingApiClient();
      final homeApiService = HomeApiService(failingApiClient);
      final repo = HomeRepositoryImpl(homeApiService);

      final dashboard = await repo.getDashboardData();

      // Phải lấy đúng tên thật của tài khoản đăng nhập, không phải Nguyễn Văn An
      expect(dashboard.greeting.userName, 'Nguyễn Xuân Quyết');
      expect(dashboard.greeting.role, 'Chuyên viên DMS');
      expect(dashboard.greeting.currentDate.contains('ngày'), isTrue);

      // Khi không có hoạt động hôm nay, recentActivities phải rỗng, không tự tạo mock
      expect(dashboard.recentActivities, isEmpty);

      // Trạng thái ca làm việc mặc định khi chưa vào ca
      expect(dashboard.attendance.isCheckedIn, isFalse);
      expect(dashboard.attendance.statusLabel, 'Chưa vào ca');
    });

    test('4. AttendanceRepositoryImpl lưu trữ ca làm việc thực tế, không trả mock stats', () async {
      SharedPreferences.setMockInitialValues({});
      final failingApiClient = FailingApiClient();
      final attApiService = AttendanceApiService(failingApiClient);
      final repo = AttendanceRepositoryImpl(attApiService);

      // Khi chưa từng chấm công
      final initial = await repo.getAttendanceDetail();
      expect(initial.isWorking, isFalse);
      expect(initial.checkInTime, '--:--');
      expect(initial.monthlyStats.workingDays, 0);
      expect(initial.monthlyStats.lateDays, 0);
      expect(initial.history, isEmpty);

      // Người dùng bấm VÀO CA
      final clockedIn = await repo.toggleAttendanceCheck();
      expect(clockedIn.isWorking, isTrue);
      expect(clockedIn.checkInTime, isNot('--:--'));

      // Người dùng bấm HẾT CA
      final clockedOut = await repo.toggleAttendanceCheck();
      expect(clockedOut.isWorking, isFalse);
      expect(clockedOut.checkInTime, '--:--');
      expect(clockedOut.history.length, 1);
      expect(clockedOut.monthlyStats.workingDays, 1);
    });

    test('5. NotificationsRepositoryImpl xử lý an toàn khi không có mock backend', () async {
      final failingApiClient = FailingApiClient();
      final notifApiService = NotificationsApiService(failingApiClient);
      final repo = NotificationsRepositoryImpl(notifApiService);

      final notifs = await repo.getNotifications();
      expect(notifs.today, isEmpty);
      expect(notifs.earlier, isEmpty);
    });

    test('6. RouteApiService getRouteDetail và getDealerCheckinData trả dữ liệu mặc định an toàn khi không có mock', () async {
      SharedPreferences.setMockInitialValues({});
      final failingApiClient = FailingApiClient();
      final routeApiService = RouteApiService(failingApiClient);

      final routeDetail = await routeApiService.getRouteDetail();
      expect(routeDetail.dealers, isEmpty);
      expect(routeDetail.totalDealers, 0);

      final checkinData = await routeApiService.getDealerCheckinData();
      expect(checkinData.dealer.id, '');
      expect(checkinData.tasks, isEmpty);
    });
  });
}
