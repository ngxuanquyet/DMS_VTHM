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

  /// Công tắc "Cập nhật vật tư khi viếng thăm" (`materials_enabled`) — tắt thì màn check-in không có mục Vật tư và
  /// check-out không đòi vật tư. Server cũ không gửi ⇒ coi như bật (giữ hành vi trước).
  final bool materialsEnabled;

  const VisitRules({
    this.requireGeofence = true,
    this.defaultRadiusM = 100,
    this.blockOnMockLocation = false,
    this.minDurationMinutes = 5,
    this.minPhotos = 2,
    this.closedMinPhotos = 1,
    this.routeScope = 'assigned',
    this.autoCloseAfterHours = 0,
    this.materialsEnabled = true,
  });

  factory VisitRules.fromJson(Map<String, dynamic> json) {
    return VisitRules(
      requireGeofence: json['require_geofence'] as bool? ?? true,
      defaultRadiusM: (json['default_radius_m'] as num?)?.toInt() ?? 100,
      blockOnMockLocation: json['block_on_mock_location'] as bool? ?? false,
      minDurationMinutes: (json['min_duration_minutes'] as num?)?.toInt() ??
          (json['min_duration'] as num?)?.toInt() ??
          5,
      minPhotos: (json['min_photos'] as num?)?.toInt() ?? 2,
      closedMinPhotos: (json['closed_min_photos'] as num?)?.toInt() ?? 1,
      routeScope: json['route_scope']?.toString() ?? 'assigned',
      autoCloseAfterHours:
          (json['auto_close_after_hours'] as num?)?.toInt() ?? 0,
      materialsEnabled: json['materials_enabled'] as bool? ?? true,
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
        'materials_enabled': materialsEnabled,
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

/// Luật biểu mẫu thị trường trên app (mobile-rules `forms`).
class FormsRules {
  /// Chờ server tối đa chừng này giây khi tải biểu mẫu; quá thì dùng bản đã lưu trong máy + làm mới ngầm.
  final int fetchTimeoutSeconds;

  /// Mã biểu mẫu THU THẬP mà nút «Thêm mới NPP» trên trang chủ mở (tham số server `dms.form_home_npp_form`); rỗng = chưa
  /// cấu hình. Server cũ không gửi ⇒ mặc định `create_npp` (Khảo sát NPP Mới VTHM).
  final String homeNppFormCode;

  /// Mặc định khi server không gửi — trùng `DmsSettingProvider::DEFAULT_HOME_NPP_FORM` phía server.
  static const String defaultHomeNppFormCode = 'create_npp';

  const FormsRules({this.fetchTimeoutSeconds = 5, this.homeNppFormCode = defaultHomeNppFormCode});

  factory FormsRules.fromJson(Map<String, dynamic> json) {
    return FormsRules(
      fetchTimeoutSeconds: ((json['fetch_timeout_seconds'] as num?)?.toInt() ?? 5).clamp(1, 15),
      homeNppFormCode: json['home_npp_form_code'] is String ? (json['home_npp_form_code'] as String).trim() : defaultHomeNppFormCode,
    );
  }

  Map<String, dynamic> toJson() => {
        'fetch_timeout_seconds': fetchTimeoutSeconds,
        'home_npp_form_code': homeNppFormCode,
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

/// Báo bản app mới (mobile-rules `app_update`, 25/11/2026). Server cũ không gửi ⇒ mọi số 0 / rỗng = không báo gì.
class AppUpdateRules {
  /// App có số build (`+N` của phiên bản) thấp hơn ⇒ màn chặn «Cần cập nhật app»; 0 = không bắt buộc.
  final int minBuild;

  /// Manifest APK do `scripts/publish_apk.sh dms` ghi (versionCode, fileName, size, sha256); rỗng = không báo trên Android.
  final String androidManifestUrl;

  /// Build iOS mới nhất đã có trên TestFlight / App Store; 0 = không báo trên iPhone.
  final int iosLatestBuild;

  /// Link TestFlight / App Store mà nút «Cập nhật» trên iPhone mở; rỗng = không báo trên iPhone.
  final String iosUpdateUrl;

  const AppUpdateRules({
    this.minBuild = 0,
    this.androidManifestUrl = '',
    this.iosLatestBuild = 0,
    this.iosUpdateUrl = '',
  });

  /// Số build đọc mềm (số hoặc chuỗi số): ép `as num?` ném lỗi với chuỗi ⇒ hỏng CẢ `MobileRules.fromJson`, app kẹt luật cũ.
  static int _build(Object? v) => v is num ? v.toInt() : (int.tryParse(v?.toString() ?? '') ?? 0);

  factory AppUpdateRules.fromJson(Map<String, dynamic> json) {
    return AppUpdateRules(
      minBuild: _build(json['min_build']),
      androidManifestUrl: json['android_manifest_url'] is String ? (json['android_manifest_url'] as String).trim() : '',
      iosLatestBuild: _build(json['ios_latest_build']),
      iosUpdateUrl: json['ios_update_url'] is String ? (json['ios_update_url'] as String).trim() : '',
    );
  }

  Map<String, dynamic> toJson() => {
        'min_build': minBuild,
        'android_manifest_url': androidManifestUrl,
        'ios_latest_build': iosLatestBuild,
        'ios_update_url': iosUpdateUrl,
      };

  @override
  bool operator ==(Object other) =>
      other is AppUpdateRules &&
      other.minBuild == minBuild &&
      other.androidManifestUrl == androidManifestUrl &&
      other.iosLatestBuild == iosLatestBuild &&
      other.iosUpdateUrl == iosUpdateUrl;

  @override
  int get hashCode => Object.hash(minBuild, androidManifestUrl, iosLatestBuild, iosUpdateUrl);
}

class MobileRules {
  final VisitRules visit;
  final PositionRules position;
  final FormsRules forms;
  final ClockRules clock;
  final AppUpdateRules appUpdate;

  const MobileRules({
    this.visit = const VisitRules(),
    this.position = const PositionRules(),
    this.forms = const FormsRules(),
    this.clock = const ClockRules(),
    this.appUpdate = const AppUpdateRules(),
  });

  factory MobileRules.fromJson(Map<String, dynamic> json) {
    return MobileRules(
      visit: json['visit'] is Map<String, dynamic>
          ? VisitRules.fromJson(json['visit'] as Map<String, dynamic>)
          : const VisitRules(),
      position: json['position'] is Map<String, dynamic>
          ? PositionRules.fromJson(json['position'] as Map<String, dynamic>)
          : const PositionRules(),
      forms: json['forms'] is Map<String, dynamic>
          ? FormsRules.fromJson(json['forms'] as Map<String, dynamic>)
          : const FormsRules(),
      clock: json['clock'] is Map<String, dynamic>
          ? ClockRules.fromJson(json['clock'] as Map<String, dynamic>)
          : const ClockRules(),
      appUpdate: json['app_update'] is Map<String, dynamic>
          ? AppUpdateRules.fromJson(json['app_update'] as Map<String, dynamic>)
          : const AppUpdateRules(),
    );
  }

  Map<String, dynamic> toJson() => {
        'visit': visit.toJson(),
        'position': position.toJson(),
        'forms': forms.toJson(),
        'clock': clock.toJson(),
        'app_update': appUpdate.toJson(),
      };
}
