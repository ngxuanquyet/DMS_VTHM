import '../../../../core/constants/app_constants.dart';

/// DTO phản hồi tải ảnh biểu mẫu thị trường từ API POST /dms/form-photos (§2)
/// Host: https://api-app.vthmgroup.vn
/// Phản hồi HTTP 201 Created:
/// {
///   "success": true,
///   "message": "Đã tải tệp lên.",
///   "data": {
///     "token": "b83a1130671e0b1f5b75592494186ea5",
///     "name": "bien-hieu.png",
///     "ext": "png",
///     "size": 70,
///     "mime": "image/png",
///     "url": "/dms/form-photos/public/b83a1130671e0b1f5b75592494186ea5"
///   }
/// }
class FormPhotoModel {
  final String token; // 32 ký tự hex
  final String name;
  final String ext;
  final int size;
  final String mime;
  final String url; // Đường dẫn tương đối do server trả về (§2 & §4.1)

  const FormPhotoModel({
    required this.token,
    required this.name,
    required this.ext,
    required this.size,
    required this.mime,
    required this.url,
  });

  factory FormPhotoModel.fromJson(Map<String, dynamic> json) {
    return FormPhotoModel(
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

  /// Đường dẫn tuyệt đối ghép với host API để hiển thị (§4.1)
  /// "Dùng chuỗi server trả về, đừng tự ghép từ token"
  String get fullUrl {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final cleanUrl = url.startsWith('/') ? url : '/$url';
    return '${AppConstants.baseUrl}$cleanUrl';
  }
}
