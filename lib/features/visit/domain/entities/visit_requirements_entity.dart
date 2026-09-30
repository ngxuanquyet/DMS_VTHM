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

class VisitRequirementsEntity {
  final bool satisfied;
  final int secondsRemaining;
  final int photosMissing;
  final List<MissingFormEntity> missingForms;
  final List<String> blockers;

  const VisitRequirementsEntity({
    this.satisfied = false,
    this.secondsRemaining = 0,
    this.photosMissing = 0,
    this.missingForms = const [],
    this.blockers = const [],
  });

  factory VisitRequirementsEntity.fromJson(Map<String, dynamic> json) {
    var rawForms = json['missing_forms'];
    List<MissingFormEntity> forms = [];
    if (rawForms is List) {
      forms = rawForms
          .whereType<Map<String, dynamic>>()
          .map((f) => MissingFormEntity.fromJson(f))
          .toList();
    }

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
      blockers: bl,
    );
  }

  Map<String, dynamic> toJson() => {
        'satisfied': satisfied,
        'seconds_remaining': secondsRemaining,
        'photos_missing': photosMissing,
        'missing_forms': missingForms.map((f) => f.toJson()).toList(),
        'blockers': blockers,
      };

  VisitRequirementsEntity copyWith({
    bool? satisfied,
    int? secondsRemaining,
    int? photosMissing,
    List<MissingFormEntity>? missingForms,
    List<String>? blockers,
  }) {
    return VisitRequirementsEntity(
      satisfied: satisfied ?? this.satisfied,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      photosMissing: photosMissing ?? this.photosMissing,
      missingForms: missingForms ?? this.missingForms,
      blockers: blockers ?? this.blockers,
    );
  }
}
