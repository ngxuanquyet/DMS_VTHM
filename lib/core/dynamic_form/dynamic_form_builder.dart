import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import 'models/dynamic_form_field.dart';
import 'widgets/boolean_field_widget.dart';
import 'widgets/datetime_field_widget.dart';
import 'widgets/gps_field_widget.dart';
import 'widgets/long_text_field_widget.dart';
import 'widgets/multiple_choice_field_widget.dart';
import 'widgets/number_field_widget.dart';
import 'widgets/photo_field_widget.dart';
import 'widgets/rating_field_widget.dart';
import 'widgets/single_choice_field_widget.dart';
import 'widgets/text_field_widget.dart';

class DynamicFormBuilder extends StatefulWidget {
  /// Danh sách đặc tả các trường form nhận từ API
  final List<DynamicFormField> fields;

  /// Dữ liệu khởi tạo (Map key-value)
  final Map<String, dynamic> initialData;

  /// Callback khi có bất kỳ trường nào thay đổi giá trị
  final void Function(Map<String, dynamic> formData)? onChanged;

  /// Callback khi nhấn nút Lưu / Submit form
  final Future<void> Function(Map<String, dynamic> formData)? onSubmit;

  /// Text nút submit (nếu null sẽ không vẽ nút submit tự động)
  final String? submitButtonText;

  /// Đang submit (loading)
  final bool isSubmitting;

  const DynamicFormBuilder({
    super.key,
    required this.fields,
    this.initialData = const {},
    this.onChanged,
    this.onSubmit,
    this.submitButtonText,
    this.isSubmitting = false,
  });

  @override
  State<DynamicFormBuilder> createState() => DynamicFormBuilderState();
}

