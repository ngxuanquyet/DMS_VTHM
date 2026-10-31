import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../choice_other.dart';
import '../models/dynamic_form_field.dart';
import 'choice_other_input.dart';
import 'dynamic_form_field_wrapper.dart';

class DynamicSingleChoiceFieldWidget extends StatelessWidget {
  final DynamicFormField field;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;
  final String? errorText;
  final FocusNode? focusNode;

  /// «Khác…» (ô bật [DynamicFormField.allowOther], xem [ChoiceOther]): chuỗi đang gõ khi đang chọn «Khác…» (có thể
  /// rỗng), `null` = không chọn. Màn chứa giữ trạng thái này; [value] luôn là giá trị THẬT.
  final String? otherText;

  /// Bật «Khác…» (`''`), gõ (chuỗi đã trim) hoặc bỏ «Khác…» (`null`); `null` = ô không có «Khác…».
  final ValueChanged<String?>? onOtherChanged;

  const DynamicSingleChoiceFieldWidget({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.focusNode,
    this.otherText,
    this.onOtherChanged,
  });

  bool get _showOther => field.allowOther && onOtherChanged != null;
  bool get _otherActive => _showOther && otherText != null;

  /// Chọn một mục — [ChoiceOther.key] là mục «Khác…» (chỉ bật ô gõ, không ghi giá trị giả).
  void _select(dynamic val) {
    if (val == ChoiceOther.key) {
      if (!_otherActive) onOtherChanged!('');
      return;
    }
    if (_otherActive) onOtherChanged!(null);
    onChanged(val);
  }

