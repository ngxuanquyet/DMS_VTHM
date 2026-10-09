import 'dart:convert';
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
  final Map<String, dynamic>? blockJson;

  const MarketFormBlockModel({
    required this.ref,
    required this.type,
    required this.required,
    this.colSpan = 12,
    this.showIf,
    required this.resolved,
    this.blockJson,
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
          ? MarketFormResolvedModel.fromJson(
              json['resolved'] as Map<String, dynamic>,
              blockJson: json,
            )
          : MarketFormResolvedModel.empty(blockJson: json),
      blockJson: json,
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
  final Map<String, dynamic>? resolvedJson;
  final Map<String, dynamic>? blockJson;

  const MarketFormResolvedModel({
    required this.code,
    required this.label,
    required this.inputType,
    this.config,
    this.description,
    this.resolvedJson,
    this.blockJson,
  });

  factory MarketFormResolvedModel.empty({Map<String, dynamic>? blockJson}) =>
      MarketFormResolvedModel(
        code: '',
        label: '',
        inputType: 'text',
        blockJson: blockJson,
      );

  factory MarketFormResolvedModel.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? blockJson,
  }) {
    return MarketFormResolvedModel(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      inputType: json['input_type']?.toString() ?? 'text',
      config: json['config'],
      description: json['description']?.toString(),
      resolvedJson: json,
      blockJson: blockJson,
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

    final isImage = inputType.toLowerCase() == 'image';

    // §1 & Yêu cầu UI: Parse max_files phòng thủ, linh hoạt từ nhiều vị trí:
    // 1. resolved.config['max_files'] (Map, chuỗi JSON, hoặc mảng)
    // 2. resolved['max_files'], resolved['max_photos'], ...
    // 3. block['max_files'], block['config']['max_files'], ...
    // 4. Nếu vắng mặt trong schema (config: [] hoặc chưa cấu hình): mặc định 10 (theo cấu hình hệ thống)
    final parsedMaxFiles = _parseMaxFiles(
      config: config,
      resolvedJson: resolvedJson,
      blockJson: blockJson,
      isImage: isImage,
    );

    // Parse options & validation
    final rawCfg = config;
    Map<String, dynamic> cfg = {};
    if (rawCfg is Map) {
      cfg = Map<String, dynamic>.from(rawCfg);
    } else if (rawCfg is String && rawCfg.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(rawCfg);
        if (decoded is Map) cfg = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }

    final rawOptions = cfg['options'] ?? resolvedJson?['options'] ?? blockJson?['options'];
    if (rawOptions is List) {
      parsedOptions = rawOptions
          .whereType<Map<String, dynamic>>()
          .map((o) => MarketFormOptionEntity(
                value: o['value']?.toString() ?? '',
                label: o['label']?.toString() ?? '',
              ))
          .toList();
    }

    final rawValidation = cfg['validation'] ?? resolvedJson?['validation'] ?? blockJson?['validation'];
    if (rawValidation is Map<String, dynamic>) {
      final valMap = rawValidation;
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

    return MarketFormResolvedEntity(
      code: code,
      label: label,
      inputType: inputType,
      config: config,
      description: description,
      options: parsedOptions,
      validation: parsedValidation,
      maxFiles: parsedMaxFiles,
    );
  }

  static int _parseMaxFiles({
    dynamic config,
    Map<String, dynamic>? resolvedJson,
    Map<String, dynamic>? blockJson,
    bool isImage = false,
  }) {
    int? toInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val != null) {
        final s = val.toString().trim();
        return int.tryParse(s);
      }
      return null;
    }

    const candidateKeys = [
      'max_files',
      'maxFiles',
      'max_photos',
      'maxPhotos',
      'max_images',
      'maxImages',
      'max_count',
      'maxCount',
      'max',
      'limit',
    ];

    int? findInMap(Map<dynamic, dynamic>? map) {
      if (map == null) return null;
      for (final k in candidateKeys) {
        if (map.containsKey(k)) {
          final res = toInt(map[k]);
          if (res != null) return res;
        }
      }
      if (map['validation'] is Map) {
        final valMap = map['validation'] as Map;
        final res = toInt(valMap['max']) ??
            toInt(valMap['max_files']) ??
            toInt(valMap['max_photos']);
        if (res != null) return res;
      }
      return null;
    }

    int? findInConfig(dynamic raw) {
      if (raw == null) return null;
      if (raw is Map) return findInMap(raw);
      if (raw is String) {
        final trimmed = raw.trim();
        if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is Map) return findInMap(decoded);
          } catch (_) {}
        }
        return toInt(trimmed);
      }
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            final res = findInMap(item);
            if (res != null) return res;
            if (item['key']?.toString() == 'max_files' ||
                item['name']?.toString() == 'max_files' ||
                item['key']?.toString() == 'max_photos') {
              final val = toInt(item['value']);
              if (val != null) return val;
            }
          }
        }
      }
      return null;
    }

    // 1. Ưu tiên đọc từ config của resolved
    int? found = findInConfig(config);

    // 2. Đọc trực tiếp từ cấp resolved (resolved['max_files'], ...)
    found ??= findInMap(resolvedJson);

    // 3. Đọc từ cấp block (block['max_files'], block['config'], ...)
    if (blockJson != null) {
      found ??= findInMap(blockJson);
      found ??= findInConfig(blockJson['config']);
      if (blockJson['validation'] is Map) {
        found ??= findInMap(blockJson['validation'] as Map);
      }
    }

    if (found != null) {
      // §1: max_files <= 0 hiểu là 1; kẹp trần 10
      if (found <= 0) return 1;
      if (found > 10) return 10;
      return found;
    }

    // Nếu không khai trong schema (config: [] hoặc vắng mặt):
    // Hệ thống cấu hình tối đa 10 ảnh max cho ô ảnh, nên mặc định là 10
    if (isImage) {
      return 10;
    }

    return 1;
  }
}
