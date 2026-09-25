import '../../domain/entities/route_entity.dart';
import '../../../forms/domain/entities/market_form_entity.dart';

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
  final List<MarketFormConfigEntity> surveyForms;
  final Set<int> submittedSurveyConfigIds;
  final String? errorMessage;
  final String liveVisitDuration;
  final String checkinTime;
  final int visitId;
  final dynamic customer;

  const CheckInState({
    this.status = CheckInStatus.initial,
    this.checkinData,
    this.surveyForms = const [],
    this.submittedSurveyConfigIds = const {},
    this.errorMessage,
    this.liveVisitDuration = '00:00:00',
    this.checkinTime = '--:--:--',
    this.visitId = 41066,
    this.customer,
  });

  /// Danh sách các biểu mẫu khảo sát bắt buộc chưa hoàn thành
  List<MarketFormConfigEntity> get unsubmittedRequiredSurveys {
    return surveyForms
        .where((f) => f.isRequired && !submittedSurveyConfigIds.contains(f.configId))
        .toList();
  }

  bool get hasUnsubmittedRequiredSurveys => unsubmittedRequiredSurveys.isNotEmpty;

  CheckInState copyWith({
    CheckInStatus? status,
    DealerCheckinDataEntity? checkinData,
    List<MarketFormConfigEntity>? surveyForms,
    Set<int>? submittedSurveyConfigIds,
    String? errorMessage,
    String? liveVisitDuration,
    String? checkinTime,
    int? visitId,
    dynamic customer,
  }) {
    return CheckInState(
      status: status ?? this.status,
      checkinData: checkinData ?? this.checkinData,
      surveyForms: surveyForms ?? this.surveyForms,
      submittedSurveyConfigIds: submittedSurveyConfigIds ?? this.submittedSurveyConfigIds,
      errorMessage: errorMessage,
      liveVisitDuration: liveVisitDuration ?? this.liveVisitDuration,
      checkinTime: checkinTime ?? this.checkinTime,
      visitId: visitId ?? this.visitId,
      customer: customer ?? this.customer,
    );
  }
}
