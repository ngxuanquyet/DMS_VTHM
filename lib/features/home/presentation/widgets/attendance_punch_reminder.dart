import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/localization/app_strings.dart';

/// Lớp phủ nhắc chấm công trên trang chủ khi hôm nay nhân viên chưa có lượt chấm nào:
/// nền tối phủ toàn màn hình, khoét sáng ô "Chấm công", robot (remind_att_punch.json) đứng bên phải vẫy tay sang
/// trái — đúng về phía ô — kèm hộp lời nhắc.
/// - Chỉ hiện MỘT lần trong một vòng đời app (biến tĩnh); mở app lần sau mà vẫn chưa chấm thì hiện lại.
/// - Nền tối CHẶN chạm xuyên và không tự đóng — chỉ đóng bằng "Để sau", hoặc vào chấm công bằng "Chấm công ngay" /
///   chạm thẳng vào ô đang sáng. Nút Back cũng không đóng.
class AttendancePunchReminder {
  AttendancePunchReminder._();

  static bool _shownThisLaunch = false;

  static bool get shownThisLaunch => _shownThisLaunch;

  /// Hiện lớp phủ bám theo ô có [targetKey]. Trả về false nếu ô chưa được vẽ/đang khuất (chưa hiện gì).
  static bool show({
    required BuildContext context,
    required GlobalKey targetKey,
    required AppStrings strings,
    required String userName,
    required VoidCallback onPunchNow,
  }) {
    if (_shownThisLaunch) return false;
    final box = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return false;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    // Ô đang bị cuộn khuất (một phần) thì chưa hiện — khoét sáng chỗ không thấy là vô nghĩa.
    if (rect.top < 0 || rect.bottom > MediaQuery.sizeOf(context).height) return false;

    _shownThisLaunch = true;
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, _, __) => _ReminderOverlay(
        targetKey: targetKey,
        initialRect: rect,
        strings: strings,
        userName: userName,
        onLater: () => Navigator.of(dialogContext).pop(),
        onPunchNow: () {
          Navigator.of(dialogContext).pop();
          onPunchNow();
        },
      ),
      transitionBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
    );
    return true;
  }
}

class _ReminderOverlay extends StatefulWidget {
  final GlobalKey targetKey;
  final Rect initialRect;
  final AppStrings strings;
  final String userName;
  final VoidCallback onLater;
  final VoidCallback onPunchNow;

  const _ReminderOverlay({
    required this.targetKey,
    required this.initialRect,
    required this.strings,
    required this.userName,
    required this.onLater,
    required this.onPunchNow,
  });

  @override
  State<_ReminderOverlay> createState() => _ReminderOverlayState();
}

class _ReminderOverlayState extends State<_ReminderOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  static const _amber = Color(0xFFD97706);
  static const _robotSize = 170.0;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  late Rect _lastRect = widget.initialRect;

  /// Đo lại vị trí ô mỗi khung hình — lúc mới vào app dashboard còn đang tải lại ngầm, lưới nút có thể xô đi khi
  /// lớp phủ đang mở; giữ toạ độ cũ thì lỗ sáng và vùng chạm lệch khỏi ô. Ô bị đẩy khuất màn hình thì giữ vị trí
  /// hợp lệ gần nhất (như điều kiện của `show()`).
  Rect _targetRect(double screenHeight) {
    final box = widget.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.attached && box.hasSize) {
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.top >= 0 && rect.bottom <= screenHeight) _lastRect = rect;
    }
    return _lastRect;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _pulse, builder: (context, _) => _buildOverlay(context));
  }

  Widget _buildOverlay(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hole = _targetRect(screen.height).inflate(6);

    // Robot đứng sát bên phải ô, tay trái (phía người xem) chạm mép ô; thân kéo xuống ngang đáy ô.
    final robotLeft = (hole.right - 18).clamp(0.0, screen.width - _robotSize);
    final robotTop = hole.bottom - _robotSize + 8;

    // Hộp lời nhắc nằm dưới ô; không đủ chỗ thì lên trên.
    const boxHeightEstimate = 190.0;
    final placeBelow = hole.bottom + 16 + boxHeightEstimate < screen.height - padding.bottom;

    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          // Nền tối khoét lỗ — nuốt mọi chạm, không đóng lớp phủ.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: CustomPaint(painter: _SpotlightPainter(hole: hole)),
            ),
          ),

          // Viền sáng nhịp thở quanh ô; chạm vào ô = đi chấm công.
          Positioned.fromRect(
            rect: hole,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onPunchNow,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _amber.withValues(alpha: 0.6 + 0.4 * _pulse.value), width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.25 + 0.35 * _pulse.value),
                      blurRadius: 12 + 14 * _pulse.value,
                      spreadRadius: 1 + 3 * _pulse.value,
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            left: robotLeft,
            top: robotTop,
            width: _robotSize,
            height: _robotSize,
            child: IgnorePointer(
              child: Lottie.asset('assets/animations/remind_att_punch.json', repeat: true, fit: BoxFit.contain),
            ),
          ),

          Positioned(
            left: 16,
            right: 16,
            top: placeBelow ? hole.bottom + 16 : null,
            bottom: placeBelow ? null : screen.height - hole.top + 16,
            child: Material(
              color: isDark ? const Color(0xFF1F2937) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.access_time_filled_rounded, color: _amber, size: 26),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.strings.punchReminderTitle(widget.userName),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.strings.punchReminderBody,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.4,
                        color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: widget.onLater, child: Text(widget.strings.punchReminderLater)),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: widget.onPunchNow,
                          icon: const Icon(Icons.fingerprint_rounded, size: 20),
                          label: Text(widget.strings.punchReminderPunchNow),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _amber,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect hole;

  _SpotlightPainter({required this.hole});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(20)));
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.72));
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.hole != hole;
}
