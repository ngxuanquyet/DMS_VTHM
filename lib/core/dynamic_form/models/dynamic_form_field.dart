import 'package:flutter/material.dart';

/// Các kiểu dữ liệu của trường form động do API trả về
enum DynamicFormFieldType {
  /// Văn bản ngắn (1 dòng)
  text,

  /// Văn bản dài (nhiều dòng / textarea)
  longText,

  /// Kiểu số (nguyên, thực, tiền tệ, số lượng)
  number,

  /// Lựa chọn 1 (Radio list, Dropdown, hoặc Chip đơn)
  singleChoice,

  /// Lựa chọn nhiều (Checkbox list, Multi-select chips)
  multipleChoice,

  /// Chọn ngày
  date,

  /// Chọn giờ
  time,

  /// Chọn ngày & giờ
  datetime,

  /// Chụp ảnh / Chọn ảnh đính kèm
  photo,

  /// Bật / Tắt (Boolean switch / Checkbox)
  boolean,

  /// Đánh giá sao / Thang điểm
  rating,

  /// Lấy tọa độ GPS (Vị trí)
  gps,

  /// Chữ ký điện tử
  signature;

  /// Chuyển đổi chuỗi type từ API (case-insensitive) sang enum
  static DynamicFormFieldType fromString(String? typeStr) {
    if (typeStr == null) return DynamicFormFieldType.text;
    final clean = typeStr.trim().toLowerCase().replaceAll('-', '_');

    switch (clean) {
      case 'text':
      case 'string':
      case 'varchar':
      case 'char':
      case 'input':
        return DynamicFormFieldType.text;

      case 'long_text':
      case 'longtext':
      case 'textarea':
      case 'paragraph':
      case 'note':
      case 'description':
        return DynamicFormFieldType.longText;

      case 'number':
      case 'numeric':
      case 'integer':
      case 'int':
      case 'float':
      case 'double':
      case 'decimal':
      case 'currency':
      case 'money':
        return DynamicFormFieldType.number;

      case 'single_choice':
      case 'singlechoice':
      case 'radio':
      case 'select':
      case 'dropdown':
      case 'combobox':
      case 'choice':
        return DynamicFormFieldType.singleChoice;

      case 'multiple_choice':
      case 'multiplechoice':
      case 'multi_choice':
      case 'checkbox':
      case 'multi_select':
      case 'multiselect':
      case 'tags':
        return DynamicFormFieldType.multipleChoice;

      case 'date':
      case 'datepicker':
        return DynamicFormFieldType.date;

      case 'time':
      case 'timepicker':
        return DynamicFormFieldType.time;

      case 'datetime':
      case 'datetimepicker':
      case 'timestamp':
        return DynamicFormFieldType.datetime;

      case 'photo':
      case 'image':
      case 'camera':
      case 'picture':
      case 'attachment':
      case 'file':
        return DynamicFormFieldType.photo;

      case 'boolean':
      case 'bool':
      case 'switch':
      case 'toggle':
        return DynamicFormFieldType.boolean;

      case 'rating':
      case 'star':
      case 'score':
      case 'scale':
        return DynamicFormFieldType.rating;

      case 'gps':
      case 'location':
      case 'coords':
      case 'coordinates':
      case 'lat_lng':
        return DynamicFormFieldType.gps;

      case 'signature':
      case 'sign':
        return DynamicFormFieldType.signature;

      default:
        return DynamicFormFieldType.text;
    }
  }
}

/// Lựa chọn cho các trường SingleChoice hoặc MultipleChoice
class DynamicFormOption {
  final String label;
  final dynamic value;
  final String? code;
  final IconData? icon;
  final Color? color;
  final String? description;

  const DynamicFormOption({
    required this.label,
    required this.value,
    this.code,
    this.icon,
    this.color,
    this.description,
  });

  factory DynamicFormOption.fromJson(dynamic json) {
    if (json is String) {
      return DynamicFormOption(label: json, value: json);
    }
    if (json is Map<String, dynamic>) {
      return DynamicFormOption(
        label: json['label']?.toString() ?? json['name']?.toString() ?? json['title']?.toString() ?? json['value']?.toString() ?? '',
        value: json['value'] ?? json['id'] ?? json['code'] ?? '',
        code: json['code']?.toString(),
        description: json['description']?.toString(),
      );
    }
    return DynamicFormOption(label: json.toString(), value: json);
  }
}

/// Model đặc tả 1 trường nhập liệu động nhận từ API
class DynamicFormField {
  /// Mã định danh của trường (field code / key dùng khi submit JSON)
  final String code;

  /// Tiêu đề / Tên hiển thị của trường
  final String label;

  /// Kiểu dữ liệu nhập
  final DynamicFormFieldType type;

  /// Gợi ý nhập liệu (placeholder / hint text)
  final String? placeholder;

  /// Hướng dẫn chi tiết bên dưới trường
  final String? helperText;

  /// Bắt buộc nhập hay không
  final bool isRequired;

  /// Chỉ đọc (không cho chỉnh sửa)
  final bool isReadOnly;

