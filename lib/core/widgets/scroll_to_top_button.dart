import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Nút tròn mũi tên lên: hiện khi danh sách gắn [controller] đã cuộn quá [showAfter] px, bấm thì cuộn mượt về đầu.
///
/// Nơi gọi tự đặt vị trí (thường `Positioned` ngay trên nút nổi chính) — đặt TRƯỚC lớp menu tròn trong `Stack` để menu mở
/// ra phủ lên nút này.
class ScrollToTopButton extends StatefulWidget {
  final ScrollController controller;

  /// Nhãn cho trình đọc màn hình (`AppStrings.scrollToTop`).
  final String label;
  final double showAfter;

  const ScrollToTopButton({
    super.key,
    required this.controller,
    required this.label,
    this.showAfter = 400,
  });

  @override
  State<ScrollToTopButton> createState() => _ScrollToTopButtonState();
}

class _ScrollToTopButtonState extends State<ScrollToTopButton> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
    // Dựng lại khi danh sách đã cuộn sẵn (vd vừa tắt chế độ bản đồ) ⇒ tính trạng thái ngay, không chờ cú cuộn kế.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onScroll();
    });
  }

  @override
  void didUpdateWidget(ScrollToTopButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
    // Nơi gọi dựng lại thường là lúc danh sách bị THAY (tìm không ra ⇒ màn trống, đang tải): vị trí mới gắn vào ở 0 mà
    // không phát thông báo cuộn nào ⇒ tự tính lại sau khung hình, không thì nút cũ treo trên màn trống.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onScroll();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  /// Chỉ `setState` khi đổi trạng thái hiện/ẩn — không dựng lại theo từng khung hình cuộn.
  void _onScroll() {
    final c = widget.controller;
    final visible = c.hasClients && c.offset > widget.showAfter;
    if (visible != _visible) setState(() => _visible = visible);
  }

  void _scrollToTop() {
    final c = widget.controller;
    if (!c.hasClients) return;
    c.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      ignoring: !_visible,
      // Đang ẩn (thu về 0) thì gỡ hẳn khỏi cây trợ năng — không để trình đọc màn hình đọc một nút vô hình.
      child: ExcludeSemantics(
        excluding: !_visible,
        child: Semantics(
          button: true,
          label: widget.label,
          child: AnimatedScale(
            scale: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: Material(
              color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
              shape: const CircleBorder(),
              elevation: 0,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _scrollToTop,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkOutlineVariant
                          : AppColors.outlineVariant,
                    ),
                    boxShadow: AppShadows.level2,
                  ),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    size: 22,
                    color: isDark
                        ? AppColors.primaryFixedDim
                        : AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
