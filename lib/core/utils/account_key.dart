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
