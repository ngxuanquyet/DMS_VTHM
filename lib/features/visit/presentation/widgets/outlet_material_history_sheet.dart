import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../forms/domain/entities/market_form_entity.dart';
import '../../data/models/outlet_material_view_model.dart';
import '../../data/models/visit_material_model.dart';
import '../../data/repositories/visit_material_repository.dart';
import '../../domain/entities/visit_entity.dart';
import 'material_card.dart';
import 'material_condition_badges.dart';

/// Dòng thời gian thay đổi của MỘT loại vật tư tại điểm bán (#24707) — mới nhất trước: thao tác, giờ, người, lượt,
/// số lượng theo tình trạng (cũ → mới), ô chi tiết đổi (cũ → mới), lý do gỡ, ảnh.
Future<void> showOutletMaterialHistory(
  BuildContext context, {
  required int customerId,
  required OutletMaterialType type,
  required List<MaterialCondition> conditions,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, controller) => _HistorySheet(
        customerId: customerId,
        type: type,
        conditions: conditions,
        controller: controller,
      ),
    ),
  );
}

class _HistorySheet extends ConsumerStatefulWidget {
  final int customerId;
  final OutletMaterialType type;
  final List<MaterialCondition> conditions;
  final ScrollController controller;

  const _HistorySheet({
    required this.customerId,
    required this.type,
    required this.conditions,
    required this.controller,
  });

