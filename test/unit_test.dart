import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/network/mock_backend.dart';
import 'package:vthm_dms/features/attendance/data/models/attendance_model.dart';
import 'package:vthm_dms/features/home/data/models/dashboard_model.dart';
import 'package:vthm_dms/features/notifications/data/models/notification_model.dart';
import 'package:vthm_dms/features/profile/data/models/user_profile_model.dart';
import 'package:vthm_dms/features/route/data/models/route_model.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Clean Architecture & Model Serialization Tests', () {
    test('DashboardModel toEntity converts nested objects accurately', () {
      final json = {
        'greeting': {
          'userName': 'Nguyễn Văn An',
          'role': 'Nhân viên thị trường',
          'currentDate': 'Thứ Hai, 24/08/2026',
        },
        'attendance': {
          'isCheckedIn': true,
          'checkInTime': '07:45',
          'workDuration': '04:15:20',
          'statusLabel': 'Đang làm việc',
        },
        'routeSummary': {
          'routeName': 'Tuyến Vĩnh Tường - Yên Lạc',
          'completedCount': 8,
          'totalCount': 12,
          'progressPercent': 0.67,
          'nextStop': 'Đại lý VLXD Thành Công',
        },
        'formSummary': {
          'pendingCount': 3,
          'completedCount': 5,
          'overdueCount': 0,
        },
        'recentActivities': [
          {
            'id': 'ACT-01',
            'time': '09:30',
            'title': 'Check-in thành công tại',
            'highlight': 'Đại lý Thành Công',
            'suffix': 'Hợp lệ GPS (sai số 5m)',
            'isPrimary': true,
          }
        ],
      };

      final model = DashboardModel.fromJson(json);
      final entity = model.toEntity();

      expect(entity.greeting.userName, 'Nguyễn Văn An');
      expect(entity.attendance.isCheckedIn, true);
      expect(entity.routeSummary.completedCount, 8);
      expect(entity.formSummary.pendingCount, 3);
      expect(entity.recentActivities.length, 1);
      expect(entity.recentActivities.first.highlight, 'Đại lý Thành Công');
    });

    test('AttendanceDetailModel toEntity converts location and stats accurately', () {
      final json = {
        'isWorking': true,
        'currentTime': '08:30:15',
        'currentDateFormatted': 'Thứ Hai, 24/08/2026',
        'checkInTime': '07:45:00',
        'workDurationSeconds': 2700,
        'location': {
          'address': 'Khu CN Khai Quang, Vĩnh Yên, Vĩnh Phúc',
          'gpsAccuracy': 'Chính xác (sai số 5m)',
          'latitude': 21.312345,
          'longitude': 105.598765,
        },
        'monthlyStats': {
          'monthLabel': 'Tháng 08/2026',
          'workingDays': 20,
          'lateDays': 1,
        },
        'history': [
          {
            'id': 'ATT-01',
            'date': 'Hôm nay (24/08)',
            'timeRange': '07:45 - Hiện tại',
            'status': 'Đúng giờ',
            'isLate': false,
          }
        ],
      };

      final model = AttendanceDetailModel.fromJson(json);
      final entity = model.toEntity();

      expect(entity.isWorking, true);
      expect(entity.location.gpsAccuracy, contains('5m'));
      expect(entity.monthlyStats.workingDays, 20);
      expect(entity.history.first.isLate, false);
    });

    test('RouteDetailModel toEntity converts dealer visit statuses accurately', () {
      final json = {
        'id': 'RT-20260824',
        'title': 'Tuyến Vĩnh Tường - Yên Lạc',
        'totalDealers': 12,
        'completedDealers': 8,
        'pendingDealers': 4,
        'progressPercent': 0.67,
        'dealers': [
          {
            'id': 'DL-01',
            'order': '01',
            'name': 'Đại lý Thành Công',
            'address': 'Khu 3, Vĩnh Tường',
            'status': 'completed',
            'statusLabel': 'Đã ghé thăm',
            'visitedTime': '08:15',
            'isVip': true,
          },
          {
            'id': 'DL-02',
            'order': '02',
            'name': 'NPP Xi Măng Hoàng Gia',
            'address': 'Đường Hùng Vương, Vĩnh Tường',
            'status': 'in_progress',
            'statusLabel': 'Đang ghé thăm',
            'isVip': false,
          }
        ],
      };

      final model = RouteDetailModel.fromJson(json);
      final entity = model.toEntity();

      expect(entity.dealers.first.status, DealerVisitStatus.completed);
      expect(entity.dealers.first.isVip, true);
      expect(entity.dealers[1].status, DealerVisitStatus.inProgress);
    });

    test('NotificationDataModel converts unread and categories properly', () {
      final json = {
        'today': [
          {
            'id': 'NOTIF-01',
            'type': 'attendance',
            'title': 'Chấm công thành công',
            'message': 'Đã ghi nhận giờ vào lúc 07:45.',
            'timeAgo': '5 phút trước',
            'isRead': false,
            'category': 'work',
          }
        ],
        'earlier': [
          {
            'id': 'NOTIF-05',
            'type': 'system',
            'title': 'Bảo trì hệ thống',
            'message': 'Hệ thống sẽ bảo trì lúc 23:00.',
            'timeAgo': 'Hôm qua, 16:45',
            'isRead': true,
            'category': 'system',
          }
        ],
      };

      final model = NotificationDataModel.fromJson(json);
      final entity = model.toEntity();

      expect(entity.today.length, 1);
      expect(entity.today.first.isRead, false);
      expect(entity.earlier.first.category, 'system');
    });

    test('UserProfileModel serialization works smoothly', () {
      final json = {
        'id': 'USR-001',
        'name': 'Nguyễn Văn An',
        'employeeId': 'NV00128',
        'role': 'Nhân viên thị trường',
        'region': 'Khu vực Vĩnh Phúc',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'email': 'an.nv@vthm.vn',
        'phone': '0912 345 678',
        'isDarkMode': true,
        'language': 'Tiếng Việt',
      };

      final model = UserProfileModel.fromJson(json);
      final entity = model.toEntity();

      expect(entity.isDarkMode, true);
      expect(entity.employeeId, 'NV00128');
    });
  });

  group('ConnectivityNotifier & Disconnection Tests', () {
    test('ConnectivityNotifier toggles online and offline correctly', () {
      final notifier = ConnectivityNotifier();

      notifier.simulateOffline();
      expect(notifier.state.isOnline, false);

      notifier.simulateOnline();
      expect(notifier.state.isOnline, true);

      notifier.dispose();
    });
  });

  group('Mock Backend Interceptor Tests', () {
    test('MockBackend handles /auth/login and /home/dashboard correctly', () async {
      final dio = Dio();
      dio.interceptors.add(MockBackendInterceptor());
      final apiClient = ApiClient(dio);

      final loginResp = await apiClient.post('/auth/login', data: {
        'username': 'sale01',
        'password': 'password123',
      }) as Map<String, dynamic>;

      expect(loginResp['token'], isNotNull);
      expect(loginResp['user']['name'], 'Nguyễn Văn An');

      final dashResp = await apiClient.get('/home/dashboard') as Map<String, dynamic>;
      expect(dashResp['greeting']['userName'], 'Nguyễn Văn An');
      expect(dashResp['attendance']['isCheckedIn'], true);
    });
  });
}
