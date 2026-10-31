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
import '../widgets/material_card.dart';
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
  bool _requiredFromOtherOutlet = false;
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
      _requiredFromOtherOutlet = res.requiredFromOtherOutlet;
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
          customerId: widget.customerId,
          visitClientUuid: vm.sessionClientUuid,
          dealerName: widget.dealerName,
          op: op,
        );
    if (!outcome.ok) return outcome.error;

    final data = _data;
    if (data != null) {
      final next = applyMaterialOperation(
        data,
        op,
        outletMaterialId: outcome.outletMaterialId,
        trusted: !outcome.queued,
      );
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
            if (_requiredFromOtherOutlet)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(strings.materialsRequiredFromOtherOutlet,
                    style: const TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w600)),
              ),
            if (data.items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(strings.materialsEmpty, textAlign: TextAlign.center),
              ),
            if (data.items.isNotEmpty) _buildSummary(data, strings, isDark),
            ..._sorted(data).map((i) => _buildRow(i, data, strings)),
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

  /// Thứ tự thẻ: việc còn thiếu lên đầu — bắt buộc chưa kiểm → chưa kiểm → đã kiểm lượt này → không có tại điểm.
  static List<OutletMaterialItem> _sorted(VisitMaterialsData data) {
    final items = data.items;
    int rank(OutletMaterialItem i) {
      if (_isRequired(data, i) && !i.checkedInVisit) return 0;
      if (i.isEmptyQuantity) return 3;
      return i.checkedInVisit ? 2 : 1;
    }

    final indexed = items.asMap().entries.toList()
      ..sort((a, b) {
        final r = rank(a.value).compareTo(rank(b.value));
        return r != 0 ? r : a.key.compareTo(b.key);
      });
    return indexed.map((e) => e.value).toList();
  }

  /// Dải tổng quan: đã kiểm x/y loại + số loại bắt buộc còn thiếu + thanh tiến độ.
  Widget _buildSummary(VisitMaterialsData data, AppStrings strings, bool isDark) {
    final total = data.items.length;
    final checked = data.items.where((i) => i.checkedInVisit).length;
    final missing = data.missingAfterLocal.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(strings.materialsSummary(checked, total),
                  style: AppTypography.titleMedium(color: isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                      .copyWith(fontWeight: FontWeight.w700)),
              if (missing > 0)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                  const SizedBox(width: 2),
                  Text(strings.materialsRequiredLeft(missing),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warning)),
                ]),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : checked / total,
              minHeight: 6,
              color: missing > 0 ? AppColors.warning : AppColors.success,
              backgroundColor: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Bắt buộc theo `required_type_ids` của bản đang dùng — chế độ "không chắc luật" ([VisitMaterialsData.withoutRequired])
  /// xoá danh sách đó nhưng `items[].is_required` còn; thẻ phải khớp dải tổng quan.
  static bool _isRequired(VisitMaterialsData data, OutletMaterialItem i) =>
      i.isRequired && data.requiredTypeIds.contains(i.materialTypeId);

  Widget _buildRow(OutletMaterialItem item, VisitMaterialsData data, AppStrings strings) {
    final status = item.checkedInVisit
        ? MaterialCardStatus.checked
        : _isRequired(data, item)
            ? MaterialCardStatus.required
            : MaterialCardStatus.pending;
    return MaterialCard(
      // Giữ trạng thái mở/thu gọn theo loại khi danh sách sắp lại sau lần kiểm.
      key: ValueKey(item.materialTypeId),
      collapsible: true,
      strings: strings,
      // Loại trong danh mục mang `schema` chi tiết (nhãn ô); `items[].type` thì không.
      type: data.typeById(item.materialTypeId) ?? item.type,
      conditions: data.conditions,
      counts: item.isBlank ? null : (item.conditionCounts ?? const {}),
      details: item.details,
      photos: item.lastPhotos,
      status: status,
      footer: item.asOf != null && item.asOf!.length >= 10
          ? strings.materialsLastCheck(_shortDateTime(item.asOf!), item.lastUserName)
          : null,
      onTap: () => _openEdit(item.type, item),
    );
  }

  /// "2026-10-30 12:10:03+07" → "30/10 12:10"; chỉ có ngày → "30/10". Server trả giờ VN kèm múi, giữ nguyên như chuỗi.
  static String _shortDateTime(String raw) {
    final day = '${raw.substring(8, 10)}/${raw.substring(5, 7)}';
    return raw.length >= 16 ? '$day ${raw.substring(11, 16)}' : day;
  }
}
