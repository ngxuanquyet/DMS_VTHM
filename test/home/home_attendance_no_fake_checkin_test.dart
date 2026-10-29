import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/utils/account_key.dart';
import 'package:vthm_dms/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:vthm_dms/features/attendance/data/services/attendance_api_service.dart';
import 'package:vthm_dms/features/attendance/domain/entities/attendance_entity.dart';
import 'package:vthm_dms/features/home/data/models/dashboard_model.dart';
import 'package:vthm_dms/features/home/data/repositories/home_repository_impl.dart';
import 'package:vthm_dms/features/home/data/services/home_api_service.dart';

class _FakeHomeApiService implements HomeApiService {
  @override
  Future<DashboardModel> getDashboardData() async => throw Exception('offline');
}

/// Máy chủ không với tới — mọi lời gọi ném lỗi mạng.
class _OfflineApiClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<dynamic>.error(Exception('offline'));
}

/// Máy chủ có mạng, lịch sử trả [history]; còn lại ném lỗi mạng.
class _HistoryApiClient implements ApiClient {
  final List<Map<String, dynamic>> history;
  _HistoryApiClient(this.history);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #get) return Future<dynamic>.value({'data': history});
    return Future<dynamic>.error(Exception('offline'));
  }
}

/// Trang chủ tự hiện "đã chấm công" khi người dùng CHƯA chấm: giờ vào lấy từ lượt viếng thăm đang mở, phiên kiểu cũ,
/// lịch sử của tài khoản khác trên cùng máy, hoặc khối `today` của hôm trước trong bộ đệm cấu hình.
void main() {
  final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
  const me = '{"id":7}';

  Future<bool> checkedIn(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final dashboard = await HomeRepositoryImpl(_FakeHomeApiService()).getDashboardData();
    return dashboard.attendance.isCheckedIn ||
        dashboard.recentActivities.any((a) => a.title.contains('Chấm công'));
  }

  test('Lượt viếng thăm đang mở KHÔNG được coi là đã chấm công', () async {
    final visit = {'id': 5, 'customer_id': 9, 'customer_name': 'KH', 'checkin_at': '${todayStr}T08:05:00+07:00'};
    expect(await checkedIn({'vthm_user_data': me, 'dms_active_visit_session_v1': jsonEncode(visit)}), isFalse);
  });

  test('Phiên "đang làm việc" của bản cũ KHÔNG được coi là đã chấm công', () async {
    final session = {'is_working': true, 'check_in_time': '07:58', 'check_in_iso': '2026-09-01T07:58:00'};
    expect(await checkedIn({'vthm_user_data': me, 'dms_local_attendance_session_v1': jsonEncode(session)}), isFalse);
  });

  test('Lịch sử chấm công của tài khoản khác / khoá dùng chung cũ KHÔNG hiện cho tài khoản đang đăng nhập', () async {
    final punches = jsonEncode([
      {'id': 1, 'punch_at': '${todayStr}T08:00:00+07:00', 'client_uuid': 'u1', 'direction': 'in'},
    ]);
    expect(
      await checkedIn({
        'vthm_user_data': me,
        'dms_attendance_history_cache_v2': punches,
        'dms_attendance_history_cache_v2_8': punches,
      }),
      isFalse,
    );
    // Của chính mình thì vẫn hiện.
    expect(await checkedIn({'vthm_user_data': me, 'dms_attendance_history_cache_v2_7': punches}), isTrue);
  });

  test('Chưa đăng nhập ⇒ không có khoá lịch sử (không rơi vào ngăn dùng chung)', () async {
    SharedPreferences.setMockInitialValues({});
    expect(attendanceHistoryCacheKey(await SharedPreferences.getInstance()), isNull);
  });

  test('Khởi động dọn khoá chấm công dùng chung kiểu cũ, giữ khoá theo tài khoản', () async {
    SharedPreferences.setMockInitialValues({
      'dms_attendance_history_cache_v2': '[]',
      'dms_local_attendance_session_v1': '{}',
      'dms_attendance_history_cache_v2_7': '[]',
    });
    final prefs = await SharedPreferences.getInstance();
    await removeLegacySharedCaches(prefs);
    expect(prefs.getKeys(), {'dms_attendance_history_cache_v2_7'});
  });

  group('AttendanceConfigEntity.currentToday', () {
    AttendanceConfigEntity config(String workDate) => AttendanceConfigEntity(
          canPunch: true,
          group: const AttendanceGroupEntity(code: 'M', name: 'M', enforceGeofence: false),
          photo: const AttendancePhotoConfigEntity(),
          locations: const [],
          today: AttendanceTodayEntity(workDate: workDate, punchCount: 1, firstInAt: '$workDate 07:55:00+07'),
        );

    test('Khối today của hôm trước (bộ đệm khi mất mạng / app mở qua 00:00) bị bỏ', () {
      final yesterday = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));
      expect(config(yesterday).currentToday, isNull);
    });

    test('Khối today đúng hôm nay thì dùng', () {
      expect(config(todayStr).currentToday?.firstInTimeFormatted, '07:55');
    });
  });

  test('Lượt bấm lúc mất mạng còn chờ gửi vẫn hiện dù bộ đệm lịch sử đã bị xoá (đăng xuất / nâng cấp)', () async {
    SharedPreferences.setMockInitialValues({'vthm_user_data': me});
    final db = AppDatabase(NativeDatabase.memory(), 7);
    addTearDown(db.close);
    final repo = AttendanceRepositoryImpl(AttendanceApiService(_OfflineApiClient()), database: db);

    // Bấm chấm công khi máy chủ không với tới ⇒ vào hàng đợi + bộ đệm.
    final punch = await repo.punch(lat: 21.0, lng: 105.8);
    expect(punch.id, lessThan(0));
    final photoFile = File('${Directory.systemTemp.path}/att_back_test.jpg')..writeAsBytesSync([1, 2, 3]);
    await repo.uploadPunchPhoto(punchId: punch.id, file: photoFile, photoType: 'back', parentUuid: punch.clientUuid);

    // Bộ đệm mất (đăng xuất xoá) nhưng hàng đợi còn ⇒ lịch sử vẫn có lượt đó (kèm ảnh chờ gửi), không bị báo "chưa chấm".
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(attendanceHistoryCacheKey(prefs)!);
    final history = await repo.getHistory();
    expect(history.map((p) => p.clientUuid), [punch.clientUuid]);
    expect(history.first.photos.map((p) => p.photoType), ['back']);
    expect(history.first.requirements.needBack, isFalse);
  });

  test('Lịch sử server ghi đè bộ đệm vẫn giữ lượt chờ gửi kèm ảnh đã gắn, đứng đầu danh sách', () async {
    SharedPreferences.setMockInitialValues({'vthm_user_data': me});
    final db = AppDatabase(NativeDatabase.memory(), 7);
    addTearDown(db.close);
    final offline = AttendanceRepositoryImpl(AttendanceApiService(_OfflineApiClient()), database: db);
    final punch = await offline.punch(lat: 21.0, lng: 105.8);
    final photoFile = File('${Directory.systemTemp.path}/att_front_test.jpg')..writeAsBytesSync([1, 2, 3]);
    await offline.uploadPunchPhoto(punchId: punch.id, file: photoFile, photoType: 'front', parentUuid: punch.clientUuid);

    final server = [
      {'id': 900, 'punch_at': '2026-01-01 08:00:00+07', 'client_uuid': 'server-old', 'lat': 21.0, 'lng': 105.8},
    ];
    final online = AttendanceRepositoryImpl(AttendanceApiService(_HistoryApiClient(server)), database: db);
    final history = await online.getHistory();

    expect(history.map((p) => p.clientUuid), [punch.clientUuid, 'server-old']);
    expect(history.first.photos.map((p) => p.photoType), ['front']);
    // Bộ đệm (Trang chủ đọc) cũng có lượt chờ gửi.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(attendanceHistoryCacheKey(prefs)!), contains(punch.clientUuid));
  });

  test('Đã đăng xuất khi lượt chấm mới trả về ⇒ không dựng lại bộ đệm của người cũ', () async {
    SharedPreferences.setMockInitialValues({'vthm_user_data': me});
    final prefs = await SharedPreferences.getInstance();
    final client = _LogoutDuringPunchClient(prefs);
    final repo = AttendanceRepositoryImpl(AttendanceApiService(client));

    await repo.punch(lat: 21.0, lng: 105.8);
    expect(prefs.getKeys().where((k) => k.startsWith(attendanceHistoryCachePrefix)), isEmpty);
  });
}

/// Đăng xuất (xoá hồ sơ trong máy) trong lúc yêu cầu chấm công đang bay, rồi máy chủ vẫn nhận lượt.
class _LogoutDuringPunchClient implements ApiClient {
  final SharedPreferences prefs;
  _LogoutDuringPunchClient(this.prefs);

  @override
  dynamic noSuchMethod(Invocation invocation) async {
    await prefs.remove('vthm_user_data');
    return {
      'data': {'id': 1, 'punch_at': '2026-01-01 08:00:00+07', 'client_uuid': 'x', 'lat': 21.0, 'lng': 105.8},
    };
  }
}
