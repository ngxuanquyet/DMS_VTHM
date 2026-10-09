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
  final String liveCurrentTime;
  final int liveWorkDurationSeconds;
  final AttendanceDetailEntity? detail;
  final Position? currentPosition;

  const AttendanceState({
    this.status = AttendanceStatus.initial,
    this.config,
    this.selectedLocation,
    this.history = const [],
    this.latestPunch,
    this.selectedDays = 7,
    this.isPunching = false,
    this.isUploadingPhoto = false,
    this.errorMessage,
    this.successMessage,
    this.liveCurrentTime = '--:--:--',
    this.liveWorkDurationSeconds = 0,
    this.detail,
    this.currentPosition,
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

  /// Định dạng chuỗi thời gian làm việc: HH:mm:ss
  String get formattedWorkDuration {
    final hours = (liveWorkDurationSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((liveWorkDurationSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (liveWorkDurationSeconds % 60).toString().padLeft(2, '0');
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
    String? liveCurrentTime,
    int? liveWorkDurationSeconds,
    AttendanceDetailEntity? detail,
    Position? currentPosition,
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
      liveCurrentTime: liveCurrentTime ?? this.liveCurrentTime,
      liveWorkDurationSeconds: liveWorkDurationSeconds ?? this.liveWorkDurationSeconds,
      detail: detail ?? this.detail,
      currentPosition: currentPosition ?? this.currentPosition,
    );
  }
}
