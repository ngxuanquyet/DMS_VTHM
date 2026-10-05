import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'report_menu_bottom_sheet.dart';

/// Danh mục thao tác nhanh dạng card màu trên màn hình trang chủ
/// Thiết kế theo phong cách UI thẻ màu thanh lịch, tone màu nhạt (pastel) hiện đại:
/// - Cột trái:
///   + "Chấm công" (Tone vàng nhạt / soft amber) -> chuyển đến màn hình chấm công (/attendance)
///   + "Báo cáo" (Tone chàm nhạt / soft indigo) -> mở menu danh mục báo cáo & lịch sử (viếng thăm, chấm công, khai báo vị trí, nghi vấn gian lận)
/// - Cột phải:
///   + "Khai báo vị trí" (Tone xanh ngọc nhạt / soft teal) -> chuyển đến màn hình khai báo vị trí (/position-declaration)
///   + Dành sẵn vị trí cho ô thứ 4 sau này
class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cột trái: Chấm công (trên) & Báo cáo (dưới)
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QuickActionCard(
                title: 'Chấm công',
                icon: Icons.access_time_filled_rounded,
                backgroundColor: const Color(0xFFFEF3C7),
                foregroundColor: const Color(0xFFD97706),
                borderColor: const Color(0xFFFDE68A),
                onTap: () => context.push('/attendance'),
              ),
              const SizedBox(height: 14),
              _QuickActionCard(
                title: 'Báo cáo',
                icon: Icons.bar_chart_rounded,
                backgroundColor: const Color(0xFFEEF2FF),
                foregroundColor: const Color(0xFF4F46E5),
                borderColor: const Color(0xFFC7D2FE),
                onTap: () => showReportMenuBottomSheet(context),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),

        // Cột phải: Khai báo vị trí (trên), giữ nguyên chiều cao chuẩn dành sẵn chỗ cho ô thứ 4
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _QuickActionCard(
                title: 'Khai báo vị trí',
                icon: Icons.location_on_rounded,
                backgroundColor: const Color(0xFFCCFBF1),
                foregroundColor: const Color(0xFF0D9488),
                borderColor: const Color(0xFF99F6E4),
                onTap: () => context.push('/position-declaration'),
              ),
            ],
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

  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.onTap,
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
          onTap: onTap,
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
                // Icon góc trên trái
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
