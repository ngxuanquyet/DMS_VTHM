import '../../domain/entities/attendance_entity.dart';

// =============================================================================
// MODELS CHO API CHẤM CÔNG MOBILE (API-CHAM-CONG-MOBILE-2026-10-05.md)
// =============================================================================

class AttendanceGroupModel {
  final String code;
  final String name;
  final bool enforceGeofence;

  const AttendanceGroupModel({
    required this.code,
    required this.name,
    required this.enforceGeofence,
  });

  factory AttendanceGroupModel.fromJson(Map<String, dynamic> json) {
    return AttendanceGroupModel(
      code: json['code'] as String? ?? 'MARKET',
      name: json['name'] as String? ?? 'Khối thị trường',
      enforceGeofence: json['enforce_geofence'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'enforce_geofence': enforceGeofence,
      };

  AttendanceGroupEntity toEntity() => AttendanceGroupEntity(
        code: code,
        name: name,
        enforceGeofence: enforceGeofence,
      );
}

class AttendancePhotoConfigModel {
  final int minPhotos;
  final int maxPhotos;
  final bool requireBoth;

  const AttendancePhotoConfigModel({
    this.minPhotos = 2,
    this.maxPhotos = 10,
    this.requireBoth = true,
  });

  factory AttendancePhotoConfigModel.fromJson(Map<String, dynamic> json) {
    return AttendancePhotoConfigModel(
      minPhotos: (json['min_photos'] as num?)?.toInt() ?? 2,
      maxPhotos: (json['max_photos'] as num?)?.toInt() ?? 10,
      requireBoth: json['require_both'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'min_photos': minPhotos,
        'max_photos': maxPhotos,
        'require_both': requireBoth,
      };

  AttendancePhotoConfigEntity toEntity() => AttendancePhotoConfigEntity(
        minPhotos: minPhotos,
        maxPhotos: maxPhotos,
        requireBoth: requireBoth,
      );
}

class AttendanceLocationItemModel {
  final int id;
  final String code;
  final String name;
  final double lat;
  final double lng;
  final int radiusM;
  final int? distanceM;

  const AttendanceLocationItemModel({
    required this.id,
    required this.code,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusM,
    this.distanceM,
  });

  factory AttendanceLocationItemModel.fromJson(Map<String, dynamic> json) {
    return AttendanceLocationItemModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      radiusM: (json['radius_m'] as num?)?.toInt() ?? 200,
      distanceM: (json['distance_m'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'lat': lat,
        'lng': lng,
        'radius_m': radiusM,
        'distance_m': distanceM,
      };

  AttendanceLocationItemEntity toEntity() => AttendanceLocationItemEntity(
        id: id,
        code: code,
        name: name,
        lat: lat,
        lng: lng,
        radiusM: radiusM,
        distanceM: distanceM,
      );
}

class AttendanceConfigModel {
  final bool canPunch;
  final String? blockedReason;
  final AttendanceGroupModel group;
  final AttendancePhotoConfigModel photo;
  final List<AttendanceLocationItemModel> locations;

  const AttendanceConfigModel({
    required this.canPunch,
    this.blockedReason,
    required this.group,
    required this.photo,
    required this.locations,
  });

  factory AttendanceConfigModel.fromJson(Map<String, dynamic> json) {
    return AttendanceConfigModel(
      canPunch: json['can_punch'] as bool? ?? true,
      blockedReason: json['blocked_reason'] as String?,
      group: AttendanceGroupModel.fromJson(
        json['group'] as Map<String, dynamic>? ?? {},
      ),
      photo: AttendancePhotoConfigModel.fromJson(
        json['photo'] as Map<String, dynamic>? ?? {},
      ),
      locations: (json['locations'] as List<dynamic>? ?? [])
          .map((e) => AttendanceLocationItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'can_punch': canPunch,
        'blocked_reason': blockedReason,
        'group': group.toJson(),
        'photo': photo.toJson(),
        'locations': locations.map((e) => e.toJson()).toList(),
      };

  AttendanceConfigEntity toEntity() => AttendanceConfigEntity(
        canPunch: canPunch,
        blockedReason: blockedReason,
        group: group.toEntity(),
        photo: photo.toEntity(),
        locations: locations.map((e) => e.toEntity()).toList(),
      );
}

class AttendanceRequirementsModel {
  final int photoCount;
  final int minPhotos;
  final int maxPhotos;
  final bool needFront;
  final bool needBack;
  final bool requireBoth;
  final bool satisfied;

  const AttendanceRequirementsModel({
    this.photoCount = 0,
    this.minPhotos = 2,
    this.maxPhotos = 10,
    this.needFront = true,
    this.needBack = true,
    this.requireBoth = true,
    this.satisfied = false,
  });

  factory AttendanceRequirementsModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRequirementsModel(
      photoCount: (json['photo_count'] as num?)?.toInt() ?? 0,
      minPhotos: (json['min_photos'] as num?)?.toInt() ?? 2,
      maxPhotos: (json['max_photos'] as num?)?.toInt() ?? 10,
      needFront: json['need_front'] as bool? ?? true,
      needBack: json['need_back'] as bool? ?? true,
      requireBoth: json['require_both'] as bool? ?? true,
      satisfied: json['satisfied'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'photo_count': photoCount,
        'min_photos': minPhotos,
        'max_photos': maxPhotos,
        'need_front': needFront,
        'need_back': needBack,
        'require_both': requireBoth,
        'satisfied': satisfied,
      };

  AttendanceRequirementsEntity toEntity() => AttendanceRequirementsEntity(
        photoCount: photoCount,
        minPhotos: minPhotos,
        maxPhotos: maxPhotos,
        needFront: needFront,
        needBack: needBack,
        requireBoth: requireBoth,
        satisfied: satisfied,
      );
}

class AttendancePhotoItemModel {
  final int id;
  final int? fileId;
  final String? token;
  final String url;
  final String photoType;
  final String photoTypeLabel;
  final String? photoTypeColor;
  final String? takenAt;
  final int? sortOrder;
  final bool duplicate;

  const AttendancePhotoItemModel({
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
  });

  factory AttendancePhotoItemModel.fromJson(Map<String, dynamic> json) {
    return AttendancePhotoItemModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fileId: (json['file_id'] as num?)?.toInt(),
      token: json['token'] as String?,
      url: json['url'] as String? ?? '',
      photoType: json['photo_type'] as String? ?? 'front',
      photoTypeLabel: json['photo_type_label'] as String? ?? 'Ảnh',
      photoTypeColor: json['photo_type_color'] as String?,
      takenAt: json['taken_at'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt(),
      duplicate: json['duplicate'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'file_id': fileId,
        'token': token,
        'url': url,
        'photo_type': photoType,
        'photo_type_label': photoTypeLabel,
        'photo_type_color': photoTypeColor,
        'taken_at': takenAt,
        'sort_order': sortOrder,
        'duplicate': duplicate,
      };

  AttendancePunchPhotoEntity toEntity() => AttendancePunchPhotoEntity(
        id: id,
        fileId: fileId,
        token: token,
        url: url,
        photoType: photoType,
        photoTypeLabel: photoTypeLabel,
        photoTypeColor: photoTypeColor,
        takenAt: takenAt,
        sortOrder: sortOrder,
        duplicate: duplicate,
      );
}

class AttendancePunchModel {
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
  final List<AttendancePhotoItemModel> photos;
  final AttendanceRequirementsModel requirements;

  const AttendancePunchModel({
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
    this.photos = const [],
    required this.requirements,
  });

  factory AttendancePunchModel.fromJson(Map<String, dynamic> json) {
    return AttendancePunchModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      punchAt: json['punch_at'] as String? ?? '',
      clientUuid: json['client_uuid'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
      geofenceId: (json['geofence_id'] as num?)?.toInt(),
      geofenceName: json['geofence_name'] as String?,
      isOutsideGeofence: json['is_outside_geofence'] as bool? ?? false,
      isMockLocation: json['is_mock_location'] as bool? ?? false,
      isTimeTampered: json['is_time_tampered'] as bool? ?? false,
      duplicate: json['duplicate'] as bool? ?? false,
      photos: (json['photos'] as List<dynamic>? ?? [])
          .map((e) => AttendancePhotoItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      requirements: AttendanceRequirementsModel.fromJson(
        json['requirements'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'punch_at': punchAt,
        'client_uuid': clientUuid,
        'lat': lat,
        'lng': lng,
        'accuracy_m': accuracyM,
        'geofence_id': geofenceId,
        'geofence_name': geofenceName,
        'is_outside_geofence': isOutsideGeofence,
        'is_mock_location': isMockLocation,
        'is_time_tampered': isTimeTampered,
        'duplicate': duplicate,
        'photos': photos.map((e) => e.toJson()).toList(),
        'requirements': requirements.toJson(),
      };

  AttendancePunchEntity toEntity() => AttendancePunchEntity(
        id: id,
        punchAt: punchAt,
        clientUuid: clientUuid,
        lat: lat,
        lng: lng,
        accuracyM: accuracyM,
        geofenceId: geofenceId,
        geofenceName: geofenceName,
        isOutsideGeofence: isOutsideGeofence,
        isMockLocation: isMockLocation,
        isTimeTampered: isTimeTampered,
        duplicate: duplicate,
        photos: photos.map((e) => e.toEntity()).toList(),
        requirements: requirements.toEntity(),
      );
}

class AttendancePunchRequestModel {
  final String clientUuid;
  final double lat;
  final double lng;
  final double? accuracyM;
  final String? clientTime;
  final String? isMockLocation;
  final String? isRootedDevice;
  final Map<String, dynamic>? deviceInfo;

  const AttendancePunchRequestModel({
    required this.clientUuid,
    required this.lat,
    required this.lng,
    this.accuracyM,
    this.clientTime,
    this.isMockLocation,
    this.isRootedDevice,
    this.deviceInfo,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'client_uuid': clientUuid,
      'lat': lat,
      'lng': lng,
    };
    if (accuracyM != null) map['accuracy_m'] = accuracyM;
    if (clientTime != null) map['client_time'] = clientTime;
    if (isMockLocation != null) map['is_mock_location'] = isMockLocation;
    if (isRootedDevice != null) map['is_rooted_device'] = isRootedDevice;
    if (deviceInfo != null) map['device_info'] = deviceInfo;
    return map;
  }
}

// =============================================================================
// CÁC MODEL CŨ TƯƠNG THÍCH NGƯỢC
// =============================================================================

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
