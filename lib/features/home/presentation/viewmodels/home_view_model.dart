import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/repositories/home_repository_impl.dart';
import '../../data/services/home_api_service.dart';
import '../../domain/repositories/home_repository.dart';
import '../../domain/usecases/get_dashboard_usecase.dart';
import '../states/home_state.dart';

final homeApiServiceProvider = Provider<HomeApiService>((ref) {
  return HomeApiService(ref.read(apiClientProvider));
});

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepositoryImpl(ref.read(homeApiServiceProvider));
});

final getDashboardUseCaseProvider = Provider<GetDashboardUseCase>((ref) {
  return GetDashboardUseCase(ref.read(homeRepositoryProvider));
});

final homeViewModelProvider = StateNotifierProvider<HomeViewModel, HomeState>((ref) {
  return HomeViewModel(
    getDashboardUseCase: ref.read(getDashboardUseCaseProvider),
  );
});

class HomeViewModel extends StateNotifier<HomeState> {
  final GetDashboardUseCase getDashboardUseCase;

  HomeViewModel({
    required this.getDashboardUseCase,
  }) : super(const HomeState()) {
    loadDashboard();
  }

  Future<void> loadDashboard({bool isRefresh = false}) async {
    if (isRefresh) {
      state = state.copyWith(isRefreshing: true);
    } else {
      state = state.copyWith(status: HomeStatus.loading);
    }

    try {
      final dashboard = await getDashboardUseCase();
      state = state.copyWith(
        status: HomeStatus.loaded,
        dashboard: dashboard,
        isRefreshing: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: HomeStatus.error,
        isRefreshing: false,
        errorMessage: e.toString().replaceAll('AppException: ', ''),
      );
    }
  }
}
