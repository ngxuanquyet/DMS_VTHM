/// Mô hình luật thị trường cho app di động (GET /dms/mobile-rules)
/// Theo đặc tả API-THAY-DOI-CHO-MOBILE-2026-10-01.md (§1)
class VisitRules {
  final bool requireGeofence;
  final int defaultRadiusM;
  final bool blockOnMockLocation;
  final int minDurationMinutes;
  final int minPhotos;
  final int closedMinPhotos;
  final String routeScope;
  final int autoCloseAfterHours;

  const VisitRules({
    this.requireGeofence = true,
    this.defaultRadiusM = 100,
    this.blockOnMockLocation = false,
    this.minDurationMinutes = 5,
    this.minPhotos = 2,
    this.closedMinPhotos = 1,
    this.routeScope = 'assigned',
    this.autoCloseAfterHours = 12,
  });

  factory VisitRules.fromJson(Map<String, dynamic> json) {
    return VisitRules(
      requireGeofence: json['require_geofence'] as bool? ?? true,
      defaultRadiusM: (json['default_radius_m'] as num?)?.toInt() ?? 100,
      blockOnMockLocation: json['block_on_mock_location'] as bool? ?? false,
      minDurationMinutes: (json['min_duration_minutes'] as num?)?.toInt() ?? 5,
      minPhotos: (json['min_photos'] as num?)?.toInt() ?? 2,
      closedMinPhotos: (json['closed_min_photos'] as num?)?.toInt() ?? 1,
      routeScope: json['route_scope']?.toString() ?? 'assigned',
      autoCloseAfterHours:
          (json['auto_close_after_hours'] as num?)?.toInt() ?? 12,
    );
  }

  Map<String, dynamic> toJson() => {
        'require_geofence': requireGeofence,
        'default_radius_m': defaultRadiusM,
        'block_on_mock_location': blockOnMockLocation,
        'min_duration_minutes': minDurationMinutes,
        'min_photos': minPhotos,
        'closed_min_photos': closedMinPhotos,
        'route_scope': routeScope,
        'auto_close_after_hours': autoCloseAfterHours,
      };
}

class PositionRules {
  final int minPhotos;
  final bool blockOnMockLocation;

  const PositionRules({
    this.minPhotos = 1,
    this.blockOnMockLocation = false,
  });

  factory PositionRules.fromJson(Map<String, dynamic> json) {
    return PositionRules(
      minPhotos: (json['min_photos'] as num?)?.toInt() ?? 1,
      blockOnMockLocation: json['block_on_mock_location'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'min_photos': minPhotos,
        'block_on_mock_location': blockOnMockLocation,
      };
}

class ClockRules {
  final int skewToleranceMinutes;
  final int offlineMaxQueueHours;

  const ClockRules({
    this.skewToleranceMinutes = 15,
    this.offlineMaxQueueHours = 24,
  });

  factory ClockRules.fromJson(Map<String, dynamic> json) {
    return ClockRules(
      skewToleranceMinutes:
          (json['skew_tolerance_minutes'] as num?)?.toInt() ?? 15,
      offlineMaxQueueHours:
          (json['offline_max_queue_hours'] as num?)?.toInt() ?? 24,
    );
  }

  Map<String, dynamic> toJson() => {
        'skew_tolerance_minutes': skewToleranceMinutes,
        'offline_max_queue_hours': offlineMaxQueueHours,
      };
}

class MobileRules {
  final VisitRules visit;
  final PositionRules position;
  final ClockRules clock;

  const MobileRules({
    this.visit = const VisitRules(),
    this.position = const PositionRules(),
    this.clock = const ClockRules(),
  });

  factory MobileRules.fromJson(Map<String, dynamic> json) {
    return MobileRules(
      visit: json['visit'] is Map<String, dynamic>
          ? VisitRules.fromJson(json['visit'] as Map<String, dynamic>)
          : const VisitRules(),
      position: json['position'] is Map<String, dynamic>
          ? PositionRules.fromJson(json['position'] as Map<String, dynamic>)
          : const PositionRules(),
      clock: json['clock'] is Map<String, dynamic>
          ? ClockRules.fromJson(json['clock'] as Map<String, dynamic>)
          : const ClockRules(),
    );
  }

  Map<String, dynamic> toJson() => {
        'visit': visit.toJson(),
        'position': position.toJson(),
        'clock': clock.toJson(),
      };
}
