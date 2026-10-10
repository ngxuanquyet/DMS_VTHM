import 'package:dio/dio.dart';

/// Interceptor đã được vô hiệu hoá và loại bỏ mock data hoàn toàn.
/// Tất cả request trong dự án hiện được chuyển tiếp trực tiếp sang backend máy chủ thật.
class MockBackendInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    return handler.next(options);
  }
}
