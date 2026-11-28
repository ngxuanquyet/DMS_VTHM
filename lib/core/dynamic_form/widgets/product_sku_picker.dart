import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../network/connectivity_provider.dart';
import '../../services/product_catalog_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/form_fields/form_field_parts.dart';

/// Ô chọn NHIỀU MÃ SKU hàng thành phẩm (ma trận SOS bật `own_skus`, 27/11/2026): thẻ mã đã chọn (nhãn gọn `kích thước · mã 5 số`,
/// mã ERP xám) + nút "Chọn mã" mở khung tìm trên danh mục TRONG MÁY ([ProductCatalogService] — chạy được khi mất sóng).
///
/// Giá trị = danh sách ảnh chụp `{id, code, name, size?, design?}`; server chỉ đọc `id` và dựng lại ảnh chụp. Mã đã lưu nay ngừng
/// dùng vẫn hiện từ ảnh chụp (không có trong danh mục).
class ProductSkuPicker extends ConsumerWidget {
  final String label;
  final bool isRequired;
  final List<Map<String, dynamic>> value;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;
  final bool readOnly;

  const ProductSkuPicker({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.isRequired = false,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    final thieu = isRequired && value.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormFieldLabel(label: label, isRequired: isRequired, asTextWidget: true),
        const SizedBox(height: kFormLabelGap),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final s in value)
              InputChip(
                key: ValueKey('sku_${s['id']}'),
                label: Text.rich(TextSpan(children: [
                  TextSpan(text: ProductSkuItem.labelOf(s)),
                  TextSpan(text: '  ${s['code'] ?? ''}', style: AppTypography.labelSmall(color: muted)),
                ])),
                onDeleted: readOnly ? null : () => onChanged([for (final x in value) if (x['id'] != s['id']) x]),
              ),
            if (!readOnly)
              OutlinedButton.icon(
                key: ValueKey('sku_add_$label'),
                onPressed: () => _open(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(value.isEmpty ? 'Chọn mã SKU' : 'Thêm mã'),
                style: thieu ? OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)) : null,
              ),
          ],
        ),
      ],
    );
  }

  /// Đang mở khung chọn — bấm liên tiếp không mở chồng khung (khung dưới giữ lựa chọn cũ, "Xong" sẽ đè lựa chọn khung trên).
  static bool _dangMo = false;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    if (_dangMo) return;
    _dangMo = true;
    try {
      final online = ref.read(connectivityProvider).isOnline;
      final svc = ref.read(productCatalogServiceProvider);
      // Có bản trong máy ⇒ mở NGAY, làm mới chạy ngầm; chưa có ⇒ phải chờ lượt tải đầu (khung báo nếu không tải được).
      var catalog = ProductCatalogService.memory;
      if (catalog == null) {
        catalog = await svc.load(online: online);
      } else {
        svc.refreshInBackground(online: online);
      }
      if (!context.mounted) return;
      final chon = await showModalBottomSheet<List<Map<String, dynamic>>>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _ProductSkuSheet(catalog: catalog, selected: value),
      );
      if (chon != null) onChanged(chon);
    } finally {
      _dangMo = false;
    }
  }
}

/// Khung tìm + chọn nhiều mã — bấm một dòng để bật/tắt, "Xong" trả danh sách mới.
class _ProductSkuSheet extends StatefulWidget {
  final ProductCatalog? catalog;
  final List<Map<String, dynamic>> selected;

  const _ProductSkuSheet({required this.catalog, required this.selected});

  @override
  State<_ProductSkuSheet> createState() => _ProductSkuSheetState();
}

class _ProductSkuSheetState extends State<_ProductSkuSheet> {
  late final List<Map<String, dynamic>> _chon = [for (final s in widget.selected) Map<String, dynamic>.from(s)];
  String _q = '';

  bool _co(int id) => _chon.any((s) => '${s['id']}' == '$id');

  @override
  Widget build(BuildContext context) {
    final catalog = widget.catalog;
    final kq = catalog?.search(_q) ?? const <ProductSkuItem>[];
    final muted = Theme.of(context).brightness == Brightness.dark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(child: Text('Chọn mã SKU (${_chon.length})', style: AppTypography.titleMedium())),
                  TextButton(
                    key: const ValueKey('sku_done'),
                    onPressed: () => Navigator.of(context).pop(_chon),
                    child: const Text('Xong'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const ValueKey('sku_search'),
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Gõ kích thước hoặc mã thiết kế 5 số (vd 600X600 08535)',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: catalog == null
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Chưa tải được danh mục mã hàng. Bật mạng rồi mở lại để tải lần đầu.',
                          style: AppTypography.bodyMedium(color: muted)),
                    )
                  : _q.trim().length < 2
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Gõ ít nhất 2 ký tự để tìm.', style: AppTypography.bodyMedium(color: muted)),
                        )
                      : kq.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('Không tìm thấy mã phù hợp.', style: AppTypography.bodyMedium(color: muted)),
                            )
                          : ListView.builder(
                              itemCount: kq.length,
                              itemBuilder: (_, i) {
                                final s = kq[i];
                                final co = _co(s.id);
                                return CheckboxListTile(
                                  key: ValueKey('sku_opt_${s.id}'),
                                  value: co,
                                  dense: true,
                                  title: Text(ProductSkuItem.labelOf(s.toJson())),
                                  subtitle: Text('${s.code} · ${s.name}', maxLines: 2, overflow: TextOverflow.ellipsis),
                                  onChanged: (_) => setState(() {
                                    if (co) {
                                      _chon.removeWhere((x) => '${x['id']}' == '${s.id}');
                                    } else {
                                      _chon.add(s.toJson());
                                    }
                                  }),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
