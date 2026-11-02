import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

/// Đồng hồ hàng đợi ngoại tuyến (`queued_seconds`, `client_boot_id`) — §9.1 SPEC-DONG-BO-OFFLINE &
/// API-VIENG-THAM-MOBILE-2026-09-29. Server dựng giờ bấm thật = giờ nhận − `queued_seconds` cho check-in/check-out,
/// phiếu, khai báo vị trí, tạo điểm bán và chấm công.
///
/// 🔴 Nguồn là đồng hồ của MÁY qua kênh native `vn.vthmgroup.dms/clock` (#24618): Android `elapsedRealtime()`, iOS
/// `CLOCK_MONOTONIC` — tính từ lúc bật máy, đếm CẢ lúc máy ngủ sâu, không đổi khi tắt/mở app hay chỉnh giờ; `bootId`
/// là định danh LẦN KHỞI ĐỘNG máy. Bản cũ dùng `Stopwatch` của tiến trình Dart: không đếm lúc máy ngủ (đo thiếu) và
/// `bootId` sinh mỗi lần mở app (tắt app là `queued_seconds` rỗng).
///
/// Đọc native là bất đồng bộ, còn nơi ghi hàng đợi cần số ngay ⇒ NEO: lấy số của máy ở [init] / [refresh] (mở app,
/// app trở lại từ nền — gồm cả mở khoá màn hình — và đầu mỗi lượt đồng bộ), giữa hai lần neo cộng thêm bằng
/// `Stopwatch` (app đang chạy trước mặt người dùng thì máy không ngủ, nên khoảng này đo đúng).
///
/// Không có kênh native (test, nền tảng lạ) ⇒ rơi về hành vi cũ: `Stopwatch` + `bootId` theo tiến trình.
class SystemClock {
  SystemClock._();

  static const _channel = MethodChannel('vn.vthmgroup.dms/clock');
  static final Stopwatch _stopwatch = Stopwatch()..start();

  static String _bootId = 'proc:${const Uuid().v4()}';
  static int _anchorElapsedMs = 0;
  static int _anchorStopwatchMs = 0;
  static bool _native = false;
  static bool _observing = false;

  /// Định danh lần khởi động máy (`client_boot_id`) — mục nhập ở lần khởi động khác thì không so được khoảng chờ.
  static String get bootId => _bootId;

  /// Mili-giây của đồng hồ máy (từ lúc bật máy) — ghi vào `createdElapsed` lúc nhập hàng đợi.
  static int get nowMonotonicMs => _anchorElapsedMs + (_stopwatch.elapsedMilliseconds - _anchorStopwatchMs);

  /// Trần lùi của [monotonicMsAt]: lời gọi trực tuyến hỏng (quá giờ kết nối + nhận ≈ 30s) + tải ảnh qua mạng yếu trước
  /// đó. Trần kỹ thuật, không phải tham số: giờ tường có thể vừa bị chỉnh, nên không lùi xa hơn chừng này.
  static const _maxTapLagMs = 15 * 60 * 1000;

  /// Số đồng hồ máy tại LÚC BẤM [tapWallTime] — nơi nhập hàng đợi SAU một lần gửi trực tuyến hỏng (chờ quá giờ ~30s)
  /// phải ghi mốc lúc bấm, không phải lúc nhập: ghi lúc nhập thì `queued_seconds` thiếu đúng khoảng chờ đó và server
  /// dựng giờ bấm MUỘN hơn thật (chấm công thành đi muộn). Khoảng lùi đo bằng giờ tường, kẹp ở [_maxTapLagMs] (kẹp chứ
  /// không bỏ: chậm hơn trần vẫn bù được phần lớn).
  static int monotonicMsAt(DateTime? tapWallTime) {
    final now = nowMonotonicMs;
    if (tapWallTime == null) return now;
    final lag = DateTime.now().difference(tapWallTime).inMilliseconds;
    if (lag <= 0) return now;
    return now - (lag > _maxTapLagMs ? _maxTapLagMs : lag);
  }

