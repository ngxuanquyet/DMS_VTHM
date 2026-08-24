import '../../domain/entities/route_entity.dart';
import '../../domain/repositories/route_repository.dart';
import '../services/route_api_service.dart';

class RouteRepositoryImpl implements RouteRepository {
  final RouteApiService _apiService;

  RouteRepositoryImpl(this._apiService);

  @override
  Future<RouteDetailEntity> getRouteDetail() async {
    final model = await _apiService.getRouteDetail();
    return model.toEntity();
  }

  @override
  Future<DealerCheckinDataEntity> getDealerCheckinData() async {
    final model = await _apiService.getDealerCheckinData();
    return model.toEntity();
  }

  @override
  Future<bool> checkoutDealer(String dealerId) async {
    return _apiService.checkoutDealer(dealerId);
  }
}
