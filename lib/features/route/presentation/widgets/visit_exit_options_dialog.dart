import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Hộp thoại xác nhận khi người dùng muốn thoát màn hình check-in
/// Cung cấp 3 lựa chọn:
/// 1. Tạm rời (giữ trạng thái phiên, có thể quay lại bất kỳ lúc nào)
/// 2. Ở lại (tiếp tục làm việc)
/// 3. Hủy lượt (hủy phiên viếng thăm hiện tại)
class VisitExitOptionsDialog extends StatelessWidget {
  final String dealerName;
  final String visitStatusLabel;

  const VisitExitOptionsDialog({
    super.key,
    required this.dealerName,
    this.visitStatusLabel = 'Đang tiến hành',
  });

  /// Hiển thị hộp thoại và trả về lựa chọn: 'pause' | 'stay' | 'cancel' | null
  static Future<String?> show({
    required BuildContext context,
    required String dealerName,
    String visitStatusLabel = 'Đang tiến hành',
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => VisitExitOptionsDialog(
        dealerName: dealerName,
        visitStatusLabel: visitStatusLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dialogBg = isDark ? AppColors.darkSurfaceContainer : Colors.white;
    final primaryTextColor = isDark ? AppColors.darkOnSurface : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? AppColors.darkOnSurfaceVariant : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Header Row (Icon + Tiêu đề + Badge Điểm bán)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon biểu tượng tạm dừng (Pause Circle in rounded squircle)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF075985).withValues(alpha: 0.35)
                          : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF0369A1).withValues(alpha: 0.5)
                            : const Color(0xFFBAE6FD),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF0284C7),
                            width: 2.2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 2.8,
                              height: 11,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 3.2),
                            Container(
                              width: 2.8,
                              height: 11,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Tiêu đề & Tag điểm bán
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tạm rời điểm bán?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF075985).withValues(alpha: 0.3)
                                      : const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.circle,
                                      size: 6,
                                      color: Color(0xFF0284C7),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'Điểm: $dealerName',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0284C7),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              visitStatusLabel,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 2. Đoạn văn bản mô tả hướng dẫn
              Text(
                'Bạn đang có một lượt viếng thăm chưa hoàn tất. Vui lòng chọn cách xử lý:',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkOnSurfaceVariant : const Color(0xFF475569),
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 14),

              // 3. Khối lựa chọn 1: Tạm rời
              _buildOptionCard(
                context: context,
                isDark: isDark,
                action: 'pause',
                badgeBg: const Color(0xFF0284C7),
                icon: Icons.access_time_rounded,
                iconColor: Colors.white,
                borderColor: isDark
                    ? const Color(0xFF0369A1).withValues(alpha: 0.6)
                    : const Color(0xFFBAE6FD),
                cardBg: isDark
                    ? const Color(0xFF0C4A6E).withValues(alpha: 0.22)
                    : const Color(0xFFF0F9FF),
                title: '1. Tạm rời',
                titleColor: primaryTextColor,
                description:
                    'Lưu trạng thái viếng thăm. Có thể tiếp tục bất kỳ lúc nào mà không tạo lượt mới.',
                descriptionColor: secondaryTextColor,
              ),

              const SizedBox(height: 10),

              // 4. Khối lựa chọn 2: Ở lại
              _buildOptionCard(
                context: context,
                isDark: isDark,
                action: 'stay',
                badgeBg: const Color(0xFF10B981),
                icon: Icons.check_circle_outline_rounded,
                iconColor: Colors.white,
                borderColor: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
                cardBg: isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                    : const Color(0xFFF8FAFC),
                title: '2. Ở lại',
                titleColor: primaryTextColor,
                description: 'Đóng thông báo và tiếp tục làm việc tại điểm bán này.',
                descriptionColor: secondaryTextColor,
              ),

              const SizedBox(height: 10),

              // 5. Khối lựa chọn 3: Hủy lượt
              _buildOptionCard(
                context: context,
                isDark: isDark,
                action: 'cancel',
                badgeBg: isDark
                    ? const Color(0xFF881337).withValues(alpha: 0.4)
                    : const Color(0xFFFFE4E6),
                icon: Icons.delete_outline_rounded,
                iconColor: const Color(0xFFE11D48),
                borderColor: isDark
                    ? const Color(0xFFBE123C).withValues(alpha: 0.5)
                    : const Color(0xFFFECDD3),
                cardBg: isDark
                    ? const Color(0xFF881337).withValues(alpha: 0.2)
                    : const Color(0xFFFFF1F2),
                title: '3. Hủy lượt',
                titleColor: const Color(0xFFE11D48),
                description:
                    'Hủy hoàn toàn lượt check-in hiện tại. Dữ liệu chưa lưu sẽ bị xóa.',
                descriptionColor: secondaryTextColor,
              ),

              const SizedBox(height: 20),

              // 6. Hàng 2 nút hành động chính (Ở lại & TẠM RỜI)
              Row(
                children: [
                  // Nút "Ở lại"
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop('stay'),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Ở lại',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.darkOnSurface
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Nút "TẠM RỜI"
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop('pause'),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.logout_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'TẠM RỜI',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 7. Nút toàn chiều rộng "HỦY LƯỢT CHECK-IN"
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop('cancel'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    height: 46,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF881337).withValues(alpha: 0.15)
                          : const Color(0xFFFFF5F5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFFBE123C).withValues(alpha: 0.4)
                            : const Color(0xFFFECDD3),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.close_rounded,
                          color: Color(0xFFE11D48),
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'HỦY LƯỢT CHECK-IN',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE11D48),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Card từng lựa chọn (có thể nhấn trực tiếp)
  Widget _buildOptionCard({
    required BuildContext context,
    required bool isDark,
    required String action,
    required Color badgeBg,
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
    required Color cardBg,
    required String title,
    required Color titleColor,
    required String description,
    required Color descriptionColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(action),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(icon, color: iconColor, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: descriptionColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
