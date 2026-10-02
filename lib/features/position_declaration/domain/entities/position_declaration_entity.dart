/// Bản ghi Khai báo vị trí
/// Theo đặc tả API-KHAI-BAO-VI-TRI-MOBILE-2026-10-01.md
class PositionDeclarationEntity {
  final int? id; // ID máy chủ trả về (201)
  final String clientUuid; // UUID v4 sinh lúc bấm (idempotency key)
  final int reasonId;
  final String? reasonCode;
  final String? reasonName;
  final String? reasonColor;
  final double lat;
  final double lng;
  final double? accuracyM;
  final String? address;
  final String? title;
  final String? note;
  final List<String> photoTokens; // Danh sách 32-hex tokens đã tải lên
  final List<String> localPhotoPaths; // Danh sách đường dẫn file ảnh cục bộ trên máy
  final bool isMockLocation;
  final String clientTime; // ISO-8601 lúc bấm
  final String? declaredAt; // Mốc server ghi nhận (vd: "2026-10-01 10:27:49+07")
  final String? declaredDate; // Ngày server ghi nhận (vd: "2026-10-01")
  final String syncStatus; // 'synced' | 'pending' | 'error'
  final String? syncError;
  final int createdAtMs; // Timestamp cục bộ lúc tạo

  const PositionDeclarationEntity({
    this.id,
    required this.clientUuid,
    required this.reasonId,
    this.reasonCode,
    this.reasonName,
    this.reasonColor,
    required this.lat,
    required this.lng,
    this.accuracyM,
    this.address,
    this.title,
    this.note,
    this.photoTokens = const [],
    this.localPhotoPaths = const [],
    this.isMockLocation = false,
    required this.clientTime,
    this.declaredAt,
    this.declaredDate,
    this.syncStatus = 'pending',
    this.syncError,
    required this.createdAtMs,
  });

  bool get isSynced => syncStatus == 'synced';
  bool get isPending => syncStatus == 'pending';
  bool get hasError => syncStatus == 'error';

  String get reasonDisplay {
    if (reasonCode != null && reasonCode!.isNotEmpty && reasonName != null) {
      return '[$reasonCode] $reasonName';
    }
    return reasonName ?? 'Lý do #$reasonId';
  }

  PositionDeclarationEntity copyWith({
    int? id,
    String? clientUuid,
    int? reasonId,
    String? reasonCode,
    String? reasonName,
    String? reasonColor,
    double? lat,
    double? lng,
    double? accuracyM,
    String? address,
    String? title,
    String? note,
    List<String>? photoTokens,
    List<String>? localPhotoPaths,
    bool? isMockLocation,
    String? clientTime,
    String? declaredAt,
    String? declaredDate,
    String? syncStatus,
    String? syncError,
    bool clearSyncError = false,
    int? createdAtMs,
  }) {
    return PositionDeclarationEntity(
      id: id ?? this.id,
      clientUuid: clientUuid ?? this.clientUuid,
      reasonId: reasonId ?? this.reasonId,
      reasonCode: reasonCode ?? this.reasonCode,
      reasonName: reasonName ?? this.reasonName,
      reasonColor: reasonColor ?? this.reasonColor,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      accuracyM: accuracyM ?? this.accuracyM,
      address: address ?? this.address,
      title: title ?? this.title,
      note: note ?? this.note,
      photoTokens: photoTokens ?? this.photoTokens,
      localPhotoPaths: localPhotoPaths ?? this.localPhotoPaths,
      isMockLocation: isMockLocation ?? this.isMockLocation,
      clientTime: clientTime ?? this.clientTime,
      declaredAt: declaredAt ?? this.declaredAt,
      declaredDate: declaredDate ?? this.declaredDate,
      syncStatus: syncStatus ?? this.syncStatus,
      syncError: clearSyncError ? null : (syncError ?? this.syncError),
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }

  factory PositionDeclarationEntity.fromJson(Map<String, dynamic> json) {
    return PositionDeclarationEntity(
      id: json['id'] as int?,
      clientUuid: json['client_uuid']?.toString() ?? '',
      reasonId: json['reason_id'] as int? ?? 0,
      reasonCode: json['reason_code']?.toString(),
      reasonName: json['reason_name']?.toString(),
      reasonColor: json['reason_color']?.toString(),
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
      address: json['address']?.toString(),
      title: json['title']?.toString(),
      note: json['note']?.toString(),
      photoTokens: (json['photo_tokens'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      localPhotoPaths: (json['local_photo_paths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isMockLocation: json['is_mock_location'] == true,
      clientTime: json['client_time']?.toString() ?? '',
      declaredAt: json['declared_at']?.toString(),
      declaredDate: json['declared_date']?.toString(),
      syncStatus: json['sync_status']?.toString() ?? 'pending',
      syncError: json['sync_error']?.toString(),
      createdAtMs: json['created_at_ms'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'client_uuid': clientUuid,
    'reason_id': reasonId,
    'reason_code': reasonCode,
    'reason_name': reasonName,
    'reason_color': reasonColor,
    'lat': lat,
    'lng': lng,
    'accuracy_m': accuracyM,
    'address': address,
    'title': title,
    'note': note,
    'photo_tokens': photoTokens,
    'local_photo_paths': localPhotoPaths,
    'is_mock_location': isMockLocation,
    'client_time': clientTime,
    'declared_at': declaredAt,
    'declared_date': declaredDate,
    'sync_status': syncStatus,
    'sync_error': syncError,
    'created_at_ms': createdAtMs,
  };
}
