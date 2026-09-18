import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../customer/data/repositories/customer_repository_impl.dart';
import '../../../customer/domain/entities/customer_entity.dart';
import '../../../customer/domain/repositories/customer_repository.dart';
import '../../data/repositories/route_repository_impl.dart';
import '../../data/services/route_api_service.dart';
import '../../domain/entities/route_entity.dart';
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

final routeViewModelProvider =
    StateNotifierProvider.autoDispose<RouteViewModel, RouteState>((ref) {
  final customerRepository = ref.read(customerRepositoryProvider);
  final getRouteDetailUseCase = ref.read(getRouteDetailUseCaseProvider);
  return RouteViewModel(
    customerRepository: customerRepository,
    getRouteDetailUseCase: getRouteDetailUseCase,
  );
});

class RouteViewModel extends StateNotifier<RouteState> {
  final CustomerRepository customerRepository;
  final GetRouteDetailUseCase getRouteDetailUseCase;
  List<CustomerEntity> _rawCustomers = [];

  RouteViewModel({
    required this.customerRepository,
    required this.getRouteDetailUseCase,
  }) : super(const RouteState()) {
    loadRouteDetail();
  }

  void selectTab(int index) {
    state = state.copyWith(selectedTab: index);
  }

  void selectDealer(String? dealerId) {
    state = state.copyWith(selectedDealerId: dealerId);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _recomputeRouteDetail();
  }

  void selectRoute(String routeName) {
    state = state.copyWith(selectedRoute: routeName);
    _recomputeRouteDetail();
  }

  Future<void> loadRouteDetail({bool isRefresh = false}) async {
    state = state.copyWith(status: RouteStatus.loading);
    try {
      // 1. Fetch user's customers from customer repository
      final customers = await customerRepository.getCustomers(forceRefresh: isRefresh);
      _rawCustomers = customers;

      // 2. Extract unique route names from customer list
      final Set<String> routeSet = {'Tất cả tuyến'};
      for (final c in customers) {
        if (c.route.trim().isNotEmpty) {
          routeSet.add(c.route.trim());
        }
      }
      final availableRoutes = routeSet.toList();

      // Ensure selectedRoute is valid
      String selectedRoute = state.selectedRoute;
      if (!availableRoutes.contains(selectedRoute)) {
        selectedRoute = availableRoutes.isNotEmpty ? availableRoutes.first : 'Tất cả tuyến';
      }

      state = state.copyWith(
        availableRoutes: availableRoutes,
        selectedRoute: selectedRoute,
      );

      _recomputeRouteDetail();
    } catch (e) {
      state = state.copyWith(
        status: RouteStatus.error,
        errorMessage: e.toString().replaceAll('AppException: ', ''),
      );
    }
  }

  void _recomputeRouteDetail() {
    // Filter customers by selected route
    var filtered = _rawCustomers;
    if (state.selectedRoute != 'Tất cả tuyến') {
      filtered = filtered.where((c) => c.route == state.selectedRoute).toList();
    }

    // Filter by search query
    final query = state.searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((c) {
        return c.name.toLowerCase().contains(query) ||
            c.code.toLowerCase().contains(query) ||
            c.phone.replaceAll(' ', '').contains(query) ||
            c.address.toLowerCase().contains(query);
      }).toList();
    }

    // Build DealerEntities
    bool hasFoundFirstPending = false;
    final dealers = <DealerEntity>[];

    for (int i = 0; i < filtered.length; i++) {
      final c = filtered[i];
      DealerVisitStatus visitStatus;
      String statusLabel;
      String? visitedTime;

      if (c.visitStatus == CustomerVisitStatus.visited) {
        visitStatus = DealerVisitStatus.completed;
        statusLabel = 'Đã ghé';
        visitedTime = '08:45 AM';
      } else {
        if (!hasFoundFirstPending) {
          visitStatus = DealerVisitStatus.inProgress;
          statusLabel = 'Đang ghé';
          hasFoundFirstPending = true;
        } else {
          visitStatus = DealerVisitStatus.pending;
          statusLabel = 'Chưa ghé';
        }
      }

      final isVip = c.type.toLowerCase().contains('npp') ||
          c.type.toLowerCase().contains('cấp 1') ||
          c.type.toLowerCase().contains('siêu thị');

      dealers.add(
        DealerEntity(
          id: c.id.toString(),
          order: (i + 1).toString().padLeft(2, '0'),
          name: c.name,
          code: c.code,
          phone: c.phone,
          contactPerson: c.contactPerson,
          type: c.type,
          address: c.address,
          status: visitStatus,
          statusLabel: statusLabel,
          visitedTime: visitedTime,
          isVip: isVip,
          lat: c.lat,
          lng: c.lng,
          customer: c,
        ),
      );
    }

    final total = dealers.length;
    final completed = dealers.where((d) => d.status == DealerVisitStatus.completed).length;
    final pending = total - completed;
    final progress = total > 0 ? (completed / total) : 0.0;

    final title = state.selectedRoute == 'Tất cả tuyến'
        ? 'Tất cả điểm bán trên tuyến'
        : state.selectedRoute;

    final routeDetail = RouteDetailEntity(
      id: state.selectedRoute,
      title: title,
      totalDealers: total,
      completedDealers: completed,
      pendingDealers: pending,
      progressPercent: progress,
      dealers: dealers,
    );

    state = state.copyWith(
      status: RouteStatus.loaded,
      routeDetail: routeDetail,
      selectedDealerId: state.selectedDealerId ?? (dealers.isNotEmpty ? dealers.first.id : null),
      errorMessage: null,
    );
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
