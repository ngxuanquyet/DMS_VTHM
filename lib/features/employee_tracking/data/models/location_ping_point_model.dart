import 'package:uuid/uuid.dart';

/// Mô hình một điểm GPS gửi lên server theo §2 API-VI-TRI-NHAN-VIEN-MOBILE-2026-10-09.md
class LocationPingPointModel {
  final double lat;
  final double lng;
  final double? accuracyM;
  final bool isMockLocation;
  final int? batteryPct;
  final String source; // 'auto' | 'app_exit' | 'requested'
  final String clientTime; // ISO-8601 string lúc đo
  final String clientUuid; // UUID v4 sinh lúc đo
  final int? requestId; // Chỉ có khi source = 'requested'
  final String? appVersion;

  const LocationPingPointModel({
    required this.lat,
    required this.lng,
    this.accuracyM,
    this.isMockLocation = false,
    this.batteryPct,
    this.source = 'auto',
    required this.clientTime,
    required this.clientUuid,
    this.requestId,
    this.appVersion,
  });

  /// Factory tạo điểm mới sinh UUID v4 và clientTime ngay tại thời điểm đo
  factory LocationPingPointModel.create({
    required double lat,
    required double lng,
    double? accuracyM,
    bool isMockLocation = false,
    int? batteryPct,
    String source = 'auto',
    int? requestId,
    String? appVersion,
    DateTime? measuredAt,
    String? customUuid,
  }) {
    final now = measuredAt ?? DateTime.now();
    return LocationPingPointModel(
      lat: lat,
      lng: lng,
      accuracyM: accuracyM,
      isMockLocation: isMockLocation,
      batteryPct: batteryPct,
      source: source,
      clientTime: now.toIso8601String(),
      clientUuid: customUuid ?? const Uuid().v4(),
      requestId: requestId,
      appVersion: appVersion,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'lat': lat,
      'lng': lng,
      'source': source,
      'client_uuid': clientUuid,
      'client_time': clientTime,
      'is_mock_location': isMockLocation,
    };

    if (accuracyM != null) {
      map['accuracy_m'] = accuracyM;
    }
    if (batteryPct != null) {
      map['battery_pct'] = batteryPct;
    }
    if (requestId != null) {
      map['request_id'] = requestId;
    }
    if (appVersion != null && appVersion!.isNotEmpty) {
      map['app_version'] = appVersion!.length > 32 ? appVersion!.substring(0, 32) : appVersion;
    }

    return map;
  }

  factory LocationPingPointModel.fromJson(Map<String, dynamic> json) {
    return LocationPingPointModel(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      accuracyM: json['accuracy_m'] != null ? (json['accuracy_m'] as num).toDouble() : null,
      isMockLocation: json['is_mock_location'] == true,
      batteryPct: json['battery_pct'] as int?,
      source: json['source'] as String? ?? 'auto',
      clientTime: json['client_time'] as String? ?? DateTime.now().toIso8601String(),
      clientUuid: json['client_uuid'] as String? ?? const Uuid().v4(),
      requestId: json['request_id'] as int?,
      appVersion: json['app_version'] as String?,
    );
  }
}
