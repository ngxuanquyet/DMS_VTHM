class MissingFormEntity {
  final int formId;
  final String name;

  const MissingFormEntity({
    required this.formId,
    required this.name,
  });

  factory MissingFormEntity.fromJson(Map<String, dynamic> json) {
    return MissingFormEntity(
      formId: json['form_id'] is num
          ? (json['form_id'] as num).toInt()
          : (int.tryParse(json['form_id']?.toString() ?? '') ?? 0),
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'form_id': formId,
        'name': name,
      };
}

/// Loại vật tư bắt buộc chưa kiểm trong lượt (cổng check-out ④ — `missing_materials`, #24522).
class MissingMaterialEntity {
  final int materialTypeId;
  final String name;

  const MissingMaterialEntity({
    required this.materialTypeId,
    required this.name,
  });

  factory MissingMaterialEntity.fromJson(Map<String, dynamic> json) {
    return MissingMaterialEntity(
      materialTypeId: json['material_type_id'] is num
          ? (json['material_type_id'] as num).toInt()
          : (int.tryParse(json['material_type_id']?.toString() ?? '') ?? 0),
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'material_type_id': materialTypeId,
        'name': name,
      };
}

class VisitRequirementsEntity {
  final bool satisfied;
  final int secondsRemaining;
  final int photosMissing;
  final List<MissingFormEntity> missingForms;
  final List<MissingMaterialEntity> missingMaterials;
  final List<String> blockers;

  const VisitRequirementsEntity({
    this.satisfied = false,
    this.secondsRemaining = 0,
    this.photosMissing = 0,
    this.missingForms = const [],
    this.missingMaterials = const [],
    this.blockers = const [],
  });

  /// Cổng vật tư ④ đã qua — lượt đóng cửa được bỏ qua cổng này.
  bool materialsOk(bool isClosed) => isClosed || missingMaterials.isEmpty;

  factory VisitRequirementsEntity.fromJson(Map<String, dynamic> json) {
    var rawForms = json['missing_forms'];
    List<MissingFormEntity> forms = [];
    if (rawForms is List) {
      forms = rawForms
          .whereType<Map<String, dynamic>>()
          .map((f) => MissingFormEntity.fromJson(f))
          .toList();
    }

    final rawMaterials = json['missing_materials'];
    final materials = rawMaterials is List
        ? rawMaterials
            .whereType<Map>()
            .map((m) => MissingMaterialEntity.fromJson(Map<String, dynamic>.from(m)))
            .toList()
        : <MissingMaterialEntity>[];

    var rawBlockers = json['blockers'];
    List<String> bl = [];
    if (rawBlockers is List) {
      bl = rawBlockers.map((b) => b.toString()).toList();
    }

    return VisitRequirementsEntity(
      satisfied: json['satisfied'] == true,
      secondsRemaining: json['seconds_remaining'] is num
          ? (json['seconds_remaining'] as num).toInt()
          : (int.tryParse(json['seconds_remaining']?.toString() ?? '') ?? 0),
      photosMissing: json['photos_missing'] is num
          ? (json['photos_missing'] as num).toInt()
          : (int.tryParse(json['photos_missing']?.toString() ?? '') ?? 0),
      missingForms: forms,
      missingMaterials: materials,
      blockers: bl,
    );
  }

  Map<String, dynamic> toJson() => {
        'satisfied': satisfied,
        'seconds_remaining': secondsRemaining,
        'photos_missing': photosMissing,
        'missing_forms': missingForms.map((f) => f.toJson()).toList(),
        'missing_materials': missingMaterials.map((m) => m.toJson()).toList(),
        'blockers': blockers,
      };

  VisitRequirementsEntity copyWith({
    bool? satisfied,
    int? secondsRemaining,
    int? photosMissing,
    List<MissingFormEntity>? missingForms,
    List<MissingMaterialEntity>? missingMaterials,
    List<String>? blockers,
  }) {
    return VisitRequirementsEntity(
      satisfied: satisfied ?? this.satisfied,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      photosMissing: photosMissing ?? this.photosMissing,
      missingForms: missingForms ?? this.missingForms,
      missingMaterials: missingMaterials ?? this.missingMaterials,
      blockers: blockers ?? this.blockers,
    );
  }
}
