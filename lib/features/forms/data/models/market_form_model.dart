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
  final String visitScope; // 'all' | 'first' | 'repeat' (§1 SPEC-2026-10-18)

  const MarketFormConfigModel({
    required this.configId,
    required this.formId,
    required this.code,
    required this.name,
    required this.kind,
    required this.isRequired,
    required this.sortOrder,
    required this.schema,
    this.visitScope = 'all',
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
      visitScope: json['visit_scope']?.toString() ?? 'all',
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
        'visit_scope': visitScope,
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
      visitScope: visitScope,
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
    Map<String, dynamic> resolvedMap;
    if (json['resolved'] is Map<String, dynamic>) {
      resolvedMap = json['resolved'] as Map<String, dynamic>;
    } else {
      // Khi server trả block dạng phẳng (các thuộc tính nằm ngay ở cấp block)
      resolvedMap = Map<String, dynamic>.from(json);
    }

    return MarketFormBlockModel(
      ref: json['ref']?.toString() ?? json['code']?.toString() ?? '',
      type: json['type']?.toString() ?? 'field',
      required: json['required'] == true || json['required'] == 1,
      colSpan: json['col_span'] is int
          ? json['col_span'] as int
          : (int.tryParse(json['col_span']?.toString() ?? '') ?? 12),
      showIf: json['show_if'],
      resolved: MarketFormResolvedModel.fromJson(
        resolvedMap,
        blockJson: json,
      ),
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
    final rawDesc = json['description'] ??
        json['help_text'] ??
        json['helper_text'] ??
        json['note'] ??
        blockJson?['description'] ??
        blockJson?['help_text'] ??
        blockJson?['helper_text'] ??
        (json['config'] is Map
            ? (json['config']['description'] ??
                json['config']['help_text'] ??
                json['config']['helper_text'])
            : null);

    final inputType = json['input_type']?.toString() ??
        json['type']?.toString() ??
        blockJson?['input_type']?.toString() ??
        blockJson?['type']?.toString() ??
        'text';

    final label = json['label']?.toString() ??
        json['title']?.toString() ??
        json['name']?.toString() ??
        blockJson?['label']?.toString() ??
        blockJson?['title']?.toString() ??
        '';

    final code = json['code']?.toString() ??
        json['ref']?.toString() ??
        blockJson?['code']?.toString() ??
        blockJson?['ref']?.toString() ??
        '';

    final config = json['config'] ?? blockJson?['config'];

    return MarketFormResolvedModel(
      code: code,
      label: label,
      inputType: inputType,
      config: config,
      description: rawDesc?.toString(),
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

    final lowerType = inputType.toLowerCase();
    final lowerCode = code.toLowerCase();
    final isImage = lowerType == 'image' ||
        lowerType == 'file' ||
        lowerType == 'photo' ||
        lowerType == 'photos' ||
        lowerCode.contains('photo') ||
        lowerCode.contains('image');

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

    // `min_files` (server ImageFieldLimits) — không vượt max.
    final rawMin = cfg['min_files'] ?? resolvedJson?['min_files'];
    final parsedMinFiles = lowerType == 'image'
        ? ((rawMin is num ? rawMin.toInt() : num.tryParse('${rawMin ?? ''}')?.toInt()) ?? 0).clamp(0, parsedMaxFiles)
        : 0;

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
      minFiles: parsedMinFiles,
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

    int? parseRuleString(String str) {
      final regExp = RegExp(
        r'(?:max_files|max_photos|max_images|max_count|max|limit)[:=]\s*(\d+)',
        caseSensitive: false,
      );
      final match = regExp.firstMatch(str);
      if (match != null) {
        return int.tryParse(match.group(1)!);
      }
      return null;
    }

    const candidateKeys = [
      'max_files',
      'maxFiles',
      'max_file',
      'maxFile',
      'max_photos',
      'maxPhotos',
      'max_photo',
      'maxPhoto',
      'max_images',
      'maxImages',
      'max_image',
      'maxImage',
      'max_count',
      'maxCount',
      'file_limit',
      'photo_limit',
      'image_limit',
      'max_items',
      'maxItems',
      'max_uploads',
      'maxUploads',
      'max_upload',
      'maxUpload',
      'max_quantity',
      'so_luong_anh',
      'so_anh_toi_da',
      'so_anh',
      'max',
      'limit',
      'maximum',
    ];

    int? findInMap(Map<dynamic, dynamic>? map) {
      if (map == null) return null;

      for (final k in candidateKeys) {
        if (map.containsKey(k)) {
          final res = toInt(map[k]);
          if (res != null) return res;
        }
      }

      // Kiểm tra validation hoặc rules (Map, String, List)
      final valObj = map['validation'] ?? map['rules'];
      if (valObj is Map) {
        for (final k in candidateKeys) {
          if (valObj.containsKey(k)) {
            final res = toInt(valObj[k]);
            if (res != null) return res;
          }
        }
      } else if (valObj is String) {
        final res = parseRuleString(valObj);
        if (res != null) return res;
      } else if (valObj is List) {
        for (final item in valObj) {
          if (item is Map) {
            final res = findInMap(item);
            if (res != null) return res;
          } else if (item is String) {
            final res = parseRuleString(item);
            if (res != null) return res;
          }
        }
      }

      // Kiểm tra các map lồng nhau thông dụng (extra, props, attributes, params)
      for (final subKey in ['extra', 'props', 'attributes', 'params', 'parameters']) {
        if (map[subKey] is Map) {
          final res = findInMap(map[subKey] as Map);
          if (res != null) return res;
        }
      }

      return null;
    }

    int? findInConfig(dynamic raw) {
      if (raw == null) return null;
      if (raw is num) return raw.toInt();
      if (raw is Map) return findInMap(raw);
      if (raw is String) {
        final trimmed = raw.trim();
        if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is Map) return findInMap(decoded);
          } catch (_) {}
        }
        final asNum = toInt(trimmed);
        if (asNum != null) return asNum;
        return parseRuleString(trimmed);
      }
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            final res = findInMap(item);
            if (res != null) return res;
            final keyStr = item['key']?.toString() ??
                item['name']?.toString() ??
                item['id']?.toString() ??
                '';
            if (candidateKeys.contains(keyStr)) {
              final val = toInt(item['value']);
              if (val != null) return val;
            }
          } else if (item is String) {
            final res = parseRuleString(item);
            if (res != null) return res;
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
      if (blockJson['validation'] != null) {
        if (blockJson['validation'] is Map) {
          found ??= findInMap(blockJson['validation'] as Map);
        } else if (blockJson['validation'] is String) {
          found ??= parseRuleString(blockJson['validation'] as String);
        }
      }
      if (blockJson['rules'] != null) {
        if (blockJson['rules'] is Map) {
          found ??= findInMap(blockJson['rules'] as Map);
        } else if (blockJson['rules'] is String) {
          found ??= parseRuleString(blockJson['rules'] as String);
        }
      }
    }

    if (found != null) {
      // §1: max_files <= 0 hiểu là 1; kẹp trần 10 theo spec
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
