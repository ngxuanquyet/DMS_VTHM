import '../../domain/entities/attendance_entity.dart';

enum AttendanceStatus { initial, loading, loaded, error }

class AttendanceState {
  final AttendanceStatus status;
  final AttendanceDetailEntity? detail;
  final String? errorMessage;
  final String liveCurrentTime;
  final int liveWorkDurationSeconds;

  const AttendanceState({
    this.status = AttendanceStatus.initial,
    this.detail,
    this.errorMessage,
    this.liveCurrentTime = '14:26:00',
    this.liveWorkDurationSeconds = 24264,
  });

  String get formattedWorkDuration {
    final hours = (liveWorkDurationSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((liveWorkDurationSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (liveWorkDurationSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  AttendanceState copyWith({
    AttendanceStatus? status,
    AttendanceDetailEntity? detail,
    String? errorMessage,
    String? liveCurrentTime,
    int? liveWorkDurationSeconds,
  }) {
    return AttendanceState(
      status: status ?? this.status,
      detail: detail ?? this.detail,
      errorMessage: errorMessage,
      liveCurrentTime: liveCurrentTime ?? this.liveCurrentTime,
      liveWorkDurationSeconds: liveWorkDurationSeconds ?? this.liveWorkDurationSeconds,
    );
  }
}
