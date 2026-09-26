import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/bottom_nav_bar.dart';

class FormsMenuItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int? badgeCount;

  const FormsMenuItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeCount,
  });
}

/// Circular Radial Floating Menu cho màn Biểu mẫu thị trường (FormsScreen)
/// Thiết kế, icon và hoạt ảnh đồng bộ 100% với RouteCircularMenu ở màn Tuyến
class FormsCircularMenu extends ConsumerStatefulWidget {
  final VoidCallback onSync;
  final VoidCallback onSendOfflineData;
  final int pendingOfflineCount;
  final bool isSyncing;

  const FormsCircularMenu({
    super.key,
    required this.onSync,
    required this.onSendOfflineData,
    this.pendingOfflineCount = 0,
    this.isSyncing = false,
  });

  @override
  ConsumerState<FormsCircularMenu> createState() => _FormsCircularMenuState();
}

class _FormsCircularMenuState extends ConsumerState<FormsCircularMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  late final Animation<double> _rotationAnimation;
  bool _isOpen = false;
  bool _wasTickerEnabled = true;
  bool _wasRouteCurrent = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.25).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    final routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;

    if (!tickerEnabled || !routeCurrent) {
      _closeImmediately();
    } else if (!_wasTickerEnabled || !_wasRouteCurrent) {
      _closeImmediately();
    }

    _wasTickerEnabled = tickerEnabled;
    _wasRouteCurrent = routeCurrent;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _close() {
    if (_isOpen) {
      setState(() {
        _isOpen = false;
        _controller.reverse();
      });
    }
  }

  void _closeImmediately() {
    if (_isOpen || _controller.value > 0) {
      if (mounted) {
        setState(() {
          _isOpen = false;
        });
      } else {
        _isOpen = false;
      }
      _controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(closeFloatingMenuProvider, (previous, next) {
      _closeImmediately();
    });
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = [
      FormsMenuItem(
        label: widget.pendingOfflineCount > 0
            ? 'Tải lên (${widget.pendingOfflineCount})'
            : 'Tải lên',
        icon: Icons.cloud_upload_rounded,
        color: const Color(0xFFEA580C), // Orange
        badgeCount: widget.pendingOfflineCount > 0
            ? widget.pendingOfflineCount
            : null,
        onTap: () {
          _close();
          widget.onSendOfflineData();
        },
      ),
      FormsMenuItem(
        label: widget.isSyncing ? 'Đang đồng bộ...' : 'Đồng bộ',
        icon: Icons.sync_rounded,
        color: const Color(0xFF10B981), // Emerald
        onTap: () {
          _close();
          widget.onSync();
        },
      ),
    ];

    return PopScope(
      canPop: !_isOpen,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isOpen) {
          _close();
        }
      },
      child: Stack(
        alignment: Alignment.bottomRight,
        clipBehavior: Clip.none,
        children: [
          // 1. Semi-transparent backdrop when open
          if (_isOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: AnimatedBuilder(
                  animation: _expandAnimation,
                  builder: (context, child) => Container(
                    color: Colors.black
                        .withValues(alpha: 0.35 * _expandAnimation.value),
                  ),
                ),
              ),
            ),

          // 2. Radial Circular Menu Items
          ...List.generate(items.length, (index) {
            return _buildRadialItem(
              item: items[index],
              index: index,
              totalItems: items.length,
              isDark: isDark,
            );
          }),

          // 3. Center Trigger Floating Action Button (Positioned at bottom: 88, right: 16)
          Positioned(
            bottom: 88,
            right: 16,
            child: _buildMainFab(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildRadialItem({
    required FormsMenuItem item,
    required int index,
    required int totalItems,
    required bool isDark,
  }) {
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final progress = _expandAnimation.value;
        if (progress <= 0.05) {
          return const SizedBox.shrink();
        }

        final int invertedIndex = (totalItems - 1) - index;
        const double verticalStep = 56.0;
        const double baseBottom = 158.0; // Vị trí ngay phía trên FAB chính (88 + 56 + 14)
        final double targetBottom =
            baseBottom + (invertedIndex * verticalStep);

        final double arcCurve =
            math.sin(invertedIndex / (totalItems - 1) * math.pi);
        final double targetRight = 21.0 + (arcCurve * 22.0);

        final double bottomPos = 93.0 + ((targetBottom - 93.0) * progress);
        final double rightPos = 21.0 + ((targetRight - 21.0) * progress);

        return Positioned(
          right: rightPos,
          bottom: bottomPos,
          child: Transform.scale(
            scale: progress,
            child: Opacity(
              opacity: progress.clamp(0.0, 1.0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: item.onTap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Text Label Pill
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.black12,
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.4 : 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        item.label,
                        style: AppTypography.labelSmall(
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ).copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),

                    // Circular Action Button
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: item.color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: item.color.withValues(alpha: 0.45),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              item.icon,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),

                        // Optional mini badge for pending count
                        if (item.badgeCount != null && item.badgeCount! > 0)
                          Positioned(
                            top: -3,
                            right: -3,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFDC2626), // Red
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Center(
                                child: Text(
                                  item.badgeCount! > 99
                                      ? '99+'
                                      : '${item.badgeCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Nút FAB chính: Màu sắc, kích thước, hiệu ứng xoay và icon Icons.widgets_rounded
  /// giống hệt 100% như ở màn Route (route_circular_menu.dart)
  Widget _buildMainFab(bool isDark) {
    final totalBadge = widget.pendingOfflineCount;
    final hasBadge = totalBadge > 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                Color(0xFF10B981), // Emerald
                Color(0xFF059669), // Dark Emerald
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.45),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _toggle,
              customBorder: const CircleBorder(),
              child: Center(
                child: RotationTransition(
                  turns: _rotationAnimation,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _isOpen ? Icons.close_rounded : Icons.widgets_rounded,
                      key: ValueKey<bool>(_isOpen),
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Red badge on main FAB if there are pending offline items or drafts
        if (!_isOpen && hasBadge)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Center(
                child: Text(
                  totalBadge > 99 ? '99+' : '$totalBadge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
