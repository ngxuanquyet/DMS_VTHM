import '../../domain/entities/market_form_entity.dart';

/// Model biểu diễn cấu hình biểu mẫu thị trường từ API GET /dms/forms/available
class MarketFormConfigModel {
  final int configId;
  final int formId;
  final String code;
  final String name;
  final String kind; // 'survey' | 'collect'
  final bool isRequired;
  final int sortOrder;
  final MarketFormSchemaModel schema;

  const MarketFormConfigModel({
    required this.configId,
    required this.formId,
    required this.code,
    required this.name,
    required this.kind,
    required this.isRequired,
    required this.sortOrder,
    required this.schema,
  });

  factory MarketFormConfigModel.fromJson(Map<String, dynamic> json) {
    return MarketFormConfigModel(
      configId: json['config_id'] is int
          ? json['config_id'] as int
          : (int.tryParse(json['config_id']?.toString() ?? '') ?? 0),
      formId: json['form_id'] is int
          ? json['form_id'] as int
          : (int.tryParse(json['form_id']?.toString() ?? '') ?? 0),
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'collect',
      isRequired: json['is_required'] == true || json['is_required'] == 1,
      sortOrder: json['sort_order'] is int
          ? json['sort_order'] as int
          : (int.tryParse(json['sort_order']?.toString() ?? '') ?? 0),
      schema: json['schema'] is Map<String, dynamic>
          ? MarketFormSchemaModel.fromJson(json['schema'] as Map<String, dynamic>)
          : const MarketFormSchemaModel(blocks: []),
    );
  }

  Map<String, dynamic> toJson() => {
        'config_id': configId,
        'form_id': formId,
        'code': code,
        'name': name,
        'kind': kind,
        'is_required': isRequired,
        'sort_order': sortOrder,
        'schema': schema.toJson(),
      };

  MarketFormConfigEntity toEntity() {
    return MarketFormConfigEntity(
      configId: configId,
      formId: formId,
      code: code,
      name: name,
      kind: kind,
      isRequired: isRequired,
      sortOrder: sortOrder,
      schema: schema.toEntity(),
    );
  }
}

/// Model schema biểu mẫu chứa danh sách các block
class MarketFormSchemaModel {
  final List<MarketFormBlockModel> blocks;

  const MarketFormSchemaModel({
    required this.blocks,
  });

  factory MarketFormSchemaModel.fromJson(Map<String, dynamic> json) {
    final rawBlocks = json['blocks'];
    List<MarketFormBlockModel> blockList = [];
    if (rawBlocks is List) {
      blockList = rawBlocks
          .whereType<Map<String, dynamic>>()
          .map((b) => MarketFormBlockModel.fromJson(b))
          .toList();
    }
    return MarketFormSchemaModel(blocks: blockList);
  }

  Map<String, dynamic> toJson() => {
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };

  MarketFormSchemaEntity toEntity() {
    return MarketFormSchemaEntity(
      blocks: blocks.map((b) => b.toEntity()).toList(),
    );
  }
}

/// Model block trong schema
class MarketFormBlockModel {
  final String ref;
  final String type; // 'field' | etc.
  final bool required; // cấp block
  final int colSpan;
  final dynamic showIf;
  final MarketFormResolvedModel resolved;

  const MarketFormBlockModel({
    required this.ref,
    required this.type,
    required this.required,
    this.colSpan = 12,
    this.showIf,
    required this.resolved,
  });

  factory MarketFormBlockModel.fromJson(Map<String, dynamic> json) {
    return MarketFormBlockModel(
      ref: json['ref']?.toString() ?? '',
      type: json['type']?.toString() ?? 'field',
      required: json['required'] == true || json['required'] == 1,
      colSpan: json['col_span'] is int
          ? json['col_span'] as int
          : (int.tryParse(json['col_span']?.toString() ?? '') ?? 12),
      showIf: json['show_if'],
      resolved: json['resolved'] is Map<String, dynamic>
          ? MarketFormResolvedModel.fromJson(json['resolved'] as Map<String, dynamic>)
          : MarketFormResolvedModel.empty(),
    );
  }

  Map<String, dynamic> toJson() => {
        'ref': ref,
        'type': type,
        'required': required,
        'col_span': colSpan,
        if (showIf != null) 'show_if': showIf,
        'resolved': resolved.toJson(),
      };

  MarketFormBlockEntity toEntity() {
    return MarketFormBlockEntity(
      ref: ref,
      type: type,
      required: required,
      colSpan: colSpan,
      showIf: showIf,
      resolved: resolved.toEntity(),
    );
  }
}

/// Model trường nhập liệu đã resolved
class MarketFormResolvedModel {
  final String code; // Khóa nộp answers
  final String label;
  final String inputType; // heading, currency, select, text, ...
  final dynamic config;
  final String? description;

  const MarketFormResolvedModel({
    required this.code,
    required this.label,
    required this.inputType,
    this.config,
    this.description,
  });

  factory MarketFormResolvedModel.empty() => const MarketFormResolvedModel(
        code: '',
        label: '',
        inputType: 'text',
      );

  factory MarketFormResolvedModel.fromJson(Map<String, dynamic> json) {
    return MarketFormResolvedModel(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      inputType: json['input_type']?.toString() ?? 'text',
      config: json['config'],
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'label': label,
        'input_type': inputType,
        if (config != null) 'config': config,
        if (description != null) 'description': description,
      };

  MarketFormResolvedEntity toEntity() {
    List<MarketFormOptionEntity> parsedOptions = [];
    MarketFormValidationEntity? parsedValidation;

    if (config is Map<String, dynamic>) {
      final configMap = config as Map<String, dynamic>;
      if (configMap['options'] is List) {
        parsedOptions = (configMap['options'] as List)
            .whereType<Map<String, dynamic>>()
            .map((o) => MarketFormOptionEntity(
                  value: o['value']?.toString() ?? '',
                  label: o['label']?.toString() ?? '',
                ))
            .toList();
      }
      if (configMap['validation'] is Map<String, dynamic>) {
        final valMap = configMap['validation'] as Map<String, dynamic>;
        parsedValidation = MarketFormValidationEntity(
          min: valMap['min'] is num ? valMap['min'] as num : num.tryParse(valMap['min']?.toString() ?? ''),
          max: valMap['max'] is num ? valMap['max'] as num : num.tryParse(valMap['max']?.toString() ?? ''),
          minLength: valMap['min_length'] is int
              ? valMap['min_length'] as int
              : int.tryParse(valMap['min_length']?.toString() ?? ''),
          maxLength: valMap['max_length'] is int
              ? valMap['max_length'] as int
              : int.tryParse(valMap['max_length']?.toString() ?? ''),
        );
      }
    }

    return MarketFormResolvedEntity(
      code: code,
      label: label,
      inputType: inputType,
      config: config,
      description: description,
      options: parsedOptions,
      validation: parsedValidation,
    );
  }
}
