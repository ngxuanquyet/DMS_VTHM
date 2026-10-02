import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Danh mục thao tác nhanh dạng card màu trên màn hình trang chủ
/// Thiết kế theo phong cách UI thẻ màu nổi bật với icon góc trên-trái và nhãn đậm góc dưới-phải:
/// - "Chấm công" (Màu vàng cam) -> chuyển đến màn hình chấm công (/attendance)
/// - "Khai báo vị trí" (Màu xanh mòng két / teal) -> chuyển đến màn hình khai báo vị trí (/position-declaration)
class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Nút Chấm công
        Expanded(
          child: _QuickActionCard(
            title: 'Chấm công',
            icon: Icons.access_time_filled_rounded,
            backgroundColor: const Color(0xFFE59819),
            onTap: () => context.push('/attendance'),
          ),
        ),
        const SizedBox(width: 14),

        // Nút Khai báo vị trí
        Expanded(
          child: _QuickActionCard(
            title: 'Khai báo vị trí',
            icon: Icons.location_on_rounded,
            backgroundColor: const Color(0xFF1EA1A1),
            onTap: () => context.push('/position-declaration'),
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
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withValues(alpha: 0.35),
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
          splashColor: Colors.white.withValues(alpha: 0.25),
          highlightColor: Colors.white.withValues(alpha: 0.12),
          child: Container(
            height: 114,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Icon góc trên trái
                Icon(
                  icon,
                  color: Colors.white,
                  size: 34,
                ),

                // Nhãn góc dưới phải
                Align(
                  alignment: Alignment.bottomRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomRight,
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
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