  /// Giá trị mặc định / hiện tại
  final dynamic initialValue;

  /// Danh sách tùy chọn (cho single/multiple choice)
  final List<DynamicFormOption> options;

  /// Đơn vị đo / Ký hiệu tiền tệ phía sau (VD: 'VNĐ', 'kg', '%', 'thùng')
  final String? suffixText;

  /// Ký hiệu phía trước
  final String? prefixText;

  /// Giá trị nhỏ nhất (cho number/rating/date)
  final num? min;

  /// Giá trị lớn nhất (cho number/rating/date)
  final num? max;

  /// Bước nhảy (cho number)
  final num? step;

  /// Số lượng ảnh tối đa cho phép chụp
  final int maxPhotos;

  /// Loại trường: 'fixed' hoặc 'dynamic'
  final String? kind;

  /// Nguồn dữ liệu: 'fixed', 'mobiwork', v.v.
  final String? source;

  /// Danh mục liên kết: 'customer_type', 'channel', 'region', v.v.
  final String? catalog;

  /// Tên nhóm / Section (để gom nhóm form)
  final String? section;

  /// Thứ tự sắp xếp
  final int order;

  const DynamicFormField({
    required this.code,
    required this.label,
    required this.type,
    this.placeholder,
    this.helperText,
    this.isRequired = false,
    this.isReadOnly = false,
    this.initialValue,
    this.options = const [],
    this.suffixText,
    this.prefixText,
    this.min,
    this.max,
    this.step,
    this.maxPhotos = 5,
    this.kind,
    this.source,
    this.catalog,
    this.section,
    this.order = 0,
  });

  factory DynamicFormField.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type']?.toString() ??
        json['input_type']?.toString() ??
        json['data_type']?.toString();
    final type = DynamicFormFieldType.fromString(typeStr);

    List<DynamicFormOption> opts = [];
    if (json['options'] is List) {
      opts = (json['options'] as List)
          .map((o) => DynamicFormOption.fromJson(o))
          .toList();
    } else if (json['items'] is List) {
      opts = (json['items'] as List)
          .map((o) => DynamicFormOption.fromJson(o))
          .toList();
    } else if (json['values'] is List) {
      opts = (json['values'] as List)
          .map((o) => DynamicFormOption.fromJson(o))
          .toList();
    }

    final kind = json['kind']?.toString();
    final code = json['code']?.toString() ??
        json['name']?.toString() ??
        json['id']?.toString() ??
        json['key']?.toString() ??
        '';

    // Xác định section tự động nếu API chưa truyền section tường minh
    String? section =
        json['section']?.toString() ?? json['group']?.toString() ?? json['category']?.toString();
    if (section == null || section.isEmpty) {
      if (kind == 'dynamic' || code.startsWith('mw_')) {
        section = 'Thông tin mở rộng (Động)';
      } else if (['code', 'name', 'customer_type_id', 'channel_id', 'region_id', 'status'].contains(code)) {
        section = 'Thông tin chung';
      } else if (['phone', 'email', 'contact_name', 'contact_title', 'birthday'].contains(code)) {
        section = 'Thông tin liên hệ';
      } else if (['address', 'delivery_address', 'province_name', 'ward_name', 'lat', 'lng'].contains(code)) {
        section = 'Địa chỉ & Vị trí';
      } else if (['photo_file_id'].contains(code) || type == DynamicFormFieldType.photo) {
        section = 'Hình ảnh điểm bán';
      } else {
        section = 'Thông tin khác';
      }
    }

    return DynamicFormField(
      code: code,
      label: json['label']?.toString() ??
          json['title']?.toString() ??
          json['name']?.toString() ??
          '',
      type: type,
      placeholder: json['placeholder']?.toString() ?? json['hint']?.toString(),
      helperText: json['description']?.toString() ?? json['helper_text']?.toString(),
      isRequired: json['required'] == true ||
          json['is_required'] == true ||
          json['is_required'] == 1,
      isReadOnly: json['read_only'] == true ||
          json['is_readonly'] == true ||
          json['readonly'] == true,
      initialValue: json['value'] ?? json['default_value'] ?? json['initial_value'],
      options: opts,
      suffixText: json['suffix']?.toString() ?? json['unit']?.toString(),
      prefixText: json['prefix']?.toString(),
      min: json['min'] is num ? json['min'] as num : num.tryParse(json['min']?.toString() ?? ''),
      max: json['max'] is num ? json['max'] as num : num.tryParse(json['max']?.toString() ?? ''),
      step: json['step'] is num ? json['step'] as num : num.tryParse(json['step']?.toString() ?? ''),
      maxPhotos: json['max_photos'] is int
          ? json['max_photos'] as int
          : (int.tryParse(json['max_photos']?.toString() ?? '') ?? 5),
      kind: kind,
      source: json['source']?.toString(),
      catalog: json['catalog']?.toString(),
      section: section,
      order: json['order'] is int ? json['order'] as int : (int.tryParse(json['order']?.toString() ?? '') ?? 0),
    );
  }
}
