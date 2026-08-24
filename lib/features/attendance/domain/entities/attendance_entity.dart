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
