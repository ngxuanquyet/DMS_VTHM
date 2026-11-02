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
  /// Request CÓ THỂ đã tới server (đã gửi xong mà quá giờ chờ phản hồi / đứt giữa chừng) — khác lỗi chưa kết nối được.
  /// Nơi ghi (check-in) cần biết để không coi bản ghi là "chắc chắn chưa có trên server" (#24698 lỗi 6).
  final bool mayHaveReachedServer;

  const NetworkException([
    String message = 'Không có kết nối mạng. Vui lòng kiểm tra lại.',
    String? errorId,
  ])  : mayHaveReachedServer = false,
        super(message, null, null, errorId);

  const NetworkException.maybeSent(String message, [String? errorId])
      : mayHaveReachedServer = true,
        super(message, null, null, errorId);
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


/// Máy chủ TỪ CHỐI HẲN yêu cầu (gửi lại y nguyên vẫn sai): 4xx, TRỪ lỗi của phiên đăng nhập (401, 403
/// `DMS_APP_FORBIDDEN` — đăng nhập lại là gửi được), 408 / 429 (tạm) và 409 (đã có trên server). Cùng luật phân loại của
/// hàng đợi đồng bộ (SyncService) — đường gửi trực tuyến dùng để quyết định "báo lỗi ngay" hay "xếp hàng gửi sau".
bool isPermanentRejection(Object e) {
  if (e is! AppException) return false;
  final c = e.statusCode;
  if (c == null || c < 400 || c >= 500) return false;
  if (c == 401 || c == 408 || c == 409 || c == 429) return false;
  return e.code != 'DMS_APP_FORBIDDEN';
}
