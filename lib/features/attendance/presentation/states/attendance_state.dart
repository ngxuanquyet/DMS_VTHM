import 'package:geolocator/geolocator.dart';
import '../../domain/entities/attendance_entity.dart';

enum AttendanceStatus { initial, loading, loaded, error }

class AttendanceState {
  final AttendanceStatus status;
  final AttendanceConfigEntity? config;
  final AttendanceLocationItemEntity? selectedLocation;
  final List<AttendancePunchEntity> history;
  final AttendancePunchEntity? latestPunch;
  final int selectedDays;
  final bool isPunching;
  final bool isUploadingPhoto;
  final String? errorMessage;
  final String? successMessage;
  /// Số giây đã làm việc tính tới [workDurationAsOf] (lúc tải dữ liệu); đồng hồ trên màn tự cộng thêm thời gian trôi qua
  /// ([workDurationAt]) — KHÔNG cập nhật state mỗi giây (trước đây làm Home + mọi màn theo dõi state dựng lại mỗi giây).
  final int liveWorkDurationSeconds;
  final DateTime? workDurationAsOf;
  final AttendanceDetailEntity? detail;
  final Position? currentPosition;
  final List<AttendanceShiftScheduleEntity> shifts;
  /// Kết quả bảng công theo ngày `yyyy-MM-dd` của tháng [dayResultsMonth] (server tính — vào muộn / ra sớm). Mỗi ngày một
  /// danh sách: người nhiều mã NV có nhiều bảng công cùng ngày.
  final Map<String, List<AttendanceDayResultEntity>> dayResults;
  /// Tháng `yyyy-MM` mà [dayResults] thuộc về; `null` = chưa tải được tháng nào.
  final String? dayResultsMonth;

  const AttendanceState({
    this.status = AttendanceStatus.initial,
    this.config,
    this.selectedLocation,
    this.history = const [],
    this.latestPunch,
    this.selectedDays = 30,
    this.isPunching = false,
    this.isUploadingPhoto = false,
    this.errorMessage,
    this.successMessage,
    this.liveWorkDurationSeconds = 0,
    this.workDurationAsOf,
    this.detail,
    this.currentPosition,
    this.shifts = const [],
    this.dayResults = const {},
    this.dayResultsMonth,
  });

  /// Kiểm tra tài khoản có được phép chấm công hay không (§1.2 & §2)
  bool get canPunch => config?.canPunch ?? true;

  /// Lý do bị chặn từ server (nếu canPunch = false)
  String? get blockedReason => config?.blockedReason;

  /// Đã khai địa điểm chấm công nào chưa (§0)
  bool get hasLocations => config != null && config!.locations.isNotEmpty;

  /// Nhóm có chặn cứng ngoài vùng hay không (§2 group.enforce_geofence)
  bool get isGeofenceEnforced => config?.group.enforceGeofence ?? true;

  /// Địa điểm gần nhất do hệ thống xác định theo GPS
  AttendanceLocationItemEntity? get closestLocation => config?.closestLocation;

  /// Địa điểm chấm công đang chọn (ưu tiên lựa chọn của người dùng, mặc định theo địa điểm gần nhất)
  AttendanceLocationItemEntity? get activeLocation {
    if (selectedLocation != null) return selectedLocation;
    return closestLocation;
  }

  /// Người dùng có đang đứng trong bán kính của địa điểm chấm công đang chọn hay không
  bool get isWithinGeofence {
    if (config == null || config!.locations.isEmpty) return false;
    final active = activeLocation;
    if (active != null) {
      return active.isWithinRadius;
    }
    return config!.isWithinAnyGeofence();
  }

  /// Có bị chặn do ngoài vùng không
  bool get isBlockedByGeofence {
    if (config == null) return false;
    if (config!.locations.isEmpty) return true; // Chưa khai địa điểm nào
    if (isGeofenceEnforced && !isWithinGeofence) return true;
    return false;
  }

  /// Lượt chấm gần nhất có đang thiếu ảnh không
  bool get needsPhotos =>
      latestPunch != null && !latestPunch!.requirements.satisfied;

  /// Chuỗi thời gian làm việc HH:mm:ss tại [now] từ [baseSeconds] tính tới [asOf]: chưa vào ca (0 giây) thì đứng ở 00:00:00, cộng
  /// thêm thời gian từ lúc tải dữ liệu — như đồng hồ cũ tăng 1 giây mỗi giây.
  static String workDurationAt(int baseSeconds, DateTime? asOf, DateTime now) {
    var total = baseSeconds;
    if (total > 0 && asOf != null) {
      final elapsed = now.difference(asOf).inSeconds;
      if (elapsed > 0) total += elapsed;
    }
    final hours = (total ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  AttendanceState copyWith({
    AttendanceStatus? status,
    AttendanceConfigEntity? config,
    AttendanceLocationItemEntity? selectedLocation,
    List<AttendancePunchEntity>? history,
    AttendancePunchEntity? latestPunch,
    int? selectedDays,
    bool? isPunching,
    bool? isUploadingPhoto,
    String? errorMessage,
    String? successMessage,
    int? liveWorkDurationSeconds,
    DateTime? workDurationAsOf,
    AttendanceDetailEntity? detail,
    Position? currentPosition,
    List<AttendanceShiftScheduleEntity>? shifts,
    Map<String, List<AttendanceDayResultEntity>>? dayResults,
    String? dayResultsMonth,
  }) {
    return AttendanceState(
      status: status ?? this.status,
      config: config ?? this.config,
      selectedLocation: selectedLocation ?? this.selectedLocation,
      history: history ?? this.history,
      latestPunch: latestPunch ?? this.latestPunch,
      selectedDays: selectedDays ?? this.selectedDays,
      isPunching: isPunching ?? this.isPunching,
      isUploadingPhoto: isUploadingPhoto ?? this.isUploadingPhoto,
      errorMessage: errorMessage,
      successMessage: successMessage,
      liveWorkDurationSeconds: liveWorkDurationSeconds ?? this.liveWorkDurationSeconds,
      workDurationAsOf: workDurationAsOf ?? this.workDurationAsOf,
      detail: detail ?? this.detail,
      currentPosition: currentPosition ?? this.currentPosition,
      shifts: shifts ?? this.shifts,
      dayResults: dayResults ?? this.dayResults,
      dayResultsMonth: dayResultsMonth ?? this.dayResultsMonth,
    );
  }
}
