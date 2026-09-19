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
  final bool isSortedByDistance;
  final double? userLat;
  final double? userLng;

  const RouteState({
    this.status = RouteStatus.initial,
    this.routeDetail,
    this.availableRoutes = const [],
    this.selectedRoute = 'Tất cả tuyến',
    this.searchQuery = '',
    this.selectedTab = 0,
    this.selectedDealerId,
    this.errorMessage,
    this.isSortedByDistance = false,
    this.userLat,
    this.userLng,
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
    bool? isSortedByDistance,
    double? userLat,
    double? userLng,
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
      isSortedByDistance: isSortedByDistance ?? this.isSortedByDistance,
      userLat: userLat ?? this.userLat,
      userLng: userLng ?? this.userLng,
    );
  }
}

enum CheckInStatus { initial, loading, loaded, checkingOut, checkedOut, error }

class CheckInState {
  final CheckInStatus status;
  final DealerCheckinDataEntity? checkinData;
  final String? errorMessage;
  final String liveVisitDuration;
  final String checkinTime;

  const CheckInState({
    this.status = CheckInStatus.initial,
    this.checkinData,
    this.errorMessage,
    this.liveVisitDuration = '00:00:00',
    this.checkinTime = '--:--:--',
  });

  CheckInState copyWith({
    CheckInStatus? status,
    DealerCheckinDataEntity? checkinData,
    String? errorMessage,
    String? liveVisitDuration,
    String? checkinTime,
  }) {
    return CheckInState(
      status: status ?? this.status,
      checkinData: checkinData ?? this.checkinData,
      errorMessage: errorMessage,
      liveVisitDuration: liveVisitDuration ?? this.liveVisitDuration,
      checkinTime: checkinTime ?? this.checkinTime,
    );
  }
}
