import 'dart:io';

/// Khoá ảnh của MỘT loại trưng bày trong ô Ma trận trưng bày (#24767): `<mã ô>::<mã loại>`.
///
/// Dùng chung giữa màn điền biểu mẫu (bộ chụp/tải ảnh theo khoá) và hàng đợi ngoại tuyến (`_local_photo_paths` — tải ảnh
/// lên rồi ghi token vào `answers[<mã ô>]['photos'][<mã loại>]`). Mã ô/mã loại chỉ gồm `a-z0-9_` nên `::` không thể trùng.
const String kMatrixPhotoSep = '::';

/// Khoá ảnh của loại [type] trong ô ma trận [code].
String matrixPhotoKey(String code, String type) => '$code$kMatrixPhotoSep$type';

/// Tách khoá ảnh ma trận thành (mã ô, mã loại); khoá thường (ô ảnh) ⇒ `null`.
(String, String)? splitMatrixPhotoKey(String key) {
  final i = key.indexOf(kMatrixPhotoSep);
  if (i <= 0) return null;
  return (key.substring(0, i), key.substring(i + kMatrixPhotoSep.length));
}

/// Chuỗi ảnh là TOKEN đã tải lên (32 hex), không phải đường dẫn trên máy.
bool isUploadedPhotoToken(String s) => s.length == 32 && !s.contains('/') && !s.contains(r'\');

/// Ghi danh sách token ảnh (hoặc đường dẫn) vào câu trả lời theo KHOÁ ẢNH: khoá thường ⇒ `answers[key]`; khoá ma trận ⇒
/// `answers[<mã ô>]['photos'][<mã loại>]` (giữ nguyên `counts`).
void applyPhotoList(Map<String, dynamic> answers, String key, List<String> list) {
  final m = splitMatrixPhotoKey(key);
  if (m == null) {
    answers[key] = list;
    return;
  }
  final cur = answers[m.$1];
  final value = cur is Map ? Map<String, dynamic>.from(cur) : <String, dynamic>{'counts': <String, dynamic>{}};
  final photos = value['photos'] is Map ? Map<String, dynamic>.from(value['photos'] as Map) : <String, dynamic>{};
  photos[m.$2] = list;
  value['photos'] = photos;
  answers[m.$1] = value;
}

/// Mọi chuỗi ảnh (token / đường dẫn) nằm trong `photos` của một giá trị ô ma trận; giá trị khác ⇒ rỗng.
Iterable<String> matrixPhotoStrings(dynamic value) sync* {
  final photos = value is Map ? value['photos'] : null;
  if (photos is! Map) return;
  for (final list in photos.values) {
    if (list is List) {
      for (final item in list) {
        yield item.toString();
      }
    }
  }
}

/// Đổi ảnh TRÊN MÁY trong `photos` của một giá trị ô ma trận ra token bằng [upload] (giữ token sẵn có; đường xem công khai
/// `/crm/customer-photos/public/<token>` quy về token). [upload] trả `null` ⇒ giữ đường dẫn (server sẽ báo lỗi — không lặng lẽ
/// bỏ ảnh). Giá trị không phải ô ma trận ⇒ trả nguyên.
Future<dynamic> resolveMatrixPhotos(dynamic value, Future<String?> Function(String path) upload) async {
  if (value is! Map || value['photos'] is! Map) return value;
  const congKhai = '/crm/customer-photos/public/';
  final photos = <String, dynamic>{};
  for (final e in (value['photos'] as Map).entries) {
    final list = <String>[];
    for (final item in (e.value is List ? e.value as List : const [])) {
      var s = item.toString().trim();
      if (s.isEmpty) continue;
      final i = s.indexOf(congKhai);
      if (i >= 0) s = s.substring(i + congKhai.length);
      list.add(isUploadedPhotoToken(s) ? s : (await upload(s) ?? s));
    }
    if (list.isNotEmpty) photos['${e.key}'] = list;
  }
  return Map<String, dynamic>.from(value)..['photos'] = photos;
}

/// Đường dẫn ảnh TRÊN MÁY (chưa là token) của mọi ô ma trận trong [source] — ở gốc và trong `data`. Dùng để dọn bản chép lâu
/// dài sau khi điểm bán đã lên server.
List<String> matrixLocalPaths(Map source) {
  final out = <String>[];
  void quet(Map m) {
    for (final v in m.values) {
      for (final s in matrixPhotoStrings(v)) {
        if (!isUploadedPhotoToken(s) && !s.contains('/crm/customer-photos/public/')) out.add(s);
      }
    }
  }

  quet(source);
  if (source['data'] is Map) quet(source['data'] as Map);
  return out;
}

/// Xoá các bản chép ảnh ma trận trong thư mục ảnh ngoại tuyến của điểm bán (bỏ qua tệp ngoài thư mục đó / đã mất).
Future<void> deleteOfflineMatrixPhotos(List<String> paths) async {
  for (final p in paths) {
    if (!p.contains('offline_customer_photos')) continue;
    try {
      final f = File(p);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
