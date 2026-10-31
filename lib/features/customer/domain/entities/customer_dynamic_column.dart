import '../../../../core/dynamic_form/formula_evaluator.dart';
import '../../../../core/dynamic_form/models/dynamic_form_field.dart';

class CustomerDynamicColumn {
  final String code;
  final String label;
  final String inputType;
  final String source;
  final String? legacyKey;
  final bool required;
  final bool readOnly;
  final List<DynamicFormOption> options;

  /// Định dạng ô CÔNG THỨC (`input_type = formula`): đọc khoá `formula` `{expr, format, decimals}` hoặc `config`
  /// (`formula`/`format`/`decimals` — khoá `meta.dynamicColumns` của server); `null` = ô khác / thiếu cấu hình.
  final FormulaConfig? formula;

  const CustomerDynamicColumn({
    required this.code,
    required this.label,
    required this.inputType,
    required this.source,
    this.legacyKey,
    this.required = false,
    this.readOnly = false,
    this.options = const [],
    this.formula,
  });

  bool get isFormula => inputType.toLowerCase() == 'formula';

  bool get isLocation =>
      inputType.toLowerCase() == 'location' ||
      inputType.toLowerCase() == 'address' ||
      inputType.toLowerCase() == 'dia_chi' ||
      inputType.toLowerCase() == 'gps';

  factory CustomerDynamicColumn.fromJson(Map<String, dynamic> json) {
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

    return CustomerDynamicColumn(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      inputType: json['input_type']?.toString() ?? json['type']?.toString() ?? 'text',
      source: json['source']?.toString() ?? 'own',
      legacyKey: json['legacy_key']?.toString(),
      required: json['required'] == true,
      readOnly: json['read_only'] == true,
      options: opts,
      formula: FormulaConfig.fromMap(json['formula']) ?? FormulaConfig.fromMap(json['config'], exprKey: 'formula'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'label': label,
      'input_type': inputType,
      'source': source,
      'legacy_key': legacyKey,
      'required': required,
      'read_only': readOnly,
      'options': options.map((e) => {'label': e.label, 'value': e.value}).toList(),
      if (formula != null) 'formula': formula!.toJson(),
    };
  }
}
