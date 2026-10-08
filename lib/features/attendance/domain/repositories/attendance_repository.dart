import 'dart:io';
import '../entities/attendance_entity.dart';

abstract class AttendanceRepository {
  /// Lấy cấu hình chấm công và danh sách địa điểm (§2)
  Future<AttendanceConfigEntity> getConfig({double? lat, double? lng});

  /// Gửi một lượt chấm công (§3)
  Future<AttendancePunchEntity> punch({
    required double lat,
    required double lng,
    double? accuracyM,
    bool? isMockLocation,
    String? clientUuid,
  });

  /// Tải ảnh camera cho lượt chấm (§4)
  Future<AttendancePunchPhotoEntity> uploadPunchPhoto({
    required int punchId,
    required File file,
    required String photoType,
    DateTime? takenAt,
    double? lat,
    double? lng,
    String? parentUuid,
  });

  /// Lấy lịch sử chấm công của chính mình (§5)
  Future<List<AttendancePunchEntity>> getHistory({int days = 7});

  /// Hỗ trợ tương thích ngược
  Future<AttendanceDetailEntity> getAttendanceDetail();
  Future<AttendanceDetailEntity> toggleAttendanceCheck();
}
