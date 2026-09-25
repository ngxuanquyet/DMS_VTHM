import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Widget hỗ trợ vuốt sang 2 bên để xóa bản ghi chờ đồng bộ kèm popup xác nhận
class PendingSyncDismissible extends StatelessWidget {
  final String itemKey;
  final String title;
  final bool isPending;
  final Future<bool> Function() onConfirmDelete;
  final Widget child;

  const PendingSyncDismissible({
    super.key,
    required this.itemKey,
    required this.title,
    required this.isPending,
    required this.onConfirmDelete,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPending) {
      return child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dismissible(
      key: ValueKey('dismiss_pending_$itemKey'),
      direction: DismissDirection.horizontal,
      background: _buildSwipeBackground(
        isDark: isDark,
        alignment: Alignment.centerLeft,
        iconPadding: const EdgeInsets.only(left: 20),
      ),
      secondaryBackground: _buildSwipeBackground(
        isDark: isDark,
        alignment: Alignment.centerRight,
        iconPadding: const EdgeInsets.only(right: 20),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => _DeleteConfirmationDialog(
            title: title,
            isDark: isDark,
          ),
        );
      },
      onDismissed: (direction) async {
        final success = await onConfirmDelete();
        if (success && context.mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đã xóa bản ghi chờ "$title"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFDC2626),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      },
      child: child,
    );
  }

  Widget _buildSwipeBackground({
    required bool isDark,
    required Alignment alignment,
    required EdgeInsets iconPadding,
  }) {
    return Container(
      alignment: alignment,
      padding: iconPadding,
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.delete_sweep_rounded,
            color: Colors.white,
            size: 26,
          ),
          SizedBox(width: 8),
          Text(
            'Xóa bản ghi chờ',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteConfirmationDialog extends StatelessWidget {
  final String title;
  final bool isDark;

  const _DeleteConfirmationDialog({
    required this.title,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      elevation: 12,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon cảnh báo xóa nổi bật
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark ? const Color(0x33DC2626) : const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: Color(0xFFDC2626),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            // Tiêu đề
            Text(
              'Xóa bản ghi chờ đồng bộ?',
              style: AppTypography.titleMedium(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ).copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Mô tả chi tiết
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: AppTypography.bodySmall(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                ).copyWith(height: 1.45),
                children: [
                  const TextSpan(text: 'Bản ghi '),
                  TextSpan(
                    text: '"$title"',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const TextSpan(
                    text:
                        ' chưa được gửi lên máy chủ.\nThao tác này sẽ xóa vĩnh viễn dữ liệu khỏi thiết bị và không thể hoàn tác.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Các nút hành động
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Hủy',
                      style: TextStyle(
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Xóa',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
