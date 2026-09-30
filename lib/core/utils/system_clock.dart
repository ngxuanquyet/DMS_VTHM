import 'package:uuid/uuid.dart';

/// Tiện ích quản lý đồng hồ đơn điệu (Monotonic Hardware Clock) và Boot ID
/// Tuân thủ quy chuẩn §9.1 SPEC-DONG-BO-OFFLINE & API-VIENG-THAM-MOBILE-2026-09-29
class SystemClock {
  SystemClock._();

  static const _uuid = Uuid();

  /// Định danh duy nhất của phiên khởi động thiết bị hiện tại (client_boot_id)
  static final String _bootId = _uuid.v4();

  /// Đồng hồ đơn điệu không bị ảnh hưởng bởi việc người dùng đổi giờ máy
  static final Stopwatch _monotonicStopwatch = Stopwatch()..start();

  /// Trả về Boot ID của phiên làm việc/khởi động hiện tại
  static String get bootId => _bootId;

  /// Giá trị mili-giây của đồng hồ đơn điệu tính từ lúc phiên khởi tạo
  static int get nowMonotonicMs => _monotonicStopwatch.elapsedMilliseconds;

  /// Tính toán số giây bản ghi đã nằm chờ trong hàng đợi ngoại tuyến (`queued_seconds`).
  ///
  /// Quy tắc §9.1:
  /// - Nếu [entryBootId] khác [bootId] hiện tại (thiết bị đã khởi động lại giữa chừng):
  ///   trả về `null` (RỖNG) để server nhận biết và không bịa ra mốc sai.
  /// - Nếu cùng bootId: trả về (nowMonotonicMs - createdElapsedMs) quy ra giây.
  static int? calculateQueuedSeconds({
    required int createdElapsedMs,
    required String entryBootId,
  }) {
    if (entryBootId != _bootId) {
      // Máy đã khởi động lại giữa chừng (§9.1 luật ②) -> gửi rỗng
      return null;
    }

    final diffMs = nowMonotonicMs - createdElapsedMs;
    if (diffMs < 0) return 0;
    return diffMs ~/ 1000;
  }
}
