import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Mã định danh tài khoản đang đăng nhập, đọc từ hồ sơ lưu trong máy (`AppConstants.keyUserData`).
///
/// Dùng để TÁCH bộ nhớ đệm theo tài khoản: hai người dùng chung một máy thì người sau không được đọc dữ liệu đã tính
/// riêng cho người trước (vd biểu mẫu có giá trị "tự điền theo phòng ban"). Thứ tự ưu tiên: `id` → `username` → mã NV;
/// chưa đăng nhập ⇒ `'default'`.
String currentAccountKey(SharedPreferences prefs) {
  try {
    final userJson = prefs.getString(AppConstants.keyUserData);
    if (userJson != null && userJson.isNotEmpty) {
      final map = jsonDecode(userJson) as Map<String, dynamic>;
      final id = map['id']?.toString().trim();
      final username = map['username']?.toString().trim();
      final employeeCode = map['employee_code']?.toString().trim() ?? map['employeeId']?.toString().trim();
      if (id != null && id.isNotEmpty) return id;
      if (username != null && username.isNotEmpty) return username;
      if (employeeCode != null && employeeCode.isNotEmpty) return employeeCode;
    }
  } catch (_) {}
  return 'default';
}

/// Mã tài khoản để GẮN vào khoá bộ nhớ đệm; `null` khi chưa rõ tài khoản (đang đăng xuất / mất hồ sơ trong máy).
///
/// Bộ nhớ đệm theo tài khoản KHÔNG được đọc/ghi ở ngăn `'default'`: ngăn đó ai cũng rơi vào được, đọc nó là đọc dữ liệu
/// của một người không xác định. Lượt gọi kéo dài qua `await` mạng phải gọi lại hàm này SAU `await` và so với giá trị lúc
/// bắt đầu — khác ⇒ người dùng đã đổi (hoặc đã đăng xuất), kết quả là của người cũ, đừng ghi vào bộ nhớ hay bản lưu.
String? cacheAccountKey(SharedPreferences prefs) {
  final key = currentAccountKey(prefs);

  return key == 'default' ? null : key;
}

/// Khoá bộ nhớ đệm lịch sử chấm công của tài khoản đang đăng nhập; `null` khi chưa rõ tài khoản (đừng đọc/ghi).
///
/// Bản cũ dùng chung một khoá `dms_attendance_history_cache_v2` cho mọi tài khoản ⇒ người đăng nhập sau trên cùng máy
/// thấy giờ chấm công của người trước như thể của mình.
String? attendanceHistoryCacheKey(SharedPreferences prefs) {
  final account = cacheAccountKey(prefs);

  return account == null ? null : '${attendanceHistoryCachePrefix}_$account';
}

/// Tiền tố khoá lịch sử chấm công theo tài khoản — đăng xuất xoá theo tiền tố này.
const String attendanceHistoryCachePrefix = 'dms_attendance_history_cache_v2';

/// Xoá các khoá bộ nhớ đệm DÙNG CHUNG kiểu cũ (trước khi tách theo tài khoản, 21/10/2026) — gọi mỗi lần khởi động, rẻ.
///
/// Bản cũ còn nằm trong máy thì dữ liệu của người dùng trước (tuyến được giao, biểu mẫu có tự điền theo phòng ban) ở lại
/// vô thời hạn trên máy dùng chung, dù không code nào đọc nữa. Khoá mới luôn có mã tài khoản sau tiền tố nên không trùng:
/// biểu mẫu thị trường cũ là `dms_market_forms_<kind>_<khách>`, mới là `dms_market_forms_<tk>_<kind>_<khách>`.
Future<void> removeLegacySharedCaches(SharedPreferences prefs) async {
  const exact = [
    'cached_customer_form_schema',
    'cached_customer_meta',
    'dms_route_customers_cache_v1',
    // Chấm công: lịch sử dùng chung mọi tài khoản + phiên "đang làm việc" và lịch sử của bản cũ (không kiểm ngày ⇒
    // Trang chủ hiện giờ vào cũ mãi mãi).
    attendanceHistoryCachePrefix,
    'att_mobile_history_cache',
    'dms_local_attendance_session_v1',
    'dms_local_attendance_history_v1',
  ];
  final oldForms = RegExp(r'^dms_market_forms_(survey|collect)_-?\d+$');
  for (final k in prefs.getKeys().toList()) {
    if (exact.contains(k) || oldForms.hasMatch(k)) {
      await prefs.remove(k);
    }
  }
}
