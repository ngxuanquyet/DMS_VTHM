import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_typography.dart';

class CircularMenuItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int? badgeCount;
  final bool isActive;

  const CircularMenuItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeCount,
    this.isActive = false,
  });
}

/// Circular Radial Floating Menu cho màn Tuyến (RouteScreen)
class RouteCircularMenu extends StatefulWidget {
  final VoidCallback onSortByDistance;
  final VoidCallback onSync;
  final VoidCallback onSendOfflineData;
  final VoidCallback onAddCustomer;
  final VoidCallback onRefreshGps;
  final bool isSortedByDistance;
  final int pendingOfflineCount;
  final bool isSyncing;

  const RouteCircularMenu({
    super.key,
    required this.onSortByDistance,
    required this.onSync,
    required this.onSendOfflineData,
    required this.onAddCustomer,
    required this.onRefreshGps,
    this.isSortedByDistance = false,
    this.pendingOfflineCount = 0,
    this.isSyncing = false,
  });

  @override
  State<RouteCircularMenu> createState() => _RouteCircularMenuState();
}

class _RouteCircularMenuState extends State<RouteCircularMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  late final Animation<double> _rotationAnimation;
  bool _isOpen = false;

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = [
      CircularMenuItem(
        label: 'Thêm điểm bán',
        icon: Icons.person_add_alt_1_rounded,
        color: const Color(0xFF8B5CF6), // Purple
        onTap: () {
          _close();
          widget.onAddCustomer();
        },
      ),
      CircularMenuItem(
        label: widget.pendingOfflineCount > 0
            ? 'Gửi offline (${widget.pendingOfflineCount})'
            : 'Gửi dữ liệu',
        icon: Icons.cloud_upload_rounded,
        color: const Color(0xFFEA580C), // Orange
        badgeCount: widget.pendingOfflineCount > 0 ? widget.pendingOfflineCount : null,
        onTap: () {
          _close();
          widget.onSendOfflineData();
        },
      ),
      CircularMenuItem(
        label: widget.isSyncing ? 'Đang đồng bộ...' : 'Đồng bộ tuyến',
        icon: Icons.sync_rounded,
        color: const Color(0xFF10B981), // Emerald
        onTap: () {
          _close();
          widget.onSync();
        },
      ),
      CircularMenuItem(
        label: widget.isSortedByDistance ? 'Hủy xếp cự ly' : 'Sắp xếp cự ly',
        icon: Icons.near_me_rounded,
        color: widget.isSortedByDistance ? const Color(0xFF0284C7) : const Color(0xFF64748B),
        isActive: widget.isSortedByDistance,
        onTap: () {
          _close();
          widget.onSortByDistance();
        },
      ),
      CircularMenuItem(
        label: 'Định vị GPS',
        icon: Icons.my_location_rounded,
        color: const Color(0xFF2563EB), // Blue
        onTap: () {
          _close();
          widget.onRefreshGps();
        },
      ),
    ];

    return Stack(
      alignment: Alignment.bottomRight,
      clipBehavior: Clip.none,
      children: [
        // 1. Semi-transparent backdrop when open (click anywhere to close)
        if (_isOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: AnimatedBuilder(
                animation: _expandAnimation,
                builder: (context, child) => Container(
                  color: Colors.black.withValues(alpha: 0.35 * _expandAnimation.value),
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

        // 3. Center Trigger Floating Action Button
        Positioned(
          bottom: 88,
          right: 16,
          child: _buildMainFab(isDark),
        ),
      ],
    );
  }

  Widget _buildRadialItem({
    required CircularMenuItem item,
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

        // Bố trí các nút theo hình cung quạt (radial arc) với khoảng cách dọc đều đặn
        // Đặt baseBottom = 158.0 (88 + 56 + 14) để nổi hoàn toàn phía trên thanh Bottom Nav Bar
        final int invertedIndex = (totalItems - 1) - index;
        const double verticalStep = 56.0;
        const double baseBottom = 158.0; // Vị trí ngay phía trên FAB chính (88 + 56 + 14)
        final double targetBottom = baseBottom + (invertedIndex * verticalStep);

        // Độ cong hình cung (arc) vươn sang trái ở các nút giữa
        final double arcCurve = math.sin(invertedIndex / (totalItems - 1) * math.pi);
        final double targetRight = 21.0 + (arcCurve * 22.0);

        // Hiệu ứng mở rộng từ FAB chính (bottom: 88 + 5 = 93) ra vị trí đích
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: item.isActive
                              ? item.color
                              : (isDark ? Colors.white24 : Colors.black12),
                          width: item.isActive ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        item.label,
                        style: AppTypography.labelSmall(
                          color: item.isActive
                              ? item.color
                              : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        ).copyWith(
                          fontWeight: item.isActive ? FontWeight.w700 : FontWeight.w600,
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
                            border: item.isActive
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
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
                                  item.badgeCount! > 99 ? '99+' : '${item.badgeCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
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

  Widget _buildMainFab(bool isDark) {
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

        // Red badge on main FAB if there are pending offline items
        if (!_isOpen && widget.pendingOfflineCount > 0)
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
                  widget.pendingOfflineCount > 99 ? '99+' : '${widget.pendingOfflineCount}',
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
