/// Tiện ích xử lý chuỗi và bỏ dấu tiếng Việt phục vụ tìm kiếm offline (§7.4 SPEC-DONG-BO-OFFLINE).
class StringUtils {
  static const _vietnameseDiacriticsMap = {
    'a': 'áàảãạăắằẳẵặâấầẩẫậ',
    'A': 'ÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬ',
    'd': 'đ',
    'D': 'Đ',
    'e': 'éèẻẽẹêếềểễệ',
    'E': 'ÉÈẺẼẸÊẾỀỂỄỆ',
    'i': 'íìỉĩị',
    'I': 'ÍÌỈĨỊ',
    'o': 'óòỏõọôốồổỗộơớờởỡợ',
    'O': 'ÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢ',
    'u': 'úùủũụưứừửữự',
    'U': 'ÚÙỦŨỤƯỨỪỬỮỰ',
    'y': 'ýỳỷỹỵ',
    'Y': 'ÝỲỶỸỴ',
  };

  /// Chuyển chuỗi tiếng Việt có dấu thành không dấu và chữ thường
  /// Ví dụ: "Nguyễn Văn Linh" -> "nguyen van linh"
  static String toUnaccentedLower(String? input) {
    if (input == null || input.trim().isEmpty) return '';

    String result = input;
    _vietnameseDiacriticsMap.forEach((replacement, chars) {
      for (int i = 0; i < chars.length; i++) {
        result = result.replaceAll(chars[i], replacement);
      }
    });

    return result.toLowerCase().trim();
  }

  /// Kiểm tra chuỗi [text] có chứa chuỗi tìm kiếm [query] sau khi loại bỏ dấu tiếng Việt
  static bool matchesSearch(String? text, String? query) {
    if (query == null || query.trim().isEmpty) return true;
    if (text == null || text.trim().isEmpty) return false;
    return toUnaccentedLower(text).contains(toUnaccentedLower(query));
  }
}