class DynamicFormBuilderState extends State<DynamicFormBuilder> {
  final Map<String, dynamic> _formData = {};
  final Map<String, String?> _errors = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void didUpdateWidget(covariant DynamicFormBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fields != oldWidget.fields || widget.initialData != oldWidget.initialData) {
      _initializeData();
    }
  }

  void _initializeData() {
    _formData.clear();
    for (final field in widget.fields) {
      if (widget.initialData.containsKey(field.code)) {
        _formData[field.code] = widget.initialData[field.code];
      } else if (field.initialValue != null) {
        _formData[field.code] = field.initialValue;
      } else {
        // Default fallbacks according to type
        switch (field.type) {
          case DynamicFormFieldType.multipleChoice:
            _formData[field.code] = <dynamic>[];
            break;
          case DynamicFormFieldType.photo:
            _formData[field.code] = <String>[];
            break;
          case DynamicFormFieldType.boolean:
            _formData[field.code] = false;
            break;
          case DynamicFormFieldType.rating:
            _formData[field.code] = (field.min ?? 5).toInt();
            break;
          default:
            _formData[field.code] = null;
        }
      }
    }
  }

  void updateFieldValue(String code, dynamic value) {
    setState(() {
      _formData[code] = value;
      // Clear error for this field
      if (_errors.containsKey(code)) {
        _errors[code] = null;
      }
    });
    widget.onChanged?.call(Map<String, dynamic>.from(_formData));
  }

  /// Kiểm tra tính hợp lệ toàn bộ form (Validate)
  bool validate() {
    bool isValid = true;
    final newErrors = <String, String?>{};

    for (final field in widget.fields) {
      final value = _formData[field.code];

      // 1. Kiểm tra bắt buộc nhập (Required check)
      if (field.isRequired) {
        if (value == null) {
          newErrors[field.code] = '${field.label} là bắt buộc';
          isValid = false;
          continue;
        }
        if (value is String && value.trim().isEmpty) {
          newErrors[field.code] = '${field.label} không được để trống';
          isValid = false;
          continue;
        }
        if (value is List && value.isEmpty) {
          newErrors[field.code] = 'Vui lòng chọn ít nhất 1 ${field.label.toLowerCase()}';
          isValid = false;
          continue;
        }
      }

      // 2. Kiểm tra giới hạn số (Min/Max check)
      if (field.type == DynamicFormFieldType.number && value is num) {
        if (field.min != null && value < field.min!) {
          newErrors[field.code] = 'Giá trị phải lớn hơn hoặc bằng ${field.min}';
          isValid = false;
          continue;
        }
        if (field.max != null && value > field.max!) {
          newErrors[field.code] = 'Giá trị phải nhỏ hơn hoặc bằng ${field.max}';
          isValid = false;
          continue;
        }
      }
    }

    setState(() {
      _errors.clear();
      _errors.addAll(newErrors);
    });

    return isValid;
  }

  /// Lấy toàn bộ dữ liệu form hiện tại
  Map<String, dynamic> getFormData() {
    return Map<String, dynamic>.from(_formData);
  }

  Future<void> _handleSubmit() async {
    if (validate()) {
      if (widget.onSubmit != null) {
        await widget.onSubmit!(Map<String, dynamic>.from(_formData));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng hoàn thành các trường thông tin bắt buộc (*).'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Phân nhóm các trường theo Section (nếu có)
    final sections = <String, List<DynamicFormField>>{};
    for (final field in widget.fields) {
      final sec = field.section ?? '';
      sections.putIfAbsent(sec, () => []).add(field);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...sections.entries.map((secEntry) {
          final sectionTitle = secEntry.key;
          final sectionFields = secEntry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sectionTitle.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: AppRadius.roundedFull,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        sectionTitle,
                        style: AppTypography.titleMedium(
                          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
              ...sectionFields.map((field) => _buildFieldWidget(field)),
            ],
          );
        }),

        if (widget.submitButtonText != null) ...[
          const SizedBox(height: 16),
          AppButton(
            text: widget.submitButtonText!,
            isLoading: widget.isSubmitting,
            icon: Icons.check_circle_outline_rounded,
            width: double.infinity,
            height: 48,
            onPressed: _handleSubmit,
          ),
        ],
      ],
    );
  }

  Widget _buildFieldWidget(DynamicFormField field) {
    final value = _formData[field.code];
    final errorText = _errors[field.code];

    switch (field.type) {
      case DynamicFormFieldType.text:
        return DynamicTextFieldWidget(
          field: field,
          value: value?.toString(),
          errorText: errorText,
          onChanged: (val) => updateFieldValue(field.code, val),
        );

      case DynamicFormFieldType.longText:
        return DynamicLongTextFieldWidget(
          field: field,
          value: value?.toString(),
          errorText: errorText,
          onChanged: (val) => updateFieldValue(field.code, val),
        );

      case DynamicFormFieldType.number:
        return DynamicNumberFieldWidget(
          field: field,
          value: value is num ? value : num.tryParse(value?.toString() ?? ''),
          errorText: errorText,
          onChanged: (val) => updateFieldValue(field.code, val),
        );

      case DynamicFormFieldType.singleChoice:
        return DynamicSingleChoiceFieldWidget(
          field: field,
          value: value,
          errorText: errorText,
          onChanged: (val) => updateFieldValue(field.code, val),
        );

      case DynamicFormFieldType.multipleChoice:
        final selectedList = value is List ? List<dynamic>.from(value) : <dynamic>[];
        return DynamicMultipleChoiceFieldWidget(
          field: field,
          selectedValues: selectedList,
          errorText: errorText,
          onChanged: (val) => updateFieldValue(field.code, val),
        );

      case DynamicFormFieldType.date:
      case DynamicFormFieldType.time:
      case DynamicFormFieldType.datetime:
        return DynamicDateTimeFieldWidget(
          field: field,
          value: value?.toString(),
          errorText: errorText,
          onChanged: (val) => updateFieldValue(field.code, val),
        );

      case DynamicFormFieldType.photo:
        final photoList = value is List ? List<String>.from(value.map((e) => e.toString())) : <String>[];
        return DynamicPhotoFieldWidget(
          field: field,
          photoPaths: photoList,
          errorText: errorText,
          onChanged: (val) => updateFieldValue(field.code, val),
        );

      case DynamicFormFieldType.boolean:
        final boolVal = value == true || value == 1 || value == '1' || value == 'true';
        return DynamicBooleanFieldWidget(
          field: field,
          value: boolVal,
          errorText: errorText,
          onChanged: (val) => updateFieldValue(field.code, val),
        );

      case DynamicFormFieldType.rating:
        final intVal = value is int ? value : (int.tryParse(value?.toString() ?? '') ?? 5);
        return DynamicRatingFieldWidget(
          field: field,
          value: intVal,
          errorText: errorText,
          onChanged: (val) => updateFieldValue(field.code, val),
        );

      case DynamicFormFieldType.gps:
        final gpsMap = value is Map<String, dynamic> ? value : (value is Map ? Map<String, dynamic>.from(value) : null);
        return DynamicGpsFieldWidget(
          field: field,
          value: gpsMap,
          errorText: errorText,
          onChanged: (val) => updateFieldValue(field.code, val),
        );

      case DynamicFormFieldType.signature:
        return DynamicTextFieldWidget(
          field: field,
          value: value?.toString(),
          errorText: errorText,
          onChanged: (val) => updateFieldValue(field.code, val),
        );
    }
  }
}
