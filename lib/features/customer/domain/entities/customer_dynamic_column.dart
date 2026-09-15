class CustomerDynamicColumn {
  final String code;
  final String label;
  final String inputType;
  final String source;
  final String? legacyKey;
  final bool required;
  final bool readOnly;

  const CustomerDynamicColumn({
    required this.code,
    required this.label,
    required this.inputType,
    required this.source,
    this.legacyKey,
    this.required = false,
    this.readOnly = false,
  });

  factory CustomerDynamicColumn.fromJson(Map<String, dynamic> json) {
    return CustomerDynamicColumn(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      inputType: json['input_type']?.toString() ?? 'text',
      source: json['source']?.toString() ?? 'own',
      legacyKey: json['legacy_key']?.toString(),
      required: json['required'] == true,
      readOnly: json['read_only'] == true,
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
    };
  }
}
