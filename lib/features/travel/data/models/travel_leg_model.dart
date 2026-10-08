import '../../domain/entities/travel_leg_entity.dart';

class TravelLegModel extends TravelLegEntity {
  const TravelLegModel({
    required super.id,
    required super.seq,
    required super.legKind,
    required super.legKindLabel,
    required super.status,
    required super.statusLabel,
    required super.statusColor,
    super.haversineM,
    super.roadM,
    super.fromVisitId,
    super.toVisitId,
    super.fromPunchId,
    super.toPunchId,
    super.provider,
    super.errorNote,
  });

  factory TravelLegModel.fromJson(Map<String, dynamic> json) {
    return TravelLegModel(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      seq: json['seq'] is num
          ? (json['seq'] as num).toInt()
          : (int.tryParse(json['seq']?.toString() ?? '') ?? 1),
      legKind: json['leg_kind']?.toString() ?? 'between',
      legKindLabel: json['leg_kind_label']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      statusLabel: json['status_label']?.toString() ?? '',
      statusColor: json['status_color']?.toString() ?? 'secondary',
      haversineM: json['haversine_m']?.toString(),
      roadM: json['road_m']?.toString(),
      fromVisitId: json['from_visit_id'] != null
          ? int.tryParse(json['from_visit_id'].toString())
          : null,
      toVisitId: json['to_visit_id'] != null
          ? int.tryParse(json['to_visit_id'].toString())
          : null,
      fromPunchId: json['from_punch_id'] != null
          ? int.tryParse(json['from_punch_id'].toString())
          : null,
      toPunchId: json['to_punch_id'] != null
          ? int.tryParse(json['to_punch_id'].toString())
          : null,
      provider: json['provider']?.toString(),
      errorNote: json['error_note']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'seq': seq,
        'leg_kind': legKind,
        'leg_kind_label': legKindLabel,
        'status': status,
        'status_label': statusLabel,
        'status_color': statusColor,
        'haversine_m': haversineM,
        'road_m': roadM,
        'from_visit_id': fromVisitId,
        'to_visit_id': toVisitId,
        'from_punch_id': fromPunchId,
        'to_punch_id': toPunchId,
        'provider': provider,
        'error_note': errorNote,
      };
}
