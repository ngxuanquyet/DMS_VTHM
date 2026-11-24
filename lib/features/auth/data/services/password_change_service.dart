import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_api_service.dart';

/// Đổi mật khẩu bắt buộc (#25831): quản trị đặt lại mật khẩu ⇒ máy chủ chặn mọi API (403 `PASSWORD_CHANGE_REQUIRED`) tới
/// khi người dùng tự đổi.
class PasswordChangeService {
  final AuthApiService _api;
  final AuthRepository _repo;

  PasswordChangeService(this._api, this._repo);

  /// Đổi mật khẩu rồi làm mới token NGAY: máy chủ giữ phiên này (gửi kèm refresh token) nhưng chặn access token phát trước
  /// lần đổi — không làm mới thì lời gọi kế tiếp mới 401 rồi tự làm mới, chậm một nhịp. Làm mới hỏng thì để interceptor lo
  /// ở lời gọi sau (không coi là đổi hỏng — mật khẩu ĐÃ đổi). Lỗi của lần đổi (422 sai mật khẩu…) ném nguyên cho màn hình.
  Future<void> change({required String currentPassword, required String newPassword}) async {
    final prefs = await SharedPreferences.getInstance();
    await _api.changeOwnPassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      refreshToken: prefs.getString(AppConstants.keyRefreshToken),
    );
    try {
      await _repo.refreshToken();
    } catch (_) {}
    await persistFlag(false);
  }

  /// Ghi cờ `must_change_password` vào hồ sơ lưu trên máy — phiên khôi phục lúc mở app đọc hồ sơ này (không gọi `/auth/me`).
  static Future<void> persistFlag(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(AppConstants.keyUserData);
      if (raw == null) return;
      final map = jsonDecode(raw);
      if (map is! Map) return;
      if (map['must_change_password'] == value) return;
      map['must_change_password'] = value;
      await prefs.setString(AppConstants.keyUserData, jsonEncode(map));
    } catch (_) {}
  }
}
