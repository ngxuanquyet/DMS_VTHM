import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/string_utils.dart';
import '../../data/models/visit_material_model.dart';

/// Sheet "Chọn loại vật tư" — DÙNG CHUNG cho "+ Thêm loại vật tư" ở mục Vật tư của lượt viếng thăm và form tạo điểm bán:
/// mỗi loại một thẻ có viền (biểu tượng · tên · đơn vị · ›), ô tìm không dấu khi danh mục dài.
Future<OutletMaterialType?> showMaterialTypePicker(
  BuildContext context, {
  required List<OutletMaterialType> types,
  required AppStrings strings,
}) =>
    showModalBottomSheet<OutletMaterialType>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MaterialTypePickerSheet(types: types, strings: strings),
    );

class _MaterialTypePickerSheet extends StatefulWidget {
  final List<OutletMaterialType> types;
  final AppStrings strings;

  const _MaterialTypePickerSheet({required this.types, required this.strings});

  /// Từ số loại này trở lên mới hiện ô tìm.
  static const int searchThreshold = 7;

  @override
  State<_MaterialTypePickerSheet> createState() => _MaterialTypePickerSheetState();
}

class _MaterialTypePickerSheetState extends State<_MaterialTypePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
    final subColor = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    final borderColor = isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant;
    final q = StringUtils.toUnaccentedLower(_query.trim());
    final shown = q.isEmpty
        ? widget.types
        : widget.types.where((t) => StringUtils.toUnaccentedLower(t.name).contains(q)).toList();

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // Bàn phím mở (ô tìm) ⇒ đẩy sheet lên.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: borderColor, borderRadius: AppRadius.roundedFull),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: AppRadius.roundedMd,
                    ),
                    child: const Icon(Icons.add_box_outlined, size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(strings.materialsChooseType,
                            style: AppTypography.titleMedium(color: textColor).copyWith(fontWeight: FontWeight.w700)),
                        Text(strings.materialsTypesAvailable(widget.types.length),
                            style: AppTypography.bodySmall(color: subColor)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            if (widget.types.length >= _MaterialTypePickerSheet.searchThreshold)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: strings.materialsSearchType,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: AppRadius.roundedMd, borderSide: BorderSide(color: borderColor)),
                    enabledBorder:
                        OutlineInputBorder(borderRadius: AppRadius.roundedMd, borderSide: BorderSide(color: borderColor)),
                  ),
                ),
              ),
            Divider(height: 1, color: borderColor),
            Flexible(
              child: shown.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(strings.materialsNoTypeMatch,
                          textAlign: TextAlign.center, style: TextStyle(color: subColor)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) => _TypeTile(
                        type: shown[i],
                        strings: strings,
                        isDark: isDark,
                        onTap: () => Navigator.of(ctx).pop(shown[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Một loại vật tư: thẻ có viền, biểu tượng trái, tên đậm + đơn vị, mũi tên phải.
class _TypeTile extends StatelessWidget {
  final OutletMaterialType type;
  final AppStrings strings;
  final bool isDark;
  final VoidCallback onTap;

  const _TypeTile({required this.type, required this.strings, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
    final subColor = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    return Material(
      color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
      borderRadius: AppRadius.roundedLg,
      child: InkWell(
        borderRadius: AppRadius.roundedLg,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: AppRadius.roundedLg,
            border: Border.all(color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: AppRadius.roundedMd,
                ),
                child: const Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.name,
                        style: AppTypography.bodyMedium(color: textColor).copyWith(fontWeight: FontWeight.w700)),
                    if (type.unit.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(strings.materialsUnitLabel(type.unit), style: TextStyle(fontSize: 12, color: subColor)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: subColor),
            ],
          ),
        ),
      ),
    );
  }
}
