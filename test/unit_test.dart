import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/localization/app_language.dart';
import 'package:vthm_dms/core/localization/app_strings.dart';
import 'package:vthm_dms/core/localization/language_provider.dart';
import 'package:vthm_dms/core/location/location_provider.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/features/attendance/data/models/attendance_model.dart';
import 'package:vthm_dms/features/auth/data/models/user_model.dart';
import 'package:vthm_dms/features/home/data/models/dashboard_model.dart';
import 'package:vthm_dms/features/notifications/data/models/notification_model.dart';
import 'package:vthm_dms/features/profile/data/models/user_profile_detail_model.dart';
import 'package:vthm_dms/features/profile/data/models/user_profile_model.dart';
import 'package:vthm_dms/features/profile/data/models/user_relation_model.dart';
import 'package:vthm_dms/features/route/data/models/route_model.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Clean Architecture & Model Serialization Tests', () {
    test('UserModel serializes and deserializes real API response correctly', () {
      final userJson = {
        'id': 2461,
        'username': 'VTG926',
        'email': 'quyetnx@vthmgroup.vn',
        'user_type': 1,
        'is_internal': true,
        'employee_code': 'VTG926',
        'is_super_admin': true,
        'display_name': 'Nguyễn Xuân Quyết',
        'job_title': 'Nhân viên Quản lý Hệ thống thông tin (MIS)',
        'initial': 'N',
        'avatar_url': 'https://api-app.vthmgroup.vn/media/avatar?f=user-2461-215832526f41939a.jpg',
        'must_change_password': false,
        'parallel_identities': [],
      };
      final permissions = ['*'];

      final model = UserModel.fromJson(userJson, permissions: permissions);
      final entity = model.toEntity();

      expect(entity.id, '2461');
      expect(entity.username, 'VTG926');
      expect(entity.displayName, 'Nguyễn Xuân Quyết');
      expect(entity.name, 'Nguyễn Xuân Quyết');
      expect(entity.jobTitle, 'Nhân viên Quản lý Hệ thống thông tin (MIS)');
      expect(entity.employeeCode, 'VTG926');
      expect(entity.avatarUrl, contains('api-app.vthmgroup.vn'));
      expect(entity.permissions, contains('*'));
    });

    test('UserProfileDetailModel parses /user/me/profile API response accurately', () {
      final json = {
        'id': 2461,
        'username': 'VTG926',
        'full_name': 'Nguyễn Xuân Quyết',
        'company': 'Công ty Cổ phần Tập đoàn VITTO',
        'dept_name': 'Phòng Công nghệ Thông tin và Chuyển đổi số',
        'job_name': 'Nhân viên Quản lý Hệ thống thông tin (MIS)',
        'phone': '0962649951',
        'email': 'quyetnx@vthmgroup.vn',
        'personal_email': 'quyetnx@vthmgroup.vn',
        'user_type': 1,
        'user_type_label': 'Nhân viên nội bộ',
        'status': 10,
        'status_label': 'Đang bật',
        'status_color': 'success',
        'is_super_admin': true,
        'employee_code': 'VTG926',
        'avatar_url': 'https://api-app.vthmgroup.vn/media/avatar?f=user-2461-215832526f41939a.jpg',
        'last_login_at': '2026-08-25 11:04:17+07',
        'resigned': false,
      };

      final model = UserProfileDetailModel.fromJson(json);
      final entity = model.toEntity();

      expect(entity.id, 2461);
      expect(entity.fullName, 'Nguyễn Xuân Quyết');
      expect(entity.company, 'Công ty Cổ phần Tập đoàn VITTO');
      expect(entity.deptName, 'Phòng Công nghệ Thông tin và Chuyển đổi số');
      expect(entity.phone, '0962649951');
      expect(entity.email, 'quyetnx@vthmgroup.vn');
      expect(entity.statusLabel, 'Đang bật');
    });

    test('UserRelationModel parses /hr/me/relations API response accurately', () {
      final json = {
        'employee_id': 1428161,
        'employee_code': 'VTG133',
        'employee_name': 'Trần Ngọc Hiên',
        'position_row_id': 'CVU042109',
        'branch_code': 'A11',
        'level': 1,
        'via_sub_pos_id': 'CVU041949',
        'is_primary': true,
        'phone': '0984781172',
        'email': 'hientn@vthmgroup.vn',
        'company_name': 'VTG',
        'company_branch_name': 'Công ty Cổ phần Tập đoàn VITTO',
        'job_name': 'Trưởng phòng Công nghệ Thông tin',
        'dept_name': 'Phòng Công nghệ Thông tin và Chuyển đổi số',
      };

      final model = UserRelationModel.fromJson(json);
      final entity = model.toEntity();

      expect(entity.employeeId, 1428161);
      expect(entity.employeeName, 'Trần Ngọc Hiên');
      expect(entity.employeeCode, 'VTG133');
      expect(entity.jobName, 'Trưởng phòng Công nghệ Thông tin');
      expect(entity.phone, '0984781172');
      expect(entity.email, 'hientn@vthmgroup.vn');
    });

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

  group('Localization & Language Switching Tests', () {
    test('AppLanguage enum and AppStrings translations work accurately', () {
      final viStrings = AppStrings(AppLanguage.vi);
      final enStrings = AppStrings(AppLanguage.en);

      expect(viStrings.navHome, 'Trang chủ');
      expect(enStrings.navHome, 'Home');

      expect(viStrings.personalInfo, 'Thông tin cá nhân');
      expect(enStrings.personalInfo, 'Personal Information');

      expect(viStrings.languageTitle, 'Ngôn ngữ');
      expect(enStrings.languageTitle, 'Language');

      expect(viStrings.selectLanguage, 'Chọn ngôn ngữ');
      expect(enStrings.selectLanguage, 'Select Language');

      expect(viStrings.unknown, 'Không xác định');
      expect(enStrings.unknown, 'Unknown');
    });

    test('LanguageNotifier switches language correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final notifier = LanguageNotifier();
      expect(notifier.state, AppLanguage.vi);

      await notifier.setLanguage(AppLanguage.en);
      expect(notifier.state, AppLanguage.en);

      await notifier.setLanguage(AppLanguage.vi);
      expect(notifier.state, AppLanguage.vi);
    });
  });

  group('Location & GPS Service Tests', () {
    test('LocationState initialization and copyWith work properly', () {
      const state = LocationState();
      expect(state.isServiceEnabled, true);
      expect(state.hasPermission, true);
      expect(state.isReady, true);

      final disabledState = state.copyWith(isServiceEnabled: false);
      expect(disabledState.isServiceEnabled, false);
      expect(disabledState.isReady, false);
    });

    test('Location dialog strings translation works accurately', () {
      final viStrings = AppStrings(AppLanguage.vi);
      final enStrings = AppStrings(AppLanguage.en);

      expect(viStrings.locationServiceDisabledTitle, 'Chưa bật vị trí');
      expect(enStrings.locationServiceDisabledTitle, 'Location Service Disabled');

      expect(viStrings.locationPermissionDeniedTitle, 'Yêu cầu quyền vị trí');
      expect(enStrings.locationPermissionDeniedTitle, 'Location Permission Required');

      expect(viStrings.enableGpsAction, 'BẬT VỊ TRÍ');
      expect(enStrings.enableGpsAction, 'ENABLE LOCATION');

      expect(viStrings.grantPermissionAction, 'CẤP QUYỀN');
      expect(enStrings.grantPermissionAction, 'GRANT PERMISSION');
    });
  });
}
