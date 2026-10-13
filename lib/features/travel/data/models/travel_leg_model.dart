import '../../domain/entities/travel_leg_entity.dart';

class TravelEndpointModel extends TravelEndpointEntity {
  const TravelEndpointModel({
    required super.type,
    super.label,
    super.punchId,
    super.visitId,
    super.customerId,
    super.code,
    super.name,
    super.at,
  });

  factory TravelEndpointModel.fromJson(Map<String, dynamic> json) {
    return TravelEndpointModel(
      type: json['type']?.toString().toLowerCase() ?? 'missing',
      label: json['label']?.toString(),
      punchId: json['punch_id'] != null
          ? int.tryParse(json['punch_id'].toString())
          : null,
      visitId: json['visit_id'] != null
          ? int.tryParse(json['visit_id'].toString())
          : null,
      customerId: json['customer_id'] != null
          ? int.tryParse(json['customer_id'].toString())
          : null,
      code: json['code']?.toString(),
      name: json['name']?.toString(),
      at: json['at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        if (label != null) 'label': label,
        if (punchId != null) 'punch_id': punchId,
        if (visitId != null) 'visit_id': visitId,
        if (customerId != null) 'customer_id': customerId,
        if (code != null) 'code': code,
        if (name != null) 'name': name,
        if (at != null) 'at': at,
      };
}

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
    super.from,
    super.to,
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
      from: json['from'] is Map<String, dynamic>
          ? TravelEndpointModel.fromJson(json['from'] as Map<String, dynamic>)
          : null,
      to: json['to'] is Map<String, dynamic>
          ? TravelEndpointModel.fromJson(json['to'] as Map<String, dynamic>)
          : null,
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
        if (from != null && from is TravelEndpointModel)
          'from': (from as TravelEndpointModel).toJson()
        else if (from != null)
          'from': {
            'type': from!.type,
            if (from!.label != null) 'label': from!.label,
            if (from!.punchId != null) 'punch_id': from!.punchId,
            if (from!.visitId != null) 'visit_id': from!.visitId,
            if (from!.customerId != null) 'customer_id': from!.customerId,
            if (from!.code != null) 'code': from!.code,
            if (from!.name != null) 'name': from!.name,
            if (from!.at != null) 'at': from!.at,
          },
        if (to != null && to is TravelEndpointModel)
          'to': (to as TravelEndpointModel).toJson()
        else if (to != null)
          'to': {
            'type': to!.type,
            if (to!.label != null) 'label': to!.label,
            if (to!.punchId != null) 'punch_id': to!.punchId,
            if (to!.visitId != null) 'visit_id': to!.visitId,
            if (to!.customerId != null) 'customer_id': to!.customerId,
            if (to!.code != null) 'code': to!.code,
            if (to!.name != null) 'name': to!.name,
            if (to!.at != null) 'at': to!.at,
          },
      };
}
