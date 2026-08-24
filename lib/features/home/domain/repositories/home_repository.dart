import '../entities/dashboard_entity.dart';

abstract class HomeRepository {
  Future<DashboardEntity> getDashboardData();
}
