import 'dart:convert';

import '../../../../core/dynamic_form/choice_other.dart';
import '../../../../core/dynamic_form/formula_evaluator.dart';

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
  final String visitScope; // 'all' | 'first' | 'repeat' (§1 SPEC-2026-10-18)

  const MarketFormConfigEntity({
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

  bool get isSurvey => kind == 'survey';
  bool get isCollect => kind == 'collect';
  bool get isScopeFirst => visitScope == 'first';
  bool get isScopeRepeat => visitScope == 'repeat';
  bool get isScopeAll => visitScope == 'all';
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

  bool get isImage => resolved.isImage;
  bool get isLocation => resolved.isLocation;
  int get maxFiles => resolved.maxFiles;
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
  final int maxFiles; // Số lượng ảnh tối đa của ô (mặc định 10 theo config hệ thống, kẹp trần 10 theo §1)
  /// Số ảnh tối thiểu (`config.min_files`, 0 = không đòi) — như server: chỉ áp khi ô ĐÃ có ảnh; ô trống do `required` quyết.
  final int minFiles;

  const MarketFormResolvedEntity({
    required this.code,
    required this.label,
    required this.inputType,
    this.config,
    this.description,
    this.options = const [],
    this.validation,
    this.maxFiles = 10,
    this.minFiles = 0,
  });

  bool get isImage => inputType.toLowerCase() == 'image';
  bool get isLocation => inputType.toLowerCase() == 'location';

  /// Ô CÔNG THỨC (`input_type = formula`): cấu hình `config.formula` / `format` / `decimals` / `blank_if_missing`;
  /// `null` = ô khác hoặc thiếu biểu thức.
  FormulaConfig? get formula {
    if (inputType.toLowerCase() != 'formula') return null;
    return FormulaConfig.fromMap(_configMap, exprKey: 'formula', blankKey: 'blank_if_missing');
  }

  /// Ô chọn (select / radio / multiselect / checkbox có lựa chọn) cho nhập «Khác…» (`config.allow_other`) — xem
  /// [ChoiceOther].
  bool get allowOther => options.isNotEmpty && ChoiceOther.enabledIn({'config': _configMap});

  /// `config` dạng Map (server có thể gửi chuỗi JSON); `null` nếu không đọc được.
  Map? get _configMap {
    var cfg = config;
    if (cfg is String && cfg.trim().startsWith('{')) {
      try {
        cfg = jsonDecode(cfg);
      } catch (_) {
        return null;
      }
    }
    return cfg is Map ? cfg : null;
  }
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
