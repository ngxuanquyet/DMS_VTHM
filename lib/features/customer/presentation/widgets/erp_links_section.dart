import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/services/erp_catalog_service.dart';
import '../../../../core/services/erp_link_request_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_snackbar.dart';
import 'erp_link_picker_sheet.dart';

/// Mục "Khách hàng ERP" trên màn SỬA điểm bán (#24327): mối nối đã duyệt + đề xuất đang chờ + nút "Đề xuất thêm" (cần mạng).
/// Không bắt buộc như lúc tạo — điểm bán cũ (~8.900, chủ hệ thống chốt 27/10/2026) chỉ được NHẮC khi chưa nối khách nào.
/// Đề xuất gửi ngay (không qua nút Lưu của form), quản lý duyệt trên web.
class ErpLinksSection extends ConsumerStatefulWidget {
  /// `crm_customer.id` trên server (> 0).
  final int customerId;

  const ErpLinksSection({super.key, required this.customerId});

  @override
  ConsumerState<ErpLinksSection> createState() => _ErpLinksSectionState();
}

class _ErpLinksSectionState extends ConsumerState<ErpLinksSection> {
  Future<ErpLinkStateOfStore>? _tai;
  bool _dangGui = false;

  @override
  void initState() {
    super.initState();
    _napLai();
  }

  void _napLai() {
    if (!ref.read(connectivityProvider).isOnline) {
      _tai = null;
      return;
    }
    _tai = ref.read(erpLinkRequestServiceProvider).stateOf(widget.customerId).timeout(const Duration(seconds: 8));
  }

  Future<void> _deXuatThem(ErpLinkStateOfStore state) async {
    final catalog = await ref.read(erpCatalogServiceProvider).load(online: ref.read(connectivityProvider).isOnline);
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chon = await showModalBottomSheet<ErpLinkPickResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => ErpLinkPickerSheet(
        catalog: catalog,
        required: false,
        ownerTaken: state.ownerTaken,
        excludeCodes: state.codes,
      ),
    );
    if (chon == null || chon.picks.isEmpty || !mounted) return;

    setState(() => _dangGui = true);
    final svc = ref.read(erpLinkRequestServiceProvider);
    var ok = 0;
    Object? loi;
    for (final p in chon.picks) {
      try {
        await svc
            .propose(customerId: widget.customerId, erpPartnerCode: p.code, role: p.role, matchReason: p.matchReason)
            .timeout(const Duration(seconds: 8));
        ok++;
      } catch (e) {
        loi ??= e;
      }
    }
    if (!mounted) return;
    setState(() {
      _dangGui = false;
      _napLai();
    });
    if (loi != null) {
      AppSnackBar.showError(context, loi);
    }
    if (ok > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã gửi $ok đề xuất nối khách ERP, chờ quản lý duyệt.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chuChinh = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
    final chuPhu = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;

    Widget khung(List<Widget> children) => Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.link_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('Khách hàng ERP', style: AppTypography.titleMedium(color: chuChinh)),
            ]),
            const SizedBox(height: 8),
            ...children,
          ]),
        );

    if (_tai == null) {
      return khung([
        Text('Cần kết nối mạng để xem và đề xuất nối khách ERP.', style: AppTypography.bodySmall(color: chuPhu)),
        TextButton(key: const Key('erp-links-retry'), onPressed: () => setState(_napLai), child: const Text('Thử lại')),
      ]);
    }

    return FutureBuilder<ErpLinkStateOfStore>(
      future: _tai,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          // Chữ tĩnh, không vòng xoay: mục phụ của form, mạng treo thì không có gì chạy mãi dưới đáy màn hình.
          return khung([Text('Đang tải khách ERP của điểm bán…', style: AppTypography.bodySmall(color: chuPhu))]);
        }
        if (snap.hasError || snap.data == null) {
          return khung([
            Text('Không tải được khách ERP của điểm bán.', style: AppTypography.bodySmall(color: AppColors.error)),
            TextButton(onPressed: () => setState(_napLai), child: const Text('Thử lại')),
          ]);
        }
        final s = snap.data!;
        Widget dong(ErpLinkState l, {required bool cho}) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(cho ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
                    size: 16, color: cho ? AppColors.warning : AppColors.success),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${l.name ?? l.code} (${l.code}) · ${l.roleLabel}${cho ? ' · chờ duyệt' : ''}',
                    style: AppTypography.bodySmall(color: chuChinh),
                  ),
                ),
              ]),
            );
        return khung([
          if (s.links.isEmpty && s.pending.isEmpty)
            Text(
              s.unknown
                  ? 'Đã đánh dấu "Chưa xác định NPP" — đề xuất khách ERP khi đã biết.'
                  : 'Điểm bán chưa nối khách ERP nào.',
              style: AppTypography.bodySmall(color: AppColors.warning),
            ),
          for (final l in s.links) dong(l, cho: false),
          for (final l in s.pending) dong(l, cho: true),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            key: const Key('erp-links-add'),
            onPressed: _dangGui ? null : () => _deXuatThem(s),
            icon: _dangGui
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_link_rounded),
            label: const Text('Đề xuất thêm'),
          ),
        ]);
      },
    );
  }
}
