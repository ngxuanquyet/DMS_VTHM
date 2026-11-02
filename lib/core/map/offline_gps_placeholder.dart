import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Khung thay BẢN ĐỒ khi mất mạng ở mọi ô LẤY vị trí (chấm công, tạo/sửa điểm bán, biểu mẫu, khai báo vị trí) —
/// MỘT giao diện, MỘT luật: không vẽ bản đồ (bộ đệm MapLibre chỉ có vùng đã từng xem — vùng mới ra ô xám, trông như
/// lỗi), chỉ hiện toạ độ GPS thật + nút lấy lại GPS. GPS không cần mạng nên toạ độ vẫn đúng.
///
/// [readOnly]: ô CHỈ HIỂN THỊ vị trí đã lưu (chi tiết điểm bán) — không nói "đang ghi nhận GPS", không nút.
class OfflineGpsPlaceholder extends StatelessWidget {
  /// Dòng nhắc dưới ô vị trí khi mất mạng — nguồn DUY NHẤT của câu này.
  static const addressHint = 'Đang ngoại tuyến: địa chỉ không tự điền từ toạ độ';

  /// Định dạng toạ độ hiển thị dùng chung (5 chữ số thập phân ≈ 1 m).
  static String formatCoords(double lat, double lng) => '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

  /// Vĩ độ đang ghi nhận; `null` = chưa lấy toạ độ.
  final double? lat;

  /// Kinh độ đang ghi nhận; `null` = chưa lấy toạ độ.
  final double? lng;

  /// Dòng giải thích dưới toạ độ; `null` = câu mặc định theo [readOnly].
  final String? note;

  /// Bấm nút lấy lại toạ độ GPS; `null` = ẩn nút (ô chỉ đọc).
  final VoidCallback? onRefresh;

  /// Đang lấy GPS — nút hiện vòng xoay thay vì biến mất.
  final bool busy;

  /// Ô chỉ hiển thị vị trí đã lưu.
  final bool readOnly;

  /// Chiều cao khung.
  final double height;

  /// Bo góc — mặc định bo đủ 4 góc; đặt trong thẻ có dải thông tin bên dưới thì truyền [BorderRadius.zero].
  final BorderRadius? borderRadius;

  const OfflineGpsPlaceholder({
    super.key,
    required this.lat,
    required this.lng,
    this.note,
    this.onRefresh,
    this.busy = false,
    this.readOnly = false,
    this.height = 220,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLowest
            : AppColors.surfaceContainerLow,
        borderRadius: borderRadius ?? AppRadius.roundedMd,
      ),
      child: Stack(
        children: [
          // Vòng radar định vị tượng trưng tín hiệu GPS vệ tinh
          Center(
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: (isDark ? Colors.white : AppColors.primary).withValues(alpha: 0.08),
                  width: 1.5,
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 85,
              height: 85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: (isDark ? Colors.white : AppColors.primary).withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    readOnly ? 'Bản đồ ngoại tuyến' : 'Định vị GPS ngoại tuyến',
                    style: AppTypography.titleMedium(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ).copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    (lat != null && lng != null)
                        ? formatCoords(lat!, lng!)
                        : (readOnly || onRefresh == null ? 'Chưa có toạ độ' : 'Chưa có toạ độ — bấm nút định vị để lấy GPS'),
                    style: AppTypography.bodySmall(
                      color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                    ).copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    note ??
                        (readOnly
                            ? 'Bản đồ tạm ẩn khi không có kết nối mạng.'
                            : 'Bản đồ tạm ẩn khi không có kết nối mạng.\nTọa độ GPS thực tế vẫn được ghi nhận.'),
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall(
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                    ).copyWith(fontSize: 11.5, height: 1.3),
                  ),
                ],
              ),
            ),
          ),
          if (onRefresh != null)
            Positioned(
              right: 12,
              bottom: 12,
              child: Material(
                color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
                elevation: 2,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: busy ? null : onRefresh,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          )
                        : const Icon(
                            Icons.my_location,
                            size: 20,
                            color: AppColors.primary,
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
