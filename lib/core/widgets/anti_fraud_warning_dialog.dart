import 'package:flutter/material.dart';
import '../services/anti_fraud_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

/// Hộp thoại cảnh báo rủi ro gian lận & kiểm toán tuân thủ thiết bị
class AntiFraudWarningDialog {
  AntiFraudWarningDialog._();

  /// 1. CẢNH BÁO KHI NHÂN VIÊN VÀO APP (ENTRY CHECK)
  static Future<void> showAppEntryWarning(
    BuildContext context, {
    required ComplianceReport report,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
            borderRadius: AppRadius.roundedXl,
            boxShadow: AppShadows.level3,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon biểu tượng
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: (report.hasMockGps ? AppColors.error : const Color(0xFFF59E0B))
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      report.hasMockGps
                          ? Icons.security_update_warning_rounded
                          : Icons.access_time_filled_rounded,
                      color: report.hasMockGps ? AppColors.error : const Color(0xFFD97706),
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Tiêu đề
                Text(
                  'Cảnh báo tuân thủ thiết bị',
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineSmall(
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),

                Text(
                  'Hệ thống phát hiện thiết bị chưa đạt tiêu chuẩn kiểm toán tác nghiệp thị trường:',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall(
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                // Danh sách các rủi ro phát hiện
                if (report.hasMockGps) ...[
                  _RiskCard(
                    icon: Icons.wrong_location_rounded,
                    iconColor: AppColors.error,
                    title: 'Phát hiện toạ độ giả lập (Mock GPS)',
                    description:
                        'Thiết bị đang bật tính năng giả lập vị trí hoặc ứng dụng Fake GPS. Các thao tác ghi nhận toạ độ có thể bị từ chối hoặc cần kiểm tra lại.',
                    advice: 'Vui lòng tắt ứng dụng Fake GPS trong Cài đặt của thiết bị.',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                ],

                if (report.hasClockSkew) ...[
                  _RiskCard(
                    icon: Icons.access_alarms_rounded,
                    iconColor: const Color(0xFFD97706),
                    title: 'Thời gian thiết bị chưa chuẩn (Clock Skew)',
                    description:
                        'Giờ trên điện thoại đang lệch ${report.clockSkewMinutes.abs()} phút so với giờ chuẩn của hệ thống. Dữ liệu sẽ được ghi nhận để đối soát sau.',
                    advice: 'Vui lòng vào Cài đặt máy > Ngày & giờ và bật "Tự động đặt ngày giờ theo mạng".',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                ],

                const SizedBox(height: 8),

                // Nút đóng
                AppButton(
                  text: 'ĐÃ HIỂU & TIẾP TỤC',
                  width: double.infinity,
                  height: 46,
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 2. CẢNH BÁO KHI BỊ CHẶN CỨNG (BLOCKED ACTION DO MOCK LOCATION)
  static Future<void> showActionBlocked(
    BuildContext context, {
    required String actionTitle,
    required String reason,
    required String resolution,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
            borderRadius: AppRadius.roundedXl,
            boxShadow: AppShadows.level3,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.block_rounded,
                    color: AppColors.error,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'Từ chối $actionTitle',
                textAlign: TextAlign.center,
                style: AppTypography.headlineSmall(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
                ),
                child: Text(
                  reason,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Text(
                resolution,
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                ).copyWith(height: 1.35),
              ),
              const SizedBox(height: 20),

              AppButton(
                text: 'ĐÃ HIỂU',
                width: double.infinity,
                height: 46,
                onPressed: () => Navigator.of(dialogCtx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 3. CẢNH BÁO RỦI RO KHI THỰC HIỆN THAO TÁC (WARNING ACTION - YÊU CẦU XÁC NHẬN TIẾP TỤC HOẶC HUỶ)
  static Future<bool> showActionWarning(
    BuildContext context, {
    required String actionTitle,
    required bool hasMockGps,
    required bool hasClockSkew,
    required int skewMinutes,
    required int toleranceMinutes,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
            borderRadius: AppRadius.roundedXl,
            boxShadow: AppShadows.level3,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFD97706),
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  'Cảnh báo tính hợp lệ của dữ liệu',
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineSmall(
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),

                Text(
                  'Thao tác "$actionTitle" có dấu hiệu bất thường về môi trường thiết bị:',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall(
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),

                if (hasMockGps) ...[
                  _RiskCard(
                    icon: Icons.location_off_rounded,
                    iconColor: AppColors.error,
                    title: 'Phát hiện vị trí giả lập',
                    description:
                        'Dữ liệu "$actionTitle" sẽ được gửi kèm cảnh báo vị trí bất thường tới bộ phận quản lý.',
                    advice: null,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                ],

                if (hasClockSkew) ...[
                  _RiskCard(
                    icon: Icons.history_toggle_off_rounded,
                    iconColor: const Color(0xFFD97706),
                    title: 'Giờ thiết bị lệch $skewMinutes phút',
                    description:
                        'Thời gian trên máy lệch quá quy định ($toleranceMinutes phút). Dữ liệu sẽ được gửi kèm ghi chú để đối soát.',
                    advice: null,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                ],

                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF64748B)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bạn có chắc chắn muốn tiếp tục gửi dữ liệu này lên hệ thống?',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('HUỶ BỎ'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'VẪN GỬI',
                          style: TextStyle(fontWeight: FontWeight.w700),
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

    return result ?? false;
  }
}

class _RiskCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final String? advice;
  final bool isDark;

  const _RiskCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    this.advice,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
          if (advice != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('👉 ', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Text(
                      advice!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
