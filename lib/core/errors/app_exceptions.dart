class AppException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final String? errorId;

  const AppException(this.message, [this.statusCode, this.code, this.errorId]);

  /// Chuỗi mã lỗi định danh chuẩn hóa để hiển thị trên UI, gửi cho quản trị viên tra cứu
  String? get displayErrorCode {
    if (errorId != null && errorId!.trim().isNotEmpty) {
      if (code != null && code!.trim().isNotEmpty && !errorId!.contains(code!)) {
        return '$errorId ($code)';
      }
      return errorId;
    }
    if (code != null && code!.trim().isNotEmpty) {
      if (statusCode != null && statusCode! > 0) {
        return '$code ($statusCode)';
      }
      return code;
    }
    if (statusCode != null && statusCode! > 0) {
      return 'HTTP-$statusCode';
    }
    return null;
  }

  /// Chuỗi thông báo thân thiện kèm mã lỗi định danh để hiển thị trên UI/SnackBar/Dialog
  String get userMessage {
    if (errorId != null && errorId!.isNotEmpty) {
      return '$message\n(Mã lỗi: $errorId)';
    }
    final errCode = displayErrorCode;
    if (errCode != null && errCode.isNotEmpty) {
      return '$message\n(Mã lỗi: $errCode)';
    }
    return message;
  }

  @override
  String toString() {
    if (errorId != null && errorId!.isNotEmpty) {
      return '$message (Mã lỗi: $errorId)';
    }
    final errCode = displayErrorCode;
    if (errCode != null && errCode.isNotEmpty) {
      return '$message (Mã lỗi: $errCode)';
    }
    return 'AppException: $message (code: $statusCode, error_code: $code)';
  }
}

/// Ngoại lệ khi tài khoản chưa được phân quyền truy cập app DMS (HTTP 403 DMS_APP_FORBIDDEN)
class DmsAppForbiddenException extends AppException {
  const DmsAppForbiddenException([
    String message = 'Tài khoản chưa được cấp quyền dùng app DMS. Vui lòng liên hệ quản lý.',
    String? errorId,
  ]) : super(message, 403, 'DMS_APP_FORBIDDEN', errorId);
}

class NetworkException extends AppException {
  const NetworkException([
    String message = 'Không có kết nối mạng. Vui lòng kiểm tra lại.',
    String? errorId,
  ]) : super(message, null, null, errorId);
}

class ServerException extends AppException {
  const ServerException([
    super.message = 'Lỗi máy chủ. Vui lòng thử lại sau.',
    super.statusCode,
    super.code,
    super.errorId,
  ]);
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([
    String message = 'Phiên đăng nhập đã hết hạn.',
    String? errorId,
  ]) : super(message, 401, null, errorId);
}

class CacheException extends AppException {
  const CacheException([
    String message = 'Lỗi truy xuất bộ nhớ cục bộ.',
    String? errorId,
  ]) : super(message, null, null, errorId);
}

