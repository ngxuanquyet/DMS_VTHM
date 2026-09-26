import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../data/models/market_form_submission_model.dart';
import '../../../domain/entities/market_form_entity.dart';
import '../../../domain/services/dynamic_rule_evaluator.dart';
import 'currency_field_widget.dart';
import 'ref_customer_field_widget.dart';

class MarketFormRenderer extends StatefulWidget {
  final List<MarketFormBlockEntity> blocks;
  final Map<String, dynamic> initialAnswers;
  final Map<String, dynamic> customerContext;
  final ValueChanged<Map<String, dynamic>>? onChanged;
  final int? defaultCustomerId;
  final String? defaultCustomerName;

  const MarketFormRenderer({
    super.key,
    required this.blocks,
    this.initialAnswers = const {},
    this.customerContext = const {},
    this.onChanged,
    this.defaultCustomerId,
    this.defaultCustomerName,
  });

  @override
  State<MarketFormRenderer> createState() => MarketFormRendererState();
}

class MarketFormRendererState extends State<MarketFormRenderer> {
  final Map<String, dynamic> _answers = {};
  final Map<String, String> _errors = {};
  Map<String, bool> _visibilityMap = {};

  @override
  void initState() {
    super.initState();
    _answers.addAll(widget.initialAnswers);

    // Tự động gán defaultCustomerId cho các ô ref_customer nếu chưa có câu trả lời
    if (widget.defaultCustomerId != null) {
      for (final block in widget.blocks) {
        if (block.resolved.inputType.toLowerCase() == 'ref_customer') {
          final code = block.resolved.code;
          if (!_answers.containsKey(code) || _answers[code] == null) {
            _answers[code] = widget.defaultCustomerId;
          }
        }
      }
    }

    _recomputeVisibility();
  }

