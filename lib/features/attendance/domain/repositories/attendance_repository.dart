import '../entities/attendance_entity.dart';

abstract class AttendanceRepository {
  Future<AttendanceDetailEntity> getAttendanceDetail();
  Future<AttendanceDetailEntity> toggleAttendanceCheck();
}
