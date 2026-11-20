import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'report_menu_bottom_sheet.dart';

/// Danh mục thao tác nhanh dạng card màu trên màn hình trang chủ — lưới 3 hàng × 2 ô, tone pastel:
/// - Hàng 1: "Chấm công" (vàng nhạt, /attendance) · "Viếng thăm" (xanh ngọc nhạt, /routes)
/// - Hàng 2 (thêm 20/11/2026): "Thêm mới NPP" (tím nhạt — mở biểu mẫu thu thập cấu hình ở tham số server
///   `dms.form_home_npp_form`, mặc định Khảo sát NPP Mới VTHM) · "Thêm mới điểm bán" (xanh lá nhạt, /customers/add — màn chứa mở)
/// - Hàng 3: "Báo cáo" (chàm nhạt, menu báo cáo) · "Đồng bộ" (xanh da trời nhạt, đồng bộ dữ liệu)
class HomeQuickActions extends StatelessWidget {
  final bool isSyncing;
  final VoidCallback? onSync;
  final VoidCallback? onAttendanceReturn;

  /// Bấm "Thêm mới NPP" — màn chứa tìm biểu mẫu đã cấu hình rồi mở phiếu.
  final VoidCallback? onAddNpp;

  /// Bấm "Thêm mới điểm bán" — màn chứa mở /customers/add rồi nạp lại danh sách điểm bán.
  final VoidCallback? onAddOutlet;

  /// Đang tìm biểu mẫu của nút "Thêm mới NPP" (tải danh sách biểu mẫu có thể chờ mạng).
  final bool isOpeningNpp;

  /// Gắn vào ô "Chấm công" để lớp phủ nhắc chấm công khoét sáng đúng chỗ.
  final GlobalKey? attendanceKey;

  const HomeQuickActions({
    super.key,
    this.isSyncing = false,
    this.onSync,
    this.onAttendanceReturn,
    this.onAddNpp,
    this.onAddOutlet,
    this.isOpeningNpp = false,
    this.attendanceKey,
  });

  @override
  Widget build(BuildContext context) {
    Widget hang(Widget trai, Widget phai) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: trai), const SizedBox(width: 14), Expanded(child: phai)],
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        hang(
          _QuickActionCard(
            key: attendanceKey,
            title: 'Chấm công',
            icon: Icons.access_time_filled_rounded,
            backgroundColor: const Color(0xFFFEF3C7),
            foregroundColor: const Color(0xFFD97706),
            borderColor: const Color(0xFFFDE68A),
            onTap: () async {
              await context.push('/attendance');
              onAttendanceReturn?.call();
            },
          ),
          _QuickActionCard(
            title: 'Viếng thăm',
            icon: Icons.storefront_rounded,
            backgroundColor: const Color(0xFFCCFBF1),
            foregroundColor: const Color(0xFF0D9488),
            borderColor: const Color(0xFF99F6E4),
            onTap: () => context.go('/routes'),
          ),
        ),
        const SizedBox(height: 14),
        hang(
          _QuickActionCard(
            key: const ValueKey('home_add_npp'),
            title: 'Thêm mới NPP',
            icon: Icons.handshake_rounded,
            isLoading: isOpeningNpp,
            backgroundColor: const Color(0xFFF3E8FF),
            foregroundColor: const Color(0xFF9333EA),
            borderColor: const Color(0xFFE9D5FF),
            onTap: () => onAddNpp?.call(),
          ),
          _QuickActionCard(
            key: const ValueKey('home_add_outlet'),
            title: 'Thêm mới điểm bán',
            icon: Icons.add_business_rounded,
            backgroundColor: const Color(0xFFDCFCE7),
            foregroundColor: const Color(0xFF16A34A),
            borderColor: const Color(0xFFBBF7D0),
            onTap: () => onAddOutlet?.call(),
          ),
        ),
        const SizedBox(height: 14),
        hang(
          _QuickActionCard(
            title: 'Báo cáo',
            icon: Icons.bar_chart_rounded,
            backgroundColor: const Color(0xFFEEF2FF),
            foregroundColor: const Color(0xFF4F46E5),
            borderColor: const Color(0xFFC7D2FE),
            onTap: () => showReportMenuBottomSheet(context),
          ),
          _QuickActionCard(
            title: isSyncing ? 'Đang đồng bộ...' : 'Đồng bộ',
            icon: Icons.sync_rounded,
            isLoading: isSyncing,
            backgroundColor: const Color(0xFFE0F2FE),
            foregroundColor: const Color(0xFF0284C7),
            borderColor: const Color(0xFFBAE6FD),
            onTap: () {
              if (!isSyncing && onSync != null) {
                onSync!();
              }
            },
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final VoidCallback onTap;
  final bool isLoading;

  const _QuickActionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveBgColor = isDark
        ? foregroundColor.withValues(alpha: 0.16)
        : backgroundColor;
    final effectiveBorderColor = isDark
        ? foregroundColor.withValues(alpha: 0.32)
        : borderColor;
    final effectiveFgColor = isDark
        ? foregroundColor.withValues(alpha: 0.95)
        : foregroundColor;

    return Container(
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: effectiveBorderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: foregroundColor.withValues(alpha: isDark ? 0.05 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: foregroundColor.withValues(alpha: 0.18),
          highlightColor: foregroundColor.withValues(alpha: 0.08),
          child: Container(
            height: 114,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Icon góc trên trái (hoặc loading indicator)
                if (isLoading)
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.8,
                      valueColor: AlwaysStoppedAnimation<Color>(effectiveFgColor),
                    ),
                  )
                else
                  Icon(icon, color: effectiveFgColor, size: 34),

                // Nhãn góc dưới phải
                Align(
                  alignment: Alignment.bottomRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomRight,
                    child: Text(
                      title,
                      style: TextStyle(
                        color: effectiveFgColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
