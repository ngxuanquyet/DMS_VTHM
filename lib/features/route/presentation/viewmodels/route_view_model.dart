import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/repositories/route_repository_impl.dart';
import '../../data/services/route_api_service.dart';
import '../../domain/repositories/route_repository.dart';
import '../../domain/usecases/route_usecases.dart';
import '../states/route_state.dart';

final routeApiServiceProvider = Provider<RouteApiService>((ref) {
  return RouteApiService(ref.read(apiClientProvider));
});

final routeRepositoryProvider = Provider<RouteRepository>((ref) {
  return RouteRepositoryImpl(ref.read(routeApiServiceProvider));
});

final getRouteDetailUseCaseProvider = Provider<GetRouteDetailUseCase>((ref) {
  return GetRouteDetailUseCase(ref.read(routeRepositoryProvider));
});

final getDealerCheckinUseCaseProvider = Provider<GetDealerCheckinUseCase>((ref) {
  return GetDealerCheckinUseCase(ref.read(routeRepositoryProvider));
});

final checkoutDealerUseCaseProvider = Provider<CheckoutDealerUseCase>((ref) {
  return CheckoutDealerUseCase(ref.read(routeRepositoryProvider));
});

final routeViewModelProvider = StateNotifierProvider.autoDispose<RouteViewModel, RouteState>((ref) {
  return RouteViewModel(
    getRouteDetailUseCase: ref.read(getRouteDetailUseCaseProvider),
  );
});

class RouteViewModel extends StateNotifier<RouteState> {
  final GetRouteDetailUseCase getRouteDetailUseCase;

  RouteViewModel({
    required this.getRouteDetailUseCase,
  }) : super(const RouteState()) {
    loadRouteDetail();
  }

  void selectTab(int index) {
    state = state.copyWith(selectedTab: index);
  }

  Future<void> loadRouteDetail() async {
    state = state.copyWith(status: RouteStatus.loading);
    try {
      final routeDetail = await getRouteDetailUseCase();
      state = state.copyWith(
        status: RouteStatus.loaded,
        routeDetail: routeDetail,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: RouteStatus.error,
        errorMessage: e.toString().replaceAll('AppException: ', ''),
      );
    }
  }
}

final checkInViewModelProvider =
    StateNotifierProvider.autoDispose<CheckInViewModel, CheckInState>((ref) {
  return CheckInViewModel(
    getDealerCheckinUseCase: ref.read(getDealerCheckinUseCaseProvider),
    checkoutDealerUseCase: ref.read(checkoutDealerUseCaseProvider),
  );
});

class CheckInViewModel extends StateNotifier<CheckInState> {
  final GetDealerCheckinUseCase getDealerCheckinUseCase;
  final CheckoutDealerUseCase checkoutDealerUseCase;
  Timer? _visitTimer;
  int _elapsedSeconds = 24 * 60 + 18; // 00:24:18

  CheckInViewModel({
    required this.getDealerCheckinUseCase,
    required this.checkoutDealerUseCase,
  }) : super(const CheckInState()) {
    loadCheckinData();
    _startTimer();
  }

  void _startTimer() {
    _visitTimer?.cancel();
    _visitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      final h = (_elapsedSeconds ~/ 3600).toString().padLeft(2, '0');
      final m = ((_elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
      final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
      state = state.copyWith(liveVisitDuration: '$h:$m:$s');
    });
  }

  Future<void> loadCheckinData() async {
    state = state.copyWith(status: CheckInStatus.loading);
    try {
      final data = await getDealerCheckinUseCase();
      state = state.copyWith(
        status: CheckInStatus.loaded,
        checkinData: data,
        liveVisitDuration: data.dealer.visitDuration,
      );
    } catch (e) {
      state = state.copyWith(
        status: CheckInStatus.error,
        errorMessage: e.toString().replaceAll('AppException: ', ''),
      );
    }
  }

  Future<bool> checkout() async {
    state = state.copyWith(status: CheckInStatus.checkingOut);
    try {
      final dealerId = state.checkinData?.dealer.id ?? 'DL-VP-00128';
      await checkoutDealerUseCase(dealerId);
      state = state.copyWith(status: CheckInStatus.checkedOut);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: CheckInStatus.error,
        errorMessage: e.toString().replaceAll('AppException: ', ''),
      );
      return false;
    }
  }

  @override
  void dispose() {
    _visitTimer?.cancel();
    super.dispose();
  }
}
