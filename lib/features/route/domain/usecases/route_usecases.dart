import '../entities/route_entity.dart';
import '../repositories/route_repository.dart';

class GetRouteDetailUseCase {
  final RouteRepository _repository;

  GetRouteDetailUseCase(this._repository);

  Future<RouteDetailEntity> call() {
    return _repository.getRouteDetail();
  }
}

class GetDealerCheckinUseCase {
  final RouteRepository _repository;

  GetDealerCheckinUseCase(this._repository);

  Future<DealerCheckinDataEntity> call() {
    return _repository.getDealerCheckinData();
  }
}

class CheckoutDealerUseCase {
  final RouteRepository _repository;

  CheckoutDealerUseCase(this._repository);

  Future<bool> call(String dealerId) {
    return _repository.checkoutDealer(dealerId);
  }
}
