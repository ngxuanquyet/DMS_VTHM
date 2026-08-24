import '../../domain/entities/dashboard_entity.dart';

enum HomeStatus { initial, loading, loaded, error }

class HomeState {
  final HomeStatus status;
  final DashboardEntity? dashboard;
  final String? errorMessage;
  final bool isRefreshing;

  const HomeState({
    this.status = HomeStatus.initial,
    this.dashboard,
    this.errorMessage,
    this.isRefreshing = false,
  });

  HomeState copyWith({
    HomeStatus? status,
    DashboardEntity? dashboard,
    String? errorMessage,
    bool? isRefreshing,
  }) {
    return HomeState(
      status: status ?? this.status,
      dashboard: dashboard ?? this.dashboard,
      errorMessage: errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}
