import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../customer/data/repositories/customer_repository_impl.dart';
import '../../../customer/domain/entities/customer_entity.dart';
import '../../../customer/domain/repositories/customer_repository.dart';
import '../../data/repositories/route_repository_impl.dart';
import '../../data/services/route_api_service.dart';
import '../../domain/entities/route_entity.dart';
import '../../domain/repositories/route_repository.dart';
import '../../domain/usecases/route_usecases.dart';
import '../../../forms/domain/usecases/get_available_forms_usecase.dart';
import '../../../forms/presentation/viewmodels/forms_view_model.dart';
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

  void toggleSortByDistance({double? userLat, double? userLng}) {
    if (state.isSortedByDistance) {
      state = state.copyWith(isSortedByDistance: false);
    } else {
      state = state.copyWith(
        isSortedByDistance: true,
        userLat: userLat ?? state.userLat,
        userLng: userLng ?? state.userLng,
      );
    }
    _recomputeRouteDetail();
  }

  void updateUserLocation({required double lat, required double lng}) {
    state = state.copyWith(userLat: lat, userLng: lng);
    if (state.isSortedByDistance) {
      _recomputeRouteDetail();
    }
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

    // Filter by search query (hỗ trợ không dấu)
    final rawQuery = state.searchQuery.trim();
    if (rawQuery.isNotEmpty) {
      final query = StringUtils.toUnaccentedLower(rawQuery);
      filtered = filtered.where((c) {
        return StringUtils.toUnaccentedLower(c.name).contains(query) ||
            c.code.toLowerCase().contains(query) ||
            c.phone.replaceAll(' ', '').contains(query) ||
            StringUtils.toUnaccentedLower(c.address).contains(query) ||
            StringUtils.toUnaccentedLower(c.route).contains(query) ||
            (c.contactTitle != null && StringUtils.toUnaccentedLower(c.contactTitle).contains(query));
      }).toList();
    }

    // Sort by distance if enabled
    if (state.isSortedByDistance && state.userLat != null && state.userLng != null) {
      filtered = List.from(filtered);
      filtered.sort((a, b) {
        if (!a.hasCoordinates && !b.hasCoordinates) return 0;
        if (!a.hasCoordinates) return 1;
        if (!b.hasCoordinates) return -1;
        final distA = Geolocator.distanceBetween(state.userLat!, state.userLng!, a.lat!, a.lng!);
        final distB = Geolocator.distanceBetween(state.userLat!, state.userLng!, b.lat!, b.lng!);
        return distA.compareTo(distB);
      });
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
        ? 'Tuyến'
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

  Future<bool> deletePendingCustomer(String clientUuid) async {
    try {
      final success = await customerRepository.deletePendingCustomer(clientUuid);
      if (success) {
        _rawCustomers.removeWhere((c) => c.clientUuid == clientUuid);
        _recomputeRouteDetail();
      }
      return success;
    } catch (_) {
      return false;
    }
  }
}

final checkInViewModelProvider =
    StateNotifierProvider.autoDispose<CheckInViewModel, CheckInState>((ref) {
  return CheckInViewModel(
    getDealerCheckinUseCase: ref.read(getDealerCheckinUseCaseProvider),
    checkoutDealerUseCase: ref.read(checkoutDealerUseCaseProvider),
    getAvailableFormsUseCase: ref.read(getAvailableFormsUseCaseProvider),
  );
});

class CheckInViewModel extends StateNotifier<CheckInState> {
  final GetDealerCheckinUseCase getDealerCheckinUseCase;
  final CheckoutDealerUseCase checkoutDealerUseCase;
  final GetAvailableFormsUseCase getAvailableFormsUseCase;
  Timer? _visitTimer;
  int _elapsedSeconds = 0;

  CheckInViewModel({
    required this.getDealerCheckinUseCase,
    required this.checkoutDealerUseCase,
    required this.getAvailableFormsUseCase,
  }) : super(const CheckInState(liveVisitDuration: '00:00:00')) {
    loadCheckinData();
    _startTimer();
  }

  Future<void> loadSurveyForms(int customerId) async {
    try {
      final forms = await getAvailableFormsUseCase(kind: 'survey', customerId: customerId);
      state = state.copyWith(surveyForms: forms);
    } catch (_) {}
  }

  void markSurveySubmitted(int configId) {
    final updated = Set<int>.from(state.submittedSurveyConfigIds)..add(configId);
    state = state.copyWith(submittedSurveyConfigIds: updated);
  }

  void initCheckinWithDealer(DealerEntity dealer) {
    final now = DateTime.now();
    final localTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final initialCheckinData = DealerCheckinDataEntity(
      dealer: CheckinDealerEntity(
        id: dealer.id,
        name: dealer.name,
        address: dealer.address,
        isVip: dealer.isVip,
        distanceMeters: 48,
        visitDuration: '00:00:00',
        lat: dealer.lat,
        lng: dealer.lng,
      ),
      tasks: const [
        CheckinTaskEntity(
          id: 'task_form',
          title: 'Thu thập biểu mẫu',
          subtitle: 'Đánh giá trưng bày, Tồn kho',
          completed: 2,
          total: 3,
          type: 'form',
        ),
        CheckinTaskEntity(
          id: 'task_photo',
          title: 'Chụp ảnh điểm bán',
          subtitle: 'Chưa có ảnh',
          completed: 0,
          total: 1,
          type: 'photo',
          isError: true,
        ),
        CheckinTaskEntity(
          id: 'task_note',
          title: 'Ghi chú chuyến ghé',
          subtitle: 'Thêm ý kiến phản hồi',
          completed: 0,
          total: 1,
          type: 'note',
        ),
      ],
    );

    state = state.copyWith(
      status: CheckInStatus.loaded,
      checkinData: initialCheckinData,
      checkinTime: localTime,
      liveVisitDuration: '00:00:00',
      customer: dealer.customer,
    );

    final customerId = dealer.customer is CustomerEntity
        ? (dealer.customer as CustomerEntity).id
        : (int.tryParse(dealer.id.replaceAll(RegExp(r'[^\d]'), '')) ?? 8338);
    loadSurveyForms(customerId);
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

  Future<String> _fetchWorldTime() async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 2),
          receiveTimeout: const Duration(seconds: 2),
        ),
      );
      final response = await dio.get<Map<String, dynamic>>(
        'https://worldtimeapi.org/api/timezone/Asia/Ho_Chi_Minh',
      );
      if (response.statusCode == 200 && response.data != null) {
        final datetimeStr = response.data!['datetime'] as String?;
        if (datetimeStr != null) {
          final dt = DateTime.parse(datetimeStr);
          return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
        }
      }
    } catch (_) {
      // Fallback to local time if API is unreachable / offline
    }
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  Future<void> loadCheckinData() async {
    if (state.checkinData == null) {
      state = state.copyWith(status: CheckInStatus.loading);
    }
    try {
      final now = DateTime.now();
      final localTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      // 1. Tải dữ liệu điểm bán ngay lập tức (<50ms), không để WorldTimeAPI làm đơ màn hình
      final data = await getDealerCheckinUseCase();

      state = state.copyWith(
        status: CheckInStatus.loaded,
        checkinData: data,
        checkinTime: state.checkinTime != '--:--:--' ? state.checkinTime : localTime,
        liveVisitDuration: state.liveVisitDuration,
      );

      final customerId = int.tryParse(data.dealer.id.replaceAll(RegExp(r'[^\d]'), '')) ?? 8338;
      loadSurveyForms(customerId);

      // 2. Đồng bộ chuẩn thời gian từ WorldTimeAPI ngầm, cập nhật ngay khi nhận được
      _fetchWorldTime().then((worldTime) {
        if (mounted) {
          state = state.copyWith(checkinTime: worldTime);
        }
      }).catchError((_) {});
    } catch (e) {
      if (state.checkinData == null) {
        state = state.copyWith(
          status: CheckInStatus.error,
          errorMessage: e.toString().replaceAll('AppException: ', ''),
        );
      }
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
