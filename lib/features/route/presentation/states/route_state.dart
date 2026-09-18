import '../../domain/entities/route_entity.dart';

enum RouteStatus { initial, loading, loaded, error }

class RouteState {
  final RouteStatus status;
  final RouteDetailEntity? routeDetail;
  final List<String> availableRoutes;
  final String selectedRoute;
  final String searchQuery;
  final int selectedTab; // 0: Danh sách, 1: Bản đồ
  final String? selectedDealerId;
  final String? errorMessage;

  const RouteState({
    this.status = RouteStatus.initial,
    this.routeDetail,
    this.availableRoutes = const [],
    this.selectedRoute = 'Tất cả tuyến',
    this.searchQuery = '',
    this.selectedTab = 0,
    this.selectedDealerId,
    this.errorMessage,
  });

  RouteState copyWith({
    RouteStatus? status,
    RouteDetailEntity? routeDetail,
    List<String>? availableRoutes,
    String? selectedRoute,
    String? searchQuery,
    int? selectedTab,
    String? selectedDealerId,
    String? errorMessage,
  }) {
    return RouteState(
      status: status ?? this.status,
      routeDetail: routeDetail ?? this.routeDetail,
      availableRoutes: availableRoutes ?? this.availableRoutes,
      selectedRoute: selectedRoute ?? this.selectedRoute,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTab: selectedTab ?? this.selectedTab,
      selectedDealerId: selectedDealerId ?? this.selectedDealerId,
      errorMessage: errorMessage,
    );
  }
}

enum CheckInStatus { initial, loading, loaded, checkingOut, checkedOut, error }

class CheckInState {
  final CheckInStatus status;
  final DealerCheckinDataEntity? checkinData;
  final String? errorMessage;
  final String liveVisitDuration;

  const CheckInState({
    this.status = CheckInStatus.initial,
    this.checkinData,
    this.errorMessage,
    this.liveVisitDuration = '00:24:18',
  });

  CheckInState copyWith({
    CheckInStatus? status,
    DealerCheckinDataEntity? checkinData,
    String? errorMessage,
    String? liveVisitDuration,
  }) {
    return CheckInState(
      status: status ?? this.status,
      checkinData: checkinData ?? this.checkinData,
      errorMessage: errorMessage,
      liveVisitDuration: liveVisitDuration ?? this.liveVisitDuration,
    );
  }
}
