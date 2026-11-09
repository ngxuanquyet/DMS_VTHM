import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Ô TRÌNH BÀY "tiêu đề" (`heading`) — DÙNG CHUNG biểu mẫu thị trường và form động (Thêm/Sửa điểm bán).
/// Cấp 1: chữ lớn, biểu tượng, gạch chân màu chủ đạo. Cấp 2 (tiêu đề con): chữ nhỏ hơn, thụt vào, vạch trái.
/// Cấp đọc bằng `DynamicFormField.headingLevelOf`. Không thu giá trị. Ô dưới tiêu đề con gom khung bằng [groupUnderSubheadings].
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

/// Gom các ô sau một tiêu đề con (cấp 2) tới tiêu đề kế tiếp (mọi cấp) / hết danh sách vào khung riêng thụt vào —
/// DÙNG CHUNG form điểm bán ([DynamicFormBuilder]) và biểu mẫu thị trường (`MarketFormRenderer`). `headingLevel` = cấp
/// của ô tiêu đề, `null` với ô khác; `child` là widget đã dựng (kèm khoảng cách dưới) của ô đó.
List<Widget> groupUnderSubheadings(Iterable<({int? headingLevel, Widget child})> items) {
  final out = <Widget>[];
  List<Widget>? nhom;
  void dongNhom() {
    if (nhom != null && nhom!.isNotEmpty) out.add(_SubheadingFrame(children: nhom!));
    nhom = null;
  }

  for (final item in items) {
    if (item.headingLevel != null) dongNhom();
    (nhom ?? out).add(item.child);
    if (item.headingLevel == 2) nhom = [];
  }
  dongNhom();
  return out;
}

/// Khung của các ô thuộc một tiêu đề con: thẳng mép vạch trái của tiêu đề con (thụt 16), viền mảnh bo góc.
class _SubheadingFrame extends StatelessWidget {
  final List<Widget> children;

  const _SubheadingFrame({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(left: 16, bottom: AppSpacing.stackMd),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        borderRadius: AppRadius.roundedLg,
        border: Border.all(color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}
