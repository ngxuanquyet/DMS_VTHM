import '../../domain/entities/route_entity.dart';

enum RouteStatus { initial, loading, loaded, error }

class RouteState {
  final RouteStatus status;
  final RouteDetailEntity? routeDetail;
  final int selectedTab; // 0: Danh sách, 1: Bản đồ
  final String? errorMessage;

  const RouteState({
    this.status = RouteStatus.initial,
    this.routeDetail,
    this.selectedTab = 0,
    this.errorMessage,
  });

  RouteState copyWith({
    RouteStatus? status,
    RouteDetailEntity? routeDetail,
    int? selectedTab,
    String? errorMessage,
  }) {
    return RouteState(
      status: status ?? this.status,
      routeDetail: routeDetail ?? this.routeDetail,
      selectedTab: selectedTab ?? this.selectedTab,
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
