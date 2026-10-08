import '../../domain/entities/route_entity.dart';
import '../../../forms/domain/entities/market_form_entity.dart';
import '../../../visit/domain/entities/visit_entity.dart';
import '../../../visit/domain/entities/visit_photo_entity.dart';
import '../../../visit/domain/entities/visit_requirements_entity.dart';

enum RouteStatus { initial, loading, loaded, error }

class RouteState {
  final RouteStatus status;
  final RouteDetailEntity? routeDetail;
  final List<String> availableRoutes;
  final List<UserRouteEntity> userRoutes;
  final String selectedRoute;
  final String? selectedVisitStatus; // 'all' | 'completed' | 'inProgress' | 'pending'
  final String? selectedCustomerStatus; // 'all' | 'active' | 'inactive' ...
  final String? selectedCustomerType; // 'all' | 'Tất cả loại' | specific type
  final List<String> availableCustomerTypes;
  final List<String> availableCustomerStatuses;
  final int? selectedDayOfWeek;
  final String searchQuery;
  final int selectedTab; // 0: Danh sách, 1: Bản đồ
  final String? selectedDealerId;
  final String? errorMessage;
  final bool isSortedByDistance;
  final double? userLat;
  final double? userLng;
  final VisitEntity? activeVisit;
  final List<VisitEntity> todayVisits;

  const RouteState({
    this.status = RouteStatus.initial,
    this.routeDetail,
    this.availableRoutes = const [],
    this.userRoutes = const [],
    this.selectedRoute = 'Tất cả tuyến',
    this.selectedVisitStatus,
    this.selectedCustomerStatus,
    this.selectedCustomerType,
    this.availableCustomerTypes = const [],
    this.availableCustomerStatuses = const [],
    this.selectedDayOfWeek,
    this.searchQuery = '',
    this.selectedTab = 0,
    this.selectedDealerId,
    this.errorMessage,
    this.isSortedByDistance = false,
    this.userLat,
    this.userLng,
    this.activeVisit,
    this.todayVisits = const [],
  });

  /// Số lượng tiêu chí lọc đang được áp dụng
  int get activeFiltersCount {
    int count = 0;
    if (selectedRoute != 'Tất cả tuyến' && selectedRoute.isNotEmpty) {
      count++;
    }
    if (selectedVisitStatus != null &&
        selectedVisitStatus != 'all' &&
        selectedVisitStatus != 'Tất cả') {
      count++;
    }
    if (selectedCustomerStatus != null &&
        selectedCustomerStatus != 'all' &&
        selectedCustomerStatus != 'Tất cả') {
      count++;
    }
    if (selectedCustomerType != null &&
        selectedCustomerType != 'all' &&
        selectedCustomerType != 'Tất cả' &&
        selectedCustomerType != 'Tất cả loại') {
      count++;
    }
    if (selectedDayOfWeek != null) {
      count++;
    }
    return count;
  }

  /// Kiểm tra xem có bộ lọc nào đang được kích hoạt hay không
  bool get hasActiveFilter => activeFiltersCount > 0;

