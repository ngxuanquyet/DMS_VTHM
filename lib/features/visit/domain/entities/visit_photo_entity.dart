import '../../../../core/constants/app_constants.dart';

class VisitPhotoEntity {
  final int id;
  final int? fileId;
  final String token;
  final String url;
  final String photoType;
  final String photoTypeLabel;
  final String photoTypeColor;
  final String? takenAt;
  final int sortOrder;
  final bool duplicate;
  final String? localPath;

  const VisitPhotoEntity({
    required this.id,
    this.fileId,
    required this.token,
    required this.url,
    this.photoType = 'other',
    this.photoTypeLabel = 'Khác',
    this.photoTypeColor = 'default',
    this.takenAt,
    this.sortOrder = 0,
    this.duplicate = false,
    this.localPath,
  });

  /// Đường dẫn xem ảnh công khai không cần Bearer token (§4.1 & §12)
  String get fullPublicUrl {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (token.isNotEmpty) {
      return '${AppConstants.baseUrl}/dms/visit-photos/public/$token';
    }
    if (url.startsWith('/')) {
      return '${AppConstants.baseUrl}$url';
    }
    return '${AppConstants.baseUrl}/$url';
  }

  factory VisitPhotoEntity.fromJson(Map<String, dynamic> json) {
    return VisitPhotoEntity(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      fileId: json['file_id'] is num
          ? (json['file_id'] as num).toInt()
          : int.tryParse(json['file_id']?.toString() ?? ''),
      token: json['token']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      photoType: json['photo_type']?.toString() ?? 'other',
      photoTypeLabel: json['photo_type_label']?.toString() ?? 'Ảnh chụp',
      photoTypeColor: json['photo_type_color']?.toString() ?? 'primary',
      takenAt: json['taken_at']?.toString(),
      sortOrder: json['sort_order'] is num
          ? (json['sort_order'] as num).toInt()
          : (int.tryParse(json['sort_order']?.toString() ?? '') ?? 0),
      duplicate: json['duplicate'] == true,
      localPath: json['local_path']?.toString(),
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
        'local_path': localPath,
      };

  VisitPhotoEntity copyWith({
    int? id,
    int? fileId,
    String? token,
    String? url,
    String? photoType,
    String? photoTypeLabel,
    String? photoTypeColor,
    String? takenAt,
    int? sortOrder,
    bool? duplicate,
    String? localPath,
  }) {
    return VisitPhotoEntity(
      id: id ?? this.id,
      fileId: fileId ?? this.fileId,
      token: token ?? this.token,
      url: url ?? this.url,
      photoType: photoType ?? this.photoType,
      photoTypeLabel: photoTypeLabel ?? this.photoTypeLabel,
      photoTypeColor: photoTypeColor ?? this.photoTypeColor,
      takenAt: takenAt ?? this.takenAt,
      sortOrder: sortOrder ?? this.sortOrder,
      duplicate: duplicate ?? this.duplicate,
      localPath: localPath ?? this.localPath,
    );
  }
}
