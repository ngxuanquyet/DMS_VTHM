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

    // Bổ sung loại bỏ các dấu thanh tổ hợp Unicode NFD (combining diacritics)
    result = result.replaceAll(RegExp(r'[\u0300\u0301\u0303\u0309\u0323\u02C6\u0306\u031B]'), '');

    return result.toLowerCase().trim();
  }

  /// Kiểm tra chuỗi [text] có chứa chuỗi tìm kiếm [query] sau khi loại bỏ dấu tiếng Việt
  static bool matchesSearch(String? text, String? query) {
    if (query == null || query.trim().isEmpty) return true;
    if (text == null || text.trim().isEmpty) return false;
    return toUnaccentedLower(text).contains(toUnaccentedLower(query));
  }

  /// Chuyển đổi các thông báo lỗi kỹ thuật (Dio, HTTP, Exception) thành câu từ thân thiện, dễ hiểu cho người dùng
  static String formatUserFriendlyError(dynamic error) {
    if (error == null) return 'Đã xảy ra lỗi không xác định.';
    final str = error.toString().trim();
    if (str.isEmpty) return 'Đã xảy ra lỗi không xác định.';

    final lower = str.toLowerCase();

    // Lỗi mạng, mất kết nối, timeout
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection timed out') ||
        lower.contains('connection closed') ||
        lower.contains('connecttimeout') ||
        lower.contains('receivetimeout') ||
        lower.contains('sendtimeout') ||
        lower.contains('handshakeexception')) {
      return 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại kết nối mạng.';
    }

    // Lỗi máy chủ 500, 502, 503, 504
    if (lower.contains('500') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('504') ||
        lower.contains('internal server error') ||
        lower.contains('bad gateway') ||
        lower.contains('service unavailable')) {
      return 'Hệ thống đang bận hoặc gián đoạn. Vui lòng thử lại sau.';
    }

    // Lỗi phiên đăng nhập 401
    if (lower.contains('401') || lower.contains('unauthorized')) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }

    // Lỗi quyền hạn 403
    if (lower.contains('403') || lower.contains('forbidden')) {
      return 'Bạn không có quyền thực hiện thao tác này.';
    }

    // Loại bỏ các tiền tố lập trình
    var cleaned = str
        .replaceAll(RegExp(r'^(Exception|AppException|ServerException|DioException.*?:)\s*', caseSensitive: false), '')
        .trim();

    return cleaned.isNotEmpty ? cleaned : 'Đã xảy ra sự cố. Vui lòng thử lại sau.';
  }
}
