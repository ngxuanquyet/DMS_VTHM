import '../../domain/entities/travel_day_entity.dart';

class TravelDayModel extends TravelDayEntity {
  const TravelDayModel({
    required super.id,
    required super.userId,
    required super.workDate,
    super.roadMTotal,
    super.roadKm,
    super.haversineMTotal,
    super.legCount = 0,
    super.legMissingCount = 0,
    super.legErrorCount = 0,
    super.isComplete = false,
    super.calculatedAt,
  });

  factory TravelDayModel.fromJson(Map<String, dynamic> json) {
    return TravelDayModel(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      userId: json['user_id'] is num
          ? (json['user_id'] as num).toInt()
          : (int.tryParse(json['user_id']?.toString() ?? '') ?? 0),
      workDate: json['work_date']?.toString() ?? '',
      roadMTotal: json['road_m_total']?.toString(),
      roadKm: json['road_km'] is num
          ? (json['road_km'] as num)
          : (json['road_km'] != null
              ? num.tryParse(json['road_km'].toString())
              : null),
      haversineMTotal: json['haversine_m_total']?.toString(),
      legCount: json['leg_count'] is num
          ? (json['leg_count'] as num).toInt()
          : (int.tryParse(json['leg_count']?.toString() ?? '') ?? 0),
      legMissingCount: json['leg_missing_count'] is num
          ? (json['leg_missing_count'] as num).toInt()
          : (int.tryParse(json['leg_missing_count']?.toString() ?? '') ?? 0),
      legErrorCount: json['leg_error_count'] is num
          ? (json['leg_error_count'] as num).toInt()
          : (int.tryParse(json['leg_error_count']?.toString() ?? '') ?? 0),
      isComplete: json['is_complete'] == true,
      calculatedAt: json['calculated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'work_date': workDate,
        'road_m_total': roadMTotal,
        'road_km': roadKm,
        'haversine_m_total': haversineMTotal,
        'leg_count': legCount,
        'leg_missing_count': legMissingCount,
        'leg_error_count': legErrorCount,
        'is_complete': isComplete,
        'calculated_at': calculatedAt,
      };
}
