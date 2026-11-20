/// Luật số điện thoại của ô loại `phone` (form điểm bán + biểu mẫu thị trường) — CÙNG luật server
/// (`common/helpers/PhoneHelper::normalize` + phép kiểm của ô `phone`), một chỗ cho cả hai form.
class PhoneUtils {
  PhoneUtils._();

  /// Câu lỗi khi số đã chuẩn hoá không đúng dạng số Việt Nam.
  static const invalidMessage =
      'Số điện thoại không hợp lệ (di động 10 số đầu 03/05/07/08/09, cố định 11 số đầu 02)';

  static final RegExp _nonDigit = RegExp(r'\D+');
  static final RegExp _countryPrefix = RegExp(r'^(?:00|0)?84(?=\d{9,10}$)');
  static final RegExp _valid = RegExp(r'^0(?:[35789]\d{8}|2\d{9})$');

  /// Bỏ mọi ký tự không phải chữ số; tiền tố `84`/`084`/`0084` (kể cả `+84`) đổi về `0` khi phần còn lại dài 9–10 số.
  /// Không còn chữ số nào ⇒ `null`.
  static String? normalize(String? raw) {
    if (raw == null) return null;
    final digits = raw.replaceAll(_nonDigit, '');
    if (digits.isEmpty) return null;
    return digits.replaceFirst(_countryPrefix, '0');
  }

  /// Số ĐÃ chuẩn hoá có đúng dạng: di động 10 số đầu 03/05/07/08/09, cố định 11 số đầu 02.
  static bool isValidNormalized(String normalized) => _valid.hasMatch(normalized);

  /// Kiểm giá trị ô: rỗng (sau khi bỏ khoảng trắng) ⇒ `null` (bắt buộc do phép kiểm chung lo); có chữ mà chuẩn hoá xong
  /// không hợp lệ ⇒ [invalidMessage].
  static String? validate(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.trim().isEmpty) return null;
    final n = normalize(raw);
    return n != null && isValidNormalized(n) ? null : invalidMessage;
  }
}
