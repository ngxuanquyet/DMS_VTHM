import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Dải "Đã khôi phục nháp lúc …" + nút "Xoá nháp, làm lại" — màn nào tự lưu nháp ([FormDraftStore]) thì hiện khi mở lại.
class DraftRestoredBanner extends StatelessWidget {
  /// Lần lưu nháp gần nhất.
  final DateTime savedAt;

  /// Bỏ nháp, dựng lại màn trống; null ⇒ nút tắt (đang nộp).
  final VoidCallback? onRestart;

  const DraftRestoredBanner({super.key, required this.savedAt, this.onRestart});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    // Nháp của hôm trước ghi kèm ngày.
    final sameDay = savedAt.year == now.year && savedAt.month == now.month && savedAt.day == now.day;
    final hhmm = DateFormat(sameDay ? 'HH:mm' : 'HH:mm dd/MM').format(savedAt);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đã khôi phục nháp lúc $hhmm',
              style: AppTypography.bodyMedium(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ).copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: onRestart,
            child: const Text('Xoá nháp, làm lại'),
          ),
        ],
      ),
    );
  }
}
