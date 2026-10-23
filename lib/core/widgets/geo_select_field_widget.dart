import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dynamic_form/models/dynamic_form_field.dart';
import '../dynamic_form/widgets/dynamic_form_field_wrapper.dart';
import '../services/geo_catalog_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/string_utils.dart';

/// Ô chọn TỈNH/THÀNH (`ref_province`) hoặc XÃ/PHƯỜNG (`ref_ward`) theo danh mục đơn vị hành chính (#24072).
///
/// Danh sách lấy từ danh mục đã lưu trên máy ([GeoCatalogService]) — CHẠY ĐƯỢC KHI MẤT MẠNG. Ô xã chỉ bày xã của
/// [provinceId] (tỉnh đang chọn ở ô cha), khoá lại khi chưa chọn tỉnh. Chỉ bày đơn vị CÒN DÙNG; giá trị đang giữ mà đã
/// tắt vẫn hiện tên kèm "(ngừng dùng)". Tìm KHÔNG DẤU ("viet tri" ra "Phường Việt Trì").
///
/// Giá trị là ID (số). Việc BỎ xã khi tỉnh đổi do màn chứa ô làm (nó biết ô nào phụ thuộc ô nào) — ô này chỉ hiện.
class GeoSelectFieldWidget extends ConsumerStatefulWidget {
  final DynamicFormField field;

  /// `true` = ô xã, `false` = ô tỉnh.
  final bool wardLevel;

  /// Tỉnh đang chọn ở ô cha — chỉ dùng khi [wardLevel].
  final int? provinceId;
  final dynamic value;
  final String? errorText;
  final ValueChanged<int?> onChanged;

  const GeoSelectFieldWidget({
    super.key,
    required this.field,
    required this.wardLevel,
    required this.value,
    required this.onChanged,
    this.provinceId,
    this.errorText,
  });

  /// Id từ giá trị ô (server có thể trả số hoặc chuỗi số); rác ⇒ null.
  static int? idOf(dynamic v) {
    if (v == null) return null;
    if (v is int) return v > 0 ? v : null;
    final n = int.tryParse(v.toString().trim());
    return n != null && n > 0 ? n : null;
  }

  @override
  ConsumerState<GeoSelectFieldWidget> createState() => _GeoSelectFieldWidgetState();
}

class _GeoSelectFieldWidgetState extends ConsumerState<GeoSelectFieldWidget> {
  GeoCatalog? _catalog;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _catalog = ref.read(geoCatalogServiceProvider).cached;
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() => _loading = true);
    final c = await ref.read(geoCatalogServiceProvider).load(force: force);
    if (!mounted) return;
    setState(() {
      _catalog = c;
      _loading = false;
    });
  }

  /// Đơn vị cho ô này: tỉnh, hoặc xã của tỉnh đang chọn.
  List<GeoUnit> _units() {
    final c = _catalog;
    if (c == null) return const [];
    return widget.wardLevel ? c.wardsOf(widget.provinceId) : c.provinces;
  }

  GeoUnit? _selected() {
    final id = GeoSelectFieldWidget.idOf(widget.value);
    final c = _catalog;
    if (id == null || c == null) return null;
    return widget.wardLevel ? c.ward(id) : c.province(id);
  }

  String _labelOf(GeoUnit u) => u.isActive ? u.fullName : '${u.fullName} (ngừng dùng)';

  void _openPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = GeoSelectFieldWidget.idOf(widget.value);
    final units = _units().where((u) => u.isActive || u.id == current).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GeoPickerSheet(
        title: widget.field.label,
        units: units,
        selectedId: current,
        isDark: isDark,
        labelOf: _labelOf,
        onSelected: (id) {
          Navigator.pop(ctx);
          widget.onChanged(id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _selected();
    final chuaChonTinh = widget.wardLevel && widget.provinceId == null;
    final chuaCoDanhMuc = _catalog == null;
    final khoa = widget.field.isReadOnly || chuaChonTinh || chuaCoDanhMuc;

    final String text;
    if (selected != null) {
      text = _labelOf(selected);
    } else if (chuaCoDanhMuc) {
      text = _loading ? 'Đang tải danh mục…' : 'Chưa có danh mục — kết nối mạng một lần để tải (chạm để thử lại)';
    } else if (chuaChonTinh) {
      text = 'Chọn tỉnh/thành trước';
    } else {
      text = widget.field.placeholder ?? 'Chọn ${widget.field.label.toLowerCase()}';
    }

    return DynamicFormFieldWrapper(
      field: widget.field,
      errorText: widget.errorText,
      child: InkWell(
        onTap: widget.field.isReadOnly
            ? null
            : (chuaCoDanhMuc && !_loading)
                ? () => _load(force: true)
                : (khoa ? null : _openPicker),
        borderRadius: AppRadius.roundedMd,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: khoa
                ? (isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHigh)
                : (isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest),
            borderRadius: AppRadius.roundedMd,
            border: Border.all(
              color: widget.errorText != null
                  ? AppColors.error
                  : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.wardLevel ? Icons.location_city_rounded : Icons.map_rounded,
                size: 18,
                color: selected != null
                    ? AppColors.primary
                    : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: AppTypography.bodyMedium(
                    color: selected != null
                        ? (isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                        : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline),
                  ),
                ),
              ),
              if (selected != null && !widget.field.isReadOnly)
                InkWell(
                  onTap: () => widget.onChanged(null),
                  child: Icon(Icons.clear_rounded, size: 18, color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline),
                )
              else
                Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bảng chọn có ô tìm KHÔNG DẤU.
class _GeoPickerSheet extends StatefulWidget {
  final String title;
  final List<GeoUnit> units;
  final int? selectedId;
  final bool isDark;
  final String Function(GeoUnit) labelOf;
  final ValueChanged<int> onSelected;

  const _GeoPickerSheet({
    required this.title,
    required this.units,
    required this.selectedId,
    required this.isDark,
    required this.labelOf,
    required this.onSelected,
  });

  @override
  State<_GeoPickerSheet> createState() => _GeoPickerSheetState();
}

class _GeoPickerSheetState extends State<_GeoPickerSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final rows = widget.units.where((u) => StringUtils.matchesSearch(u.fullName, _query)).toList();

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              widget.title,
              style: AppTypography.titleMedium(color: isDark ? AppColors.darkOnSurface : AppColors.onSurface),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Gõ để tìm (không cần dấu)…',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Flexible(
            child: rows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Không tìm thấy',
                      style: AppTypography.bodyMedium(color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final u = rows[i];
                      final chon = u.id == widget.selectedId;
                      return ListTile(
                        dense: true,
                        title: Text(widget.labelOf(u)),
                        trailing: chon ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                        onTap: () => widget.onSelected(u.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
