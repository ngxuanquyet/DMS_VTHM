import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../formula_evaluator.dart';

/// Ô hiển thị kết quả CÔNG THỨC (chỉ đọc, không có ô nhập) — dùng chung form điểm bán và biểu mẫu thị trường. Màn gọi
/// tự vẽ nhãn theo phong cách của mình; widget này chỉ vẽ khung giá trị. Chưa tính được (ô tham chiếu còn trống…) ⇒ `—`.
class FormulaValueBox extends StatelessWidget {
  /// Giá trị đã tính (chưa định dạng); `null` = rỗng.
  final num? value;

  /// Cấu hình định dạng (`format`/`decimals`).
  final FormulaConfig? config;

  const FormulaValueBox({super.key, required this.value, this.config});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = FormulaEvaluator.formatWith(value, config);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            Icons.functions_rounded,
            size: 18,
            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text.isEmpty ? '—' : text,
              key: const ValueKey('formula-value'),
              style: AppTypography.bodyMedium(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            'Tự tính',
            style: AppTypography.labelSmall(
              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
            ).copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
