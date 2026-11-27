import '../../domain/entities/route_entity.dart';
import '../../../forms/domain/entities/market_form_entity.dart';
import '../../../visit/domain/entities/visit_entity.dart';
import '../../../visit/domain/entities/visit_photo_entity.dart';
import '../../../visit/domain/entities/visit_requirements_entity.dart';
import '../../../../core/constants/search_target.dart';

enum RouteStatus { initial, loading, loaded, error }

/// Nguồn điểm bán trên màn lộ trình (One #25938): mọi điểm bán / chỉ điểm bán thuộc «Khu vực chăm sóc» (tỉnh được giao) /
/// chỉ điểm bán theo «Kế hoạch chăm sóc» (tuyến của mình; không có tuyến riêng ⇒ mọi điểm bán KHÔNG đến từ khu vực).
enum CareScope { all, area, plan }

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
  final CareScope careScope;
  final String searchQuery;
  final SearchTarget searchTarget;
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
    this.careScope = CareScope.all,
    this.searchQuery = '',
    this.searchTarget = SearchTarget.all,
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
    CareScope? careScope,
    String? searchQuery,
    SearchTarget? searchTarget,
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
      careScope: careScope ?? this.careScope,
      searchQuery: searchQuery ?? this.searchQuery,
      searchTarget: searchTarget ?? this.searchTarget,
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

  /// [surveyForms] đã đọc được (từ server hoặc bản lưu trong máy) cho điểm bán của lượt — `false` khi chưa đọc được
  /// (đang tải / mất mạng mà máy chưa từng lưu danh sách của điểm bán này). Phân biệt với danh sách RỖNG: rỗng là chắc
  /// chắn không có biểu mẫu bắt buộc, còn chưa đọc được thì cổng biểu mẫu của lượt ngoại tuyến không biết gì (rà soát
  /// 24/11/2026).
  final bool surveyFormsLoaded;
  final Set<int> submittedSurveyConfigIds;
  final String? errorMessage;
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
  final String visitNote;
  final bool isOutOfGeofence;
  final double? currentDistanceToDealerM;
  final double? allowedGeofenceRadiusM;

  const CheckInState({
    this.status = CheckInStatus.initial,
    this.checkinData,
    this.surveyForms = const [],
    this.surveyFormsLoaded = false,
    this.submittedSurveyConfigIds = const {},
    this.errorMessage,
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
    this.visitNote = '',
    this.isOutOfGeofence = false,
    this.currentDistanceToDealerM,
    this.allowedGeofenceRadiusM,
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

  /// Check-out lượt NGOẠI TUYẾN (id âm — cổng biểu mẫu do máy tự dựng từ [surveyForms]) mà chưa đọc được danh sách biểu
  /// mẫu ⇒ cảnh báo trước khi check-out: có thể còn phiếu bắt buộc chưa nộp, đồng bộ sẽ bị server từ chối. Vẫn cho
  /// check-out (chủ hệ thống chốt, #25868). Lượt đã lên server: cổng biểu mẫu là danh sách của server. Đóng cửa: không có
  /// cổng biểu mẫu.
  bool get shouldWarnUnknownRequiredForms => visitId < 0 && visitResult != 'closed' && !surveyFormsLoaded;

  /// Đã thỏa mãn tất cả điều kiện theo requirements API (§6)
  bool get canCheckout => requirements?.satisfied == true;

  /// Danh sách câu việc cần làm từ server (§6 blockers)
  List<String> get blockers => requirements?.blockers ?? const [];

  CheckInState copyWith({
    CheckInStatus? status,
    DealerCheckinDataEntity? checkinData,
    List<MarketFormConfigEntity>? surveyForms,
    bool? surveyFormsLoaded,
    Set<int>? submittedSurveyConfigIds,
    String? errorMessage,
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
    String? visitNote,
    bool? isOutOfGeofence,
    double? currentDistanceToDealerM,
    double? allowedGeofenceRadiusM,
  }) {
    return CheckInState(
      status: status ?? this.status,
      checkinData: checkinData ?? this.checkinData,
      surveyForms: surveyForms ?? this.surveyForms,
      surveyFormsLoaded: surveyFormsLoaded ?? this.surveyFormsLoaded,
      submittedSurveyConfigIds:
          submittedSurveyConfigIds ?? this.submittedSurveyConfigIds,
      errorMessage: errorMessage,
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
      visitNote: visitNote ?? this.visitNote,
      isOutOfGeofence: isOutOfGeofence ?? this.isOutOfGeofence,
      currentDistanceToDealerM:
          currentDistanceToDealerM ?? this.currentDistanceToDealerM,
      allowedGeofenceRadiusM:
          allowedGeofenceRadiusM ?? this.allowedGeofenceRadiusM,
    );
  }
}