  /// Neo đồng hồ máy lần đầu + theo dõi app trở lại từ nền. Gọi một lần ở `main()` TRƯỚC khi có mục nào vào hàng đợi.
  static Future<void> init() async {
    // Thử vài lần: lời gọi kênh đầu tiên lúc khởi động có thể chậm/lỗi tạm. Hỏng hẳn thì cả tiến trình dùng đồng hồ
    // tiến trình ([refresh] cố ý không chuyển nguồn giữa chừng) — ghi rõ ra nhật ký để còn lần ra.
    for (var i = 0; i < 3 && !_native; i++) {
      if (i > 0) await Future<void>.delayed(const Duration(milliseconds: 200));
      _native = await _anchor(adoptBootId: true);
    }
    if (!_native) debugPrint('[SystemClock] KHÔNG neo được đồng hồ máy — queued_seconds đo bằng đồng hồ tiến trình.');
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(_ResumeObserver());
    }
  }

  /// Neo lại theo đồng hồ máy — máy có thể đã ngủ kể từ lần neo trước (Stopwatch không đếm khoảng đó).
  ///
  /// CHỈ khi [init] đã neo được: chuyển nguồn giữa chừng (Stopwatch → máy) mà `bootId` giữ nguyên thì mục nhập trước đó
  /// mang số của Stopwatch bị trừ với số của máy ⇒ khoảng chờ bịa ra hàng giờ.
  static Future<void> refresh() async {
    if (_native) await _anchor(adoptBootId: false);
  }

  static Future<bool> _anchor({required bool adoptBootId}) async {
    try {
      final snap = await _channel.invokeMapMethod<String, dynamic>('snapshot');
      final elapsed = (snap?['elapsedMs'] as num?)?.toInt();
      if (elapsed == null) return false;
      _anchorElapsedMs = elapsed;
      _anchorStopwatchMs = _stopwatch.elapsedMilliseconds;
      final boot = snap?['bootId']?.toString();
      // Không đọc được định danh lần khởi động ⇒ đánh dấu riêng cho TIẾN TRÌNH này: không so được qua lần mở app sau
      // (rỗng — đúng luật), nhưng không bao giờ ghép nhầm hai lần khởi động máy.
      if (adoptBootId) _bootId = (boot != null && boot.isNotEmpty) ? boot : 'native-proc:${const Uuid().v4()}';
      return true;
    } catch (e) {
      debugPrint('[SystemClock] Không đọc được đồng hồ máy, dùng đồng hồ của tiến trình: $e');
      return false;
    }
  }

  /// Tính toán số giây bản ghi đã nằm chờ trong hàng đợi ngoại tuyến (`queued_seconds`).
  ///
  /// Quy tắc §9.1:
  /// - Nếu [entryBootId] khác [bootId] hiện tại (thiết bị đã khởi động lại giữa chừng):
  ///   trả về `null` (RỖNG) để server nhận biết và không bịa ra mốc sai.
  /// - Nếu cùng bootId: trả về (nowMonotonicMs - createdElapsedMs) quy ra giây.
  ///
  /// Nơi gửi nên `await` [refresh] trước (SyncService làm ở đầu mỗi lượt) để khoảng máy ngủ được tính.
  ///
  /// [wallFallbackCreatedAtMs]: CHỈ check-in/check-out viếng thăm truyền (giờ máy lúc bấm, ms). Khác lần khởi động thì
  /// tính theo GIỜ MÁY thay vì gửi rỗng — rỗng làm server ghi giờ vào/ra = lúc nhận, check-out đi sát check-in nên kẹt
  /// cổng "5 phút" và lượt treo (#24698 lỗi 4). Chủ hệ thống chốt 02/11/2026: dùng giờ máy, KHÔNG gắn cờ; server vẫn
  /// kẹp trần theo lần cuối máy online. Chấm công / khai báo vị trí KHÔNG truyền (giữ rỗng như cũ).
  static int? calculateQueuedSeconds({
    required int createdElapsedMs,
    required String entryBootId,
    int? wallFallbackCreatedAtMs,
  }) {
    if (entryBootId != _bootId) {
      if (wallFallbackCreatedAtMs != null) {
        final wallMs = DateTime.now().millisecondsSinceEpoch - wallFallbackCreatedAtMs;
        return wallMs < 0 ? 0 : wallMs ~/ 1000;
      }
      // Máy đã khởi động lại giữa chừng (§9.1 luật ②) -> gửi rỗng
      return null;
    }

    final diffMs = nowMonotonicMs - createdElapsedMs;
    if (diffMs < 0) return 0;
    return diffMs ~/ 1000;
  }

  /// Chỉ cho test: đưa về trạng thái chưa neo.
  @visibleForTesting
  static void resetForTest() {
    _bootId = 'proc:${const Uuid().v4()}';
    _anchorElapsedMs = 0;
    _anchorStopwatchMs = _stopwatch.elapsedMilliseconds;
    _native = false;
  }
}

/// Neo lại đồng hồ mỗi khi app trở lại từ nền (gồm mở khoá màn hình) — máy có thể đã ngủ trong lúc đó.
class _ResumeObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) SystemClock.refresh();
  }
}