  RouteState copyWith({
    RouteStatus? status,
    RouteDetailEntity? routeDetail,
    List<String>? availableRoutes,
    List<UserRouteEntity>? userRoutes,
    String? selectedRoute,
    String? selectedVisitStatus,
    bool clearVisitStatus = false,
    String? selectedCustomerStatus,
    bool clearCustomerStatus = false,
    String? selectedCustomerType,
    bool clearCustomerType = false,
    List<String>? availableCustomerTypes,
    List<String>? availableCustomerStatuses,
    int? selectedDayOfWeek,
    bool clearSelectedDayOfWeek = false,
    String? searchQuery,
    int? selectedTab,
    String? selectedDealerId,
    String? errorMessage,
    bool? isSortedByDistance,
    double? userLat,
    double? userLng,
    VisitEntity? activeVisit,
    bool clearActiveVisit = false,
    List<VisitEntity>? todayVisits,
  }) {
    return RouteState(
      status: status ?? this.status,
      routeDetail: routeDetail ?? this.routeDetail,
      availableRoutes: availableRoutes ?? this.availableRoutes,
      userRoutes: userRoutes ?? this.userRoutes,
      selectedRoute: selectedRoute ?? this.selectedRoute,
      selectedVisitStatus: clearVisitStatus
          ? null
          : (selectedVisitStatus ?? this.selectedVisitStatus),
      selectedCustomerStatus: clearCustomerStatus
          ? null
          : (selectedCustomerStatus ?? this.selectedCustomerStatus),
      selectedCustomerType: clearCustomerType
          ? null
          : (selectedCustomerType ?? this.selectedCustomerType),
      availableCustomerTypes:
          availableCustomerTypes ?? this.availableCustomerTypes,
      availableCustomerStatuses:
          availableCustomerStatuses ?? this.availableCustomerStatuses,
      selectedDayOfWeek: clearSelectedDayOfWeek
          ? null
          : (selectedDayOfWeek ?? this.selectedDayOfWeek),
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTab: selectedTab ?? this.selectedTab,
      selectedDealerId: selectedDealerId ?? this.selectedDealerId,
      errorMessage: errorMessage,
      isSortedByDistance: isSortedByDistance ?? this.isSortedByDistance,
      userLat: userLat ?? this.userLat,
      userLng: userLng ?? this.userLng,
      activeVisit: clearActiveVisit ? null : (activeVisit ?? this.activeVisit),
      todayVisits: todayVisits ?? this.todayVisits,
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
  final VisitEntity? visitEntity;
  final VisitRequirementsEntity? requirements;
  final List<VisitPhotoEntity> photos;
  final bool isUploadingPhoto;
  final bool isDeletingPhoto;
  final bool isRefreshingRequirements;
  final String visitResult; // 'visited' | 'closed'
  final String closedNote;

  const CheckInState({
    this.status = CheckInStatus.initial,
    this.checkinData,
    this.surveyForms = const [],
    this.submittedSurveyConfigIds = const {},
    this.errorMessage,
    this.liveVisitDuration = '00:00:00',
    this.checkinTime = '--:--:--',
    this.visitId = 0,
    this.customer,
    this.visitEntity,
    this.requirements,
    this.photos = const [],
    this.isUploadingPhoto = false,
    this.isDeletingPhoto = false,
    this.isRefreshingRequirements = false,
    this.visitResult = 'visited',
    this.closedNote = '',
  });

  /// Danh sách các biểu mẫu khảo sát bắt buộc chưa hoàn thành
  List<MarketFormConfigEntity> get unsubmittedRequiredSurveys {
    return surveyForms
        .where(
          (f) => f.isRequired && !submittedSurveyConfigIds.contains(f.configId),
        )
        .toList();
  }

  bool get hasUnsubmittedRequiredSurveys =>
      unsubmittedRequiredSurveys.isNotEmpty;

  /// Đã thỏa mãn tất cả điều kiện theo requirements API (§6)
  bool get canCheckout => requirements?.satisfied == true;

  /// Danh sách câu việc cần làm từ server (§6 blockers)
  List<String> get blockers => requirements?.blockers ?? const [];

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
    VisitEntity? visitEntity,
    VisitRequirementsEntity? requirements,
    List<VisitPhotoEntity>? photos,
    bool? isUploadingPhoto,
    bool? isDeletingPhoto,
    bool? isRefreshingRequirements,
    String? visitResult,
    String? closedNote,
  }) {
    return CheckInState(
      status: status ?? this.status,
      checkinData: checkinData ?? this.checkinData,
      surveyForms: surveyForms ?? this.surveyForms,
      submittedSurveyConfigIds:
          submittedSurveyConfigIds ?? this.submittedSurveyConfigIds,
      errorMessage: errorMessage,
      liveVisitDuration: liveVisitDuration ?? this.liveVisitDuration,
      checkinTime: checkinTime ?? this.checkinTime,
      visitId: visitId ?? this.visitId,
      customer: customer ?? this.customer,
      visitEntity: visitEntity ?? this.visitEntity,
      requirements: requirements ?? this.requirements,
      photos: photos ?? this.photos,
      isUploadingPhoto: isUploadingPhoto ?? this.isUploadingPhoto,
      isDeletingPhoto: isDeletingPhoto ?? this.isDeletingPhoto,
      isRefreshingRequirements:
          isRefreshingRequirements ?? this.isRefreshingRequirements,
      visitResult: visitResult ?? this.visitResult,
      closedNote: closedNote ?? this.closedNote,
    );
  }
}
