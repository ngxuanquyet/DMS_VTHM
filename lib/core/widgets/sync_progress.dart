import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Thanh tiến trình ĐỒNG BỘ 0→100% theo BƯỚC — dùng chung cho mọi nút "Đồng bộ" (Trang chủ, Điểm bán, Tuyến, Biểu mẫu;
/// chủ hệ thống yêu cầu 10/11/2026). Hiện ở SnackBar nổi: tên bước đang chạy + % + thanh ngang; % tăng khi một bước XONG
/// (kể cả bước lỗi — lỗi vẫn do nơi gọi xử lý như trước). Không đoán % theo thời gian: thanh chỉ chạy khi việc thật chạy.
///
/// Cách dùng: `final p = SyncProgress.show(context, total: 3);` → mỗi bước `await p.step('Tải điểm bán', () => …)`
/// (bước bỏ qua theo điều kiện thì `p.skip()`) → `await p.finish()` trước khi hiện thông báo kết quả.
class SyncProgress {
  SyncProgress._(this._messenger, this.total);

  final ScaffoldMessengerState _messenger;

  /// Tổng số bước (≥ 1).
  final int total;

  final ValueNotifier<({int done, String label})> _state = ValueNotifier((done: 0, label: 'Đang đồng bộ'));

  /// Đã đóng ([finish] gọi lại — vd nhánh lỗi — không làm gì).
  bool _closed = false;

  /// Thanh CỦA MÌNH đã rời màn hình (bị snackbar khác — toast có mạng lại, lượt đồng bộ khác — đẩy đi). Khi đó [finish] KHÔNG
  /// được `hideCurrentSnackBar()`: snackbar đang hiện là của người khác.
  bool _gone = false;

  /// Mở thanh tiến trình (thay SnackBar đang hiện).
  static SyncProgress show(BuildContext context, {required int total}) {
    final messenger = ScaffoldMessenger.of(context);
    final p = SyncProgress._(messenger, math.max(1, total));
    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: ValueListenableBuilder<({int done, String label})>(
          valueListenable: p._state,
          builder: (_, s, __) => SyncProgressBar(done: s.done, total: p.total, label: s.label),
        ),
        backgroundColor: const Color(0xFF0284C7),
        behavior: SnackBarBehavior.floating,
        // Đóng bằng [finish]; trần dài để mạng yếu không làm thanh biến mất giữa chừng.
        duration: const Duration(minutes: 10),
      ),
    );
    controller.closed.then((_) => p._gone = true);
    return p;
  }

  /// Phần trăm hiện tại (0–100).
  int get percent => (_state.value.done * 100 / total).round();

  /// Chạy một bước: hiện [label], chờ [run] xong (thành công hay lỗi) rồi tăng %; lỗi ném tiếp cho nơi gọi.
  Future<T> step<T>(String label, Future<T> Function() run) async {
    if (!_closed) _state.value = (done: _state.value.done, label: label);
    try {
      return await run();
    } finally {
      _advance(label);
    }
  }

  /// Bước không cần làm lần này (vd ngoại tuyến) — vẫn tính vào % để thanh tới 100%.
  void skip() => _advance(_state.value.label);

  void _advance(String label) {
    if (_closed) return;
    _state.value = (done: math.min(total, _state.value.done + 1), label: label);
  }

  /// Về 100%, giữ một nhịp ngắn để người dùng thấy đã xong, rồi đóng. Gọi lại lần hai không làm gì.
  Future<void> finish() async {
    if (_closed) return;
    _closed = true;
    _state.value = (done: total, label: 'Hoàn tất');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!_gone) _messenger.hideCurrentSnackBar();
    _state.dispose();
  }
}

/// Nội dung thanh tiến trình: "tên bước … 40%" + thanh ngang. Tách riêng để test vẽ được.
class SyncProgressBar extends StatelessWidget {
  const SyncProgressBar({super.key, required this.done, required this.total, required this.label});

  final int done;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final value = total <= 0 ? 1.0 : (done / total).clamp(0.0, 1.0);
    final pct = (value * 100).round();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.sync_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label == 'Hoàn tất' ? label : '$label…',
                style: const TextStyle(color: Colors.white, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text('$pct%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: value),
            duration: const Duration(milliseconds: 250),
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 6,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
