import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Ô TRÌNH BÀY "tiêu đề" (`heading`) — DÙNG CHUNG biểu mẫu thị trường và form động (Thêm/Sửa điểm bán).
/// Cấp 1: chữ lớn, biểu tượng, gạch chân màu chủ đạo. Cấp 2 (tiêu đề con): chữ nhỏ hơn, thụt vào, vạch trái.
/// Cấp đọc bằng `DynamicFormField.headingLevelOf`. Không thu giá trị.
class HeadingFieldWidget extends StatelessWidget {
  final String code;
  final String title;
  final String? description;
  final int level;

  const HeadingFieldWidget({super.key, required this.code, required this.title, this.description, this.level = 1});

  /// Dòng mô tả của tiêu đề (chữ thường) — cũng dùng riêng khi tiêu đề cấp 1 đã thành tiêu đề khung mục.
  static Widget descriptionText(BuildContext context, String desc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      desc,
      style: AppTypography.bodySmall(color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline)
          .copyWith(fontSize: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final desc = description?.trim() ?? '';
    final accent = isDark ? AppColors.primaryFixedDim : AppColors.primary;
    final titleColor = isDark ? AppColors.darkOnSurface : AppColors.onSurface;

    if (level == 2) {
      return Container(
        key: ValueKey('subheading_$code'),
        margin: const EdgeInsets.only(left: 16, top: 4),
        padding: const EdgeInsets.only(left: 10, top: 2, bottom: 2),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: accent, width: 3))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.titleMedium(color: titleColor).copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
            if (desc.isNotEmpty) ...[const SizedBox(height: 2), descriptionText(context, desc)],
          ],
        ),
      );
    }

    return Container(
      key: ValueKey('heading_$code'),
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: accent, width: 2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.label_important_rounded, size: 20, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: AppTypography.titleMedium(color: titleColor).copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (desc.isNotEmpty) ...[const SizedBox(height: 4), descriptionText(context, desc)],
        ],
      ),
    );
  }
}
