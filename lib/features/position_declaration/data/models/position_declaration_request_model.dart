/// Payload gửi khai báo vị trí (POST /dms/position-declarations)
/// Theo đặc tả §4.1 API-KHAI-BAO-VI-TRI-MOBILE-2026-10-01.md
class PositionDeclarationRequestModel {
  final int reasonId;
  final double lat;
  final double lng;
  final List<String> photoTokens;
  final String? title;
  final String? address;
  final double? accuracyM;
  final String? note;
  final bool? isMockLocation;
  final String? clientUuid;
  final String? clientTime;
  final bool? isOfflineSync;
  final int? queuedSeconds;
  final String? clientBootId;
  final Map<String, dynamic>? deviceInfo;

  const PositionDeclarationRequestModel({
    required this.reasonId,
    required this.lat,
    required this.lng,
    this.photoTokens = const [],
    this.title,
    this.address,
    this.accuracyM,
    this.note,
    this.isMockLocation,
    this.clientUuid,
    this.clientTime,
    this.isOfflineSync,
    this.queuedSeconds,
    this.clientBootId,
    this.deviceInfo,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = {
      'reason_id': reasonId,
      'lat': lat,
      'lng': lng,
      'photo_tokens': photoTokens,
    };

    if (title != null && title!.trim().isNotEmpty) {
      map['title'] = title!.trim();
    }
    if (address != null && address!.trim().isNotEmpty) {
      map['address'] = address!.trim();
    }
    if (note != null && note!.trim().isNotEmpty) {
      map['note'] = note!.trim();
    }
    if (isMockLocation != null) {
      map['is_mock_location'] = isMockLocation;
    }
    if (clientUuid != null && clientUuid!.isNotEmpty) {
      map['client_uuid'] = clientUuid;
    }
    if (clientTime != null && clientTime!.isNotEmpty) {
      map['client_time'] = clientTime;
    }
    if (isOfflineSync == true) {
      map['is_offline_sync'] = true;
    }
    if (queuedSeconds != null) {
      map['queued_seconds'] = queuedSeconds;
    }
    if (clientBootId != null && clientBootId!.isNotEmpty) {
      map['client_boot_id'] = clientBootId;
    }
    if (accuracyM != null) {
      map['accuracy_m'] = accuracyM;
    }
    if (deviceInfo != null && deviceInfo!.isNotEmpty) {
      map['device_info'] = deviceInfo;
    }

    // 🔴 BẢO ĐẢM KHÔNG BAO GIỜ CÓ TRƯỜNG km_declared (§4.1)
    map.remove('km_declared');

    return map;
  }

  factory PositionDeclarationRequestModel.fromJson(Map<String, dynamic> json) {
    return PositionDeclarationRequestModel(
      reasonId: json['reason_id'] as int? ?? 0,
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      photoTokens: (json['photo_tokens'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      title: json['title']?.toString(),
      address: json['address']?.toString(),
      accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
      note: json['note']?.toString(),
      isMockLocation: json['is_mock_location'] as bool?,
      clientUuid: json['client_uuid']?.toString(),
      clientTime: json['client_time']?.toString(),
      isOfflineSync: json['is_offline_sync'] as bool?,
      queuedSeconds: json['queued_seconds'] as int?,
      clientBootId: json['client_boot_id']?.toString(),
      deviceInfo: json['device_info'] is Map<String, dynamic>
          ? json['device_info'] as Map<String, dynamic>
          : null,
    );
  }
}
