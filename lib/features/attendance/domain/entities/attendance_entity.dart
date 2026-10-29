import 'package:intl/intl.dart';

/// Cấu hình trạng thái hôm nay từ GET /attendance/mobile/config (§2 SPEC-2026-10-06)
class AttendanceTodayEntity {
  final String? workDate;
  final int punchCount;
  final String? firstInAt;
  final String? lastOutAt;
  final String nextAction; // 'in' | 'out'
  final String nextActionLabel; // 'Vào' | 'Ra'
  final AttendanceShiftScheduleEntity? shift;

  const AttendanceTodayEntity({
    this.workDate,
    this.punchCount = 0,
    this.firstInAt,
    this.lastOutAt,
    this.nextAction = 'in',
    this.nextActionLabel = 'Vào',
    this.shift,
  });

  /// Lấy giờ vào định dạng HH:mm
  String? get firstInTimeFormatted => _formatTime(firstInAt);

  /// Lấy giờ ra định dạng HH:mm
  String? get lastOutTimeFormatted => _formatTime(lastOutAt);

  static String? _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.contains(' ')) {
      final parts = raw.split(' ');
      if (parts.length > 1) {
        final sub = parts[1].split(':');
        if (sub.length >= 2) return '${sub[0]}:${sub[1]}';
      }
    }
    final dt = DateTime.tryParse(raw.replaceAll(' ', 'T'));
    if (dt != null) {
      return DateFormat('HH:mm').format(dt);
    }
    return raw;
  }
}

/// Thông tin ca làm việc cụ thể (§8.1)
class AttendanceShiftEntity {
  final int id;
  final String code;
  final String name;
  final String startTime;
  final String endTime;
  final bool crossMidnight;

  const AttendanceShiftEntity({
    required this.id,
    required this.code,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.crossMidnight = false,
  });

  String get timeRange => '$startTime – $endTime';
}

/// Lịch ca làm việc trong ngày (§8.1 - §8.3)
class AttendanceShiftScheduleEntity {
  final String workDate;
  final String status; // 'shift' | 'multiple' | 'day_off' | 'no_schedule'
  final String? source; // 'override' | 'schedule' | 'auto'
  final AttendanceShiftEntity? shift;
  final List<AttendanceShiftEntity> candidates;

  const AttendanceShiftScheduleEntity({
    required this.workDate,
    required this.status,
    this.source,
    this.shift,
    this.candidates = const [],
  });

  bool get isShift => status == 'shift' && shift != null;
  bool get isMultiple => status == 'multiple';
  bool get isDayOff => status == 'day_off';
  bool get isNoSchedule => status == 'no_schedule';

  String get displayText {
    switch (status) {
      case 'shift':
        return shift != null ? 'Ca ${shift!.name}' : 'Ca làm việc';
      case 'multiple':
        if (candidates.isNotEmpty) {
          final candNames = candidates.map((c) => '${c.code} (${c.startTime})').join(' / ');
          return 'Xoay ca: $candNames';
        }
        return 'Xoay ca';
      case 'day_off':
        return 'Nghỉ';
      case 'no_schedule':
      default:
        return 'Chưa được xếp lịch — liên hệ nhân sự';
    }
  }
}

/// Cấu hình chấm công từ GET /attendance/mobile/config
class AttendanceConfigEntity {
  final bool canPunch;
  final String? blockedReason;
  final AttendanceGroupEntity group;
  final AttendancePhotoConfigEntity photo;
  final List<AttendanceLocationItemEntity> locations;

  /// Khối `today` NGUYÊN VĂN server trả — có thể là của ngày khác (cấu hình đọc từ bộ nhớ đệm khi mất mạng, hoặc app mở
  /// qua 00:00). Màn hình đọc [currentToday], KHÔNG đọc thẳng trường này.
  final AttendanceTodayEntity? today;

  const AttendanceConfigEntity({
    required this.canPunch,
    this.blockedReason,
    required this.group,
    required this.photo,
    required this.locations,
    this.today,
  });

  /// Trạng thái chấm công hôm nay — `null` khi khối `today` thuộc ngày khác (`work_date` ≠ hôm nay), để giờ vào / số lượt
  /// của hôm trước không hiện thành của hôm nay. "Hôm nay" theo giờ MÁY như mọi chỗ khác trong app (lịch sử, lịch ca) —
  /// hai định nghĩa "hôm nay" khác nhau trên cùng màn là lệch nhau quanh nửa đêm.
  AttendanceTodayEntity? get currentToday {
    final t = today;
    if (t == null || t.workDate != DateFormat('yyyy-MM-dd').format(DateTime.now())) return null;
    return t;
  }

  /// Kiểm tra xem hiện tại người dùng có nằm trong bất kỳ geofence nào không
  /// Quy tắc 06/10/2026: Nếu có bất kỳ địa điểm kind == 'everywhere' thì luôn hợp lệ
  bool isWithinAnyGeofence() {
    if (locations.isEmpty) return false;
    if (locations.any((loc) => loc.isEverywhere)) return true;
    return locations.any((loc) =>
        loc.distanceM != null && loc.radiusM != null && loc.distanceM! <= loc.radiusM!);
  }

