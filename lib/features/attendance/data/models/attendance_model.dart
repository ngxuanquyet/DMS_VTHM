import '../../domain/entities/attendance_entity.dart';

class AttendanceLocationModel {
  final String address;
  final String gpsAccuracy;
  final double latitude;
  final double longitude;

  const AttendanceLocationModel({
    required this.address,
    required this.gpsAccuracy,
    required this.latitude,
    required this.longitude,
  });

  factory AttendanceLocationModel.fromJson(Map<String, dynamic> json) {
    return AttendanceLocationModel(
      address: json['address'] as String? ?? '',
      gpsAccuracy: json['gpsAccuracy'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'address': address,
        'gpsAccuracy': gpsAccuracy,
        'latitude': latitude,
        'longitude': longitude,
      };

  AttendanceLocationEntity toEntity() => AttendanceLocationEntity(
        address: address,
        gpsAccuracy: gpsAccuracy,
        latitude: latitude,
        longitude: longitude,
      );
}

class MonthlyAttendanceStatsModel {
  final String monthLabel;
  final int workingDays;
  final int lateDays;

  const MonthlyAttendanceStatsModel({
    required this.monthLabel,
    required this.workingDays,
    required this.lateDays,
  });

  factory MonthlyAttendanceStatsModel.fromJson(Map<String, dynamic> json) {
    return MonthlyAttendanceStatsModel(
      monthLabel: json['monthLabel'] as String? ?? '',
      workingDays: (json['workingDays'] as num?)?.toInt() ?? 0,
      lateDays: (json['lateDays'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'monthLabel': monthLabel,
        'workingDays': workingDays,
        'lateDays': lateDays,
      };

  MonthlyAttendanceStatsEntity toEntity() => MonthlyAttendanceStatsEntity(
        monthLabel: monthLabel,
        workingDays: workingDays,
        lateDays: lateDays,
      );
}

class AttendanceHistoryItemModel {
  final String id;
  final String date;
  final String timeRange;
  final String status;
  final bool isLate;

  const AttendanceHistoryItemModel({
    required this.id,
    required this.date,
    required this.timeRange,
    required this.status,
    required this.isLate,
  });

  factory AttendanceHistoryItemModel.fromJson(Map<String, dynamic> json) {
    return AttendanceHistoryItemModel(
      id: json['id'] as String? ?? '',
      date: json['date'] as String? ?? '',
      timeRange: json['timeRange'] as String? ?? '',
      status: json['status'] as String? ?? '',
      isLate: json['isLate'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'timeRange': timeRange,
        'status': status,
        'isLate': isLate,
      };

  AttendanceHistoryItemEntity toEntity() => AttendanceHistoryItemEntity(
        id: id,
        date: date,
        timeRange: timeRange,
        status: status,
        isLate: isLate,
      );
}

class AttendanceDetailModel {
  final bool isWorking;
  final String currentTime;
  final String currentDateFormatted;
  final String checkInTime;
  final int workDurationSeconds;
  final AttendanceLocationModel location;
  final MonthlyAttendanceStatsModel monthlyStats;
  final List<AttendanceHistoryItemModel> history;

  const AttendanceDetailModel({
    required this.isWorking,
    required this.currentTime,
    required this.currentDateFormatted,
    required this.checkInTime,
    required this.workDurationSeconds,
    required this.location,
    required this.monthlyStats,
    required this.history,
  });

  factory AttendanceDetailModel.fromJson(Map<String, dynamic> json) {
    return AttendanceDetailModel(
      isWorking: json['isWorking'] as bool? ?? false,
      currentTime: json['currentTime'] as String? ?? '',
      currentDateFormatted: json['currentDateFormatted'] as String? ?? '',
      checkInTime: json['checkInTime'] as String? ?? '',
      workDurationSeconds: (json['workDurationSeconds'] as num?)?.toInt() ?? 0,
      location: AttendanceLocationModel.fromJson(
        json['location'] as Map<String, dynamic>? ?? {},
      ),
      monthlyStats: MonthlyAttendanceStatsModel.fromJson(
        json['monthlyStats'] as Map<String, dynamic>? ?? {},
      ),
      history: (json['history'] as List<dynamic>? ?? [])
          .map((e) => AttendanceHistoryItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'isWorking': isWorking,
        'currentTime': currentTime,
        'currentDateFormatted': currentDateFormatted,
        'checkInTime': checkInTime,
        'workDurationSeconds': workDurationSeconds,
        'location': location.toJson(),
        'monthlyStats': monthlyStats.toJson(),
        'history': history.map((e) => e.toJson()).toList(),
      };

  AttendanceDetailEntity toEntity() => AttendanceDetailEntity(
        isWorking: isWorking,
        currentTime: currentTime,
        currentDateFormatted: currentDateFormatted,
        checkInTime: checkInTime,
        workDurationSeconds: workDurationSeconds,
        location: location.toEntity(),
        monthlyStats: monthlyStats.toEntity(),
        history: history.map((e) => e.toEntity()).toList(),
      );
}
