import '../../domain/entities/dashboard_entity.dart';

class DashboardGreetingModel {
  final String userName;
  final String role;
  final String currentDate;

  const DashboardGreetingModel({
    required this.userName,
    required this.role,
    required this.currentDate,
  });

  factory DashboardGreetingModel.fromJson(Map<String, dynamic> json) {
    return DashboardGreetingModel(
      userName: json['userName'] as String? ?? '',
      role: json['role'] as String? ?? '',
      currentDate: json['currentDate'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'userName': userName,
        'role': role,
        'currentDate': currentDate,
      };

  DashboardGreetingEntity toEntity() => DashboardGreetingEntity(
        userName: userName,
        role: role,
        currentDate: currentDate,
      );
}

class DashboardAttendanceModel {
  final bool isCheckedIn;
  final String checkInTime;
  final String workDuration;
  final String statusLabel;

  const DashboardAttendanceModel({
    required this.isCheckedIn,
    required this.checkInTime,
    required this.workDuration,
    required this.statusLabel,
  });

  factory DashboardAttendanceModel.fromJson(Map<String, dynamic> json) {
    return DashboardAttendanceModel(
      isCheckedIn: json['isCheckedIn'] as bool? ?? false,
      checkInTime: json['checkInTime'] as String? ?? '',
      workDuration: json['workDuration'] as String? ?? '',
      statusLabel: json['statusLabel'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'isCheckedIn': isCheckedIn,
        'checkInTime': checkInTime,
        'workDuration': workDuration,
        'statusLabel': statusLabel,
      };

  DashboardAttendanceEntity toEntity() => DashboardAttendanceEntity(
        isCheckedIn: isCheckedIn,
        checkInTime: checkInTime,
        workDuration: workDuration,
        statusLabel: statusLabel,
      );
}

class DashboardRouteModel {
  final String routeName;
  final int completedCount;
  final int totalCount;
  final double progressPercent;
  final String nextStop;

  const DashboardRouteModel({
    required this.routeName,
    required this.completedCount,
    required this.totalCount,
    required this.progressPercent,
    required this.nextStop,
  });

  factory DashboardRouteModel.fromJson(Map<String, dynamic> json) {
    return DashboardRouteModel(
      routeName: json['routeName'] as String? ?? '',
      completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0.0,
      nextStop: json['nextStop'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'routeName': routeName,
        'completedCount': completedCount,
        'totalCount': totalCount,
        'progressPercent': progressPercent,
        'nextStop': nextStop,
      };

  DashboardRouteEntity toEntity() => DashboardRouteEntity(
        routeName: routeName,
        completedCount: completedCount,
        totalCount: totalCount,
        progressPercent: progressPercent,
        nextStop: nextStop,
      );
}

class DashboardFormSummaryModel {
  final int pendingCount;
  final int completedCount;
  final int overdueCount;

  const DashboardFormSummaryModel({
    required this.pendingCount,
    required this.completedCount,
    required this.overdueCount,
  });

  factory DashboardFormSummaryModel.fromJson(Map<String, dynamic> json) {
    return DashboardFormSummaryModel(
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
      completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
      overdueCount: (json['overdueCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'pendingCount': pendingCount,
        'completedCount': completedCount,
        'overdueCount': overdueCount,
      };

  DashboardFormSummaryEntity toEntity() => DashboardFormSummaryEntity(
        pendingCount: pendingCount,
        completedCount: completedCount,
        overdueCount: overdueCount,
      );
}

class ActivityTimelineModel {
  final String id;
  final String time;
  final String title;
  final String highlight;
  final String suffix;
  final bool isPrimary;

  const ActivityTimelineModel({
    required this.id,
    required this.time,
    required this.title,
    this.highlight = '',
    this.suffix = '',
    this.isPrimary = false,
  });

  factory ActivityTimelineModel.fromJson(Map<String, dynamic> json) {
    return ActivityTimelineModel(
      id: json['id'] as String? ?? '',
      time: json['time'] as String? ?? '',
      title: json['title'] as String? ?? '',
      highlight: json['highlight'] as String? ?? '',
      suffix: json['suffix'] as String? ?? '',
      isPrimary: json['isPrimary'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time,
        'title': title,
        'highlight': highlight,
        'suffix': suffix,
        'isPrimary': isPrimary,
      };

  ActivityTimelineEntity toEntity() => ActivityTimelineEntity(
        id: id,
        time: time,
        title: title,
        highlight: highlight,
        suffix: suffix,
        isPrimary: isPrimary,
      );
}

class DashboardModel {
  final DashboardGreetingModel greeting;
  final DashboardAttendanceModel attendance;
  final DashboardRouteModel routeSummary;
  final DashboardFormSummaryModel formSummary;
  final List<ActivityTimelineModel> recentActivities;

  const DashboardModel({
    required this.greeting,
    required this.attendance,
    required this.routeSummary,
    required this.formSummary,
    required this.recentActivities,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    return DashboardModel(
      greeting: DashboardGreetingModel.fromJson(
        json['greeting'] as Map<String, dynamic>? ?? {},
      ),
      attendance: DashboardAttendanceModel.fromJson(
        json['attendance'] as Map<String, dynamic>? ?? {},
      ),
      routeSummary: DashboardRouteModel.fromJson(
        json['routeSummary'] as Map<String, dynamic>? ?? {},
      ),
      formSummary: DashboardFormSummaryModel.fromJson(
        json['formSummary'] as Map<String, dynamic>? ?? {},
      ),
      recentActivities: (json['recentActivities'] as List<dynamic>? ?? [])
          .map((e) => ActivityTimelineModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'greeting': greeting.toJson(),
        'attendance': attendance.toJson(),
        'routeSummary': routeSummary.toJson(),
        'formSummary': formSummary.toJson(),
        'recentActivities': recentActivities.map((e) => e.toJson()).toList(),
      };

  DashboardEntity toEntity() => DashboardEntity(
        greeting: greeting.toEntity(),
        attendance: attendance.toEntity(),
        routeSummary: routeSummary.toEntity(),
        formSummary: formSummary.toEntity(),
        recentActivities: recentActivities.map((e) => e.toEntity()).toList(),
      );
}