  @override
  ConsumerState<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends ConsumerState<_HistorySheet> {
  final List<OutletMaterialLogEntry> _items = [];
  int _page = 0;
  bool _hasMore = false;
  bool _loading = false;
  bool _fromCache = false;
  DateTime? _fetchedAt;
  String? _error;
  bool _loadedOnce = false;

  /// Ô chi tiết của loại — đọc schema một lần cho cả sheet.
  late final Map<String, MarketFormBlockEntity> _blocks = materialDetailBlocks(widget.type);

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  /// Nạp lại từ trang 1 (nút Thử lại / có mạng trở lại khi chưa có gì).
  void _reload() {
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = false;
      _loadedOnce = false;
      _error = null;
      _fromCache = false;
      _fetchedAt = null;
    });
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading) return;
    setState(() => _loading = true);
    final res = await ref
        .read(visitMaterialRepositoryProvider)
        .loadOutletHistory(widget.customerId, widget.type.id, page: _page + 1);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _loadedOnce = true;
      final page = res.page;
      if (page != null) {
        // Phân trang theo vị trí, mới nhất trước: dòng mới ghi giữa hai trang đẩy dòng cũ sang trang sau ⇒ bỏ trùng id.
        final seen = _items.map((e) => e.id).toSet();
        _items.addAll(page.items.where((e) => seen.add(e.id)));
        _page += 1;
        _hasMore = page.hasMore;
        if (_page == 1) {
          _fromCache = res.fromCache;
          _fetchedAt = res.fetchedAt;
        }
        _error = null;
      } else {
        // Trang sau lỗi tạm / ngoại tuyến ⇒ giữ nút "Tải thêm" để thử lại.
        if (_page == 0 || res.forbidden) _hasMore = false;
        final strings = ref.read(stringsProvider);
        _error = res.forbidden
            ? strings.materialsForbidden
            : res.offline
                ? strings.outletMaterialsNeedNetwork
                : res.error;
      }
    });
  }

  String _conditionName(String code) {
    for (final c in widget.conditions) {
      if (c.code == code) return c.name;
    }
    return code;
  }

  Color _conditionColor(String code) {
    for (final c in widget.conditions) {
      if (c.code == code) return conditionColor(c.color);
    }
    return conditionColor('secondary');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(connectivityProvider.select((s) => s.isOnline), (prev, next) {
      if (prev == false && next && (_items.isEmpty || _fromCache) && !_loading) _reload();
    });
    final strings = ref.watch(stringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
    final subColor = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;

    final children = <Widget>[
      Text(
        strings.outletMaterialsHistoryTitle(widget.type.name),
        style: AppTypography.titleMedium(color: textColor).copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      if (_fromCache && _fetchedAt != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(strings.outletMaterialsCachedAt(shortLocalDateTime(_fetchedAt!)),
              style: TextStyle(fontSize: 12, color: subColor)),
        ),
    ];

    if (!_loadedOnce) {
      children.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ));
    } else if (_items.isEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(
          _error ?? (_page == 0 ? strings.outletMaterialsHistoryNoCache : strings.outletMaterialsHistoryEmpty),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: subColor),
        ),
      ));
      if (_page == 0 || _fromCache) children.add(_retryButton(strings));
    } else {
      for (var i = 0; i < _items.length; i++) {
        children.add(_entry(_items[i], strings, textColor, subColor, isLast: i == _items.length - 1 && !_hasMore));
      }
      if (_hasMore) {
        if (_error != null) children.add(Text(_error!, style: TextStyle(fontSize: 12, color: subColor)));
        children.add(Center(
          child: _loading
              ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
              : TextButton(onPressed: _loadMore, child: Text(strings.outletMaterialsLoadMore)),
        ));
      } else if (_error != null) {
        children.add(Text(_error!, style: TextStyle(fontSize: 12, color: subColor)));
      }
      // Đang xem bản lưu (mất mạng / máy chủ lỗi tạm) ⇒ cho tải lại.
      if (_fromCache) children.add(_retryButton(strings));
    }

    return ListView(
      controller: widget.controller,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: children,
    );
  }

  Widget _retryButton(AppStrings strings) =>
      Center(child: TextButton(onPressed: _loading ? null : _reload, child: Text(strings.retry)));

  Widget _entry(OutletMaterialLogEntry e, AppStrings strings, Color textColor, Color subColor, {required bool isLast}) {
    final color = VisitEntity.bootstrapColorOf(e.actionColor) ?? AppColors.outline;
    final meta = <String>[
      if (e.recordedAt != null && e.recordedAt!.length >= 10) shortMaterialDateTime(e.recordedAt!),
      if (e.userName != null) e.userName!,
      if (e.visitId != null) strings.outletMaterialsVisit(e.visitId!),
    ].join(' · ');

    final body = <Widget>[
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
          child: Text(e.actionLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(meta, style: TextStyle(fontSize: 12, color: subColor))),
      ]),
      const SizedBox(height: 6),
    ];

    if (e.action != 'remove') {
      body.add(Text(strings.outletMaterialsQuantity(e.quantity, e.type.unit),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)));
    }

    // Số theo tình trạng: dòng có thay đổi ghi "cũ → mới"; không đổi thì liệt kê số hiện có.
    final counts = e.countChanges.isNotEmpty
        ? e.countChanges.entries.map((c) => (c.key, '${c.value.$1} → ${c.value.$2}'))
        : e.conditionCounts.entries.where((c) => c.value > 0).map((c) => (c.key, '${c.value}'));
    final countWidgets = counts
        .map((c) => Row(mainAxisSize: MainAxisSize.min, children: [
              ConditionDot(color: _conditionColor(c.$1)),
              const SizedBox(width: 4),
              Text('${_conditionName(c.$1)}: ${c.$2}', style: TextStyle(fontSize: 12, color: textColor)),
            ]))
        .toList();
    if (countWidgets.isNotEmpty) {
      body.addAll([const SizedBox(height: 4), Wrap(spacing: 12, runSpacing: 4, children: countWidgets)]);
    }

    for (final d in e.detailChanges.entries) {
      // Ô ảnh/tệp không thành dòng chữ (ảnh mới đã hiện ở dải ảnh); lựa chọn ra nhãn theo schema của loại.
      final before = materialDetailValue(widget.type, d.key, d.value.$1, strings, blocks: _blocks);
      final after = materialDetailValue(widget.type, d.key, d.value.$2, strings, blocks: _blocks);
      if (before == null || after == null) continue;
      final label = e.detailLabels[d.key]?.isNotEmpty == true ? e.detailLabels[d.key]! : d.key;
      body.add(Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text('$label: ${before.isEmpty ? '—' : before} → ${after.isEmpty ? '—' : after}',
            style: TextStyle(fontSize: 12, color: textColor)),
      ));
    }
    if (e.reason != null) {
      body.add(Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(strings.outletMaterialsReason(e.reason!), style: TextStyle(fontSize: 12, color: textColor)),
      ));
    }
    if (e.photos.isNotEmpty) {
      body.addAll([const SizedBox(height: 6), MaterialPhotoStrip(photos: e.photos, title: e.type.name)]);
    }

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 20,
          child: Column(children: [
            const SizedBox(height: 4),
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            if (!isLast) Expanded(child: Container(width: 2, color: subColor.withValues(alpha: 0.25))),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: body),
          ),
        ),
      ]),
    );
  }
}
