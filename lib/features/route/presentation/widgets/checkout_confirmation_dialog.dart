import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Hộp thoại xác nhận khi người dùng đã thỏa mãn mọi điều kiện và sẵn sàng check-out.
/// Hiển thị tóm tắt phiên viếng thăm (thời lượng, ảnh, khảo sát, vị trí GPS)
/// và cho phép người dùng xác nhận hoặc ở lại tiếp tục làm việc.
class CheckoutConfirmationDialog extends StatelessWidget {
  final String dealerName;
  final String durationText;
  final int photoCount;
  final int surveyCompletedCount;
  final int surveyTotalCount;
  final bool isClosed;
  final double? distanceMeters;

  const CheckoutConfirmationDialog({
    super.key,
    required this.dealerName,
    required this.durationText,
    required this.photoCount,
    this.surveyCompletedCount = 0,
    this.surveyTotalCount = 0,
    this.isClosed = false,
    this.distanceMeters,
  });

  /// Hiển thị hộp thoại và trả về `true` nếu người dùng xác nhận check-out, ngược lại `false`.
  static Future<bool> show({
    required BuildContext context,
    required String dealerName,
    required String durationText,
    required int photoCount,
    int surveyCompletedCount = 0,
    int surveyTotalCount = 0,
    bool isClosed = false,
    double? distanceMeters,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CheckoutConfirmationDialog(
        dealerName: dealerName,
        durationText: durationText,
        photoCount: photoCount,
        surveyCompletedCount: surveyCompletedCount,
        surveyTotalCount: surveyTotalCount,
        isClosed: isClosed,
        distanceMeters: distanceMeters,
      ),
    );
    return result ?? false;
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
              // 1. Header: Icon Squircle + Tiêu đề + Pill Tên điểm & Trạng thái
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF064E3B).withValues(alpha: 0.35)
                          : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF059669).withValues(alpha: 0.5)
                            : const Color(0xFF86EFAC),
                        width: 1,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.task_alt_rounded,
                        color: Color(0xFF10B981),
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xác nhận Check-out?',
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF064E3B).withValues(alpha: 0.3)
                                    : const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.circle,
                                    size: 5.5,
                                    color: Color(0xFF10B981),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Đủ điều kiện',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? const Color(0xFF34D399)
                                          : const Color(0xFF059669),
                                    ),
                                  ),
                                ],
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

              // 2. Nội dung thông báo
              Text(
                isClosed
                    ? 'Bạn đã ghi nhận điểm bán đóng cửa và hoàn thành ảnh xác nhận. Bạn có chắc chắn muốn kết thúc và check-out không?'
                    : 'Bạn đã hoàn tất đầy đủ các điều kiện viếng thăm. Bạn có chắc chắn muốn kết thúc và check-out tại điểm bán này không?',
                style: TextStyle(
                  fontSize: 13,
                  color: secondaryTextColor,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 14),

              // 3. Card tóm tắt phiên viếng thăm (Summary Card)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Dòng 1: Thời gian viếng thăm
                    _buildSummaryRow(
                      icon: Icons.schedule_rounded,
                      iconBg: const Color(0xFFE0F2FE),
                      iconColor: const Color(0xFF0284C7),
                      label: 'Thời gian làm việc',
                      value: durationText.isNotEmpty ? durationText : '--:--',
                      isDark: isDark,
                    ),
                    const Divider(height: 16, thickness: 0.8),

                    // Dòng 2: Ảnh đã chụp
                    _buildSummaryRow(
                      icon: Icons.photo_camera_rounded,
                      iconBg: const Color(0xFFDCFCE7),
                      iconColor: const Color(0xFF10B981),
                      label: 'Ảnh đã chụp',
                      value: '$photoCount ảnh (Đạt)',
                      isDark: isDark,
                    ),
                    const Divider(height: 16, thickness: 0.8),

                    // Dòng 3: Khảo sát / Đóng cửa
                    _buildSummaryRow(
                      icon: isClosed
                          ? Icons.store_mall_directory_outlined
                          : Icons.assignment_turned_in_rounded,
                      iconBg: const Color(0xFFFEF3C7),
                      iconColor: const Color(0xFFD97706),
                      label: isClosed ? 'Trạng thái' : 'Khảo sát biểu mẫu',
                      value: isClosed
                          ? 'Đóng cửa'
                          : (surveyTotalCount > 0
                              ? '$surveyCompletedCount/$surveyTotalCount hoàn thành'
                              : 'Không có biểu mẫu'),
                      isDark: isDark,
                    ),

                    if (distanceMeters != null) ...[
                      const Divider(height: 16, thickness: 0.8),
                      // Dòng 4: Vị trí GPS
                      _buildSummaryRow(
                        icon: Icons.location_on_rounded,
                        iconBg: const Color(0xFFEDE9FE),
                        iconColor: const Color(0xFF7C3AED),
                        label: 'Vị trí check-out',
                        value: 'Hợp lệ (~${distanceMeters!.round()}m)',
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 4. Hàng 2 nút hành động: Ở lại & Xác nhận Check-out
              Row(
                children: [
                  // Nút "Ở lại"
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(false),
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

                  // Nút "XÁC NHẬN CHECK-OUT"
                  Expanded(
                    flex: 1,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(true),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.3),
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
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'CHECK-OUT',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(icon, size: 16, color: iconColor),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppColors.darkOnSurfaceVariant : const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppColors.darkOnSurface : const Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
