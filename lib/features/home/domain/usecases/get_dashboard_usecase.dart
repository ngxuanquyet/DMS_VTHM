import '../entities/dashboard_entity.dart';
import '../repositories/home_repository.dart';

class GetDashboardUseCase {
  final HomeRepository _repository;

  GetDashboardUseCase(this._repository);

  Future<DashboardEntity> call() {
    return _repository.getDashboardData();
  }
}
