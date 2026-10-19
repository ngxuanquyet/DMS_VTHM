import '../errors/app_exceptions.dart';

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

  /// Chuyển đổi các thông báo lỗi kỹ thuật (Dio, HTTP, Exception) thành câu từ thân thiện, dễ hiểu cho người dùng kèm mã lỗi
  static String formatUserFriendlyError(dynamic error) {
    if (error == null) return 'Đã xảy ra lỗi không xác định.';
    final str = error.toString().trim();
    if (str.isEmpty) return 'Đã xảy ra lỗi không xác định.';

    // Trích xuất mã lỗi nếu có
    String? extractedCode;
    if (error is AppException) {
      extractedCode = error.displayErrorCode;
    }
    if (extractedCode == null || extractedCode.isEmpty) {
      final codeMatch = RegExp(r'\(Mã lỗi:\s*([^)]+)\)').firstMatch(str);
      if (codeMatch != null) {
        extractedCode = codeMatch.group(1)?.trim();
      } else {
        final legacyMatch = RegExp(r'\(code:\s*(\d+),\s*error_code:\s*([^)]+)\)').firstMatch(str);
        if (legacyMatch != null) {
          extractedCode = legacyMatch.group(2)?.trim();
        }
      }
    }

    final lower = str.toLowerCase();
    String friendlyMsg;

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
      friendlyMsg = 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại kết nối mạng.';
    } else if (lower.contains('500') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('504') ||
        lower.contains('internal server error') ||
        lower.contains('bad gateway') ||
        lower.contains('service unavailable')) {
      friendlyMsg = 'Hệ thống đang bận hoặc gián đoạn. Vui lòng thử lại sau.';
      extractedCode ??= lower.contains('500') ? 'HTTP-500' : 'HTTP-503';
    } else if (lower.contains('401') || lower.contains('unauthorized')) {
      friendlyMsg = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      extractedCode ??= 'UNAUTHORIZED';
    } else if (lower.contains('403') || lower.contains('forbidden')) {
      friendlyMsg = 'Bạn không có quyền thực hiện thao tác này.';
      extractedCode ??= 'FORBIDDEN';
    } else {
      var cleaned = str
          .replaceAll(RegExp(r'^(Exception|AppException|ServerException|DioException.*?:)\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'\(Mã lỗi:\s*[^)]+\)'), '')
          .replaceAll(RegExp(r'\(code:\s*\d+,\s*error_code:\s*[^)]+\)'), '')
          .trim();
      friendlyMsg = cleaned.isNotEmpty ? cleaned : 'Đã xảy ra sự cố. Vui lòng thử lại sau.';
    }

    if (extractedCode != null && extractedCode.isNotEmpty && !friendlyMsg.contains(extractedCode)) {
      return '$friendlyMsg (Mã lỗi: $extractedCode)';
    }
    return friendlyMsg;
  }
}
