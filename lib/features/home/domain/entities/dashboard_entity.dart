class DashboardGreetingEntity {
  final String userName;
  final String role;
  final String currentDate;

  const DashboardGreetingEntity({
    required this.userName,
    required this.role,
    required this.currentDate,
  });
}

class DashboardAttendanceEntity {
  final bool isCheckedIn;
  final String checkInTime;
  final String workDuration;
  final String statusLabel;

  const DashboardAttendanceEntity({
    required this.isCheckedIn,
    required this.checkInTime,
    required this.workDuration,
    required this.statusLabel,
  });
}

class DashboardRouteEntity {
  final String routeName;
  final int completedCount;
  final int totalCount;
  final double progressPercent;
  final String nextStop;

  const DashboardRouteEntity({
    required this.routeName,
    required this.completedCount,
    required this.totalCount,
    required this.progressPercent,
    required this.nextStop,
  });
}

class DashboardFormSummaryEntity {
  final int pendingCount;
  final int completedCount;
  final int overdueCount;

  const DashboardFormSummaryEntity({
    required this.pendingCount,
    required this.completedCount,
    required this.overdueCount,
  });
}

class ActivityTimelineEntity {
  final String id;
  final String time;
  final String title;
  final String highlight;
  final String suffix;
  final bool isPrimary;

  const ActivityTimelineEntity({
    required this.id,
    required this.time,
    required this.title,
    required this.highlight,
    required this.suffix,
    required this.isPrimary,
  });
}

class DashboardEntity {
  final DashboardGreetingEntity greeting;
  final DashboardAttendanceEntity attendance;
  final DashboardRouteEntity routeSummary;
  final DashboardFormSummaryEntity formSummary;
  final List<ActivityTimelineEntity> recentActivities;

  const DashboardEntity({
    required this.greeting,
    required this.attendance,
    required this.routeSummary,
    required this.formSummary,
    required this.recentActivities,
  });
}
