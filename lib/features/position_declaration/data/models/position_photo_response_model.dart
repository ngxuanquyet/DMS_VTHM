/// Phản hồi tải ảnh khai báo vị trí (POST /dms/position-photos)
/// Theo đặc tả §3 API-KHAI-BAO-VI-TRI-MOBILE-2026-10-01.md
class PositionPhotoResponseModel {
  final String token;
  final String name;
  final String ext;
  final int size;
  final String mime;
  final String url; // Đường dẫn xem công khai (vd: /dms/position-photos/public/token)

  const PositionPhotoResponseModel({
    required this.token,
    required this.name,
    required this.ext,
    required this.size,
    required this.mime,
    required this.url,
  });

  factory PositionPhotoResponseModel.fromJson(Map<String, dynamic> json) {
    return PositionPhotoResponseModel(
      token: json['token']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      ext: json['ext']?.toString() ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      mime: json['mime']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'name': name,
    'ext': ext,
    'size': size,
    'mime': mime,
    'url': url,
  };
}
