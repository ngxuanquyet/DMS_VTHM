import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/bottom_nav_bar.dart';
import '../../../customer/presentation/viewmodels/rejected_read_status_notifier.dart';

class CircularMenuItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int? badgeCount;
  final bool hasBadgeDot;
  final bool isActive;

  const CircularMenuItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeCount,
    this.hasBadgeDot = false,
    this.isActive = false,
  });
}

/// Circular Radial Floating Menu cho màn Tuyến (RouteScreen)
class RouteCircularMenu extends ConsumerStatefulWidget {
  final VoidCallback onSortByDistance;
  final VoidCallback onSync;
  final VoidCallback onSendOfflineData;
  final VoidCallback onAddCustomer;
  final VoidCallback onRefreshGps;
  final VoidCallback? onOpenRejected;
  final VoidCallback? onToggleMapView;
  final bool isSortedByDistance;
  final bool isMapView;
  final int pendingOfflineCount;
  final int? rejectedCount;
  final bool? hasUnreadRejected;
  final bool isSyncing;
  final double bottomOffset;

  const RouteCircularMenu({
    super.key,
    required this.onSortByDistance,
    required this.onSync,
    required this.onSendOfflineData,
    required this.onAddCustomer,
    required this.onRefreshGps,
    this.onOpenRejected,
    this.onToggleMapView,
    this.isSortedByDistance = false,
    this.isMapView = false,
    this.pendingOfflineCount = 0,
    this.rejectedCount,
    this.hasUnreadRejected,
    this.isSyncing = false,
    this.bottomOffset = 88.0,
  });

  @override
  ConsumerState<RouteCircularMenu> createState() => _RouteCircularMenuState();
}

class _RouteCircularMenuState extends ConsumerState<RouteCircularMenu>
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

    // Đóng menu ngay lập tức nếu tab bị ẩn (TickerMode tắt),
    // hoặc màn hình bị che bởi route khác,
    // hoặc khi quay lại màn hình này từ màn khác / tab khác.
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
    // Lắng nghe tín hiệu chuyển tab từ BottomNavBar để đóng ngay lập tức
    ref.listen<int>(closeFloatingMenuProvider, (previous, next) {
      _closeImmediately();
    });
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUnreadFromProvider = ref.watch(hasUnreadRejectedProvider);
    final unreadCountFromProvider = ref.watch(unreadRejectedCountProvider);
    final hasUnread = widget.hasUnreadRejected ??
        (widget.rejectedCount != null
            ? widget.rejectedCount! > 0
            : hasUnreadFromProvider);
    final unreadCount = widget.rejectedCount ?? unreadCountFromProvider;

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
      if (widget.onOpenRejected != null)
        CircularMenuItem(
          label: unreadCount > 0
              ? 'Bị từ chối ($unreadCount)'
              : 'Điểm bán bị từ chối',
          icon: Icons.cancel_outlined,
          color: const Color(0xFFDC2626), // Red
          hasBadgeDot: hasUnread,
          badgeCount: unreadCount > 0 ? unreadCount : null,
          onTap: () {
            _close();
            widget.onOpenRejected!();
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
      if (widget.onToggleMapView != null)
        CircularMenuItem(
          label: widget.isMapView ? 'Xem Danh sách' : 'Xem Bản đồ',
          icon: widget.isMapView
              ? Icons.format_list_bulleted_rounded
              : Icons.map_rounded,
          color: const Color(0xFF0D9488), // Teal
          isActive: widget.isMapView,
          onTap: () {
            _close();
            widget.onToggleMapView!();
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
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            bottom: widget.bottomOffset,
            right: 16,
            child: _buildMainFab(isDark, hasUnreadRejected: hasUnread),
          ),
        ],
      ),
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
        // Đặt baseBottom = widget.bottomOffset + 70.0 để nổi hoàn toàn phía trên FAB chính
        final int invertedIndex = (totalItems - 1) - index;
        final double verticalStep = totalItems > 5 ? 50.0 : 56.0;
        final double baseBottom = widget.bottomOffset + 70.0;
        final double targetBottom = baseBottom + (invertedIndex * verticalStep);

        // Độ cong hình cung (arc) vươn sang trái ở các nút giữa
        final double arcCurve = math.sin(invertedIndex / (totalItems - 1) * math.pi);
        final double targetRight = 21.0 + (arcCurve * 22.0);

        // Hiệu ứng mở rộng từ FAB chính ra vị trí đích
        final double fabCenterBottom = widget.bottomOffset + 5.0;
        final double bottomPos = fabCenterBottom + ((targetBottom - fabCenterBottom) * progress);
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

                        // Optional mini badge for pending count or unread dot
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
                          )
                        else if (item.hasBadgeDot)
                          Positioned(
                            top: -1,
                            right: -1,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
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

  Widget _buildMainFab(bool isDark, {required bool hasUnreadRejected}) {
    final showOfflineBadge = widget.pendingOfflineCount > 0;
    final showRedDot = !_isOpen && hasUnreadRejected && !showOfflineBadge;
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

        // Red badge for offline items OR red dot for unread rejected items
        if (!_isOpen && (showOfflineBadge || showRedDot))
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              padding: showOfflineBadge
                  ? const EdgeInsets.symmetric(horizontal: 5, vertical: 2)
                  : EdgeInsets.zero,
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: showOfflineBadge
                    ? BorderRadius.circular(10)
                    : BorderRadius.circular(5),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: BoxConstraints(
                minWidth: showOfflineBadge ? 18 : 10,
                minHeight: showOfflineBadge ? 18 : 10,
              ),
              child: showOfflineBadge
                  ? Center(
                      child: Text(
                        widget.pendingOfflineCount > 99
                            ? '99+'
                            : '${widget.pendingOfflineCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}