  /// Địa điểm gần nhất
  AttendanceLocationItemEntity? get closestLocation {
    if (locations.isEmpty) return null;
    final everywhere = locations.where((l) => l.isEverywhere).toList();
    final withDistance =
        locations.where((l) => !l.isEverywhere && l.distanceM != null).toList();
    if (withDistance.isNotEmpty) {
      final inside = withDistance.where((l) => l.isWithinRadius).toList();
      if (inside.isNotEmpty) {
        inside.sort((a, b) => a.distanceM!.compareTo(b.distanceM!));
        return inside.first;
      }
      if (everywhere.isNotEmpty) {
        return everywhere.first;
      }
      withDistance.sort((a, b) => a.distanceM!.compareTo(b.distanceM!));
      return withDistance.first;
    }
    if (everywhere.isNotEmpty) {
      return everywhere.first;
    }
    return locations.first;
  }
}

class AttendanceGroupEntity {
  final String code;
  final String name;
  final bool enforceGeofence;

  const AttendanceGroupEntity({
    required this.code,
    required this.name,
    required this.enforceGeofence,
  });
}

class AttendancePhotoConfigEntity {
  final int minPhotos;
  final int maxPhotos;
  final bool requireBoth;

  const AttendancePhotoConfigEntity({
    this.minPhotos = 2,
    this.maxPhotos = 10,
    this.requireBoth = true,
  });
}

class AttendanceLocationItemEntity {
  final int id;
  final String code;
  final String name;
  final String kind; // 'radius' | 'everywhere'
  final String kindLabel; // 'Bán kính' | 'Mọi nơi'
  final double? lat; // null khi kind == 'everywhere'
  final double? lng; // null khi kind == 'everywhere'
  final int? radiusM; // null khi kind == 'everywhere'
  final int? distanceM; // null khi kind == 'everywhere'

  const AttendanceLocationItemEntity({
    required this.id,
    required this.code,
    required this.name,
    this.kind = 'radius',
    this.kindLabel = 'Bán kính',
    this.lat,
    this.lng,
    this.radiusM,
    this.distanceM,
  });

  bool get isEverywhere => kind == 'everywhere';

  bool get isWithinRadius {
    if (isEverywhere) return true;
    return distanceM != null && radiusM != null && distanceM! <= radiusM!;
  }
}

/// Yêu cầu ảnh chụp kèm lượt chấm công
class AttendanceRequirementsEntity {
  final int photoCount;
  final int minPhotos;
  final int maxPhotos;
  final bool needFront;
  final bool needBack;
  final bool requireBoth;
  final bool satisfied;

  const AttendanceRequirementsEntity({
    this.photoCount = 0,
    this.minPhotos = 2,
    this.maxPhotos = 10,
    this.needFront = true,
    this.needBack = true,
    this.requireBoth = true,
    this.satisfied = false,
  });
}

/// Một ảnh gắn với lượt chấm công (POST .../photos & GET .../history)
class AttendancePunchPhotoEntity {
  final int id;
  final int? fileId;
  final String? token;
  final String url;
  final String photoType; // 'front' | 'back' | 'extra'
  final String photoTypeLabel;
  final String? photoTypeColor;
  final String? takenAt;
  final int? sortOrder;
  final bool duplicate;
  final AttendanceRequirementsEntity? requirements;

  const AttendancePunchPhotoEntity({
    required this.id,
    this.fileId,
    this.token,
    required this.url,
    required this.photoType,
    required this.photoTypeLabel,
    this.photoTypeColor,
    this.takenAt,
    this.sortOrder,
    this.duplicate = false,
    this.requirements,
  });

  /// Sinh full URL từ base URL của hệ thống
  String getFullUrl(String baseUrl) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanUrl = url.startsWith('/') ? url : '/$url';
    return '$cleanBase$cleanUrl';
  }
}

/// Lượt chấm công chuẩn hoá (§3 & §5 API-CHAM-CONG-MOBILE-2026-10-05.md + 2026-10-06.md)
class AttendancePunchEntity {
  final int id;
  final String punchAt;
  final String clientUuid;
  final double lat;
  final double lng;
  final double? accuracyM;
  final int? geofenceId;
  final String? geofenceName;
  final bool isOutsideGeofence;
  final bool isMockLocation;
  final bool isTimeTampered;
  final bool duplicate;
  final String? direction; // 'in' | 'out' | null
  final String? directionLabel; // 'Vào' | 'Ra' | null
  final List<AttendancePunchPhotoEntity> photos;
  final AttendanceRequirementsEntity requirements;

  const AttendancePunchEntity({
    required this.id,
    required this.punchAt,
    required this.clientUuid,
    required this.lat,
    required this.lng,
    this.accuracyM,
    this.geofenceId,
    this.geofenceName,
    this.isOutsideGeofence = false,
    this.isMockLocation = false,
    this.isTimeTampered = false,
    this.duplicate = false,
    this.direction,
    this.directionLabel,
    this.photos = const [],
    required this.requirements,
  });

