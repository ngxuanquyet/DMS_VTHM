import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/attendance/presentation/states/attendance_state.dart';

/// Đồng hồ thời gian làm việc: tính từ số giây lúc tải + thời gian trôi qua (29/10/2026 — bỏ timer cập nhật state chấm
/// công mỗi giây, vốn làm Home + mọi màn theo dõi state dựng lại mỗi giây).
void main() {
  final asOf = DateTime(2026, 10, 29, 8, 0, 0);

  test('đang làm việc: cộng thêm thời gian từ lúc tải', () {
    expect(AttendanceState.workDurationAt(100, asOf, asOf.add(const Duration(seconds: 5))), '00:01:45');
    expect(AttendanceState.workDurationAt(3600, asOf, asOf.add(const Duration(minutes: 30))), '01:30:00');
  });

  test('chưa vào ca (0 giây) thì đứng ở 00:00:00; đồng hồ máy lùi không làm giảm', () {
    expect(AttendanceState.workDurationAt(0, asOf, asOf.add(const Duration(hours: 2))), '00:00:00');
    expect(AttendanceState.workDurationAt(100, asOf, asOf.subtract(const Duration(seconds: 30))), '00:01:40');
  });

  test('state mặc định không có đồng hồ chạy — không còn trường liveCurrentTime', () {
    const s = AttendanceState();
    expect(s.liveWorkDurationSeconds, 0);
    expect(s.workDurationAsOf, isNull);
  });
}
