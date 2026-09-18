import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_button.dart';
import 'models/dynamic_form_field.dart';
import 'widgets/boolean_field_widget.dart';
import 'widgets/datetime_field_widget.dart';
import 'widgets/gps_coordinates_field_widget.dart';
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

  IconData _getSectionIcon(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('chung') || lower.contains('cơ bản') || lower.contains('tổng quan')) {
      return Icons.storefront_rounded;
    }
    if (lower.contains('liên hệ') || lower.contains('người liên hệ') || lower.contains('contact')) {
      return Icons.contact_phone_rounded;
    }
    if (lower.contains('địa chỉ') || lower.contains('vị trí') || lower.contains('tọa độ') || lower.contains('gps')) {
      return Icons.location_on_rounded;
    }
    if (lower.contains('ảnh') || lower.contains('hình') || lower.contains('photo') || lower.contains('image')) {
      return Icons.photo_camera_rounded;
    }
    if (lower.contains('mở rộng') || lower.contains('động') || lower.contains('dynamic') || lower.contains('khác')) {
      return Icons.extension_rounded;
    }
    return Icons.folder_open_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Phân nhóm các trường theo Section (nếu có)
    final sections = <String, List<DynamicFormField>>{};
    for (final field in widget.fields) {
      final sec = field.section ?? 'Thông tin chung';
      sections.putIfAbsent(sec, () => []).add(field);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...sections.entries.map((secEntry) {
          final sectionTitle = secEntry.key;
          final sectionFields = secEntry.value;
          final hasRequired = sectionFields.any((f) => f.isRequired);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surfaceContainerLowest,
              borderRadius: AppRadius.roundedLg,
              border: Border.all(
                color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  offset: Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section Header Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceContainerLowest
                        : AppColors.surfaceContainerHigh.withValues(alpha: 0.35),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: AppRadius.roundedSm,
                        ),
                        child: Icon(
                          _getSectionIcon(sectionTitle),
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          sectionTitle,
                          style: AppTypography.titleMedium(
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ).copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                      if (hasRequired)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: AppRadius.roundedSm,
                          ),
                          child: Text(
                            'Có trường bắt buộc',
                            style: AppTypography.labelSmall(color: AppColors.error).copyWith(fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                ),

                // Fields List inside Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildSectionFieldWidgets(sectionFields),
                  ),
                ),
              ],
            ),
          );
        }),

        if (widget.submitButtonText != null) ...[
          const SizedBox(height: 8),
          AppButton(
            text: widget.submitButtonText!,
            isLoading: widget.isSubmitting,
            icon: Icons.check_circle_outline_rounded,
            width: double.infinity,
            height: 48,
            onPressed: _handleSubmit,
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  List<Widget> _buildSectionFieldWidgets(List<DynamicFormField> sectionFields) {
    final widgets = <Widget>[];
    final hasLat = sectionFields.any((f) => f.code == 'lat');
    final hasLng = sectionFields.any((f) => f.code == 'lng');

    for (int i = 0; i < sectionFields.length; i++) {
      final field = sectionFields[i];

      // Nếu gặp trường lat (và có lng đi cùng hoặc lat đơn lẻ) -> Dựng DynamicGpsCoordinatesWidget
      if (field.code == 'lat') {
        final lngField = hasLng ? sectionFields.firstWhere((f) => f.code == 'lng') : null;
        final latVal = _formData['lat'] is num
            ? _formData['lat'] as num
            : num.tryParse(_formData['lat']?.toString() ?? '');
        final lngVal = _formData['lng'] is num
            ? _formData['lng'] as num
            : num.tryParse(_formData['lng']?.toString() ?? '');
        final errText = _errors['lat'] ?? _errors['lng'];

        widgets.add(
          DynamicGpsCoordinatesWidget(
            latField: field,
            lngField: lngField,
            lat: latVal,
            lng: lngVal,
            errorText: errText,
            onCoordinatesChanged: (newLat, newLng) {
              updateFieldValue('lat', newLat);
              if (hasLng) {
                updateFieldValue('lng', newLng);
              }
            },
          ),
        );
        continue;
      }

      // Nếu gặp trường lng mà đã có trường lat đi cùng -> Đã được vẽ chung trong GpsCoordinatesWidget
      if (field.code == 'lng' && hasLat) {
        continue;
      }

      // Nếu chỉ có lng đơn lẻ mà không có lat
      if (field.code == 'lng' && !hasLat) {
        final lngVal = _formData['lng'] is num
            ? _formData['lng'] as num
            : num.tryParse(_formData['lng']?.toString() ?? '');
        final errText = _errors['lng'];

        widgets.add(
          DynamicGpsCoordinatesWidget(
            lngField: field,
            lat: null,
            lng: lngVal,
            errorText: errText,
            onCoordinatesChanged: (newLat, newLng) {
              updateFieldValue('lng', newLng);
            },
          ),
        );
        continue;
      }

      // Các trường thông thường khác
      widgets.add(_buildFieldWidget(field));
    }

    return widgets;
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
