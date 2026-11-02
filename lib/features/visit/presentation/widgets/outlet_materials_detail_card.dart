import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../route/presentation/viewmodels/route_view_model.dart';
import '../../data/models/outlet_material_view_model.dart';
import '../../data/models/visit_material_model.dart';
import '../../data/repositories/visit_material_repository.dart';
import '../../data/repositories/visit_repository_impl.dart';
import '../screens/visit_materials_screen.dart';
import 'material_card.dart';
import 'outlet_material_history_sheet.dart';

/// Mục "Vật tư" ở màn chi tiết điểm bán (#24707, chủ hệ thống chốt 02/11/2026):
/// - hiện trạng từng loại (dùng lại [MaterialCard]); chạm một loại ⇒ dòng thời gian thay đổi của loại đó;
/// - SỬA chỉ khi đang check-in tại CHÍNH điểm bán này ⇒ mở màn Vật tư của lượt (mọi thay đổi gắn một lượt — luật 30/10);
/// - mất mạng ⇒ bản lưu gần nhất kèm giờ cập nhật; loại có thao tác khai trong lượt còn chờ gửi gắn nhãn "Chờ đồng bộ".
///
/// Tài khoản không có quyền xem (403) ⇒ ẩn hẳn mục — kể cả khung: màn cha bọc nội dung qua [sectionBuilder].
class OutletMaterialsDetailCard extends ConsumerStatefulWidget {
  final int customerId;

  /// `client_uuid` của điểm bán — nhận lượt ngoại tuyến tạo khi điểm bán chưa có id ([VisitEntity.isAtCustomer]).
  final String? customerClientUuid;
  final String customerName;

  /// Bọc nội dung vào khung mục của màn cha (tiêu đề + viền + khoảng cách); không gọi khi bị ẩn.
  final Widget Function(Widget content) sectionBuilder;

  /// Màn cha tăng số này khi kéo làm mới ⇒ mục nạp lại.
  final int refreshToken;

  const OutletMaterialsDetailCard({
    super.key,
    required this.customerId,
    this.customerClientUuid,
    required this.customerName,
    required this.sectionBuilder,
    this.refreshToken = 0,
  });

  @override
  ConsumerState<OutletMaterialsDetailCard> createState() => _OutletMaterialsDetailCardState();
}

class _OutletMaterialsDetailCardState extends ConsumerState<OutletMaterialsDetailCard> {
  OutletMaterialsLoadResult? _result;
  bool _loading = true;

  /// Có lượt mở tại điểm bán này nhưng màn check-in chưa nạp lượt đó (vd mở lại app) ⇒ chỉ nhắc vào lại lượt.
  bool _openVisitHere = false;

