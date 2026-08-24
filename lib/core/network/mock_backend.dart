import 'dart:convert';
import 'package:dio/dio.dart';

class MockBackendInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Artificial slight network latency for realistic feel
    await Future.delayed(const Duration(milliseconds: 300));

    final path = options.path;
    final method = options.method.toUpperCase();

    // 1. Auth endpoints
    if (path.contains('/auth/login') && method == 'POST') {
      final data = options.data is Map ? options.data : jsonDecode(options.data.toString());
      final username = data['username'] ?? '';
      final password = data['password'] ?? '';

      if (username.toString().trim().isNotEmpty && password.toString().trim().isNotEmpty) {
        return handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'message': 'Đăng nhập thành công',
              'token': 'mock_jwt_token_vthm_2026_field_ops_00128',
              'user': {
                'id': 'user_00128',
                'name': 'Nguyễn Văn An',
                'employeeId': 'NV00128',
                'role': 'Nhân viên thị trường',
                'region': 'Khu vực Vĩnh Phúc',
                'avatarUrl':
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuCrBzPvd-uLd3UPU7rt-8SsuTNgR6oFdKenP9ScNUa05heHQvw4rgjyyAxBzi-WPtezQigtJju-LMCU60dfdKXYyAHeoPk4zQuey_F_JS10oN1z9f-p4gXoY8odvKdB15_eqNWuybMX-o5x0Vo0RfeWGjwMlkHxVG2imvTio2i7YvxDQu2bAVh19gAPpK1T0ReM4hzHlfDYJ8sz_SWnzRVFhUqrTMHoPGQNLciQMs6ZzuDfbDlbk5KgNQ',
                'email': 'an.nguyen@vthm.vn',
                'phone': '0987 654 321',
              }
            },
          ),
        );
      } else {
        return handler.reject(
          DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 400,
              data: {'success': false, 'message': 'Vui lòng nhập tài khoản và mật khẩu'},
            ),
          ),
        );
      }
    }

    // 2. Home Dashboard endpoint
    if (path.contains('/dashboard') && method == 'GET') {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'greeting': {
              'userName': 'Nguyễn Văn An',
              'role': 'Nhân viên thị trường',
              'currentDate': 'Thứ 4, 24 Tháng 5, 2023',
            },
            'attendance': {
              'isCheckedIn': true,
              'checkInTime': '07:42',
              'workDuration': '03:18',
              'statusLabel': 'Đã chấm công',
            },
            'routeSummary': {
              'routeName': 'Tuyến Vĩnh Yên – Bình Xuyên',
              'completedCount': 8,
              'totalCount': 12,
              'progressPercent': 0.67,
              'nextStop': 'Cửa hàng Tạp hóa Lan',
            },
            'formSummary': {
              'pendingCount': 3,
              'completedCount': 5,
              'overdueCount': 1,
            },
            'recentActivities': [
              {
                'id': 'act_1',
                'time': '10:15 AM',
                'title': 'Hoàn thành biểu mẫu',
                'highlight': 'Kiểm tra trưng bày',
                'suffix': 'tại Cửa hàng A',
                'isPrimary': true,
              },
              {
                'id': 'act_2',
                'time': '09:30 AM',
                'title': 'Check-in tại',
                'highlight': 'Cửa hàng A',
                'suffix': '',
                'isPrimary': false,
              },
              {
                'id': 'act_3',
                'time': '07:42 AM',
                'title': 'Chấm công thành công',
                'highlight': '',
                'suffix': '',
                'isPrimary': false,
              }
            ]
          },
        ),
      );
    }

    // 3. Attendance detail endpoint
    if (path.contains('/attendance') && method == 'GET') {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'isWorking': true,
            'currentTime': '14:26:00',
            'currentDateFormatted': 'Thứ Sáu, 15/08/2026',
            'checkInTime': '07:42',
            'workDurationSeconds': 24264, // 06:44:24
            'location': {
              'address': 'Vĩnh Yên, Vĩnh Phúc',
              'gpsAccuracy': '±8m',
              'latitude': 21.3089,
              'longitude': 105.6049,
            },
            'monthlyStats': {
              'monthLabel': 'Tháng 08/2026',
              'workingDays': 18,
              'lateDays': 2,
            },
            'history': [
              {
                'id': 'att_1',
                'date': '14/08/2026',
                'timeRange': '07:55 - 17:05',
                'status': 'Đúng giờ',
                'isLate': false,
              },
              {
                'id': 'att_2',
                'date': '13/08/2026',
                'timeRange': '08:15 - 17:00',
                'status': 'Đi muộn',
                'isLate': true,
              },
              {
                'id': 'att_3',
                'date': '12/08/2026',
                'timeRange': '07:45 - 17:02',
                'status': 'Đúng giờ',
                'isLate': false,
              }
            ]
          },
        ),
      );
    }

    // 4. Routes endpoint
    if (path.contains('/routes') && method == 'GET') {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'id': 'route_vinh_yen_01',
            'title': 'Tuyến Vĩnh Yên – Bình Xuyên',
            'totalDealers': 12,
            'completedDealers': 8,
            'pendingDealers': 4,
            'progressPercent': 0.67,
            'dealers': [
              {
                'id': 'dl_01',
                'order': '01',
                'name': 'Đại lý Cường Thịnh',
                'address': 'Số 12 Quang Trung, Vĩnh Yên',
                'status': 'completed', // completed | in_progress | pending
                'statusLabel': 'Đã ghé',
                'visitedTime': '08:30 AM',
                'isVip': false,
              },
              {
                'id': 'dl_02',
                'order': '02',
                'name': 'CH VLXD Hoàng Gia',
                'address': 'Ngã 4 Định Trung, Vĩnh Yên',
                'status': 'completed',
                'statusLabel': 'Đã ghé',
                'visitedTime': '10:15 AM',
                'isVip': true,
              },
              {
                'id': 'dl_03',
                'order': '03',
                'name': 'NPP Tôn thép Minh Phát',
                'address': 'KCN Bá Thiện 2, Bình Xuyên',
                'status': 'in_progress',
                'statusLabel': 'Chưa ghé',
                'visitedTime': null,
                'isVip': true,
              },
              {
                'id': 'dl_04',
                'order': '04',
                'name': 'Công ty ABCD',
                'address': 'KCN Thăng Long Vĩnh Phúc',
                'status': 'pending',
                'statusLabel': 'Chưa ghé',
                'visitedTime': null,
                'isVip': false,
              }
            ]
          },
        ),
      );
    }

    // 5. Dealer Check-in detail
    if (path.contains('/dealers/checkin') && method == 'GET') {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'dealer': {
              'id': 'DL-VP-00128',
              'name': 'Đại lý VLXD Thành Công',
              'address': 'Tổ hợp Thương mại Bá Thiện, Bình Xuyên',
              'isVip': true,
              'distanceMeters': 48,
              'visitDuration': '00:24:18',
            },
            'tasks': [
              {
                'id': 'task_form',
                'title': 'Thu thập biểu mẫu',
                'subtitle': 'Đánh giá trưng bày, Tồn kho',
                'completed': 2,
                'total': 3,
                'type': 'form',
              },
              {
                'id': 'task_photo',
                'title': 'Chụp ảnh điểm bán',
                'subtitle': 'Chưa có ảnh',
                'completed': 0,
                'total': 1,
                'type': 'photo',
                'isError': true,
              },
              {
                'id': 'task_note',
                'title': 'Ghi chú chuyến ghé',
                'subtitle': 'Thêm ý kiến phản hồi',
                'completed': 0,
                'total': 1,
                'type': 'note',
              }
            ]
          },
        ),
      );
    }

    // 6. Forms list endpoint
    if (path.contains('/forms') && method == 'GET') {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: [
            {
              'id': 'form_01',
              'title': 'Khảo sát điểm bán',
              'dealerName': 'Đại lý Thành Công',
              'deadline': '17:00',
              'status': 'todo', // todo | in_progress | completed
              'statusLabel': 'Chưa thực hiện',
              'questionsCount': 8,
              'answeredCount': 0,
              'progressPercent': 0.0,
            },
            {
              'id': 'form_02',
              'title': 'Kiểm tra trưng bày',
              'dealerName': 'Cửa hàng Quận 1',
              'deadline': 'Trong ngày',
              'status': 'in_progress',
              'statusLabel': 'Đang thực hiện',
              'questionsCount': 8,
              'answeredCount': 5,
              'progressPercent': 0.625,
            },
            {
              'id': 'form_03',
              'title': 'Báo cáo tồn kho thép',
              'dealerName': 'NPP Tôn thép Minh Phát',
              'deadline': 'Hôm qua',
              'status': 'completed',
              'statusLabel': 'Hoàn thành',
              'questionsCount': 10,
              'answeredCount': 10,
              'progressPercent': 1.0,
            }
          ],
        ),
      );
    }

    // 7. Profile endpoint
    if (path.contains('/profile') && method == 'GET') {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'id': 'user_00128',
            'name': 'Nguyễn Văn An',
            'employeeId': 'NV00128',
            'role': 'Nhân viên thị trường',
            'region': 'Khu vực Vĩnh Phúc',
            'avatarUrl':
                'https://lh3.googleusercontent.com/aida-public/AB6AXuC-QWtmcitzfeX9IQj-lFar7AZXCE4cwtrz0pjVWJy7BZj9tnvvPX2FE6kyE405-70z1WQjIngcuo5m3ZCdrKJlMzywZTGfSZOWDYH5cNqqePQZfZnr1MomcLvmBHHbCqUD49rJWMyJ9CxIJWxHCXpgDjy4l_0bbLnx5khAcNLRzx51zkrIKn7SLt1TsEwdO61NYzmBr-8hMTRYnT71dOEo1qHqPnq6VAFhgewyJuF8unnduiDH2ROo5w',
            'email': 'an.nguyen@vthm.vn',
            'phone': '0987 654 321',
            'isDarkMode': false,
            'language': 'Tiếng Việt',
          },
        ),
      );
    }

    // 8. Notifications endpoint
    if (path.contains('/notifications') && method == 'GET') {
      return handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'today': [
              {
                'id': 'notif_01',
                'type': 'attendance', // attendance | route | form | checkin | system
                'title': 'Chấm công thành công',
                'message': 'Bạn đã chấm công vào lúc 07:42 hôm nay.',
                'timeAgo': '5 phút trước',
                'isRead': false,
                'category': 'work',
              },
              {
                'id': 'notif_02',
                'type': 'route',
                'title': 'Tuyến làm việc sắp bắt đầu',
                'message': 'Tuyến Vĩnh Yên – Bình Xuyên còn 4 điểm cần hoàn thành.',
                'timeAgo': '20 phút trước',
                'isRead': false,
                'category': 'work',
              },
              {
                'id': 'notif_03',
                'type': 'form',
                'title': 'Biểu mẫu cần hoàn thành',
                'message': 'Bạn có 3 biểu mẫu đang chờ xử lý.',
                'timeAgo': '1 giờ trước',
                'isRead': false,
                'category': 'work',
              },
              {
                'id': 'notif_04',
                'type': 'checkin',
                'title': 'Hoàn thành điểm Check-in',
                'message': 'Bạn đã hoàn thành check-in tại Cửa hàng Tạp hóa Lan.',
                'timeAgo': '2 giờ trước',
                'isRead': true,
                'category': 'work',
              }
            ],
            'earlier': [
              {
                'id': 'notif_05',
                'type': 'route',
                'title': 'Tuyến đã hoàn thành',
                'message': 'Bạn đã hoàn thành tuyến Vĩnh Yên – Bình Xuyên với 12/12 điểm.',
                'timeAgo': 'Hôm qua, 16:45',
                'isRead': true,
                'category': 'work',
              },
              {
                'id': 'notif_06',
                'type': 'system',
                'title': 'Thông báo hệ thống',
                'message': 'Ứng dụng VTHM Group đã được cập nhật lên phiên bản mới.',
                'timeAgo': '18/08/2026',
                'isRead': true,
                'category': 'system',
              }
            ]
          },
        ),
      );
    }

    return handler.next(options);
  }
}