  /// Ghép ô gõ «Khác» dưới ô chọn khi đang chọn «Khác…».
  Widget _withOther(Widget child) {
    if (!_otherActive) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        ChoiceOtherInput(
          key: ValueKey('choice_other_${field.code}'),
          initialText: otherText,
          enabled: !field.isReadOnly,
          onChanged: onOtherChanged!,
        ),
      ],
    );
  }

  void _showSearchablePicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _SearchableOptionPickerSheet(
          field: field,
          selectedValue: _otherActive ? ChoiceOther.key : value,
          showOther: _showOther,
          onSelected: (selectedVal) {
            Navigator.pop(ctx);
            _select(selectedVal);
          },
          isDark: isDark,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = field.options;

    // Lấy label của item đang chọn (nếu có)
    final selectedOption = _otherActive
        ? null
        : options.cast<DynamicFormOption?>().firstWhere(
            (o) => (o?.value == value || o?.value.toString() == value?.toString()) &&
                value != null &&
                value.toString().trim().isNotEmpty,
            orElse: () => null,
          );
    final otherOption =
        _showOther ? const DynamicFormOption(label: ChoiceOther.label, value: ChoiceOther.key) : null;

    // 🔴 Hiển thị dạng Dropdown nếu là trường tuyến bán hàng (route_ids/route_id) hoặc được cấu hình dropdown/badge Danh sách chọn
    final isDropdown = field.code == 'route_ids' ||
        field.code == 'route_id' ||
        field.catalog == 'dropdown' ||
        field.choiceDisplay == 'dropdown' ||
        field.catalog == 'route' ||
        field.source == 'dropdown' ||
        field.badge == 'Danh sách chọn' ||
        field.code.startsWith('nhan_') ||
        field.code == 'khach_hang_vthm';

    if (isDropdown) {
      final isRoute = field.code.contains('route');
      return DynamicFormFieldWrapper(
        field: field,
        errorText: errorText,
        child: _withOther(DropdownButtonFormField<dynamic>(
          focusNode: focusNode,
          initialValue: _otherActive ? ChoiceOther.key : selectedOption?.value,
          isDense: true,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
          ),
          dropdownColor: isDark ? AppColors.darkSurfaceContainer : Colors.white,
          borderRadius: AppRadius.roundedMd,
          style: AppTypography.bodyMedium(
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ).copyWith(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            prefixIcon: Icon(
              isRoute ? Icons.alt_route_rounded : Icons.arrow_drop_down_circle_outlined,
              size: 20,
              color: selectedOption != null
                  ? AppColors.primary
                  : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline),
            ),
            hintText: field.placeholder ?? 'Chọn ${field.label.toLowerCase()}...',
            hintStyle: AppTypography.bodyMedium(
              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
            ),
            filled: true,
            fillColor: field.isReadOnly
                ? (isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHigh)
                : (isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest),
            border: OutlineInputBorder(
              borderRadius: AppRadius.roundedMd,
              borderSide: BorderSide(
                color: errorText != null
                    ? AppColors.error
                    : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.roundedMd,
              borderSide: BorderSide(
                color: errorText != null
                    ? AppColors.error
                    : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.roundedMd,
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppRadius.roundedMd,
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
          hint: Text(
            field.placeholder ?? 'Chọn ${field.label.toLowerCase()}...',
            style: AppTypography.bodyMedium(
              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
            ),
          ),
          items: [...options, ?otherOption].map((opt) {
            return DropdownMenuItem<dynamic>(
              value: opt.value,
              child: Row(
                children: [
                  if (opt.icon != null) ...[
                    Icon(opt.icon, size: 16, color: opt.color ?? AppColors.primary),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      opt.label,
                      style: AppTypography.bodyMedium(
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: field.isReadOnly ? null : (val) => _select(val),
        )),
      );
    }

    // Nếu options > 4 hoặc catalog != null, render ô chọn modal/bottomsheet tìm kiếm — trừ khi admin đặt "bày hết ra"
    // (`choiceDisplay == 'list'`, ô Kênh): luôn vẽ nút chọn bên dưới dù nhiều lựa chọn.
    if (field.choiceDisplay != 'list' && (options.length > 4 || field.catalog != null)) {
      return DynamicFormFieldWrapper(
        field: field,
        errorText: errorText,
        child: _withOther(InkWell(
          onTap: field.isReadOnly ? null : () => _showSearchablePicker(context),
          borderRadius: AppRadius.roundedMd,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: field.isReadOnly
                  ? (isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHigh)
                  : (isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest),
              borderRadius: AppRadius.roundedMd,
              border: Border.all(
                color: errorText != null
                    ? AppColors.error
                    : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.arrow_drop_down_circle_outlined,
                  size: 18,
                  color: selectedOption != null
                      ? AppColors.primary
                      : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selectedOption?.label ??
                        (_otherActive ? ChoiceOther.label : null) ??
                        field.placeholder ??
                        'Chọn ${field.label.toLowerCase()}',
                    style: AppTypography.bodyMedium(
                      color: selectedOption != null
                          ? (isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                          : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline),
                    ).copyWith(
                      fontWeight: selectedOption != null ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if ((selectedOption != null || _otherActive) && !field.isReadOnly)
                  GestureDetector(
                    onTap: () {
                      if (_otherActive) onOtherChanged!(null);
                      onChanged(null);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.cancel_rounded,
                        size: 16,
                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
                      ),
                    ),
                  ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
                ),
              ],
            ),
          ),
        )),
      );
    }

    // Nếu options <= 4, render dạng các nút Chip / Radio cards trực quan
    return DynamicFormFieldWrapper(
      field: field,
      errorText: errorText,
      child: _withOther(Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [...options, ?otherOption].map((opt) {
          final isSelected = opt.value == ChoiceOther.key
              ? _otherActive
              : !_otherActive && (opt.value == value || opt.value.toString() == value?.toString());
          return InkWell(
            onTap: field.isReadOnly ? null : () => _select(opt.value),
            borderRadius: AppRadius.roundedMd,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? AppColors.primary : AppColors.primaryContainer)
                    : (isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest),
                borderRadius: AppRadius.roundedMd,
                border: Border.all(
                  color: isSelected
                      ? (isDark ? AppColors.primary : AppColors.primaryContainer)
                      : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
                  width: isSelected ? 1.5 : 1.0,
                ),
                boxShadow: isSelected ? AppShadows.level1 : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    opt.label,
                    style: AppTypography.bodySmall(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppColors.darkOnSurface : AppColors.onSurface),
                    ).copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      )),
    );
  }
}

class _SearchableOptionPickerSheet extends StatefulWidget {
  final DynamicFormField field;
  final dynamic selectedValue;
  final ValueChanged<dynamic> onSelected;
  final bool isDark;

  /// Thêm mục «Khác…» ở cuối danh sách (luôn hiện, không lọc theo ô tìm).
  final bool showOther;

  const _SearchableOptionPickerSheet({
    required this.field,
    required this.selectedValue,
    required this.onSelected,
    required this.isDark,
    this.showOther = false,
  });

  @override
  State<_SearchableOptionPickerSheet> createState() => _SearchableOptionPickerSheetState();
}

class _SearchableOptionPickerSheetState extends State<_SearchableOptionPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final options = widget.field.options;

    final filtered = options.where((o) {
      if (_query.trim().isEmpty) return true;
      return o.label.toLowerCase().contains(_query.trim().toLowerCase());
    }).toList();
    if (widget.showOther) filtered.add(const DynamicFormOption(label: ChoiceOther.label, value: ChoiceOther.key));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            offset: Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                borderRadius: AppRadius.roundedFull,
              ),
            ),
            const SizedBox(height: 12),

            // Header Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: AppRadius.roundedSm,
                    ),
                    child: const Icon(
                      Icons.format_list_bulleted_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.field.label,
                          style: AppTypography.titleMedium(
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${options.length} tùy chọn khả dụng',
                          style: AppTypography.bodySmall(
                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search Bar (if options > 6)
            if (options.length > 6) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceContainerLowest
                        : AppColors.surfaceContainerHigh.withValues(alpha: 0.4),
                    borderRadius: AppRadius.roundedMd,
                    border: Border.all(
                      color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                    ),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    style: AppTypography.bodyMedium(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm ${widget.field.label.toLowerCase()}...',
                      hintStyle: AppTypography.bodySmall(
                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      filled: false,
                      fillColor: Colors.transparent,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            const Divider(height: 1),

            // Options List
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        'Không tìm thấy tùy chọn phù hợp',
                        style: AppTypography.bodyMedium(
                          color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: isDark
                            ? AppColors.darkOutlineVariant.withValues(alpha: 0.3)
                            : AppColors.outlineVariant.withValues(alpha: 0.3),
                      ),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isSelected = item.value == widget.selectedValue ||
                            item.value.toString() == widget.selectedValue?.toString();

                        return ListTile(
                          onTap: () => widget.onSelected(item.value),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                          title: Text(
                            item.label,
                            style: AppTypography.bodyMedium(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark ? AppColors.darkOnSurface : AppColors.onSurface),
                            ).copyWith(
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                            ),
                          ),
                          trailing: isSelected
                              ? Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
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
