import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../choice_other.dart';
import '../models/dynamic_form_field.dart';
import 'choice_other_input.dart';
import '../../widgets/form_fields/form_field_parts.dart';
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
      return DynamicFormFieldWrapper(
        field: field,
        child: _withOther(FormDropdown<dynamic>(
          focusNode: focusNode,
          initialValue: _otherActive ? ChoiceOther.key : selectedOption?.value,
          isExpanded: true,
          readOnly: field.isReadOnly,
          hintText: field.placeholder ?? 'Chọn ${field.label.toLowerCase()}...',
          errorText: errorText,
          items: [...options, ?otherOption].map((opt) {
            return DropdownMenuItem<dynamic>(
              value: opt.value,
              child: Text(opt.label, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: field.isReadOnly ? null : (val) => _select(val),
        )),
      );
    }

    // Nếu options > 4 hoặc catalog != null, render ô chọn modal/bottomsheet tìm kiếm — trừ khi admin đặt "bày hết ra"
    // (`choiceDisplay == 'list'`, ô Kênh): luôn vẽ danh sách dù nhiều lựa chọn.
    if (field.choiceDisplay != 'list' && (options.length > 4 || field.catalog != null)) {
      final daChon = selectedOption != null || _otherActive;
      return DynamicFormFieldWrapper(
        field: field,
        child: _withOther(FormTapField(
          text: selectedOption?.label ??
              (_otherActive ? ChoiceOther.label : null) ??
              field.placeholder ??
              'Chọn ${field.label.toLowerCase()}',
          hasValue: daChon,
          hintText: 'Chọn ${field.label.toLowerCase()}',
          errorText: errorText,
          readOnly: field.isReadOnly,
          onTap: field.isReadOnly ? null : () => _showSearchablePicker(context),
          suffixIcon: daChon && !field.isReadOnly
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  tooltip: 'Bỏ chọn',
                  onPressed: () {
                    if (_otherActive) onOtherChanged!(null);
                    onChanged(null);
                  },
                )
              : const Icon(Icons.arrow_drop_down),
        )),
      );
    }

    // Ít lựa chọn (hoặc admin đặt "bày hết ra"): danh sách nút tròn trong khung — như biểu mẫu khảo sát.
    return DynamicFormFieldWrapper(
      field: field,
      gap: kFormLabelGapChoice,
      errorText: errorText,
      child: _withOther(FormRadioGroup(
        options: [...options, ?otherOption].map((o) => FormChoiceOption(o.value, o.label)).toList(),
        selectedKey: _otherActive ? ChoiceOther.key : selectedOption?.value.toString(),
        hasError: errorText != null,
        onChanged: field.isReadOnly ? null : _select,
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