  /// Chiều chuẩn hoá hiển thị cho người dùng: chỉ có 'Vào' hoặc 'Ra'
  String get displayDirectionLabel {
    if (directionLabel == 'Ra' || direction == 'out') return 'Ra';
    if (directionLabel == 'Vào' || direction == 'in') return 'Vào';
    return directionLabel ?? 'Vào';
  }

  /// Phân tích DateTime từ chuỗi punch_at của server
  DateTime? get punchAtDateTime {
    try {
      // Dạng "2026-10-05 13:30:19+07" hoặc ISO-8601
      String clean = punchAt.replaceAll(' ', 'T');
      return DateTime.tryParse(clean);
    } catch (_) {
      return null;
    }
  }

  /// Định dạng giờ phút hiển thị: "13:30" (ưu tiên giờ SERVER theo spec §3.3)
  String get timeFormatted {
    if (punchAt.contains(' ')) {
      final parts = punchAt.split(' ');
      if (parts.length > 1) {
        final timePart = parts[1];
        final sub = timePart.split(':');
        if (sub.length >= 2) {
          return '${sub[0]}:${sub[1]}';
        }
      }
    }
    final dt = punchAtDateTime;
    if (dt != null) {
      return DateFormat('HH:mm').format(dt);
    }
    return punchAt;
  }

  /// Định dạng ngày hiển thị: "05/10/2026"
  String get dateFormatted {
    if (punchAt.contains(' ')) {
      final datePart = punchAt.split(' ')[0];
      final parts = datePart.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    }
    final dt = punchAtDateTime;
    if (dt != null) {
      return DateFormat('dd/MM/yyyy').format(dt);
    }
    return '';
  }

  /// Ảnh chân dung (`front`) — tên loại giữ theo API, chụp bằng camera nào cũng được
  AttendancePunchPhotoEntity? get frontPhoto {
    final match = photos.where((p) => p.photoType == 'front').toList();
    return match.isNotEmpty ? match.first : null;
  }

  /// Ảnh khung cảnh (`back`) — tên loại giữ theo API, chụp bằng camera nào cũng được
  AttendancePunchPhotoEntity? get backPhoto {
    final match = photos.where((p) => p.photoType == 'back').toList();
    return match.isNotEmpty ? match.first : null;
  }
}

// =============================================================================
// Các entity phụ trợ tương thích với các widget cũ
// =============================================================================

class AttendanceLocationEntity {
  final String address;
  final String gpsAccuracy;
  final double latitude;
  final double longitude;

  const AttendanceLocationEntity({
    required this.address,
    required this.gpsAccuracy,
    required this.latitude,
    required this.longitude,
  });
}

class MonthlyAttendanceStatsEntity {
  final String monthLabel;
  final int workingDays;
  final int lateDays;

  const MonthlyAttendanceStatsEntity({
    required this.monthLabel,
    required this.workingDays,
    required this.lateDays,
  });
}

class AttendanceHistoryItemEntity {
  final String id;
  final String date;
  final String timeRange;
  final String status;
  final bool isLate;

  const AttendanceHistoryItemEntity({
    required this.id,
    required this.date,
    required this.timeRange,
    required this.status,
    required this.isLate,
  });
}

class AttendanceDetailEntity {
  final bool isWorking;
  final String currentTime;
  final String currentDateFormatted;
  final String checkInTime;
  final int workDurationSeconds;
  final AttendanceLocationEntity location;
  final MonthlyAttendanceStatsEntity monthlyStats;
  final List<AttendanceHistoryItemEntity> history;

  const AttendanceDetailEntity({
    required this.isWorking,
    required this.currentTime,
    required this.currentDateFormatted,
    required this.checkInTime,
    required this.workDurationSeconds,
    required this.location,
    required this.monthlyStats,
    required this.history,
  });
}

/// Kết quả bảng công server ĐÃ TÍNH cho một ngày — GET /attendance/mobile/days (§8.4 API-NHAC-CA-MOBILE).
/// Phút muộn/sớm đã trừ phút cho phép của ca, = 0 khi ca tắt tính muộn/sớm hoặc giải trình đã duyệt.
/// Người nhiều mã NV có thể có nhiều dòng một ngày (mỗi mã một bảng công riêng) — hiện TỪNG dòng, KHÔNG cộng.
class AttendanceDayResultEntity {
  final String workDate;
  final String employeeCode;
  final int workMinutes;
  final int lateMinutes;
  final int earlyMinutes;
  final bool lateEarlyExcused;
  final String dayStatus;
  final String dayStatusLabel;
  /// Mã màu Bootstrap của trạng thái ngày (`success/warning/danger/info/primary/secondary/dark`).
  final String dayStatusColor;

  const AttendanceDayResultEntity({
    required this.workDate,
    this.employeeCode = '',
    this.workMinutes = 0,
    this.lateMinutes = 0,
    this.earlyMinutes = 0,
    this.lateEarlyExcused = false,
    this.dayStatus = '',
    this.dayStatusLabel = '',
    this.dayStatusColor = 'secondary',
  });

  bool get isLate => lateMinutes > 0;
  bool get isEarly => earlyMinutes > 0;
}

