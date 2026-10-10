import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../data/models/form_photo_model.dart';
import '../../../data/models/market_form_submission_model.dart';
import '../../../domain/entities/market_form_entity.dart';
import '../../../domain/services/dynamic_rule_evaluator.dart';
import 'currency_field_widget.dart';
import 'ref_customer_field_widget.dart';
import '../../../../../core/widgets/voice_input_mic_button.dart';
import '../../../../../core/widgets/camera_permission_dialog.dart';

/// Mục ảnh quản lý trạng thái tải lên và hiển thị cục bộ
class FormPhotoEntry {
  final String localPath;
  String? token;
  String? previewUrl;
  bool isUploading;
  String? uploadError;

  FormPhotoEntry({
    required this.localPath,
    this.token,
    this.previewUrl,
    this.isUploading = false,
    this.uploadError,
  });

  String get fullPreviewUrl {
    if (previewUrl == null || previewUrl!.isEmpty) return '';
    if (previewUrl!.startsWith('http://') || previewUrl!.startsWith('https://')) {
      return previewUrl!;
    }
    final clean = previewUrl!.startsWith('/') ? previewUrl! : '/$previewUrl';
    return '${AppConstants.baseUrl}$clean';
  }
}

class MarketFormRenderer extends StatefulWidget {
  final List<MarketFormBlockEntity> blocks;
  final Map<String, dynamic> initialAnswers;
  final Map<String, dynamic> customerContext;
  final ValueChanged<Map<String, dynamic>>? onChanged;
  final int? defaultCustomerId;
  final String? defaultCustomerName;
  final String? defaultCustomerCode;
  final String? defaultCustomerAddress;
  final bool lockCustomer;
  final int defaultMaxPhotos;
  final Future<FormPhotoModel> Function(File file)? onUploadPhoto;

  const MarketFormRenderer({
    super.key,
    required this.blocks,
    this.initialAnswers = const {},
    this.customerContext = const {},
    this.onChanged,
    this.defaultCustomerId,
    this.defaultCustomerName,
    this.defaultCustomerCode,
    this.defaultCustomerAddress,
    this.lockCustomer = false,
    this.defaultMaxPhotos = 10,
    this.onUploadPhoto,
  });

  @override
  State<MarketFormRenderer> createState() => MarketFormRendererState();
}

class MarketFormRendererState extends State<MarketFormRenderer> {
  final Map<String, dynamic> _answers = {};
  final Map<String, String> _errors = {};
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, List<FormPhotoEntry>> _photoEntries = {};
  Map<String, bool> _visibilityMap = {};

  TextEditingController _getController(String code, String initial) {
    if (!_textControllers.containsKey(code)) {
      _textControllers[code] = TextEditingController(text: initial);
    }
    return _textControllers[code]!;
  }

  /// Trả về bản đồ đường dẫn ảnh cục bộ trên máy phục vụ lưu trữ offline (§5)
  Map<String, List<String>> getLocalPhotoPaths() {
    final Map<String, List<String>> map = {};
    _photoEntries.forEach((code, entries) {
      final paths = entries
          .map((e) => e.localPath)
          .where((p) => p.isNotEmpty)
          .toList();
      if (paths.isNotEmpty) {
        map[code] = paths;
      }
    });
    return map;
  }

