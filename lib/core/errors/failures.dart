abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure && runtimeType == other.runtimeType && message == other.message;

  @override
  int get hashCode => message.hashCode;
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Lỗi kết nối máy chủ']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Không có kết nối mạng']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Tài khoản hoặc mật khẩu không chính xác']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Lỗi lưu trữ dữ liệu']);
}
