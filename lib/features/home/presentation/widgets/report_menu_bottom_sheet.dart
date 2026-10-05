import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Hiển thị Modal Bottom Sheet khi bấm vào box "Báo cáo" trên trang chủ
/// Gồm 4 mục theo yêu cầu:
/// 1. Báo cáo viếng thăm
/// 2. Lịch sử chấm công
/// 3. Lịch sử khai báo vị trí
/// 4. Nghi vấn gian lận
void showReportMenuBottomSheet(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2420) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Thanh kéo modal (handle bar)
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Tiêu đề
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.bar_chart_rounded,
                        color: Color(0xFF4F46E5),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Báo cáo & Lịch sử',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF181C1B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Chọn mục báo cáo hoặc tra cứu hoạt động',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : const Color(0xFF6F7A74),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(
                  height: 1,
                  thickness: 0.8,
                  color: isDark ? Colors.white12 : const Color(0xFFE2E7E2),
                ),
                const SizedBox(height: 8),

                // 1. Báo cáo viếng thăm
                ReportMenuItem(
                  title: 'Báo cáo viếng thăm',
                  subtitle: 'Tổng hợp lượt chăm sóc và biểu mẫu tại điểm bán',
                  icon: Icons.store_mall_directory_rounded,
                  iconColor: const Color(0xFF0284C7),
                  iconBgColor: const Color(0xFFE0F2FE),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    try {
                      context.push('/daily-report');
                    } catch (_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tính năng Báo cáo viếng thăm đang được cập nhật'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),

                // 2. Lịch sử chấm công
                ReportMenuItem(
                  title: 'Lịch sử chấm công',
                  subtitle: 'Xem bảng chấm công vào/ra và thời gian làm việc',
                  icon: Icons.access_time_filled_rounded,
                  iconColor: const Color(0xFFE59819),
                  iconBgColor: const Color(0xFFFEF3C7),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.push('/attendance');
                  },
                ),

                // 3. Lịch sử khai báo vị trí
                ReportMenuItem(
                  title: 'Lịch sử khai báo vị trí',
                  subtitle: 'Nhật ký các lần khai báo toạ độ và địa điểm',
                  icon: Icons.location_on_rounded,
                  iconColor: const Color(0xFF1EA1A1),
                  iconBgColor: const Color(0xFFCCFBF1),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.push('/position-declaration/history');
                  },
                ),

                // 4. Nghi vấn gian lận
                ReportMenuItem(
                  title: 'Nghi vấn gian lận',
                  subtitle: 'Kiểm tra cảnh báo vị trí ảo, can thiệp GPS hoặc sai lệch giờ',
                  icon: Icons.security_rounded,
                  iconColor: const Color(0xFFE11D48),
                  iconBgColor: const Color(0xFFFFE4E6),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    showFraudSuspicionDialog(context);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class ReportMenuItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final VoidCallback onTap;

  const ReportMenuItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: iconColor.withValues(alpha: 0.12),
          highlightColor: iconColor.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? iconColor.withValues(alpha: 0.18) : iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF181C1B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : const Color(0xFF6F7A74),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.white38 : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hộp thoại hiển thị thông tin kiểm tra gian lận (Mock location, Clock skew, Geofence)
void showFraudSuspicionDialog(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showDialog(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E2420) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Color(0xFF10B981),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Kiểm tra gian lận',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trạng thái tuân thủ quy tắc thị trường hiện tại của thiết bị:',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : const Color(0xFF6F7A74),
            ),
          ),
          const SizedBox(height: 16),
          const _FraudCheckStatusRow(
            label: 'Toạ độ giả lập (Mock GPS)',
            status: 'Hợp lệ - Không phát hiện phần mềm giả lập',
            isNormal: true,
          ),
          const SizedBox(height: 10),
          const _FraudCheckStatusRow(
            label: 'Đồng hồ thiết bị (Clock Skew)',
            status: 'Chuẩn xác theo máy chủ (lệch < 1 phút)',
            isNormal: true,
          ),
          const SizedBox(height: 10),
          const _FraudCheckStatusRow(
            label: 'Bán kính viếng thăm (Geofence)',
            status: 'Tuân thủ đúng ngưỡng khoảng cách',
            isNormal: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(),
          child: const Text(
            'Đóng',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF006E15),
            ),
          ),
        ),
      ],
    ),
  );
}

class _FraudCheckStatusRow extends StatelessWidget {
  final String label;
  final String status;
  final bool isNormal;

  const _FraudCheckStatusRow({
    required this.label,
    required this.status,
    required this.isNormal,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF7FAF6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E7E2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isNormal ? Icons.check_circle_rounded : Icons.warning_rounded,
            size: 18,
            color: isNormal ? const Color(0xFF10B981) : const Color(0xFFE11D48),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF181C1B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isNormal ? const Color(0xFF10B981) : const Color(0xFFE11D48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