  int _resolveMaxFiles(MarketFormBlockEntity block) {
    if (block.resolved.maxFiles > 0) {
      return block.resolved.maxFiles.clamp(1, 10);
    }
    return widget.defaultMaxPhotos.clamp(1, 10);
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isCustomerBlock(MarketFormBlockEntity block) {
    final type = block.resolved.inputType.toLowerCase();
    if (type == 'ref_customer') return true;
    final code = block.resolved.code.toLowerCase();
    return code == 'customer_id' ||
        code == 'khach_hang_id' ||
        code == 'diem_ban_khao_sat';
  }

  bool _isCustomerNameBlock(MarketFormBlockEntity block) {
    final code = block.resolved.code.toLowerCase();
    return code == 'customer_name' ||
        code == 'ten_khach_hang' ||
        code == 'ten_diem_ban';
  }

  bool _isCustomerCodeBlock(MarketFormBlockEntity block) {
    final code = block.resolved.code.toLowerCase();
    return code == 'customer_code' ||
        code == 'ma_khach_hang' ||
        code == 'ma_diem_ban';
  }

  @override
  void initState() {
    super.initState();
    _answers.addAll(widget.initialAnswers);

    // Khởi tạo danh sách ảnh cho các ô ảnh / tệp từ initialAnswers
    for (final block in widget.blocks) {
      if (block.isImage || block.resolved.inputType.toLowerCase() == 'file') {
        final code = block.resolved.code;
        final rawVal = _answers[code];
        final List<FormPhotoEntry> entries = [];
        if (rawVal is List) {
          for (final item in rawVal) {
            final str = item.toString().trim();
            if (str.isEmpty) continue;
            if (str.length == 32 && !str.contains('/') && !str.contains(r'\')) {
              // Token hex 32 ký tự
              entries.add(FormPhotoEntry(
                localPath: '',
                token: str,
                previewUrl: '/dms/form-photos/public/$str',
              ));
            } else {
              // File cục bộ
              entries.add(FormPhotoEntry(localPath: str));
            }
          }
        } else if (rawVal is String && rawVal.trim().isNotEmpty) {
          final str = rawVal.trim();
          if (str.length == 32 && !str.contains('/') && !str.contains(r'\')) {
            entries.add(FormPhotoEntry(
              localPath: '',
              token: str,
              previewUrl: '/dms/form-photos/public/$str',
            ));
          } else {
            entries.add(FormPhotoEntry(localPath: str));
          }
        }
        if (entries.isNotEmpty) {
          _photoEntries[code] = entries;
        }
      }
    }

    // Tự động gán defaultCustomerId cho các ô ref_customer hoặc ô khách hàng
    if (widget.defaultCustomerId != null) {
      for (final block in widget.blocks) {
        if (_isCustomerBlock(block)) {
          final code = block.resolved.code;
          if (widget.lockCustomer || !_answers.containsKey(code) || _answers[code] == null) {
            _answers[code] = widget.defaultCustomerId;
          }
        }
      }
    }

    if (widget.lockCustomer) {
      for (final block in widget.blocks) {
        if (_isCustomerNameBlock(block) && widget.defaultCustomerName != null) {
          final code = block.resolved.code;
          if (!_answers.containsKey(code) || _answers[code] == null) {
            _answers[code] = widget.defaultCustomerName;
          }
        } else if (_isCustomerCodeBlock(block) && widget.defaultCustomerCode != null) {
          final code = block.resolved.code;
          if (!_answers.containsKey(code) || _answers[code] == null) {
            _answers[code] = widget.defaultCustomerCode;
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
    if (widget.lockCustomer && widget.defaultCustomerId != null) {
      for (final block in widget.blocks) {
        if (_isCustomerBlock(block)) {
          _answers[block.resolved.code] = widget.defaultCustomerId;
        }
      }
    }

    _recomputeVisibility();
    final Map<String, String> newErrors = {};

    for (final block in widget.blocks) {
      if (block.isPresentation) continue;
      // Ô đang ẩn được MIỄN kiểm tra bắt buộc (§5)
      if (!_isBlockVisible(block)) continue;

      final code = block.resolved.code;
      final label = block.resolved.label.isNotEmpty ? block.resolved.label : code;

      // Xử lý riêng cho ô ảnh (§1, §2, §3)
      if (block.isImage || block.resolved.inputType.toLowerCase() == 'file') {
        final entries = _photoEntries[code] ?? [];
        final hasUploading = entries.any((e) => e.isUploading);
        if (hasUploading) {
          newErrors[code] = '$label: Vui lòng chờ ảnh tải lên hoàn tất.';
          continue;
        }
        if (block.required && entries.isEmpty) {
          newErrors[code] = '$label không được để trống.';
          continue;
        }
        final maxAllowed = _resolveMaxFiles(block);
        if (entries.length > maxAllowed) {
          newErrors[code] = '$label chỉ cho phép tối đa $maxAllowed ảnh.';
          continue;
        }
        if (entries.isNotEmpty) {
          // LUÔN gửi mảng các token (hoặc local path nếu offline chưa có token) (§3)
          _answers[code] = entries
              .map((e) => (e.token != null && e.token!.isNotEmpty) ? e.token! : e.localPath)
              .where((s) => s.isNotEmpty)
              .toList();
        } else {
          _answers.remove(code);
        }
        continue;
      }

      final val = _answers[code];

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

    final imageCodes = widget.blocks
        .where((b) => b.isImage || b.resolved.inputType.toLowerCase() == 'file')
        .map((b) => b.resolved.code)
        .toSet();

    // Làm sạch: Bỏ các trường rỗng, ô trình bày, và ô đang ẩn (§5, §9)
    return MarketFormSubmissionModel.sanitizeAnswers(
      _answers,
      presentationCodes: _presentationCodes,
      allowedCodes: visibleCodes,
      imageCodes: imageCodes,
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
      case 'image':
      case 'file':
        return _buildImageField(context, block, isDark);
      case 'ref_customer':
        final currentVal = _answers[block.resolved.code];
        final int? selectedId = (widget.lockCustomer && widget.defaultCustomerId != null)
            ? widget.defaultCustomerId
            : (currentVal is int
                ? currentVal
                : (currentVal != null ? int.tryParse(currentVal.toString()) : null));
        return RefCustomerFieldWidget(
          block: block,
          selectedId: selectedId ?? (widget.lockCustomer ? widget.defaultCustomerId : null),
          errorText: _errors[block.resolved.code],
          defaultCustomerName: widget.defaultCustomerName,
          defaultCustomerCode: widget.defaultCustomerCode,
          defaultCustomerAddress: widget.defaultCustomerAddress,
          isReadOnly: widget.lockCustomer,
          onChanged: widget.lockCustomer
              ? (_) {}
              : (val) => _updateValue(block.resolved.code, val),
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
    final isCustomerField = _isCustomerBlock(block) ||
        _isCustomerNameBlock(block) ||
        _isCustomerCodeBlock(block);
    final isLocked = widget.lockCustomer && isCustomerField;

    final code = block.resolved.code;
    final initial = _answers[code]?.toString() ?? '';
    final controller = _getController(code, initial);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(block, isDark),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: isLocked,
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
            suffixIcon: isLocked
                ? null
                : VoiceInputMicButton(
                    fieldName: block.resolved.label.isNotEmpty ? block.resolved.label : code,
                    currentText: controller.text,
                    onTextRecognized: (text) {
                      controller.text = text;
                      controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: text.length),
                      );
                      _updateValue(code, text);
                    },
                  ),
          ),
          onChanged: isLocked ? null : (val) => _updateValue(code, val),
        ),
      ],
    );
  }

  // ==========================================
  // Ô NHẬP SỐ (NUMBER)
  // ==========================================

  Widget _buildNumberField(MarketFormBlockEntity block, bool isDark) {
    final isLocked = widget.lockCustomer && _isCustomerBlock(block);
    final code = block.resolved.code;
    final initial = _answers[code]?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(block, isDark),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: initial,
          readOnly: isLocked,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppTypography.bodyMedium(
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ),
          decoration: _inputDecoration(
            hintText: 'Nhập số...',
            isDark: isDark,
            errorText: _errors[code],
          ),
          onChanged: isLocked
              ? null
              : (val) {
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
  // Ô ẢNH / MÁY ẢNH (IMAGE & FILE) (§1, §2, §3)
  // ==========================================

  Widget _buildImageField(
    BuildContext context,
    MarketFormBlockEntity block,
    bool isDark,
  ) {
    final code = block.resolved.code;
    final maxFiles = _resolveMaxFiles(block);
    final entries = _photoEntries[code] ?? [];
    final canAddMore = entries.length < maxFiles;
    final error = _errors[code];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _buildLabel(block, isDark)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${entries.length}/$maxFiles ảnh',
                style: AppTypography.labelSmall(
                  color: entries.length >= maxFiles
                      ? AppColors.primary
                      : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (block.resolved.description != null && block.resolved.description!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            block.resolved.description!,
            style: AppTypography.bodySmall(
              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: error != null
                  ? AppColors.error
                  : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
              width: error != null ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entries.isNotEmpty) ...[
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: entries
                      .map((entry) => _buildPhotoThumbnail(context, block, entry, isDark))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],

              // Nút chụp ảnh
              if (canAddMore)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                    side: BorderSide(
                      color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                      width: 1.2,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.camera_alt_rounded, size: 20),
                  label: Text(
                    entries.isEmpty
                        ? 'Chụp ảnh ${block.resolved.label.isNotEmpty ? block.resolved.label : ""}'.trim()
                        : 'Chụp thêm ảnh (${entries.length}/$maxFiles)',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  onPressed: () => _showPhotoSourceSheet(context, block),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.primaryFixedDim : AppColors.primary).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Đã đủ $maxFiles ảnh tối đa',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (error != null) _buildErrorText(error),
      ],
    );
  }

  Widget _buildPhotoThumbnail(
    BuildContext context,
    MarketFormBlockEntity block,
    FormPhotoEntry entry,
    bool isDark,
  ) {
    final hasLocal = entry.localPath.isNotEmpty && File(entry.localPath).existsSync();
    final hasRemote = entry.previewUrl != null && entry.previewUrl!.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => _showImagePreviewDialog(context, entry),
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
              ),
              color: isDark ? AppColors.darkSurface : AppColors.surfaceContainerHigh,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasLocal)
                    Image.file(File(entry.localPath), fit: BoxFit.cover)
                  else if (hasRemote)
                    Image.network(
                      entry.fullPreviewUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_rounded, color: AppColors.error),
                      ),
                    )
                  else
                    const Center(child: Icon(Icons.photo_rounded, size: 28, color: Colors.grey)),

                  // Trạng thái đang tải lên
                  if (entry.isUploading)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                  // Trạng thái lỗi tải lên
                  if (!entry.isUploading && entry.uploadError != null)
                    Container(
                      color: Colors.black54,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 22),
                            const SizedBox(height: 2),
                            InkWell(
                              onTap: () => _retryUploadPhoto(block.resolved.code, entry),
                              child: const Text(
                                'Thử lại',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Nút xoá ảnh
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: () => _removePhoto(block.resolved.code, entry),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  void _showPhotoSourceSheet(BuildContext context, MarketFormBlockEntity block) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                title: const Text('Chụp ảnh từ máy ảnh (Khuyến nghị)', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Chụp ảnh trực tiếp tại điểm bán'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndUploadPhoto(context, block, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.secondary),
                title: const Text('Chọn ảnh từ thư viện'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndUploadPhoto(context, block, ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImagePreviewDialog(BuildContext context, FormPhotoEntry entry) {
    final hasLocal = entry.localPath.isNotEmpty && File(entry.localPath).existsSync();
    final hasRemote = entry.previewUrl != null && entry.previewUrl!.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                child: hasLocal
                    ? Image.file(File(entry.localPath), fit: BoxFit.contain)
                    : hasRemote
                        ? Image.network(entry.fullPreviewUrl, fit: BoxFit.contain)
                        : Container(
                            color: Colors.black,
                            height: 200,
                            child: const Center(
                              child: Text('Không thể tải ảnh', style: TextStyle(color: Colors.white)),
                            ),
                          ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.cancel_rounded, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(
    BuildContext context,
    MarketFormBlockEntity block,
    ImageSource source,
  ) async {
    final code = block.resolved.code;
    final maxFiles = _resolveMaxFiles(block);
    final currentEntries = _photoEntries[code] ?? [];
    if (currentEntries.length >= maxFiles) return;

    if (source == ImageSource.camera) {
      final hasPermission = await CameraPermissionDialog.checkAndRequestPermission(
        context,
        featureName: 'khảo sát thị trường',
        customDescription: 'Ứng dụng cần quyền Camera để chụp ảnh khảo sát trực tiếp tại điểm bán. Vui lòng cấp quyền Máy ảnh trong Cài đặt thiết bị.',
      );
      if (!hasPermission) return;
    }

    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (photo == null) return;

      final entry = FormPhotoEntry(
        localPath: photo.path,
        isUploading: widget.onUploadPhoto != null,
      );

      setState(() {
        if (!_photoEntries.containsKey(code)) {
          _photoEntries[code] = [];
        }
        _photoEntries[code]!.add(entry);
        _errors.remove(code);
      });

      // Nếu có callback upload, thực hiện upload ngay lập tức (§2: Tải ảnh lên TRƯỚC)
      if (widget.onUploadPhoto != null) {
        try {
          final result = await widget.onUploadPhoto!(File(photo.path));
          if (mounted) {
            setState(() {
              entry.token = result.token;
              entry.previewUrl = result.url;
              entry.isUploading = false;
              entry.uploadError = null;
              _updateAnswersForImageField(code);
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              entry.isUploading = false;
              entry.uploadError = e.toString().replaceAll('AppException: ', '');
              _updateAnswersForImageField(code);
            });
          }
        }
      } else {
        _updateAnswersForImageField(code);
      }
    } catch (e) {
      debugPrint('[MarketFormRenderer] Lỗi chụp/chọn ảnh: $e');
    }
  }

  Future<void> _retryUploadPhoto(
    String code,
    FormPhotoEntry entry,
  ) async {
    if (widget.onUploadPhoto == null || entry.localPath.isEmpty) return;

    setState(() {
      entry.isUploading = true;
      entry.uploadError = null;
    });

    try {
      final result = await widget.onUploadPhoto!(File(entry.localPath));
      if (mounted) {
        setState(() {
          entry.token = result.token;
          entry.previewUrl = result.url;
          entry.isUploading = false;
          entry.uploadError = null;
          _updateAnswersForImageField(code);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          entry.isUploading = false;
          entry.uploadError = e.toString().replaceAll('AppException: ', '');
          _updateAnswersForImageField(code);
        });
      }
    }
  }

  void _removePhoto(String code, FormPhotoEntry entry) {
    setState(() {
      _photoEntries[code]?.remove(entry);
      if (_photoEntries[code]?.isEmpty ?? false) {
        _photoEntries.remove(code);
      }
      _updateAnswersForImageField(code);
    });
  }

  void _updateAnswersForImageField(String code) {
    final entries = _photoEntries[code] ?? [];
    if (entries.isNotEmpty) {
      _answers[code] = entries
          .map((e) => (e.token != null && e.token!.isNotEmpty) ? e.token! : e.localPath)
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      _answers.remove(code);
    }
    widget.onChanged?.call(_answers);
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
