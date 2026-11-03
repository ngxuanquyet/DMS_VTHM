import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../route/domain/entities/route_entity.dart';
import '../../../../../core/widgets/geo_select_field_widget.dart';
import '../../../../route/presentation/providers/user_routes_provider.dart';

/// Ô "Tuyến bán hàng" (`ref_dms_route`) của biểu mẫu thị trường: chọn MỘT tuyến trong danh sách tuyến của NV.
/// Giá trị lưu = SỐ NGUYÊN id tuyến.
///
/// Tự điền: khi ô còn trống, lấy id đầu tiên trong [preferredIds] (tuyến của lượt viếng thăm / của điểm bán) CÓ trong
/// danh sách tuyến của NV — chỉ một lần, NV đổi được.
class RouteFieldWidget extends ConsumerStatefulWidget {
  final Widget label;
  final int? selectedId;
  final List<int> preferredIds;
  final InputDecoration decoration;
  final ValueChanged<int?> onChanged;

  const RouteFieldWidget({
    super.key,
    required this.label,
    required this.selectedId,
    required this.decoration,
    required this.onChanged,
    this.preferredIds = const [],
  });

  static const String emptyMessage = 'Chưa có danh sách tuyến — cần kết nối mạng để tải';

  /// Quy giá trị đang lưu (int / chuỗi số / null) về id tuyến — cùng luật [GeoSelectFieldWidget.idOf].
  static int? idOf(dynamic value) =>
      // Số lẻ (3.7) là dữ liệu hỏng — KHÔNG làm tròn thành tuyến 3 (tuyến thật khác).
      GeoSelectFieldWidget.idOf(value is num ? (value == value.truncate() ? value.toInt() : null) : value);

  @override
  ConsumerState<RouteFieldWidget> createState() => _RouteFieldWidgetState();
}

class _RouteFieldWidgetState extends ConsumerState<RouteFieldWidget> {
  bool _autofillDone = false;

  void _maybeAutofill(List<UserRouteEntity> routes) {
    if (_autofillDone) return;
    _autofillDone = true;
    if (widget.selectedId != null) return;
    final ids = routes.map((r) => r.id).toSet();
    final pick = widget.preferredIds.cast<int?>().firstWhere((id) => ids.contains(id), orElse: () => null);
    if (pick == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.selectedId == null) widget.onChanged(pick);
    });
  }

  /// Không có danh sách tuyến mà ô đang mang giá trị (nháp / tự điền trước đó) ⇒ HIỆN giá trị đó và cho bỏ chọn — giấu đi
  /// thì phiếu vẫn gửi tuyến người dùng không thấy.
  Widget _emptyWithSelection(bool isDark) {
    final selected = widget.selectedId;
    if (selected == null) return _message(isDark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _message(isDark),
        Row(
          children: [
            Expanded(child: Text('Đã chọn tuyến mã $selected (chưa kiểm được khi chưa có danh sách tuyến)')),
            TextButton(onPressed: () => widget.onChanged(null), child: const Text('Bỏ chọn')),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(userAssignedRoutesProvider);

    final Widget body = async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => _emptyWithSelection(isDark),
      data: (routes) {
        if (routes.isEmpty) return _emptyWithSelection(isDark);
        _maybeAutofill(routes);
        final selected = widget.selectedId;
        final known = selected == null || routes.any((r) => r.id == selected);
        return DropdownButtonFormField<int>(
          // initialValue chỉ đọc lần đầu ⇒ đổi key khi giá trị đổi từ ngoài (tự điền).
          key: ValueKey('route_${selected ?? 0}'),
          initialValue: selected,
          isExpanded: true,
          items: [
            ...routes.map((r) => DropdownMenuItem<int>(
                  value: r.id,
                  child: Text(_labelOf(r), overflow: TextOverflow.ellipsis),
                )),
            // Giá trị cũ (nháp) không còn trong danh sách tuyến: vẫn hiện để không mất lựa chọn.
            if (!known) DropdownMenuItem<int>(value: selected, child: Text('Tuyến #$selected')),
          ],
          style: AppTypography.bodyMedium(
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ),
          dropdownColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest,
          decoration: widget.decoration,
          onChanged: widget.onChanged,
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.label,
        const SizedBox(height: 8),
        body,
      ],
    );
  }

  static String _labelOf(UserRouteEntity r) {
    final code = r.code?.trim() ?? '';
    return code.isNotEmpty && code != r.name ? '${r.name} ($code)' : r.name;
  }

  Widget _message(bool isDark) {
    final error = widget.decoration.errorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          RouteFieldWidget.emptyMessage,
          style: AppTypography.bodySmall(
            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
          ).copyWith(fontStyle: FontStyle.italic),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(error, style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ),
      ],
    );
  }
}
