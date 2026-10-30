import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../../../route/presentation/viewmodels/route_view_model.dart';
import '../../data/models/visit_material_model.dart';
import '../../data/repositories/visit_material_repository.dart';
import '../widgets/material_condition_badges.dart';
import 'material_edit_screen.dart';

/// Mục "Vật tư" của lượt viếng thăm đang mở (#24522): vật tư tại điểm bán theo LOẠI + SỐ LƯỢNG chia theo tình trạng,
/// lần kiểm gần nhất, ⚠️ loại bắt buộc, dòng trống cho loại bắt buộc chưa khai, "+ Thêm loại vật tư".
/// Lượt đang mở đọc từ [checkInViewModelProvider]; cổng check-out ④ cập nhật qua `applyMaterialRequirements`.
class VisitMaterialsScreen extends ConsumerStatefulWidget {
  final int customerId;
  final String dealerName;

  const VisitMaterialsScreen({super.key, required this.customerId, required this.dealerName});

  @override
  ConsumerState<VisitMaterialsScreen> createState() => _VisitMaterialsScreenState();
}

class _VisitMaterialsScreenState extends ConsumerState<VisitMaterialsScreen> {
  VisitMaterialsData? _data;
  bool _loading = true;
  bool _fromCache = false;
  bool _forbidden = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final vm = ref.read(checkInViewModelProvider.notifier);
    final res = await ref.read(visitMaterialRepositoryProvider).load(
          visitId: ref.read(checkInViewModelProvider).visitId,
          customerId: widget.customerId,
          visitClientUuid: vm.sessionClientUuid,
        );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _data = res.data;
      _fromCache = res.fromCache;
      _forbidden = res.forbidden;
      _error = res.error;
    });
    if (res.data != null) vm.applyMaterialRequirements(res.data!.missingAfterLocal);
  }

  /// Gửi một thao tác; lỗi server (results[i].ok = false) trả về cho form để hiện đúng dòng.
  Future<String?> _submit(MaterialOperation op) async {
    final strings = ref.read(stringsProvider);
    final vm = ref.read(checkInViewModelProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref.read(visitMaterialRepositoryProvider).submit(
          visitId: ref.read(checkInViewModelProvider).visitId,
          visitClientUuid: vm.sessionClientUuid,
          dealerName: widget.dealerName,
          op: op,
        );
    if (!outcome.ok) return outcome.error;

    final data = _data;
    if (data != null) {
      final next = applyMaterialOperation(data, op, outletMaterialId: outcome.outletMaterialId);
      if (mounted) setState(() => _data = next);
      vm.applyMaterialRequirements(
        outcome.requirements?.missingMaterials ?? next.missingAfterLocal,
        serverRequirements: outcome.requirements,
      );
    }
    if (outcome.queued) {
      AppSnackBar.showWarningOn(messenger, strings.materialsQueued);
      if (ref.read(connectivityProvider).isOnline) ref.read(syncServiceProvider).syncQueue();
    } else {
      AppSnackBar.showSuccessOn(messenger, strings.materialsSaved);
    }
    return null;
  }

  Future<void> _openEdit(OutletMaterialType type, OutletMaterialItem? item) async {
    final data = _data;
    if (data == null) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MaterialEditScreen(
          // Loại trong danh mục mang `schema` chi tiết; `items[].type` thì không.
          type: data.typeById(type.id) ?? type,
          item: item,
          conditions: data.conditions,
          onSubmit: _submit,
        ),
      ),
    );
  }

  Future<void> _pickTypeToAdd(AppStrings strings) async {
    final addable = _data?.addableTypes ?? const <OutletMaterialType>[];
    if (addable.isEmpty) {
      AppSnackBar.showWarningOn(ScaffoldMessenger.of(context), strings.materialsNoAddable);
      return;
    }
    final picked = await showModalBottomSheet<OutletMaterialType>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(strings.materialsChooseType, style: AppTypography.titleMedium()),
              ),
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
    if (picked != null && mounted) await _openEdit(picked, null);
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = _data;

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_forbidden) {
      body = Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(strings.materialsForbidden)));
    } else if (data == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? strings.materialsNoData, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: Text(strings.retry)),
            ],
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.marginMobile),
          children: [
            if (_fromCache)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(strings.materialsOfflineCache,
                    style: const TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w600)),
              ),
            if (data.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(strings.materialsEmpty, textAlign: TextAlign.center),
              ),
            ...data.items.map((i) => _buildRow(i, data, strings, isDark)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _pickTypeToAdd(strings),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
              child: Text(strings.materialsAdd),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: VthmTopAppBar(
        title: strings.materialsTitle,
        showBackButton: true,
        showAvatar: false,
        showLogo: false,
      ),
      body: body,
    );
  }

  Widget _buildRow(OutletMaterialItem item, VisitMaterialsData data, AppStrings strings, bool isDark) {
    final muted = item.isEmptyQuantity;
    final textColor = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
    final subColor = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;

    Widget trailing;
    if (item.checkedInVisit) {
      trailing = Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
        const SizedBox(width: 4),
        Text(strings.materialsChecked,
            style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w700)),
      ]);
    } else if (item.isRequired) {
      trailing = Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
        const SizedBox(width: 4),
        Text(strings.materialsRequired,
            style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w700)),
      ]);
    } else {
      trailing = Icon(Icons.chevron_right, color: subColor);
    }

    final lastCheck = item.asOf != null && item.asOf!.length >= 10
        ? strings.materialsLastCheck(_shortDate(item.asOf!), item.lastUserName)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openEdit(item.type, item),
        child: Opacity(
          opacity: muted ? 0.55 : 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.type.name,
                          style: AppTypography.titleMedium(color: textColor).copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      if (item.isBlank)
                        Text(strings.materialsNotDeclared, style: TextStyle(fontSize: 12, color: subColor))
                      else
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              muted ? strings.materialsNone : strings.materialsQuantity(item.quantity ?? 0, item.type.unit),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                            ),
                            MaterialConditionBadges(counts: item.conditionCounts ?? const {}, conditions: data.conditions),
                          ],
                        ),
                      if (lastCheck != null) ...[
                        const SizedBox(height: 2),
                        Text(lastCheck, style: TextStyle(fontSize: 11, color: subColor)),
                      ],
                    ],
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "2026-10-30 12:10:03+07" → "30/10".
  static String _shortDate(String raw) {
    final d = raw.substring(0, 10).split('-');
    return d.length == 3 ? '${d[2]}/${d[1]}' : raw.substring(0, 10);
  }
}
