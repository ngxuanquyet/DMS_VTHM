import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../visit/data/models/material_create_rules.dart';
import '../../../visit/data/models/visit_material_model.dart';
import '../../../visit/presentation/screens/material_edit_screen.dart';
import '../../../visit/presentation/widgets/material_card.dart';
import '../../../visit/presentation/widgets/material_type_picker_sheet.dart';

/// Bước "Vật tư tại điểm" của form TẠO điểm bán (#24526): loại bắt buộc (⚠️, dòng trống khi chưa khai) + loại đã khai +
/// "+ Thêm loại vật tư". Bấm dòng ⇒ dùng LẠI [MaterialEditScreen] của lượt viếng thăm (số lượng theo tình trạng, chi tiết
/// theo schema, ảnh); chỉ thao tác `add`, `client_uuid` sinh lúc bấm Lưu. Thao tác giữ ở màn tạo, gửi CÙNG điểm bán.
class OutletCreateMaterialsSection extends ConsumerWidget {
  final MaterialCreateCatalog catalog;
  final List<OutletMaterialType> requiredTypes;

  /// Thao tác đã khai theo `material_type_id`.
  final Map<int, MaterialOperation> ops;
  final ValueChanged<Map<int, MaterialOperation>> onChanged;

  const OutletCreateMaterialsSection({
    super.key,
    required this.catalog,
    required this.requiredTypes,
    required this.ops,
    required this.onChanged,
  });

  Future<void> _edit(BuildContext context, OutletMaterialType type) async {
    final op = ops[type.id];
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MaterialEditScreen(
          type: catalog.typeById(type.id) ?? type,
          // Dòng trống (id null) ⇒ form chạy thao tác `add`; khai lại thì mở sẵn giá trị đã khai.
          item: op == null
              ? null
              : OutletMaterialItem(
                  materialTypeId: type.id,
                  type: type,
                  conditionCounts: op.conditionCounts,
                  details: {...?op.details, materialPhotoFieldCode: op.photos},
                ),
          conditions: catalog.conditions,
          onSubmit: (next) async {
            onChanged({...ops, type.id: next});
            return null;
          },
        ),
      ),
    );
  }

  Future<void> _pickType(BuildContext context, List<OutletMaterialType> addable, AppStrings strings) async {
    final picked = await showMaterialTypePicker(context, types: addable, strings: strings);
    if (picked != null && context.mounted) await _edit(context, picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final requiredIds = requiredTypes.map((t) => t.id).toSet();
    final declaredOptional = ops.keys
        .where((id) => !requiredIds.contains(id))
        .map((id) => catalog.typeById(id) ?? OutletMaterialType(id: id, name: '#$id'))
        .toList();
    final addable = catalog.types
        .where((t) => t.isActive && !requiredIds.contains(t.id) && !ops.containsKey(t.id))
        .toList();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.createMaterialsTitle,
            style: AppTypography.titleMedium(color: isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            strings.createMaterialsHint,
            style: AppTypography.labelSmall(color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
          ),
          if (requiredTypes.isNotEmpty || ops.isNotEmpty) ...[
            const SizedBox(height: 6),
            _summary(strings, requiredTypes.length + declaredOptional.length),
          ],
          const SizedBox(height: 8),
          ...requiredTypes.map((t) => _row(context, strings, t, isRequired: true)),
          ...declaredOptional.map((t) => _row(context, strings, t, isRequired: false)),
          if (addable.isNotEmpty)
            OutlinedButton(
              onPressed: () => _pickType(context, addable, strings),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
              child: Text(strings.materialsAdd),
            ),
        ],
      ),
    );
  }

  /// "Đã khai x/y loại · ⚠ Bắt buộc còn n".
  Widget _summary(AppStrings strings, int total) {
    final missing = requiredTypes.where((t) => !ops.containsKey(t.id)).length;
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(strings.createMaterialsSummary(ops.length, total),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        if (missing > 0)
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
            const SizedBox(width: 2),
            Text(strings.materialsRequiredLeft(missing),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warning)),
          ]),
      ],
    );
  }

  Widget _row(BuildContext context, AppStrings strings, OutletMaterialType type, {required bool isRequired}) {
    final op = ops[type.id];
    return MaterialCard(
      strings: strings,
      type: catalog.typeById(type.id) ?? type,
      conditions: catalog.conditions,
      counts: op == null ? null : (op.conditionCounts ?? const {}),
      details: op?.details,
      photos: op == null ? const [] : op.photos.map(MaterialPhoto.fromRaw).toList(),
      status: op == null && isRequired ? MaterialCardStatus.required : MaterialCardStatus.none,
      compactDetails: true,
      onTap: () => _edit(context, type),
      action: op == null
          ? null
          : IconButton(
              tooltip: strings.createMaterialsUndo,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              iconSize: 20,
              style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              icon: const Icon(Icons.close),
              onPressed: () => onChanged(Map.of(ops)..remove(type.id)),
            ),
    );
  }
}