  /// Số lượt nạp — kéo làm mới / có mạng lại / quay về từ màn Sửa có thể chồng nhau; chỉ lượt MỚI NHẤT được ghi kết quả.
  int _loadSeq = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OutletMaterialsDetailCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customerId != widget.customerId) {
      // Điểm bán khác ⇒ bỏ kết quả cũ (không hiện vật tư điểm bán trước dưới tên điểm bán mới).
      _result = null;
      _openVisitHere = false;
      _load();
    } else if (oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    setState(() => _loading = true);
    final res = await ref.read(visitMaterialRepositoryProvider).loadOutletView(widget.customerId);
    bool openHere = false;
    try {
      // Bản lưu lượt đang mở trên máy (KHÔNG qua findOpenVisit: nó dựng RouteViewModel ⇒ kéo tuyến từ mạng chỉ để đọc).
      final saved = await ref.read(visitRepositoryProvider).getActiveVisit();
      openHere = saved != null && saved.isOpen && saved.isAtCustomer(widget.customerId, widget.customerClientUuid);
    } catch (_) {}
    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _result = res;
      _openVisitHere = openHere;
      _loading = false;
    });
  }

  Future<void> _openEdit() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => VisitMaterialsScreen(customerId: widget.customerId, dealerName: widget.customerName),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    // Có mạng trở lại ⇒ nạp bản mới thay bản lưu.
    ref.listen<bool>(connectivityProvider.select((s) => s.isOnline), (prev, next) {
      if (prev == false && next) _load();
    });
    final res = _result;
    if (res != null && res.forbidden) return const SizedBox.shrink();

    final strings = ref.watch(stringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    final visit = ref.watch(checkInViewModelProvider.select((s) => s.visitEntity));
    // Màn Vật tư của lượt đọc lượt/phiên từ checkInViewModel ⇒ chỉ mở khi CHÍNH lượt đó đang nạp, đúng điểm bán này.
    final canEdit = visit != null && visit.isOpen && visit.isAtCustomer(widget.customerId, widget.customerClientUuid);

    final children = <Widget>[];
    if (_loading && res == null) {
      children.add(const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ));
    } else {
      final snapshot = res?.snapshot;
      if (res?.fromCache == true && res?.fetchedAt != null) {
        children.add(_note(Icons.cloud_off_rounded, strings.outletMaterialsCachedAt(shortLocalDateTime(res!.fetchedAt!)), subColor));
      }
      if (snapshot == null) {
        children.add(_note(Icons.info_outline_rounded, res?.error ?? strings.outletMaterialsNoCache, subColor));
      } else {
        // Máy chủ từ chối (4xx) nhưng còn bản lưu ⇒ vẫn nói ra.
        if (res!.error != null) children.add(_note(Icons.error_outline_rounded, res.error!, AppColors.error));
        final pending = res.pendingTypeIds;
        if (pending.isNotEmpty) {
          children.add(_note(Icons.sync_rounded, strings.outletMaterialsPendingNote(pending.length), AppColors.warning));
        }
        if (snapshot.items.isEmpty) {
          children.add(_note(Icons.inventory_2_outlined, strings.materialsEmpty, subColor));
        }
        for (final item in snapshot.items) {
          children.add(_row(item, snapshot.conditions, res, strings));
        }
      }
    }

    children.add(const SizedBox(height: 4));
    if (canEdit) {
      children.add(SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _openEdit,
          icon: const Icon(Icons.edit_rounded, size: 18),
          label: Text(strings.outletMaterialsEdit),
        ),
      ));
    } else {
      children.add(_note(
        Icons.lock_outline_rounded,
        _openVisitHere ? strings.outletMaterialsResumeHint : strings.outletMaterialsEditHint,
        subColor,
      ));
    }

    return widget.sectionBuilder(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children));
  }

  Widget _row(
    OutletMaterialView item,
    List<MaterialCondition> conditions,
    OutletMaterialsLoadResult res,
    AppStrings strings,
  ) {
    final footer = item.asOf != null && item.asOf!.length >= 10
        ? strings.materialsLastCheck(shortMaterialDateTime(item.asOf!), item.lastUserName)
        : null;
    // Cờ hiện ở đầu thẻ (thẻ thu gọn mặc định giấu chân thẻ).
    final chips = <Widget>[
      if (res.pendingTypeIds.contains(item.type.id))
        _chip(Icons.sync_rounded, strings.outletMaterialsPendingSync, AppColors.warning),
      if (item.hidden) _chip(Icons.visibility_off_outlined, strings.outletMaterialsHidden, AppColors.error),
      if (!item.type.isActive) _chip(Icons.block_rounded, strings.outletMaterialsTypeRetired, AppColors.outline),
    ];
    // Tên/đơn vị theo server; schema (nhãn lựa chọn, ô ảnh) mượn từ danh mục đã lưu nếu có.
    final type = withCatalogSchema(item.type, res.catalogTypes[item.type.id]);
    return MaterialCard(
      key: ValueKey(item.type.id),
      collapsible: true,
      strings: strings,
      type: type,
      detailLabels: item.detailLabels,
      conditions: conditions,
      counts: item.conditionCounts,
      details: item.details,
      status: MaterialCardStatus.none,
      action: chips.isEmpty
          ? null
          : Flexible(child: Wrap(alignment: WrapAlignment.end, spacing: 4, runSpacing: 4, children: chips)),
      footer: footer,
      onTap: () => showOutletMaterialHistory(
        context,
        customerId: widget.customerId,
        type: type,
        conditions: conditions,
      ),
    );
  }

  Widget _chip(IconData icon, String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
      );

  Widget _note(IconData icon, String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color, height: 1.35))),
        ]),
      );
}
