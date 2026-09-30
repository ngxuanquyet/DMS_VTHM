import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../../core/utils/system_clock.dart';
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
import '../../../visit/data/models/checkin_request_model.dart';
import '../../../visit/data/models/checkout_request_model.dart';
import '../../../visit/data/repositories/visit_repository_impl.dart';
import '../../../visit/domain/entities/visit_entity.dart';
import '../../../visit/domain/entities/visit_photo_entity.dart';
import '../../../visit/domain/repositories/visit_repository.dart';
import '../../../visit/domain/usecases/visit_usecases.dart';
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
  final getTodayVisitsUseCase = ref.read(getTodayVisitsUseCaseProvider);
  return RouteViewModel(
    customerRepository: customerRepository,
    getRouteDetailUseCase: getRouteDetailUseCase,
    getTodayVisitsUseCase: getTodayVisitsUseCase,
  );
});

class RouteViewModel extends StateNotifier<RouteState> {
  final CustomerRepository customerRepository;
  final GetRouteDetailUseCase getRouteDetailUseCase;
  final GetTodayVisitsUseCase getTodayVisitsUseCase;
  List<CustomerEntity> _rawCustomers = [];

  RouteViewModel({
    required this.customerRepository,
    required this.getRouteDetailUseCase,
    required this.getTodayVisitsUseCase,
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

      // 2. Fetch today's visits to detect visited/in-progress dealers (§2.3)
      List<VisitEntity> todayVisits = [];
      try {
        todayVisits = await getTodayVisitsUseCase();
      } catch (e) {
        debugPrint('[RouteViewModel] Lỗi khi tải lượt viếng thăm hôm nay: $e');
      }

      VisitEntity? activeVisit;
      for (final v in todayVisits) {
        if (v.isOpen) {
          activeVisit = v;
          break;
        }
      }

      // 3. Extract unique route names from customer list
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
        todayVisits: todayVisits,
        activeVisit: activeVisit,
        clearActiveVisit: activeVisit == null,
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

    // Map today's visits by customer_id (§2.3)
    final Map<int, VisitEntity> visitMap = {};
    for (final v in state.todayVisits) {
      visitMap[v.customerId] = v;
    }

    // Build DealerEntities
    final dealers = <DealerEntity>[];

    for (int i = 0; i < filtered.length; i++) {
      final c = filtered[i];
      final visit = visitMap[c.id];

      DealerVisitStatus visitStatus;
      String statusLabel;
      String? visitedTime;

      if (visit != null) {
        if (visit.isOpen) {
          visitStatus = DealerVisitStatus.inProgress;
          statusLabel = 'Đang ghé';
          if (visit.checkinAt != null) {
            visitedTime =
                '${visit.checkinAt!.hour.toString().padLeft(2, '0')}:${visit.checkinAt!.minute.toString().padLeft(2, '0')}';
          }
        } else {
          visitStatus = DealerVisitStatus.completed;
          statusLabel = 'Đã ghé';
          final inTime = visit.checkinAt;
          final outTime = visit.checkoutAt;
          if (inTime != null && outTime != null) {
            final inStr =
                '${inTime.hour.toString().padLeft(2, '0')}:${inTime.minute.toString().padLeft(2, '0')}';
            final outStr =
                '${outTime.hour.toString().padLeft(2, '0')}:${outTime.minute.toString().padLeft(2, '0')}';
            visitedTime = '$inStr - $outStr';
          } else if (outTime != null) {
            visitedTime =
                '${outTime.hour.toString().padLeft(2, '0')}:${outTime.minute.toString().padLeft(2, '0')}';
          } else if (inTime != null) {
            visitedTime =
                '${inTime.hour.toString().padLeft(2, '0')}:${inTime.minute.toString().padLeft(2, '0')}';
          }
        }
      } else if (c.visitStatus == CustomerVisitStatus.visited) {
        visitStatus = DealerVisitStatus.completed;
        statusLabel = 'Đã ghé';
        visitedTime = '08:30 - 08:45';
      } else {
        visitStatus = DealerVisitStatus.pending;
        statusLabel = 'Chưa ghé';
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
          visit: visit,
        ),
      );
    }

    final total = dealers.length;
    final completed = dealers.where((d) => d.status == DealerVisitStatus.completed).length;
    final pending = total - completed;
    final progress = total > 0 ? completed / total : 0.0;

    final detail = RouteDetailEntity(
      id: 'active_route',
      title: state.selectedRoute,
      totalDealers: total,
      completedDealers: completed,
      pendingDealers: pending,
      progressPercent: progress,
      dealers: dealers,
    );

    state = state.copyWith(
      status: RouteStatus.loaded,
      routeDetail: detail,
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
    StateNotifierProvider<CheckInViewModel, CheckInState>((ref) {
  return CheckInViewModel(
    getDealerCheckinUseCase: ref.read(getDealerCheckinUseCaseProvider),
    checkoutDealerUseCase: ref.read(checkoutDealerUseCaseProvider),
    getAvailableFormsUseCase: ref.read(getAvailableFormsUseCaseProvider),
    checkinUseCase: ref.read(checkinUseCaseProvider),
    checkoutUseCase: ref.read(checkoutUseCaseProvider),
    getVisitRequirementsUseCase: ref.read(getVisitRequirementsUseCaseProvider),
    uploadVisitPhotoUseCase: ref.read(uploadVisitPhotoUseCaseProvider),
    deleteVisitPhotoUseCase: ref.read(deleteVisitPhotoUseCaseProvider),
    cancelVisitUseCase: ref.read(cancelVisitUseCaseProvider),
    visitRepository: ref.read(visitRepositoryProvider),
  );
});

class CheckInViewModel extends StateNotifier<CheckInState> {
  final GetDealerCheckinUseCase getDealerCheckinUseCase;
  final CheckoutDealerUseCase checkoutDealerUseCase;
  final GetAvailableFormsUseCase getAvailableFormsUseCase;
  final CheckinUseCase checkinUseCase;
  final CheckoutUseCase checkoutUseCase;
  final GetVisitRequirementsUseCase getVisitRequirementsUseCase;
  final UploadVisitPhotoUseCase uploadVisitPhotoUseCase;
  final DeleteVisitPhotoUseCase deleteVisitPhotoUseCase;
  final CancelVisitUseCase cancelVisitUseCase;
  final VisitRepository visitRepository;

  Timer? _visitTimer;
  int _elapsedSeconds = 0;
  DateTime? _targetDoneTime;
  String _sessionClientUuid = const Uuid().v4();

  CheckInViewModel({
    required this.getDealerCheckinUseCase,
    required this.checkoutDealerUseCase,
    required this.getAvailableFormsUseCase,
    required this.checkinUseCase,
    required this.checkoutUseCase,
    required this.getVisitRequirementsUseCase,
    required this.uploadVisitPhotoUseCase,
    required this.deleteVisitPhotoUseCase,
    required this.cancelVisitUseCase,
    required this.visitRepository,
  }) : super(const CheckInState(liveVisitDuration: '00:00:00')) {
    _startTimer();
  }

  /// Tải dữ liệu điểm bán mặc định / hiện tại nếu chưa được khởi tạo
  Future<void> loadCheckinData() async {
    if (state.checkinData == null) {
      state = state.copyWith(status: CheckInStatus.loading);
    }
    try {
      final now = DateTime.now();
      final localTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      final data = await getDealerCheckinUseCase();
      state = state.copyWith(
        status: CheckInStatus.loaded,
        checkinData: data,
        checkinTime: state.checkinTime != '--:--:--' ? state.checkinTime : localTime,
        liveVisitDuration: state.liveVisitDuration,
      );

      final customerId = int.tryParse(data.dealer.id.replaceAll(RegExp(r'[^\d]'), '')) ?? 8338;
      loadSurveyForms(customerId);
    } catch (e) {
      if (state.checkinData == null) {
        state = state.copyWith(
          status: CheckInStatus.error,
          errorMessage: e.toString().replaceAll('AppException: ', ''),
        );
      }
    }
  }

  void resetSession() {
    _visitTimer?.cancel();
    _elapsedSeconds = 0;
    _targetDoneTime = null;
    _sessionClientUuid = const Uuid().v4();
    state = const CheckInState(liveVisitDuration: '00:00:00');
  }

  Future<void> loadSurveyForms(int customerId) async {
    try {
      final forms = await getAvailableFormsUseCase(kind: 'survey', customerId: customerId);
      state = state.copyWith(surveyForms: forms);
    } catch (_) {}
  }

  void markSurveySubmitted(int configId) {
    final updated = Set<int>.from(state.submittedSurveyConfigIds)..add(configId);
    
    var updatedReq = state.requirements;
    if (updatedReq != null) {
      final remainingForms = updatedReq.missingForms.where((f) => f.formId != configId).toList();
      final isTimeOk = updatedReq.secondsRemaining <= 0 || state.visitResult == 'closed';
      final isFormsOk = remainingForms.isEmpty || state.visitResult == 'closed';
      final isPhotosOk = updatedReq.photosMissing <= 0;
      final newSatisfied = isTimeOk && isFormsOk && isPhotosOk;

      List<String> newBlockers = List<String>.from(updatedReq.blockers);
      if (remainingForms.isEmpty) {
        newBlockers.removeWhere((b) =>
            b.toLowerCase().contains('khảo sát') ||
            b.toLowerCase().contains('biểu mẫu'));
      }

      updatedReq = updatedReq.copyWith(
        missingForms: remainingForms,
        satisfied: newSatisfied,
        blockers: newBlockers,
      );
    }

    state = state.copyWith(
      submittedSurveyConfigIds: updated,
      requirements: updatedReq,
    );
    if (state.visitId > 0) {
      refreshRequirements();
    }
  }

  /// Khởi tạo phiên viếng thăm với Dealer
  /// Nếu dealer đã có lượt mở (inProgress) -> Tự động phục hồi phiên
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
        distanceMeters: 0,
        visitDuration: '00:00:00',
        lat: dealer.lat,
        lng: dealer.lng,
      ),
      tasks: const [],
    );

    // Kiểm tra nếu dealer đã có lượt viếng thăm đang mở (§2.3)
    if (dealer.visit != null && dealer.visit!.isOpen) {
      final existingVisit = dealer.visit!;
      _sessionClientUuid = const Uuid().v4();
      _setupVisitTimer(existingVisit.checkinAt);

      state = state.copyWith(
        status: CheckInStatus.loaded,
        checkinData: initialCheckinData,
        checkinTime: existingVisit.checkinAt != null
            ? '${existingVisit.checkinAt!.hour.toString().padLeft(2, '0')}:${existingVisit.checkinAt!.minute.toString().padLeft(2, '0')}:${existingVisit.checkinAt!.second.toString().padLeft(2, '0')}'
            : localTime,
        visitId: existingVisit.id,
        visitEntity: existingVisit,
        requirements: existingVisit.requirements,
        customer: dealer.customer,
      );

      final customerId = dealer.customer is CustomerEntity
          ? (dealer.customer as CustomerEntity).id
          : (int.tryParse(dealer.id.replaceAll(RegExp(r'[^\d]'), '')) ?? 8338);
      loadSurveyForms(customerId);
      refreshRequirements();
      return;
    }

    // Trường hợp mới bắt đầu check-in
    _sessionClientUuid = const Uuid().v4();
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

  /// Gọi API check-in thật lên server (§3)
  /// Trả về null nếu thành công; trả về chuỗi thông báo lỗi tiếng Việt nếu bị từ chối
  Future<String?> performCheckin({
    required int customerId,
    double? lat,
    double? lng,
    double? accuracyM,
    String? address,
    bool? isMockLocation,
    String? note,
  }) async {
    try {
      final request = CheckinRequestModel(
        customerId: customerId,
        lat: lat,
        lng: lng,
        accuracyM: accuracyM,
        address: address,
        isMockLocation: isMockLocation,
        clientUuid: _sessionClientUuid,
        clientTime: DateTime.now().toIso8601String(),
        clientBootId: SystemClock.bootId,
        note: note,
      );

      final visit = await checkinUseCase(request);
      _setupVisitTimer(visit.checkinAt);

      var req = visit.requirements;
      if (req != null && req.secondsRemaining > 0) {
        _targetDoneTime = DateTime.now().add(Duration(seconds: req.secondsRemaining));
      }

      final cTime = visit.checkinAt != null
          ? '${visit.checkinAt!.hour.toString().padLeft(2, '0')}:${visit.checkinAt!.minute.toString().padLeft(2, '0')}:${visit.checkinAt!.second.toString().padLeft(2, '0')}'
          : state.checkinTime;

      state = state.copyWith(
        visitId: visit.id,
        visitEntity: visit,
        requirements: req,
        checkinTime: cTime,
        status: CheckInStatus.loaded,
      );

      loadSurveyForms(customerId);
      if (req == null) {
        refreshRequirements();
      }
      return null;
    } catch (e) {
      final msg = e.toString().replaceAll('ServerException: ', '').replaceAll('AppException: ', '');
      state = state.copyWith(errorMessage: msg);
      return msg;
    }
  }

  void _setupVisitTimer(DateTime? checkinTime) {
    _visitTimer?.cancel();
    if (checkinTime != null) {
      final diff = DateTime.now().difference(checkinTime).inSeconds;
      _elapsedSeconds = diff > 0 ? diff : 0;
    } else {
      _elapsedSeconds = 0;
    }
    _startTimer();
  }

  void _startTimer() {
    _visitTimer?.cancel();
    _visitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      final h = (_elapsedSeconds ~/ 3600).toString().padLeft(2, '0');
      final m = ((_elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
      final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');

      var updatedReq = state.requirements;
      if (updatedReq != null) {
        int newSec = updatedReq.secondsRemaining;
        if (_targetDoneTime != null) {
          final diff = _targetDoneTime!.difference(DateTime.now()).inSeconds;
          newSec = diff > 0 ? diff : 0;
        } else if (newSec > 0) {
          newSec = newSec - 1;
        }

        final isTimeOk = newSec <= 0 || state.visitResult == 'closed';
        final isFormsOk = updatedReq.missingForms.isEmpty || state.visitResult == 'closed';
        final isPhotosOk = updatedReq.photosMissing <= 0;
        final newSatisfied = isTimeOk && isFormsOk && isPhotosOk;

        List<String> newBlockers = List<String>.from(updatedReq.blockers);
        if (newSec <= 0) {
          newBlockers.removeWhere((b) =>
              b.toLowerCase().contains('thời gian') ||
              b.toLowerCase().contains('giây') ||
              b.toLowerCase().contains('phút') ||
              b.toLowerCase().contains('ở lại thêm'));
        }

        final hadSecondsLeft = updatedReq.secondsRemaining > 0;
        updatedReq = updatedReq.copyWith(
          secondsRemaining: newSec,
          satisfied: newSatisfied,
          blockers: newBlockers,
        );

        if (hadSecondsLeft && newSec == 0 && state.visitId > 0) {
          refreshRequirements();
        }
      }

      state = state.copyWith(
        liveVisitDuration: '$h:$m:$s',
        requirements: updatedReq,
      );
    });
  }

  /// Tải 1 tấm ảnh lên cho lượt viếng thăm (§4.1)
  Future<(bool, String?)> uploadPhoto(
    File file, {
    String photoType = 'other',
    double? lat,
    double? lng,
  }) async {
    if (state.visitId <= 0) {
      return (false, 'Chưa có lượt viếng thăm hợp lệ');
    }
    state = state.copyWith(isUploadingPhoto: true);
    try {
      final photo = await uploadVisitPhotoUseCase(
        visitId: state.visitId,
        file: file,
        photoType: photoType,
        takenAt: DateTime.now(),
        lat: lat,
        lng: lng,
      );

      final updatedPhotos = List<VisitPhotoEntity>.from(state.photos)..add(photo);
      var currentReq = state.requirements;
      if (currentReq != null && !photo.duplicate) {
        final newPhotosMissing = math.max(0, currentReq.photosMissing - 1);
        final isTimeOk = currentReq.secondsRemaining <= 0 || state.visitResult == 'closed';
        final isFormsOk = currentReq.missingForms.isEmpty || state.visitResult == 'closed';
        final isPhotosOk = newPhotosMissing <= 0;
        final newSatisfied = isTimeOk && isFormsOk && isPhotosOk;

        List<String> newBlockers = List<String>.from(currentReq.blockers);
        if (newPhotosMissing <= 0) {
          newBlockers.removeWhere((b) =>
              b.toLowerCase().contains('ảnh') ||
              b.toLowerCase().contains('chụp'));
        }

        currentReq = currentReq.copyWith(
          photosMissing: newPhotosMissing,
          satisfied: newSatisfied,
          blockers: newBlockers,
        );
      }

      state = state.copyWith(
        photos: updatedPhotos,
        requirements: currentReq,
        isUploadingPhoto: false,
      );

      await refreshRequirements();

      if (photo.duplicate) {
        return (true, 'Ảnh này đã có trong lượt viếng thăm, không thêm gì thêm.');
      }
      return (true, null);
    } catch (e) {
      state = state.copyWith(isUploadingPhoto: false);
      final msg = e.toString().replaceAll('ServerException: ', '').replaceAll('AppException: ', '');
      return (false, msg);
    }
  }

  /// Xoá 1 tấm ảnh (§4.2)
  Future<(bool, String?)> deletePhoto(int photoId) async {
    if (state.visitId <= 0) {
      return (false, 'Chưa có lượt viếng thăm');
    }
    state = state.copyWith(isDeletingPhoto: true);
    try {
      final newReq = await deleteVisitPhotoUseCase(
        visitId: state.visitId,
        photoId: photoId,
      );

      final updatedPhotos = state.photos.where((p) => p.id != photoId).toList();
      state = state.copyWith(
        photos: updatedPhotos,
        requirements: newReq,
        isDeletingPhoto: false,
      );
      return (true, null);
    } catch (e) {
      state = state.copyWith(isDeletingPhoto: false);
      final msg = e.toString().replaceAll('ServerException: ', '').replaceAll('AppException: ', '');
      return (false, msg);
    }
  }

  /// Làm mới thông tin điều kiện check-out từ server (§6)
  Future<void> refreshRequirements({String? visitResult}) async {
    if (state.visitId <= 0) return;
    try {
      final req = await getVisitRequirementsUseCase(
        state.visitId,
        visitResult: visitResult ?? state.visitResult,
      );
      if (req.secondsRemaining > 0) {
        _targetDoneTime = DateTime.now().add(Duration(seconds: req.secondsRemaining));
      } else {
        _targetDoneTime = null;
      }
      state = state.copyWith(requirements: req);
    } catch (_) {}
  }

  /// Đổi kết quả viếng thăm: 'visited' (Mở cửa) hoặc 'closed' (Đóng cửa)
  void setVisitResult(String result) {
    if (state.visitResult != result) {
      final isClosed = result == 'closed';
      var currentReq = state.requirements;
      if (currentReq != null) {
        final isPhotosOk = currentReq.photosMissing <= 0;
        final isTimeOk = isClosed || currentReq.secondsRemaining <= 0;
        final isFormsOk = isClosed || currentReq.missingForms.isEmpty;
        final satisfied = isPhotosOk && isTimeOk && isFormsOk;
        currentReq = currentReq.copyWith(satisfied: satisfied);
      }
      state = state.copyWith(
        visitResult: result,
        requirements: currentReq,
      );
      refreshRequirements(visitResult: result);
    }
  }

  /// Ghi chú lý do đóng cửa
  void setClosedNote(String note) {
    state = state.copyWith(closedNote: note);
  }

  /// Thực hiện check-out (§7)
  Future<(bool, String?)> checkout({
    double? lat,
    double? lng,
    double? accuracyM,
  }) async {
    if (state.visitId <= 0) {
      return (false, 'Lượt viếng thăm chưa được tạo trên máy chủ');
    }

    state = state.copyWith(status: CheckInStatus.checkingOut);
    try {
      final request = CheckoutRequestModel(
        visitResult: state.visitResult,
        closedNote: state.visitResult == 'closed' ? state.closedNote : null,
        lat: lat,
        lng: lng,
        accuracyM: accuracyM,
        clientTime: DateTime.now().toIso8601String(),
        clientBootId: SystemClock.bootId,
      );

      await checkoutUseCase(
        visitId: state.visitId,
        request: request,
      );

      _visitTimer?.cancel();
      state = state.copyWith(status: CheckInStatus.checkedOut);
      return (true, null);
    } catch (e) {
      final rawMsg = e.toString();
      // Nếu server trả về 422 "đã check-out rồi" / "đã đóng" thì coi là thành công (§9)
      if (rawMsg.contains('đã check-out rồi') || rawMsg.contains('đã đóng')) {
        _visitTimer?.cancel();
        state = state.copyWith(status: CheckInStatus.checkedOut);
        return (true, null);
      }

      final msg = rawMsg.replaceAll('ServerException: ', '').replaceAll('AppException: ', '');
      state = state.copyWith(
        status: CheckInStatus.loaded,
        errorMessage: msg,
      );
      return (false, msg);
    }
  }

  /// Huỷ lượt check-in (§3.4 HUY-LUOT-VIENG-THAM-2026-09-30.md)
  Future<(bool, String?)> cancelVisit() async {
    final visitId = state.visitId;

    // Nếu lượt chưa kịp tạo trên máy chủ (ví dụ mới khởi tạo cục bộ) -> chỉ cần xoá session
    if (visitId <= 0) {
      _visitTimer?.cancel();
      resetSession();
      return (true, null);
    }

    try {
      await cancelVisitUseCase(visitId);
      _visitTimer?.cancel();
      resetSession();
      return (true, null);
    } catch (e) {
      final rawMsg = e.toString();
      // Server idempotent (§3.4): Nếu đã huỷ trước đó thì coi là thành công
      if (rawMsg.contains('đã bị huỷ') || rawMsg.contains('đã huỷ')) {
        _visitTimer?.cancel();
        resetSession();
        return (true, null);
      }
      final msg = rawMsg.replaceAll('ServerException: ', '').replaceAll('AppException: ', '');
      return (false, msg);
    }
  }

  @override
  void dispose() {
    _visitTimer?.cancel();
    super.dispose();
  }
}
