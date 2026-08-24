class AppException implements Exception {
  final String message;
  final int? statusCode;

  const AppException(this.message, [this.statusCode]);

  @override
  String toString() => 'AppException: $message (code: $statusCode)';
}

class NetworkException extends AppException {
  const NetworkException([String message = 'Không có kết nối mạng. Vui lòng kiểm tra lại.'])
      : super(message, null);
}

class ServerException extends AppException {
  const ServerException([super.message = 'Lỗi máy chủ. Vui lòng thử lại sau.', super.statusCode]);
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([String message = 'Phiên đăng nhập đã hết hạn.'])
      : super(message, 401);
}

class CacheException extends AppException {
  const CacheException([String message = 'Lỗi truy xuất bộ nhớ cục bộ.'])
      : super(message, null);
}
