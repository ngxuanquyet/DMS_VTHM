/// Entity cấu hình biểu mẫu thị trường
class MarketFormConfigEntity {
  final int configId;
  final int formId;
  final String code;
  final String name;
  final String kind; // 'survey' | 'collect'
  final bool isRequired;
  final int sortOrder;
  final MarketFormSchemaEntity schema;

  const MarketFormConfigEntity({
    required this.configId,
    required this.formId,
    required this.code,
    required this.name,
    required this.kind,
    required this.isRequired,
    required this.sortOrder,
    required this.schema,
  });

  bool get isSurvey => kind == 'survey';
  bool get isCollect => kind == 'collect';
}

/// Entity schema chứa danh sách blocks
class MarketFormSchemaEntity {
  final List<MarketFormBlockEntity> blocks;

  const MarketFormSchemaEntity({
    required this.blocks,
  });
}

/// Entity block
class MarketFormBlockEntity {
  final String ref;
  final String type;
  final bool required;
  final int colSpan;
  final dynamic showIf;
  final MarketFormResolvedEntity resolved;

  const MarketFormBlockEntity({
    required this.ref,
    required this.type,
    required this.required,
    this.colSpan = 12,
    this.showIf,
    required this.resolved,
  });

  bool get isPresentation =>
      resolved.inputType == 'heading' ||
      resolved.inputType == 'divider' ||
      resolved.inputType == 'note';
}

/// Entity trường nhập liệu đã giải mã
class MarketFormResolvedEntity {
  final String code;
  final String label;
  final String inputType;
  final dynamic config;
  final String? description;
  final List<MarketFormOptionEntity> options;
  final MarketFormValidationEntity? validation;

  const MarketFormResolvedEntity({
    required this.code,
    required this.label,
    required this.inputType,
    this.config,
    this.description,
    this.options = const [],
    this.validation,
  });
}

/// Lựa chọn cho ô select, multiselect, radio, checkbox
class MarketFormOptionEntity {
  final String value;
  final String label;

  const MarketFormOptionEntity({
    required this.value,
    required this.label,
  });
}

/// Điều kiện ràng buộc validation
class MarketFormValidationEntity {
  final num? min;
  final num? max;
  final int? minLength;
  final int? maxLength;

  const MarketFormValidationEntity({
    this.min,
    this.max,
    this.minLength,
    this.maxLength,
  });
}