  @override
  void didUpdateWidget(covariant MarketFormRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blocks != widget.blocks ||
        oldWidget.customerContext != widget.customerContext) {
      _recomputeVisibility();
    }
  }

  /// Tính toán lại trạng thái ẩn/hiện của tất cả các block theo quy tắc §3 & §7
  void _recomputeVisibility() {
    _visibilityMap = DynamicRuleEvaluator.computeVisibility(
      blocks: widget.blocks,
      answers: _answers,
      customerContext: widget.customerContext,
    );
  }

  /// Trả về bản sao các câu trả lời hiện tại
  Map<String, dynamic> get currentAnswers => Map<String, dynamic>.from(_answers);

  /// Danh sách các mã code thuộc nhóm trình bày (không thu dữ liệu)
  Set<String> get _presentationCodes {
    return widget.blocks
        .where((b) => b.isPresentation)
        .map((b) => b.resolved.code)
        .toSet();
  }

  /// Kiểm tra điều kiện show_if của một block (dựa trên visibility map đã duyệt theo thứ tự)
  bool _isBlockVisible(MarketFormBlockEntity block) {
    final code = block.resolved.code;
    final ref = block.ref;
    return _visibilityMap[code] ?? _visibilityMap[ref] ?? true;
  }

  /// Validate toàn bộ form và trả về câu trả lời đã làm sạch (hoặc null nếu có lỗi)
  Map<String, dynamic>? validateAndGetAnswers() {
    _recomputeVisibility();
    final Map<String, String> newErrors = {};

    for (final block in widget.blocks) {
      if (block.isPresentation) continue;
      // Ô đang ẩn được MIỄN kiểm tra bắt buộc (§5)
      if (!_isBlockVisible(block)) continue;

      final code = block.resolved.code;
      final val = _answers[code];
      final label = block.resolved.label.isNotEmpty ? block.resolved.label : code;

      // 1. Kiểm tra bắt buộc (required) - 0, "0", false không phải rỗng (§2 Luật 1)
      final isEmpty = DynamicRuleEvaluator.isEmptyValue(val);

      if (block.required && isEmpty) {
        newErrors[code] = '$label không được để trống.';
        continue;
      }

      // 2. Kiểm tra validation nếu có giá trị
      if (!isEmpty && block.resolved.validation != null) {
        final v = block.resolved.validation!;
        if (val is num) {
          if (v.min != null && val < v.min!) {
            newErrors[code] = '$label tối thiểu là ${v.min}.';
          } else if (v.max != null && val > v.max!) {
            newErrors[code] = '$label tối đa là ${v.max}.';
          }
        } else if (val is String) {
          if (v.minLength != null && val.trim().length < v.minLength!) {
            newErrors[code] = '$label phải có ít nhất ${v.minLength} ký tự.';
          } else if (v.maxLength != null && val.trim().length > v.maxLength!) {
            newErrors[code] = '$label không được vượt quá ${v.maxLength} ký tự.';
          }
        }
      }
    }

    setState(() {
      _errors.clear();
      _errors.addAll(newErrors);
    });

    if (newErrors.isNotEmpty) {
      return null;
    }

    // Lấy danh sách các mã trường đang hiển thị để loại bỏ ô ẩn khi nộp (§5, §9)
    final visibleCodes = widget.blocks
        .where((b) => !b.isPresentation && _isBlockVisible(b))
        .map((b) => b.resolved.code)
        .toSet();

    // Làm sạch: Bỏ các trường rỗng, ô trình bày, và ô đang ẩn (§5, §9)
    return MarketFormSubmissionModel.sanitizeAnswers(
      _answers,
      presentationCodes: _presentationCodes,
      allowedCodes: visibleCodes,
    );
  }

  void _updateValue(String code, dynamic value) {
    setState(() {
      if (value == null || (value is String && value.isEmpty)) {
        _answers.remove(code);
      } else {
        _answers[code] = value;
      }
      _errors.remove(code);
      _recomputeVisibility();
    });
    widget.onChanged?.call(_answers);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final visibleBlocks = widget.blocks.where(_isBlockVisible).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: visibleBlocks.map((block) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.stackMd),
          child: _buildBlock(context, block, isDark),
        );
      }).toList(),
    );
  }

  Widget _buildBlock(
    BuildContext context,
    MarketFormBlockEntity block,
    bool isDark,
  ) {
    final type = block.resolved.inputType.toLowerCase();

    switch (type) {
      case 'heading':
        return _buildHeading(block, isDark);
      case 'divider':
        return const Divider(height: 24, thickness: 1);
      case 'note':
        return _buildNote(block, isDark);
      case 'text':
        return _buildTextField(block, isDark, isMultiline: false);
      case 'textarea':
        return _buildTextField(block, isDark, isMultiline: true);
      case 'number':
        return _buildNumberField(block, isDark);
      case 'currency':
        return CurrencyFieldWidget(
          block: block,
          initialValue: _answers[block.resolved.code] as num?,
          errorText: _errors[block.resolved.code],
          onChanged: (val) => _updateValue(block.resolved.code, val),
        );
      case 'boolean':
        return _buildBooleanField(block, isDark);
      case 'checkbox':
        return _buildCheckboxField(block, isDark);
      case 'radio':
        return _buildRadioField(block, isDark);
      case 'select':
        return _buildSelectField(block, isDark);
      case 'multiselect':
        return _buildMultiSelectField(block, isDark);
      case 'date':
        return _buildDateField(context, block, isDark);
      case 'file':
        return _buildFileField(context, block, isDark);
      case 'ref_customer':
        final currentVal = _answers[block.resolved.code];
        final int? selectedId = currentVal is int
            ? currentVal
            : (currentVal != null ? int.tryParse(currentVal.toString()) : null);
        return RefCustomerFieldWidget(
          block: block,
          selectedId: selectedId,
          errorText: _errors[block.resolved.code],
          defaultCustomerName: widget.defaultCustomerName,
          onChanged: (val) => _updateValue(block.resolved.code, val),
        );
      default:
        return _buildTextField(block, isDark, isMultiline: false);
    }
  }

  // ==========================================
  // NHÓM TRÌNH BÀY (HEADING / NOTE / DIVIDER)
  // ==========================================

  Widget _buildHeading(MarketFormBlockEntity block, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.label_important_rounded,
            size: 20,
            color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              block.resolved.label,
              style: AppTypography.titleMedium(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNote(MarketFormBlockEntity block, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainer
            : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 20, color: AppColors.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              block.resolved.label.isNotEmpty
                  ? block.resolved.label
                  : (block.resolved.description ?? ''),
              style: AppTypography.bodyMedium(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Ô NHẬP VĂN BẢN (TEXT & TEXTAREA)
  // ==========================================

  Widget _buildTextField(
    MarketFormBlockEntity block,
    bool isDark, {
    required bool isMultiline,
  }) {
    final code = block.resolved.code;
    final initial = _answers[code]?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(block, isDark),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: initial,
          maxLines: isMultiline ? 4 : 1,
          minLines: isMultiline ? 3 : 1,
          keyboardType: isMultiline ? TextInputType.multiline : TextInputType.text,
          style: AppTypography.bodyMedium(
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ),
          decoration: _inputDecoration(
            hintText: 'Nhập ${block.resolved.label.toLowerCase()}...',
            isDark: isDark,
            errorText: _errors[code],
          ),
          onChanged: (val) => _updateValue(code, val),
        ),
      ],
    );
  }

  // ==========================================
  // Ô NHẬP SỐ (NUMBER)
  // ==========================================

  Widget _buildNumberField(MarketFormBlockEntity block, bool isDark) {
    final code = block.resolved.code;
    final initial = _answers[code]?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(block, isDark),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: initial,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppTypography.bodyMedium(
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ),
          decoration: _inputDecoration(
            hintText: 'Nhập số...',
            isDark: isDark,
            errorText: _errors[code],
          ),
          onChanged: (val) {
            final parsed = num.tryParse(val);
            _updateValue(code, parsed);
          },
        ),
      ],
    );
  }

  // ==========================================
  // Ô BẬT TẮT (BOOLEAN)
  // ==========================================

  Widget _buildBooleanField(MarketFormBlockEntity block, bool isDark) {
    final code = block.resolved.code;
    final current = _answers[code] == true;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _errors.containsKey(code)
              ? AppColors.error
              : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
        ),
      ),
      child: SwitchListTile(
        title: _buildLabel(block, isDark),
        value: current,
        activeThumbColor: AppColors.primary,
        onChanged: (val) => _updateValue(code, val),
      ),
    );
  }

  // ==========================================
  // Ô CHỌN MỘT (RADIO)
  // ==========================================

  Widget _buildRadioField(MarketFormBlockEntity block, bool isDark) {
    final code = block.resolved.code;
    final current = _answers[code];
    final options = block.resolved.options;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(block, isDark),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _errors.containsKey(code)
                  ? AppColors.error
                  : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
            ),
          ),
          child: Column(
            children: options.map((opt) {
              // ignore: deprecated_member_use
              return RadioListTile<String>(
                title: Text(
                  opt.label,
                  style: AppTypography.bodyMedium(
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ),
                ),
                value: opt.value,
                // ignore: deprecated_member_use
                groupValue: current?.toString(),
                activeColor: AppColors.primary,
                // ignore: deprecated_member_use
                onChanged: (val) => _updateValue(code, val),
              );
            }).toList(),
          ),
        ),
        if (_errors.containsKey(code)) _buildErrorText(_errors[code]!),
      ],
    );
  }

  // ==========================================
  // Ô CHỌN NHIỀU (CHECKBOX)
  // ==========================================

  Widget _buildCheckboxField(MarketFormBlockEntity block, bool isDark) {
    final code = block.resolved.code;
    final currentList = (_answers[code] as List?)?.map((e) => e.toString()).toList() ?? [];
    final options = block.resolved.options;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(block, isDark),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _errors.containsKey(code)
                  ? AppColors.error
                  : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
            ),
          ),
          child: Column(
            children: options.map((opt) {
              final isChecked = currentList.contains(opt.value);
              return CheckboxListTile(
                title: Text(
                  opt.label,
                  style: AppTypography.bodyMedium(
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ),
                ),
                value: isChecked,
                activeColor: AppColors.primary,
                onChanged: (checked) {
                  final updated = List<String>.from(currentList);
                  if (checked == true) {
                    updated.add(opt.value);
                  } else {
                    updated.remove(opt.value);
                  }
                  _updateValue(code, updated);
                },
              );
            }).toList(),
          ),
        ),
        if (_errors.containsKey(code)) _buildErrorText(_errors[code]!),
      ],
    );
  }

  // ==========================================
  // Ô SELECT (DROPDOWN CHỌN MỘT)
  // ==========================================

  Widget _buildSelectField(MarketFormBlockEntity block, bool isDark) {
    final code = block.resolved.code;
    final current = _answers[code]?.toString();
    final options = block.resolved.options;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(block, isDark),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: options.any((o) => o.value == current) ? current : null,
          items: options
              .map((o) => DropdownMenuItem(
                    value: o.value,
                    child: Text(o.label),
                  ))
              .toList(),
          style: AppTypography.bodyMedium(
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ),
          dropdownColor:
              isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest,
          decoration: _inputDecoration(
            hintText: 'Chọn một giá trị...',
            isDark: isDark,
            errorText: _errors[code],
          ),
          onChanged: (val) => _updateValue(code, val),
        ),
      ],
    );
  }

  // ==========================================
  // Ô MULTISELECT (CHIPS CHỌN NHIỀU)
  // ==========================================

  Widget _buildMultiSelectField(MarketFormBlockEntity block, bool isDark) {
    final code = block.resolved.code;
    final currentList = (_answers[code] as List?)?.map((e) => e.toString()).toList() ?? [];
    final options = block.resolved.options;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(block, isDark),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final isSelected = currentList.contains(opt.value);
            return FilterChip(
              label: Text(opt.label),
              selected: isSelected,
              selectedColor: isDark
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.primaryContainer.withValues(alpha: 0.3),
              checkmarkColor: isDark ? AppColors.primaryFixedDim : AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected
                    ? (isDark ? AppColors.primaryFixedDim : AppColors.primary)
                    : (isDark ? AppColors.darkOnSurface : AppColors.onSurface),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              onSelected: (selected) {
                final updated = List<String>.from(currentList);
                if (selected) {
                  updated.add(opt.value);
                } else {
                  updated.remove(opt.value);
                }
                _updateValue(code, updated);
              },
            );
          }).toList(),
        ),
        if (_errors.containsKey(code)) _buildErrorText(_errors[code]!),
      ],
    );
  }

  // ==========================================
  // Ô CHỌN NGÀY (DATE)
  // ==========================================

  Widget _buildDateField(
    BuildContext context,
    MarketFormBlockEntity block,
    bool isDark,
  ) {
    final code = block.resolved.code;
    final current = _answers[code]?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(block, isDark),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final initialDate = current != null
                ? (DateTime.tryParse(current) ?? DateTime.now())
                : DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) {
              final formatted =
                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              _updateValue(code, formatted);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: InputDecorator(
            decoration: _inputDecoration(
              hintText: 'Chọn ngày...',
              isDark: isDark,
              errorText: _errors[code],
              suffixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
            ),
            child: Text(
              current ?? 'Chưa chọn ngày',
              style: AppTypography.bodyMedium(
                color: current != null
                    ? (isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                    : (isDark ? AppColors.darkOutline : AppColors.outlineVariant),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // Ô FILE / CHỤP ẢNH
  // ==========================================

  Widget _buildFileField(
    BuildContext context,
    MarketFormBlockEntity block,
    bool isDark,
  ) {
    final code = block.resolved.code;
    final currentPath = _answers[code]?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(block, isDark),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _errors.containsKey(code)
                  ? AppColors.error
                  : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              if (currentPath != null && currentPath.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: File(currentPath).existsSync()
                      ? Image.file(
                          File(currentPath),
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 54,
                          height: 54,
                          color: AppColors.primaryContainer,
                          child: const Icon(Icons.attach_file, color: Colors.white),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    currentPath.split(Platform.pathSeparator).last,
                    style: AppTypography.bodySmall(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.error),
                  onPressed: () => _updateValue(code, null),
                ),
              ] else ...[
                Expanded(
                  child: Text(
                    'Chưa có ảnh/tệp đính kèm',
                    style: AppTypography.bodySmall(
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Chụp ảnh'),
                  onPressed: () async {
                    final picker = ImagePicker();
                    final photo = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 80,
                    );
                    if (photo != null) {
                      _updateValue(code, photo.path);
                    }
                  },
                ),
              ],
            ],
          ),
        ),
        if (_errors.containsKey(code)) _buildErrorText(_errors[code]!),
      ],
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================

  Widget _buildLabel(MarketFormBlockEntity block, bool isDark) {
    return RichText(
      text: TextSpan(
        text: block.resolved.label,
        style: AppTypography.titleMedium(
          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
        ).copyWith(fontWeight: FontWeight.w600, fontSize: 14),
        children: [
          if (block.required)
            const TextSpan(
              text: ' *',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorText(String error) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Text(
        error,
        style: const TextStyle(color: AppColors.error, fontSize: 12),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required bool isDark,
    String? errorText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTypography.bodyMedium(
        color: isDark ? AppColors.darkOutline : AppColors.outlineVariant,
      ),
      errorText: errorText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor:
          isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}
