import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Container tối ưu hiệu năng cao cho các branch Navigators của [StatefulShellRoute].
///
/// Sử dụng thuần túy [SlideTransition] (RenderTransform layer matrix) ở tầng phần cứng GPU,
/// TUYỆT ĐỐI KHÔNG dùng FadeTransition (saveLayerAlpha) và KHÔNG dùng AnimatedBuilder
/// để tránh ép GPU phải copy texture Native OpenGL (MapLibre bản đồ tuyến) gây giật lag.
class BranchAnimatedSlideContainer extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  const BranchAnimatedSlideContainer({
    super.key,
    required this.navigationShell,
    required this.children,
  });

  @override
  State<BranchAnimatedSlideContainer> createState() =>
      _BranchAnimatedSlideContainerState();
}

class _BranchAnimatedSlideContainerState
    extends State<BranchAnimatedSlideContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<Offset> _incomingSlideAnimation;
  late Animation<Offset> _outgoingSlideAnimation;

  int _currentIndex = 0;
  int _previousIndex = 0;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.navigationShell.currentIndex;
    _previousIndex = _currentIndex;

    // Thời gian trượt siêu mượt 240ms, phản hồi tức thì
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _setupAnimations(direction: 1.0);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _isAnimating = false;
            _previousIndex = _currentIndex;
          });
        }
      }
    });
  }

  void _setupAnimations({required double direction}) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );

    _incomingSlideAnimation = Tween<Offset>(
      begin: Offset(direction, 0.0),
      end: Offset.zero,
    ).animate(curve);

    _outgoingSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(-direction, 0.0),
    ).animate(curve);
  }

  @override
  void didUpdateWidget(covariant BranchAnimatedSlideContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newIndex = widget.navigationShell.currentIndex;
    if (newIndex != _currentIndex) {
      final direction = (newIndex > _currentIndex) ? 1.0 : -1.0;
      _previousIndex = _currentIndex;
      _currentIndex = newIndex;
      _setupAnimations(direction: direction);
      _isAnimating = true;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: List<Widget>.generate(widget.children.length, (index) {
          final isCurrent = index == _currentIndex;
          final isPrevious = index == _previousIndex && _isAnimating;

          // Các nhánh không hoạt động được ẩn bằng Offstage + TickerMode(disabled)
          // để giải phóng CPU nhưng vẫn giữ nguyên State (cuộn, vị trí bản đồ, input form)
          if (!isCurrent && !isPrevious) {
            return Offstage(
              offstage: true,
              child: TickerMode(
                enabled: false,
                child: widget.children[index],
              ),
            );
          }

          // Nhánh mới đang trượt vào: RenderTransform thuần ở GPU, không rebuild widget tree
          if (isCurrent && _isAnimating) {
            return SlideTransition(
              position: _incomingSlideAnimation,
              child: TickerMode(
                enabled: true,
                child: widget.children[index],
              ),
            );
          }

          // Nhánh cũ đang trượt ra
          if (isPrevious) {
            return SlideTransition(
              position: _outgoingSlideAnimation,
              child: TickerMode(
                enabled: false,
                child: widget.children[index],
              ),
            );
          }

          // Trạng thái nghỉ (chỉ hiển thị nhánh hiện tại)
          return Offstage(
            offstage: false,
            child: TickerMode(
              enabled: true,
              child: widget.children[index],
            ),
          );
        }),
      ),
    );
  }
}
