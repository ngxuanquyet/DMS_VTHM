import 'dart:io';

import '../utils/offline_photo_store.dart';

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

/// [answers] có chỗ cho khoá ảnh [key] (ô ảnh có mặt; ô ma trận có `photos.<loại>`) — chỉ những khoá này mới tải ảnh + ghi
/// token; khoá còn lại là ảnh của ô đang ẩn / loại không chụp ảnh, bỏ qua (kể cả tệp đã mất — không làm hỏng cả phiếu).
bool hasPhotoSlot(Map<String, dynamic> answers, String key) {
  final m = splitMatrixPhotoKey(key);
  if (m == null) return answers.containsKey(key);
  final cur = answers[m.$1];
  return cur is Map && cur['photos'] is Map && (cur['photos'] as Map).containsKey(m.$2);
}

/// Ghi danh sách token ảnh (hoặc đường dẫn) vào câu trả lời theo KHOÁ ẢNH: khoá thường ⇒ `answers[key]`; khoá ma trận ⇒
/// `answers[<mã ô>]['photos'][<mã loại>]` (giữ nguyên `counts`).
///
/// CHỈ THAY danh sách đã có trong [answers] — `answers` (đã làm sạch: bỏ ô ẩn, loại không chụp ảnh) quyết ô nào được gửi,
/// `_local_photo_paths` chỉ là nguồn tệp. Dựng mới ô vắng mặt ⇒ ô đang ẩn sống lại với `counts` rỗng, server áp hiện trạng
/// SOS "ô trống = 0" ⇒ xoá trắng hiện trạng điểm bán (#24698 vòng 4, F1).
void applyPhotoList(Map<String, dynamic> answers, String key, List<String> list) {
  if (!hasPhotoSlot(answers, key)) return;
  final m = splitMatrixPhotoKey(key);
  if (m == null) {
    answers[key] = list;
    return;
  }
  final value = Map<String, dynamic>.from(answers[m.$1] as Map);
  final photos = Map<String, dynamic>.from(value['photos'] as Map);
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

const _congKhai = '/crm/customer-photos/public/';
const _duoiAnh = {'.jpg', '.jpeg', '.png', '.heic', '.heif', '.webp', '.gif', '.bmp'};

/// Chuỗi là ĐƯỜNG DẪN ẢNH trên máy (ô ảnh của form điểm bán: ô chụp ảnh tự khai, #24792) — đường tuyệt đối / `file://`, đuôi
/// ảnh. Đuôi ảnh để giá trị ô chọn / ô chữ (không bao giờ là đường dẫn ảnh) không bị đem đi tải lên.
bool isLocalPhotoPath(String s) {
  final t = s.trim().toLowerCase();
  if (t.contains(_congKhai) || !(t.startsWith('/') || t.startsWith('file://'))) return false;
  return _duoiAnh.any(t.endsWith);
}

/// Đổi ảnh TRÊN MÁY trong giá trị một ô điểm bán ra token bằng [upload]: ô ma trận (`photos.<loại>`, mọi mục chưa là token),
/// ô ảnh (danh sách / chuỗi đường dẫn ảnh — [isLocalPhotoPath]). Token giữ nguyên; đường xem công khai
/// `/crm/customer-photos/public/<token>` quy về token. [upload] trả `null` ⇒ giữ đường dẫn (server sẽ báo lỗi — không lặng lẽ
/// bỏ ảnh). Giá trị khác ⇒ trả nguyên.
Future<dynamic> resolveLocalPhotos(dynamic value, Future<String?> Function(String path) upload) async {
  String? token(String s) {
    final i = s.indexOf(_congKhai);
    final t = i >= 0 ? s.substring(i + _congKhai.length) : s;
    return isUploadedPhotoToken(t) ? t : null;
  }

  if (value is Map && value['photos'] is Map) {
    final photos = <String, dynamic>{};
    for (final e in (value['photos'] as Map).entries) {
      final list = <String>[];
      for (final item in (e.value is List ? e.value as List : const [])) {
        final s = item.toString().trim();
        if (s.isEmpty) continue;
        list.add(token(s) ?? await upload(OfflinePhotoStore.toFilePath(s)) ?? s);
      }
      if (list.isNotEmpty) photos['${e.key}'] = list;
    }
    return Map<String, dynamic>.from(value)..['photos'] = photos;
  }
  if (value is String) {
    if (value.contains(_congKhai)) return token(value.trim()) ?? value;
    // Ô ảnh một chuỗi ⇒ gửi DANH SÁCH token (server nhận ô ảnh dạng mảng).
    return isLocalPhotoPath(value) ? [await upload(OfflinePhotoStore.toFilePath(value.trim())) ?? value] : value;
  }
  if (value is List && value.any((x) => x is String && (isLocalPhotoPath(x) || x.contains(_congKhai)))) {
    return [
      for (final x in value)
        if (x is String && x.contains(_congKhai))
          token(x.trim()) ?? x
        else if (x is String && isLocalPhotoPath(x))
          await upload(OfflinePhotoStore.toFilePath(x.trim())) ?? x
        else
          x,
    ];
  }
  return value;
}

/// Đường dẫn ảnh TRÊN MÁY (chưa là token) trong giá trị một ô điểm bán: ảnh ô ma trận, ô ảnh ([isLocalPhotoPath]).
List<String> localPhotoPathsOf(dynamic value) => [
      for (final s in matrixPhotoStrings(value))
        if (!isUploadedPhotoToken(s) && !s.contains(_congKhai)) s,
      if (value is String && isLocalPhotoPath(value)) value,
      if (value is List) ...value.whereType<String>().where(isLocalPhotoPath),
    ];

/// Xoá các bản chép ảnh trong thư mục ảnh ngoại tuyến của điểm bán (bỏ qua tệp ngoài thư mục đó / đã mất).
Future<void> deleteOfflineCustomerPhotos(List<String> paths) async {
  for (final p in paths) {
    if (!p.contains('offline_customer_photos')) continue;
    try {
      final f = File(OfflinePhotoStore.toFilePath(p));
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
