import 'dart:async';

/// Kết quả các lời gọi API trong MỘT lượt làm mới (kéo xuống làm mới) — để báo "làm mới thành công" cho đúng.
///
/// App offline-first: repository bắt lỗi server rồi trả dữ liệu trong máy, nên màn hình không biết lượt làm mới có tới
/// được server không. [track] chạy lượt làm mới trong một Zone riêng; [ApiClient] ghi nhận từng lời gọi phát ra trong
/// Zone đó ([record]) — kể cả lời gọi nằm sâu trong repository đã nuốt lỗi.
class RefreshOutcome {
  /// Số lời gọi lấy được dữ liệu (2xx).
  int reached = 0;

  /// Số lời gọi KHÔNG lấy được dữ liệu: mất mạng, quá giờ, mọi phản hồi lỗi (401 hết phiên, 403, 404, 5xx…).
  int failed = 0;

  static const _zoneKey = #vthmRefreshOutcome;

  /// Chạy [body] và đếm các lời gọi API nó phát ra.
  static Future<RefreshOutcome> track(Future<void> Function() body) async {
    final outcome = RefreshOutcome();
    await runZoned(body, zoneValues: {_zoneKey: outcome});
    return outcome;
  }

  /// Chạy [body] mà KHÔNG tính các lời gọi của nó vào lượt làm mới bao ngoài — vd đẩy hàng đợi đồng bộ (gửi ảnh, lượt
  /// check-in): một mục gửi hỏng không có nghĩa là làm mới dữ liệu hỏng.
  static Future<T> untracked<T>(Future<T> Function() body) => runZoned(body, zoneValues: {_zoneKey: null});

  /// [ApiClient] gọi sau mỗi lời gọi — ngoài lượt làm mới đang theo dõi thì không làm gì.
  static void record({required bool reachedServer}) {
    final outcome = Zone.current[_zoneKey];
    if (outcome is! RefreshOutcome) return;
    if (reachedServer) {
      outcome.reached++;
    } else {
      outcome.failed++;
    }
  }
}
