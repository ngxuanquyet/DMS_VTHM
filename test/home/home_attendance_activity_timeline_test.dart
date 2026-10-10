import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/features/daily_report/domain/entities/daily_activity_entity.dart';
import 'package:vthm_dms/features/daily_report/presentation/widgets/daily_activity_timeline_card.dart';
import 'package:vthm_dms/features/home/data/models/dashboard_model.dart';
import 'package:vthm_dms/features/home/data/repositories/home_repository_impl.dart';
import 'package:vthm_dms/features/home/data/services/home_api_service.dart';

class _FakeHomeApiService implements HomeApiService {
  @override
  Future<DashboardModel> getDashboardData() async {
    throw Exception('Offline / No backend dashboard endpoint');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kiểm tra Lưu Chấm Công vào Hoạt Động Trong Ngày (Trang Chủ)', () {
    test('1. HomeRepositoryImpl lấy các lượt chấm công hôm nay vào recentActivities', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Lưu 2 lượt chấm công hôm nay (Vào sáng & Ra chiều)
      final samplePunches = [
        {
          'id': 101,
          'punch_at': '${todayStr}T08:15:00+07:00',
          'client_uuid': 'uuid_punch_in_101',
          'lat': 21.028511,
          'lng': 105.854444,
          'geofence_name': 'Văn phòng Tổng công ty',
          'direction': 'in',
          'direction_label': 'Vào',
          'is_outside_geofence': false,
          'photos': [
            {'url': 'https://example.com/photo_in.jpg'},
          ],
        },
        {
          'id': 102,
          'punch_at': '${todayStr}T17:30:00+07:00',
          'client_uuid': 'uuid_punch_out_102',
          'lat': 21.028520,
          'lng': 105.854450,
          'geofence_name': 'Văn phòng Tổng công ty',
          'direction': 'out',
          'direction_label': 'Ra',
          'is_outside_geofence': false,
          'photos': [],
        },
      ];

      await prefs.setString('dms_attendance_history_cache_v2', jsonEncode(samplePunches));

      final homeRepo = HomeRepositoryImpl(_FakeHomeApiService());
      final dashboard = await homeRepo.getDashboardData();

      // Kiểm tra recentActivities có chứa 2 lượt chấm công
      final attActivities = dashboard.recentActivities
          .where((a) => a.title.contains('Chấm công'))
          .toList();

      expect(attActivities.length, 2);

      // Thứ tự sắp xếp mới nhất lên đầu: 17:30 (Ra) đứng trước 08:15 (Vào)
      expect(attActivities[0].time, '17:30');
      expect(attActivities[0].title, 'Chấm công Ra');
      expect(attActivities[0].highlight, 'Văn phòng Tổng công ty');

      expect(attActivities[1].time, '08:15');
      expect(attActivities[1].title, 'Chấm công Vào');
      expect(attActivities[1].highlight, 'Văn phòng Tổng công ty');
      expect(attActivities[1].photos, ['https://example.com/photo_in.jpg']);
      expect(attActivities[1].lat, 21.028511);
      expect(attActivities[1].lng, 105.854444);
    });

    testWidgets('2. DailyActivityTimelineCard hiển thị đúng lượt Chấm công và mở chi tiết khi chạm', (tester) async {
      final sampleActivities = [
        const DailyActivityEntity(
          id: 'att_102',
          time: '17:30',
          title: 'Chấm công Ra',
          subtitle: 'Văn phòng Tổng công ty (Trong vùng)',
          type: DailyActivityType.attendanceOut,
          customerName: 'Văn phòng Tổng công ty',
          lat: 21.028520,
          lng: 105.854450,
        ),
        const DailyActivityEntity(
          id: 'att_101',
          time: '08:15',
          title: 'Chấm công Vào',
          subtitle: 'Văn phòng Tổng công ty (Trong vùng)',
          type: DailyActivityType.attendanceIn,
          customerName: 'Văn phòng Tổng công ty',
          lat: 21.028511,
          lng: 105.854444,
          photos: ['https://example.com/photo_in.jpg'],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyActivityTimelineCard(
                title: 'Dòng thời gian hôm nay',
                activities: sampleActivities,
              ),
            ),
          ),
        ),
      );

      // Kiểm tra tiêu đề và các mục timeline
      expect(find.text('Dòng thời gian hôm nay'), findsOneWidget);
      expect(find.text('Chấm công Ra'), findsOneWidget);
      expect(find.text('17:30'), findsOneWidget);
      expect(find.text('Chấm công Vào'), findsOneWidget);
      expect(find.text('08:15'), findsOneWidget);
      expect(find.text('1 ảnh'), findsOneWidget);

      // Chạm vào mục Chấm công Vào để mở ActivityDetailSheet
      await tester.tap(find.text('Chấm công Vào'));
      await tester.pumpAndSettle();

      // Kiểm tra trong Sheet chi tiết hiển thị nhãn "Địa điểm chấm" thay vì "Điểm bán"
      expect(find.text('Địa điểm chấm'), findsOneWidget);
      expect(find.text('Văn phòng Tổng công ty'), findsOneWidget);
      expect(find.text('Thời gian: 08:15'), findsOneWidget);
      expect(find.text('Toạ độ GPS'), findsOneWidget);
    });

    test('3. Hiển thị đúng lượt Chấm công Vào và Ra trên dòng thời gian', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Server trả về 2 lượt: Vào (08:00) và Ra (17:30)
      final samplePunches = [
        {
          'id': 201,
          'punch_at': '${todayStr}T08:00:00+07:00',
          'client_uuid': 'uuid_201',
          'direction': 'in',
          'direction_label': 'Vào',
        },
        {
          'id': 202,
          'punch_at': '${todayStr}T17:30:00+07:00',
          'client_uuid': 'uuid_202',
          'direction': 'out',
          'direction_label': 'Ra',
        },
      ];

      await prefs.setString('dms_attendance_history_cache_v2', jsonEncode(samplePunches));

      final homeRepo = HomeRepositoryImpl(_FakeHomeApiService());
      final dashboard = await homeRepo.getDashboardData();

      final attActivities = dashboard.recentActivities
          .where((a) => a.title.contains('Chấm công'))
          .toList();

      expect(attActivities.length, 2);

      // Lượt 17:30 là "Chấm công Ra"
      final outPunchActivity = attActivities.firstWhere((a) => a.time == '17:30');
      expect(outPunchActivity.title, 'Chấm công Ra');

      // Lượt 08:00 là "Chấm công Vào"
      final inPunchActivity = attActivities.firstWhere((a) => a.time == '08:00');
      expect(inPunchActivity.title, 'Chấm công Vào');
    });
  });
}
