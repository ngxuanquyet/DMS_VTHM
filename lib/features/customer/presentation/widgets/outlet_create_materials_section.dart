import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../visit/data/models/material_create_rules.dart';
import '../../../visit/data/models/visit_material_model.dart';
import '../../../visit/presentation/screens/material_edit_screen.dart';
import '../../../visit/presentation/widgets/material_condition_badges.dart';

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

  Future<void> _pickType(BuildContext context, List<OutletMaterialType> addable, String title) async {
    final picked = await showModalBottomSheet<OutletMaterialType>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(padding: const EdgeInsets.all(16), child: Text(title, style: AppTypography.titleMedium())),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: addable
                      .map((t) => ListTile(
                            title: Text(t.name),
                            subtitle: t.unit.isNotEmpty ? Text(t.unit) : null,
                            onTap: () => Navigator.of(ctx).pop(t),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          const SizedBox(height: 8),
          ...requiredTypes.map((t) => _row(context, strings, t, isRequired: true)),
          ...declaredOptional.map((t) => _row(context, strings, t, isRequired: false)),
          if (addable.isNotEmpty)
            OutlinedButton(
              onPressed: () => _pickType(context, addable, strings.materialsChooseType),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
              child: Text(strings.materialsAdd),
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, AppStrings strings, OutletMaterialType type, {required bool isRequired}) {
    final op = ops[type.id];
    final counts = op?.conditionCounts ?? const <String, int>{};
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      onTap: () => _edit(context, type),
      leading: isRequired && op == null
          ? const Icon(Icons.warning_amber_rounded, color: AppColors.warning)
          : Icon(op == null ? Icons.radio_button_unchecked : Icons.check_circle_rounded,
              color: op == null ? AppColors.outline : AppColors.success),
      title: Text(type.name),
      subtitle: op == null
          ? Text(strings.materialsNotDeclared)
          : Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(total == 0 ? strings.materialsNone : strings.materialsQuantity(total, type.unit)),
                MaterialConditionBadges(counts: counts, conditions: catalog.conditions),
              ],
            ),
      trailing: op == null
          ? const Icon(Icons.chevron_right)
          : IconButton(
              tooltip: strings.createMaterialsUndo,
              icon: const Icon(Icons.close),
              onPressed: () => onChanged(Map.of(ops)..remove(type.id)),
            ),
    );
  }
}
