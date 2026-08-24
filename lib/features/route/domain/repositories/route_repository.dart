import '../entities/route_entity.dart';

abstract class RouteRepository {
  Future<RouteDetailEntity> getRouteDetail();
  Future<DealerCheckinDataEntity> getDealerCheckinData();
  Future<bool> checkoutDealer(String dealerId);
}
