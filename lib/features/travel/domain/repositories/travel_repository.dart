import '../entities/travel_day_entity.dart';
import '../entities/travel_leg_entity.dart';

abstract class TravelRepository {
  /// Lấy quãng đường của chính mình theo ngày (§4.1)
  /// GET /dms/travel/mine
  Future<List<TravelDayEntity>> getMyTravel({
    String? from,
    String? to,
    int page = 1,
    int perPage = 50,
    String sort = '-work_date',
    bool forceRefresh = false,
  });

  /// Lấy chi tiết từng chặng của một ngày công (§4.2)
  /// GET /dms/travel/legs/{userId}/{workDate}
  Future<List<TravelLegEntity>> getTravelLegs({
    required dynamic userId,
    required String workDate,
    bool forceRefresh = false,
  });
}
