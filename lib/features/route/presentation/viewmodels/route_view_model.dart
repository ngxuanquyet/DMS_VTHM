import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/rules/mobile_rules_model.dart';
import '../../../../core/rules/mobile_rules_service.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../../core/utils/photo_watermark_helper.dart';
import '../../../../core/utils/system_clock.dart';
import '../../../customer/data/datasources/customer_local_data_source.dart';
import '../../../customer/data/repositories/customer_repository_impl.dart';
import '../../../customer/domain/entities/customer_entity.dart';
import '../../../customer/domain/entities/customer_meta_entity.dart';
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
import '../../../visit/data/services/visit_progress_store.dart';
import '../../../visit/domain/entities/visit_entity.dart';
import '../../../visit/domain/entities/visit_photo_entity.dart';
import '../../../visit/domain/repositories/visit_repository.dart';
import '../../../visit/domain/usecases/visit_usecases.dart';
import '../states/route_state.dart';
import '../../../../core/constants/search_target.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/network/connectivity_provider.dart';

import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/rules/geofence_rule_helper.dart';
import '../../../../core/services/app_notification_service.dart';
import '../../../notifications/presentation/viewmodels/notifications_view_model.dart';
import '../../../travel/presentation/viewmodels/travel_view_model.dart';
import '../../../visit/domain/entities/visit_requirements_entity.dart';
import '../../../visit/data/repositories/visit_material_repository.dart' show visitMaterialFlushTimeout;

final routeApiServiceProvider = Provider<RouteApiService>((ref) {
  return RouteApiService(
    ref.read(apiClientProvider),
    ref.read(appDatabaseProvider),
  );
});

final routeRepositoryProvider = Provider<RouteRepository>((ref) {
  return RouteRepositoryImpl(ref.read(routeApiServiceProvider));
});

final getRouteDetailUseCaseProvider = Provider<GetRouteDetailUseCase>((ref) {
  return GetRouteDetailUseCase(ref.read(routeRepositoryProvider));
});

final getDealerCheckinUseCaseProvider = Provider<GetDealerCheckinUseCase>((
  ref,
) {
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
      final visitRepository = ref.read(visitRepositoryProvider);
      final routeApiService = ref.read(routeApiServiceProvider);
      final vm = RouteViewModel(
        customerRepository: customerRepository,
        getRouteDetailUseCase: getRouteDetailUseCase,
        getTodayVisitsUseCase: getTodayVisitsUseCase,
        visitRepository: visitRepository,
        routeApiService: routeApiService,
        ref: ref,
      );
      // Tải ngầm ghi xong bản mới vào máy ⇒ nạp lại từ máy, không hiện vòng tải (không thì màn giữ bản cũ, vd 199 điểm).
      ref.listen(customerCacheVersionProvider, (_, __) => vm.loadRouteDetail(silent: true));
      return vm;
    });

String _formatTimeHHmmss(DateTime? dt) {
  if (dt == null) return '--:--:--';
  final local = dt.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
}

String _formatTimeHHmm(DateTime? dt) {
  if (dt == null) return '--:--';
  final local = dt.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

class RouteViewModel extends StateNotifier<RouteState> {
  final CustomerRepository customerRepository;
  final GetRouteDetailUseCase getRouteDetailUseCase;
  final GetTodayVisitsUseCase getTodayVisitsUseCase;
  final VisitRepository? visitRepository;
  final RouteApiService? routeApiService;
  final Ref? ref;
  List<CustomerEntity> _rawCustomers = [];
  Timer? _searchDebounce;

  /// Số thứ tự lượt nạp THƯỜNG — lượt thường bắt đầu sau cùng thắng. Lượt nạp NGẦM không tăng số này nên không bao
  /// giờ thay được lượt thường (lượt thường có thể mang lượt viếng thăm vừa check-in, và tự đọc bản mới trong máy).
  int _loadSeq = 0;
  int _normalLoadsInFlight = 0;

  /// Lượt ngầm cũng loại nhau: chỉ lượt ngầm bắt đầu sau cùng được áp.
  int _silentSeq = 0;

  /// Có báo "tải ngầm xong" tới lúc lượt thường đang chạy — lượt thường có thể đã đọc bản CŨ trong máy trước khi tải
  /// ngầm ghi xong (đúng lỗi tuyến 1.090 điểm hiện 199), nên chạy lại lượt ngầm ngay khi lượt thường xong.
  bool _silentPending = false;

  RouteViewModel({
    required this.customerRepository,
    required this.getRouteDetailUseCase,
    required this.getTodayVisitsUseCase,
    this.visitRepository,
    this.routeApiService,
    this.ref,
  }) : super(const RouteState()) {
    loadRouteDetail();
  }

  void setActiveVisit(VisitEntity? visit) {
    if (!mounted) return;
    state = state.copyWith(activeVisit: visit, clearActiveVisit: visit == null);
    _recomputeRouteDetail();
  }

  void markVisitCancelledLocally(int visitId, {String? clientUuid}) {
    if (!mounted) return;
    final updatedVisits = state.todayVisits.map((v) {
      if (v.id == visitId ||
          (clientUuid != null && v.clientUuid == clientUuid)) {
        return v.copyWith(
          cancelledAt: DateTime.now(),
          cancelledAtRaw: DateTime.now().toIso8601String(),
        );
      }
      return v;
    }).toList();

    final shouldClearActive =
        state.activeVisit?.id == visitId ||
        (clientUuid != null && state.activeVisit?.clientUuid == clientUuid);

    state = state.copyWith(
      todayVisits: updatedVisits,
      activeVisit: shouldClearActive ? null : state.activeVisit,
      clearActiveVisit: shouldClearActive,
    );
    _recomputeRouteDetail();
  }

  void selectTab(int index) {
    state = state.copyWith(selectedTab: index);
  }

  void selectDealer(String? dealerId) {
    state = state.copyWith(selectedDealerId: dealerId);
  }

  void setSearchQuery(String query) {
    _searchDebounce?.cancel();
    state = state.copyWith(searchQuery: query);
    _recomputeRouteDetail();
  }

  /// Ô tìm kiếm gọi khi gõ: lọc lại cả tuyến (tới 2.000 điểm bán) sau khi NGỪNG gõ 250ms. Hẹn giờ nằm ở đây để
  /// [setSearchQuery]/[resetFilters] (kể cả từ ngăn bộ lọc) huỷ được — không thì từ khoá cũ bị áp lại sau khi đặt lại.
  void setSearchQueryDebounced(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () => setSearchQuery(query));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void setSearchTarget(SearchTarget target) {
    state = state.copyWith(searchTarget: target);
    _recomputeRouteDetail();
  }

  void selectRoute(String routeName) {
    state = state.copyWith(selectedRoute: routeName);
    _recomputeRouteDetail();
  }

  void selectVisitStatus(String? status) {
    state = state.copyWith(
      selectedVisitStatus: status,
      clearVisitStatus: status == null || status == 'all' || status == 'Tất cả',
    );
    _recomputeRouteDetail();
  }

  void selectCustomerStatus(String? status) {
    state = state.copyWith(
      selectedCustomerStatus: status,
      clearCustomerStatus: status == null || status == 'all' || status == 'Tất cả',
    );
    _recomputeRouteDetail();
  }

  void selectCustomerType(String? type) {
    state = state.copyWith(
      selectedCustomerType: type,
      clearCustomerType: type == null ||
          type == 'all' ||
          type == 'Tất cả' ||
          type == 'Tất cả loại',
    );
    _recomputeRouteDetail();
  }

  void selectDayOfWeek(int? day) {
    if (state.selectedDayOfWeek == day) {
      state = state.copyWith(clearSelectedDayOfWeek: true);
    } else {
      state = state.copyWith(
        selectedDayOfWeek: day,
        clearSelectedDayOfWeek: day == null,
      );
    }
    _recomputeRouteDetail();
  }

  /// Đếm số điểm bán theo từng thứ trong tuần (loại trừ điểm bán bị từ chối).
  ///
  /// Hàng chip ngày gọi hàm này mỗi lần dựng — tính MỘT lần cho 8 chip rồi nhớ, chỉ tính lại khi danh sách điểm bán
  /// hoặc tuyến của tài khoản đổi. Đếm thẳng mỗi lần là 7 × 1.000+ điểm bán × dò tên tuyến theo ngày ⇒ giật.
  int getDealerCountForDay(int? day) {
    if (!identical(_dayCountsCustomers, _rawCustomers) || !identical(_dayCountsRoutes, state.userRoutes)) {
      _dayCounts = null;
    }
    final counts = _dayCounts ??= _countByDay();
    return counts[day == 0 ? 7 : day] ?? 0; // 0 = Chủ nhật (DB/API), như isSameDayOfWeek
  }

  Map<int?, int>? _dayCounts;
  List<CustomerEntity>? _dayCountsCustomers;
  List<UserRouteEntity>? _dayCountsRoutes;

  Map<int?, int> _countByDay() {
    _dayCountsCustomers = _rawCustomers;
    _dayCountsRoutes = state.userRoutes;
    final visible = _rawCustomers.where((c) => !c.isRejectedApproval).toList();
    return {
      null: visible.length,
      for (var d = 1; d <= 7; d++) d: visible.where((c) => _matchesCustomerDayOfWeek(c, d)).length,
    };
  }

  void applyFilters({
    String? route,
    String? visitStatus,
    String? customerStatus,
    String? customerType,
  }) {
    state = state.copyWith(
      selectedRoute: route ?? 'Tất cả tuyến',
      selectedVisitStatus: visitStatus,
      clearVisitStatus: visitStatus == null ||
          visitStatus == 'all' ||
          visitStatus == 'Tất cả',
      selectedCustomerStatus: customerStatus,
      clearCustomerStatus: customerStatus == null ||
          customerStatus == 'all' ||
          customerStatus == 'Tất cả',
      selectedCustomerType: customerType,
      clearCustomerType: customerType == null ||
          customerType == 'all' ||
          customerType == 'Tất cả' ||
          customerType == 'Tất cả loại',
    );
    _recomputeRouteDetail();
  }

  void resetFilters() {
    _searchDebounce?.cancel();
    state = state.copyWith(
      selectedRoute: 'Tất cả tuyến',
      clearVisitStatus: true,
      clearCustomerStatus: true,
      clearCustomerType: true,
      clearSelectedDayOfWeek: true,
      searchQuery: '',
    );
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
    checkProximitySuggestion(userLat: lat, userLng: lng);
  }

  /// Gợi ý thông minh điểm bán lân cận chưa ghé trong bán kính 500m
  void checkProximitySuggestion({double? userLat, double? userLng}) {
    final lat = userLat ?? state.userLat;
    final lng = userLng ?? state.userLng;
    if (lat == null || lng == null || state.routeDetail == null) return;

    final pendingDealers = state.routeDetail!.dealers
        .where((d) =>
            d.status == DealerVisitStatus.pending &&
            d.lat != null &&
            d.lng != null)
        .toList();

    DealerEntity? closest;
    double minDistance = double.infinity;
    for (final d in pendingDealers) {
      final dist = Geolocator.distanceBetween(lat, lng, d.lat!, d.lng!);
      if (dist < minDistance) {
        minDistance = dist;
        closest = d;
      }
    }

    if (closest != null && minDistance <= 500) {
      if (ref != null) {
        try {
          ref!.read(appNotificationServiceProvider).notifyNearbyDealerSuggestion(
                dealerName: closest.name,
                distanceMeters: minDistance.round(),
                dealerId: closest.id,
              );
          ref!.invalidate(unreadNotificationCountProvider);
        } catch (_) {}
      }
    }
  }

  /// Lượt viếng thăm hôm nay + lượt đang mở — có đối chiếu với lượt lưu trong máy (có thể xoá/huỷ lượt lỗi thời).
  /// CHỈ chạy ở lượt nạp thường; lượt nạp ngầm sau tải điểm bán KHÔNG gọi — chụp todayVisits cũ mà đối chiếu đúng lúc
  /// người dùng vừa check-in là huỷ nhầm lượt mới.
  Future<(List<VisitEntity>, VisitEntity?)> _loadTodayVisits() async {
    // 2. Fetch today's visits to detect visited/in-progress dealers (§2.3)
    List<VisitEntity> todayVisits = [];
    try {
      todayVisits = await getTodayVisitsUseCase();
    } catch (e) {
      debugPrint('[RouteViewModel] Lỗi khi tải lượt viếng thăm hôm nay: $e');
    }

    // Kiểm tra các lượt đang nằm trong hàng đợi huỷ ngoại tuyến (sync_queue)
    if (ref != null) {
      try {
        final db = ref!.read(appDatabaseProvider);
        final pendingCancels =
            await (db.select(db.syncQueueEntries)..where(
                  (tbl) =>
                      db.isMine(tbl) &
                      tbl.entity.equals('visit') &
                      tbl.op.equals('cancel') &
                      (tbl.state.equals('pending') |
                          tbl.state.equals('sending')),
                ))
                .get();
        final pendingCancelVisitIds = <int>{};
        final pendingCancelUuids = <String>{};
        for (final entry in pendingCancels) {
          if (entry.parentUuid != null) {
            pendingCancelUuids.add(entry.parentUuid!);
          }
          try {
            final payload = jsonDecode(entry.payload);
            if (payload is Map && payload['visit_id'] != null) {
              final vId = int.tryParse(payload['visit_id'].toString());
              if (vId != null && vId > 0) pendingCancelVisitIds.add(vId);
            }
          } catch (_) {}
        }
        if (pendingCancelVisitIds.isNotEmpty ||
            pendingCancelUuids.isNotEmpty) {
          todayVisits = todayVisits.map((v) {
            if (pendingCancelVisitIds.contains(v.id) ||
                (v.clientUuid != null &&
                    pendingCancelUuids.contains(v.clientUuid))) {
              return v.copyWith(
                cancelledAt: DateTime.now(),
                cancelledAtRaw: DateTime.now().toIso8601String(),
              );
            }
            return v;
          }).toList();
        }
      } catch (_) {}
    }

    VisitEntity? activeVisit;
    for (final v in todayVisits) {
      if (v.isOpen && !v.isCancelled) {
        activeVisit = v;
        break;
      }
    }

    // Nếu không có lượt mở từ API (ví dụ đang offline hoặc lỗi mạng),
    // kiểm tra bản ghi active visit lưu trữ cục bộ trong SharedPreferences
    if (activeVisit == null && visitRepository != null) {
      try {
        final saved = await visitRepository!.getActiveVisit();
        if (saved != null && saved.isOpen && !saved.isCancelled) {
          // Kiểm tra xem lượt này trên server (todayVisits) đã có bản ghi và đã đóng/huỷ chưa
          final matchingServerVisit = todayVisits
              .where(
                (v) =>
                    (v.id == saved.id && v.id > 0) ||
                    v.customerId == saved.customerId,
              )
              .firstOrNull;
          if (matchingServerVisit != null && !matchingServerVisit.isOpen) {
            // Server đã đóng/check-out hoặc huỷ lượt này rồi -> Xoá active visit cục bộ bị lỗi thời!
            debugPrint(
              '[RouteViewModel] Lượt viếng thăm id=${saved.id} đã hoàn tất trên server, xoá active visit stale.',
            );
            await visitRepository!.clearActiveVisit();
          } else if (todayVisits.isNotEmpty && saved.id > 0 && matchingServerVisit == null) {
            // ⚠️ LƯỢT ĐÃ BỊ HUỶ TRÊN SERVER (§4.1 HUY-LUOT-VIENG-THAM-2026-09-30):
            // Khi server trả về todayVisits thành công nhưng lượt server (saved.id > 0) biến mất hoàn toàn
            // khỏi todayVisits, điều đó có nghĩa là lượt này đã bị huỷ trên server!
            debugPrint(
              '[RouteViewModel] Lượt viếng thăm id=${saved.id} không còn trong todayVisits của server (đã bị huỷ), dọn dẹp active visit.',
            );
            await visitRepository!.clearActiveVisit();
            await visitRepository!.cancelVisit(saved.id, clientUuid: saved.clientUuid);
          } else {
            activeVisit = saved;
          }
        }
      } catch (_) {}
    }

    return (todayVisits, activeVisit);
  }

  /// [silent]: nạp lại ngầm (sau lượt tải ngầm) — không chuyển sang trạng thái tải, danh sách đang xem giữ nguyên.
  Future<void> loadRouteDetail({bool isRefresh = false, bool silent = false}) async {
    // Đang có lượt thường chạy ⇒ bỏ lượt ngầm: lượt thường đọc bản mới trong máy và áp cả lượt viếng thăm mới.
    if (silent && _normalLoadsInFlight > 0) {
      _silentPending = true;
      return;
    }
    final seq = silent ? _loadSeq : ++_loadSeq;
    final silentSeq = silent ? ++_silentSeq : _silentSeq;
    if (!silent) {
      _normalLoadsInFlight++;
      state = state.copyWith(status: RouteStatus.loading);
    }
    try {
      // 1. Fetch user's customers from customer repository
      final customers = await customerRepository.getCustomers(
        forceRefresh: isRefresh,
      );

      // 2. Lượt viếng thăm hôm nay (§2.3) — nạp ngầm giữ nguyên lượt đang có, xem [_loadTodayVisits].
      var todayVisits = state.todayVisits;
      VisitEntity? activeVisit = state.activeVisit;
      if (!silent) {
        (todayVisits, activeVisit) = await _loadTodayVisits();
      }

      // 3. Trích xuất danh sách tuyến từ API tuyến của tài khoản (getMyRoutes) và khách hàng
      final Set<String> routeSet = {'Tất cả tuyến'};
      final routeMap = <int, String>{};
      List<UserRouteEntity> loadedUserRoutes = [];

      if (routeApiService != null) {
        try {
          final myRoutes = await routeApiService!.getMyRoutes(
            forceRefresh: isRefresh,
          );
          loadedUserRoutes = myRoutes;
          for (final r in myRoutes) {
            final trimmed = r.name.trim();
            if (trimmed.isNotEmpty &&
                !CustomerEntity.isInvalidOrProvinceRoute(trimmed)) {
              routeSet.add(trimmed);
              routeMap[r.id] = trimmed;
            }
          }
        } catch (_) {}
      }

      // Đồng bộ thông tin tuyến cho các khách hàng (giải mã routeIds nếu c.route chưa có)
      final resolvedCustomers = customers.map((c) {
        final cleanRoutes = c.routes
            .where(
              (r) => !CustomerEntity.isInvalidOrProvinceRoute(
                r,
                provinceName: c.provinceName,
              ),
            )
            .toList();
        if (cleanRoutes.isNotEmpty) {
          if (!c.isRejectedApproval) {
            for (final r in cleanRoutes) {
              routeSet.add(r);
            }
          }
          return c;
        }
        if (c.routeIds.isNotEmpty && routeMap.isNotEmpty) {
          final mappedNames = c.routeIds
              .map((id) => routeMap[id])
              .whereType<String>()
              .toList();
          if (mappedNames.isNotEmpty) {
            if (!c.isRejectedApproval) {
              for (final r in mappedNames) {
                routeSet.add(r);
              }
            }
            return c.copyWith(
              routes: mappedNames,
              route: mappedNames.join(', '),
            );
          }
        }
        if (c.route.trim().isNotEmpty &&
            c.route.trim() != 'Tất cả tuyến' &&
            !CustomerEntity.isInvalidOrProvinceRoute(
              c.route,
              provinceName: c.provinceName,
            )) {
          final parts = c.route
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty);
          for (final p in parts) {
            if (!CustomerEntity.isInvalidOrProvinceRoute(
              p,
              provinceName: c.provinceName,
            )) {
              if (!c.isRejectedApproval) {
                routeSet.add(p);
              }
            }
          }
        }
        return c;
      }).toList();

      // Loại trừ các điểm bán bị từ chối duyệt (hiển thị riêng ở màn hình từ chối)
      final rawCustomers = CustomerLocalDataSource.deduplicateCustomers(resolvedCustomers)
          .where((c) => !c.isRejectedApproval)
          .toList();
      final availableRoutes = routeSet.toList();

      // Trích xuất danh sách loại khách hàng từ meta hệ thống và khách hàng thực tế
      CustomerMetaData? meta;
      try {
        meta = await customerRepository.getCustomerMeta(forceRefresh: isRefresh);
      } catch (_) {}

      final typeSet = <String>{};
      if (meta != null) {
        for (final ct in meta.customerTypes) {
          final t = ct.name.trim();
          if (t.isNotEmpty && t != 'Tất cả' && t != 'Tất cả loại') {
            typeSet.add(t);
          }
        }
      }
      for (final c in rawCustomers) {
        final t = c.type.trim();
        if (t.isNotEmpty && t != 'Tất cả' && t != 'Tất cả loại') {
          typeSet.add(t);
        }
      }
      final customerTypes = typeSet.toList()..sort();

      final customerStatuses = rawCustomers
          .map((c) => c.status.trim())
          .where((s) => s.isNotEmpty && s != 'Tất cả')
          .toSet()
          .toList();
      customerStatuses.sort();

      // Ensure selectedRoute is valid
      String selectedRoute = state.selectedRoute;
      if (!availableRoutes.contains(selectedRoute)) {
        selectedRoute = availableRoutes.isNotEmpty
            ? availableRoutes.first
            : 'Tất cả tuyến';
      }

      // Lượt thường mới hơn đã bắt đầu ⇒ bỏ kết quả lượt này (kể cả `_rawCustomers` — gán sau chốt này).
      if (!mounted || seq != _loadSeq || (silent && silentSeq != _silentSeq)) return;
      _rawCustomers = rawCustomers;
      state = state.copyWith(
        availableRoutes: availableRoutes,
        availableCustomerTypes: customerTypes,
        availableCustomerStatuses: customerStatuses,
        userRoutes: loadedUserRoutes,
        selectedRoute: selectedRoute,
        // Nạp ngầm: lượt viếng thăm lấy theo state LÚC ÁP (có thể vừa check-in trong lúc nạp), không theo lúc bắt đầu.
        todayVisits: silent ? state.todayVisits : todayVisits,
        activeVisit: silent ? state.activeVisit : activeVisit,
        clearActiveVisit: !silent && activeVisit == null,
      );

      _recomputeRouteDetail();
    } catch (e) {
      if (!mounted || silent || seq != _loadSeq) return;
      state = state.copyWith(
        status: RouteStatus.error,
        errorMessage: e.toString().replaceAll('AppException: ', ''),
      );
    } finally {
      if (!silent) _normalLoadsInFlight--;
      if (_silentPending && _normalLoadsInFlight == 0 && mounted) {
        _silentPending = false;
        unawaited(loadRouteDetail(silent: true));
      }
    }
  }

  void _recomputeRouteDetail() {
    if (!mounted) return;
    // 1. Lọc theo tuyến được chọn (loại trừ các điểm bán bị từ chối duyệt)
    var filtered = _rawCustomers.where((c) => !c.isRejectedApproval).toList();
    if (state.selectedRoute != 'Tất cả tuyến' && state.selectedRoute.isNotEmpty) {
      filtered = filtered.where((c) {
        if (c.route == state.selectedRoute) return true;
        if (c.routes.contains(state.selectedRoute)) return true;
        final parts = c.route.split(',').map((e) => e.trim());
        return parts.contains(state.selectedRoute);
      }).toList();
    }

    // 2. Lọc theo trạng thái khách hàng (active, inactive...)
    if (state.selectedCustomerStatus != null &&
        state.selectedCustomerStatus != 'all' &&
        state.selectedCustomerStatus != 'Tất cả' &&
        state.selectedCustomerStatus!.isNotEmpty) {
      final targetStatus = state.selectedCustomerStatus!.toLowerCase().trim();
      filtered = filtered.where((c) {
        return c.status.toLowerCase().trim() == targetStatus;
      }).toList();
    }

    // 3. Lọc theo loại khách hàng (NPP, Đại lý, Tạp hóa...)
    if (state.selectedCustomerType != null &&
        state.selectedCustomerType != 'all' &&
        state.selectedCustomerType != 'Tất cả' &&
        state.selectedCustomerType != 'Tất cả loại' &&
        state.selectedCustomerType!.isNotEmpty) {
      final targetType = state.selectedCustomerType!.toLowerCase().trim();
      filtered = filtered.where((c) {
        return c.type.toLowerCase().trim() == targetType;
      }).toList();
    }

    // 4. Lọc tuyến theo ngày trong tuần (selectedDayOfWeek: 1 = Thứ 2 ... 7 = Chủ nhật)
    if (state.selectedDayOfWeek != null) {
      final targetDay = state.selectedDayOfWeek!;
      filtered = filtered.where((c) {
        return _matchesCustomerDayOfWeek(c, targetDay);
      }).toList();
    }

    // Filter by search query và tiêu chí (hỗ trợ không dấu)
    final rawQuery = state.searchQuery.trim();
    if (rawQuery.isNotEmpty) {
      final query = StringUtils.toUnaccentedLower(rawQuery);
      filtered = filtered
          .where((c) => state.searchTarget.matchesCustomer(c, query))
          .toList();
    }

    // Sort by distance if enabled
    if (state.isSortedByDistance &&
        state.userLat != null &&
        state.userLng != null) {
      // Tính khoảng cách MỘT lần mỗi điểm rồi mới sắp — tính trong hàm so sánh là ~n·log n lượt (2.000 điểm ≈ 44.000).
      final withDist = [
        for (final c in filtered)
          (c, c.hasCoordinates ? Geolocator.distanceBetween(state.userLat!, state.userLng!, c.lat!, c.lng!) : null),
      ];
      withDist.sort((a, b) {
        final distA = a.$2;
        final distB = b.$2;
        if (distA == null && distB == null) return 0;
        if (distA == null) return 1;
        if (distB == null) return -1;
        return distA.compareTo(distB);
      });
      filtered = [for (final e in withDist) e.$1];
    }

    // Map today's visits by customer_id (§2.3)
    final Map<int, VisitEntity> visitMap = {};
    final Set<int> cancelledCustomerIds = {};

    for (final v in state.todayVisits) {
      if (v.isCancelled) {
        cancelledCustomerIds.add(v.customerId);
        continue; // Lượt đã huỷ tuyệt đối không tính là đã viếng thăm (§3 HUY-LUOT-VIENG-THAM)
      }
      final existing = visitMap[v.customerId];
      if (existing == null) {
        visitMap[v.customerId] = v;
      } else if (!existing.isOpen && v.isOpen) {
        // Ưu tiên lượt đang mở
        visitMap[v.customerId] = v;
      } else if (!existing.isOpen && !v.isOpen) {
        // Cả hai đều đã hoàn thành -> Chọn lượt mới nhất để hiển thị giờ ghé gần nhất
        if (v.id > existing.id ||
            (v.checkinAt != null &&
                existing.checkinAt != null &&
                v.checkinAt!.isAfter(existing.checkinAt!))) {
          visitMap[v.customerId] = v;
        }
      }
    }
    // Bổ sung activeVisit vào visitMap nếu chưa có và không bị huỷ (rất quan trọng khi offline)
    if (state.activeVisit != null &&
        state.activeVisit!.isOpen &&
        !state.activeVisit!.isCancelled) {
      visitMap[state.activeVisit!.customerId] = state.activeVisit!;
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
            visitedTime = _formatTimeHHmm(visit.checkinAt);
          }
        } else {
          // Lượt đã hoàn thành (không tính lượt đã huỷ vì đã lọc ở trên)
          visitStatus = DealerVisitStatus.completed;
          statusLabel = 'Đã ghé';
          final inTime = visit.checkinAt;
          final outTime = visit.checkoutAt;
          if (inTime != null && outTime != null) {
            final inStr = _formatTimeHHmm(inTime);
            final outStr = _formatTimeHHmm(outTime);
            visitedTime = '$inStr - $outStr';
          } else if (outTime != null) {
            visitedTime = _formatTimeHHmm(outTime);
          } else if (inTime != null) {
            visitedTime = _formatTimeHHmm(inTime);
          }
        }
      } else if (c.visitStatus == CustomerVisitStatus.visited &&
          !cancelledCustomerIds.contains(c.id)) {
        visitStatus = DealerVisitStatus.completed;
        statusLabel = 'Đã ghé';
        visitedTime = '08:30 - 08:45';
      } else {
        visitStatus = DealerVisitStatus.pending;
        statusLabel = 'Chưa ghé';
      }

      final isVip =
          c.type.toLowerCase().contains('npp') ||
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
          geofenceRadiusM: c.geofenceRadiusM,
          customer: c,
          visit: visit,
        ),
      );
    }

    // 8. Lọc dealers theo trạng thái viếng thăm
    var finalDealers = dealers;
    if (state.selectedVisitStatus != null &&
        state.selectedVisitStatus != 'all' &&
        state.selectedVisitStatus != 'Tất cả' &&
        state.selectedVisitStatus!.isNotEmpty) {
      finalDealers = dealers.where((d) {
        switch (state.selectedVisitStatus) {
          case 'completed':
            return d.status == DealerVisitStatus.completed;
          case 'inProgress':
            return d.status == DealerVisitStatus.inProgress;
          case 'pending':
            return d.status == DealerVisitStatus.pending;
          default:
            return true;
        }
      }).toList();
    }

    final total = finalDealers.length;
    final completed = finalDealers
        .where((d) => d.status == DealerVisitStatus.completed)
        .length;
    final pending = total - completed;
    final progress = total > 0 ? completed / total : 0.0;

    final detail = RouteDetailEntity(
      id: 'active_route',
      title: state.selectedRoute,
      totalDealers: total,
      completedDealers: completed,
      pendingDealers: pending,
      progressPercent: progress,
      dealers: finalDealers,
    );

    state = state.copyWith(status: RouteStatus.loaded, routeDetail: detail);

    // Tự động kích hoạt nhắc nhở lộ trình đầu ngày (cảnh báo tiến độ tuyến đã gỡ 29/10/2026)
    if (ref != null && total > 0) {
      () async {
        try {
          final now = DateTime.now();
          final hour = now.hour;
          final routeName = state.selectedRoute.isNotEmpty && state.selectedRoute != 'Tất cả tuyến'
              ? state.selectedRoute
              : 'Tuyến hôm nay';

          final notifService = ref!.read(appNotificationServiceProvider);

          // Nhắc lộ trình đầu ngày (07:00 - 11:00). Nhắc chấm công chỉ qua push server (21/10/2026).
          if (hour >= 7 && hour < 11) {
            await notifService.notifyRouteBriefing(
              totalDealers: total,
              routeName: routeName,
            );
            ref!.invalidate(unreadNotificationCountProvider);
          }

        } catch (_) {}
      }();
    }
  }

  Future<bool> deletePendingCustomer(String clientUuid) async {
    try {
      final success = await customerRepository.deletePendingCustomer(
        clientUuid,
      );
      if (success) {
        _rawCustomers.removeWhere((c) => c.clientUuid == clientUuid);
        _dayCounts = null; // sửa tại chỗ — cùng đối tượng danh sách nên phải tự bỏ số đếm đã nhớ
        _recomputeRouteDetail();
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  int? _extractDayOfWeekFromName(String? text) {
    return CustomerEntity.extractDayOfWeekFromName(text);
  }

  bool _matchesCustomerDayOfWeek(CustomerEntity c, int targetDay) {
    return c.matchesDayOfWeek(targetDay, userRoutes: state.userRoutes);
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
        getVisitRequirementsUseCase: ref.read(
          getVisitRequirementsUseCaseProvider,
        ),
        uploadVisitPhotoUseCase: ref.read(uploadVisitPhotoUseCaseProvider),
        deleteVisitPhotoUseCase: ref.read(deleteVisitPhotoUseCaseProvider),
        cancelVisitUseCase: ref.read(cancelVisitUseCaseProvider),
        visitRepository: ref.read(visitRepositoryProvider),
        ref: ref,
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
  final Ref? ref;

  Timer? _visitTimer;
  StreamSubscription<Position>? _geofenceStreamSubscription;
  int _elapsedSeconds = 0;
  DateTime? _targetDoneTime;
  String _sessionClientUuid = const Uuid().v4();

  /// false trong lúc khôi phục một lượt đang mở — chưa nạp tiến độ đã lưu ([VisitProgressStore]) thì không được ghi
  /// đè nó bằng danh sách ảnh / biểu mẫu rỗng của trạng thái vừa dựng lại.
  bool _progressReady = true;

  /// Mã lần khôi phục gần nhất — lần khôi phục CŨ (người dùng đã sang lượt khác) không được mở lại [_progressReady] giữa
  /// lúc lần mới còn đang nạp (mở sớm ⇒ lần ghi kế tiếp đè ô lưu của lượt mới bằng danh sách rỗng).
  int _restoreToken = 0;

  /// Bắt đầu một lần khôi phục: chặn ghi tới khi nạp xong; trả mã để chỉ chính lần đó được mở lại.
  int _beginRestore() {
    _progressReady = false;
    return ++_restoreToken;
  }

  /// Kết thúc lần khôi phục [token] — chỉ mở lại việc ghi nếu đó vẫn là lần mới nhất.
  void _endRestore(int token) {
    if (token == _restoreToken) _progressReady = true;
  }

  /// Huỷ mọi lần khôi phục đang chạy (lượt đóng / check-in mới) và mở việc ghi.
  void _cancelRestores() {
    _restoreToken++;
    _progressReady = true;
  }

  /// Mọi lần đổi trạng thái đi qua đây — ảnh / biểu mẫu đã nộp đổi thì lưu xuống máy, lượt đóng thì xoá; khỏi phải
  /// nhớ gọi lưu ở từng chỗ chụp, xoá ảnh, nộp phiếu.
  @override
  set state(CheckInState value) {
    final prev = super.state;
    super.state = value;
    _persistProgress(prev, value);
  }

  void _persistProgress(CheckInState prev, CheckInState next) {
    // Xoá ô lưu KHÔNG ở đây (mọi lần về 0) mà ở chỗ lượt THẬT SỰ đóng: [resetSession], huỷ lượt.
    if (!_progressReady || next.visitId == 0) return;
    if (prev.visitId == next.visitId &&
        identical(prev.photos, next.photos) &&
        setEquals(prev.submittedSurveyConfigIds, next.submittedSurveyConfigIds)) {
      return;
    }
    VisitProgressStore.save(
      visitId: next.visitId,
      clientUuid: _sessionClientUuid,
      photos: next.photos,
      submittedConfigIds: next.submittedSurveyConfigIds,
    );
  }

  /// Ảnh của lượt còn trong hàng đợi đồng bộ (chụp ngoại tuyến / tải lỗi mạng) — nạp lại khi vào lại lượt sau khi app bị
  /// tắt. Gọi ở CẢ hai đường vào lại (danh sách tuyến và khôi phục lượt đang mở).
  Future<void> _restoreQueuedPhotos(int forVisitId) async {
    try {
      if (ref != null && _sessionClientUuid.isNotEmpty) {
        final db = ref!.read(appDatabaseProvider);
        final photoEntries = await (db.select(db.syncQueueEntries)
          ..where((t) =>
              t.entity.equals('visit_photo') &
              t.parentUuid.equals(_sessionClientUuid) &
              t.state.isNotValue('dead'))
        ).get();
        if (state.visitId != forVisitId) return; // đã rời / sang lượt khác trong lúc đọc
        if (photoEntries.isNotEmpty) {
          final restoredPhotos = photoEntries.map((e) {
            Map<String, dynamic> p = {};
            try {
              p = jsonDecode(e.payload) as Map<String, dynamic>;
            } catch (_) {}
            return VisitPhotoEntity(
              id: -e.id,
              token: '',
              url: e.localPath ?? '',
              photoType: p['photo_type']?.toString() ?? 'other',
              photoTypeLabel: _photoTypeLabel(p['photo_type']?.toString() ?? 'other'),
              takenAt: DateTime.fromMillisecondsSinceEpoch(e.createdAt).toIso8601String(),
            );
          }).toList();
          // GỘP (không thay): ảnh người dùng chụp trong lúc đang đọc hàng đợi không được mất.
          final have = state.photos.map((x) => x.id).toSet();
          state = state.copyWith(photos: [...state.photos, ...restoredPhotos.where((x) => !have.contains(x.id))]);
        }
      }
    } catch (_) {}
  }

  /// Nạp lại ảnh đã tải lên + biểu mẫu đã nộp của lượt đang mở sau khi app bị tắt hẳn (state trong bộ nhớ đã mất);
  /// gộp với ảnh còn chờ trong hàng đợi đồng bộ đã có trong state.
  Future<void> _restoreLocalProgress(int forVisitId, int token) async {
    try {
      final saved = await VisitProgressStore.load(visitId: forVisitId, clientUuid: _sessionClientUuid);
      if (saved != null && state.visitId == forVisitId) {
        final have = state.photos.map((p) => p.id).toSet();
        state = state.copyWith(
          photos: [...saved.photos.where((p) => !have.contains(p.id)), ...state.photos],
          submittedSurveyConfigIds: {...state.submittedSurveyConfigIds, ...saved.submittedConfigIds},
        );
      }
    } catch (_) {}
    if (token != _restoreToken) return; // lần khôi phục khác đã thay chỗ
    _endRestore(token);
    // Thao tác xảy ra TRONG lúc đang nạp bị bỏ qua (chưa sẵn sàng) ⇒ ghi một lần trạng thái đã gộp — chỉ khi vẫn đúng lượt.
    if (state.visitId == forVisitId) {
      VisitProgressStore.save(
        visitId: state.visitId,
        clientUuid: _sessionClientUuid,
        photos: state.photos,
        submittedConfigIds: state.submittedSurveyConfigIds,
      );
    }
  }

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
    this.ref,
  }) : super(const CheckInState()) {
    _startTimer();
  }

  /// Lấy luật di động hiện hành từ Riverpod hoặc fallback sang mặc định
  MobileRules get activeMobileRules =>
      ref?.read(mobileRulesProvider) ?? const MobileRules();

  /// Đọc luật di động có đối chiếu SharedPreferences cache nếu provider chưa khởi tạo xong
  Future<MobileRules> getEffectiveMobileRules() async {
    MobileRules? currentRules = ref?.read(mobileRulesProvider);
    try {
      final cached = await MobileRulesNotifier.getCachedRules();
      if (cached != null) {
        currentRules = cached;
        if (ref != null) {
          ref!.read(mobileRulesProvider.notifier).setRules(cached);
        }
      }
    } catch (_) {}
    return currentRules ?? const MobileRules();
  }

  /// Tính toán lại điều kiện check-out cục bộ dựa trên luật (đặc biệt khi ngoại tuyến hoặc đóng cửa điểm bán)
  void _recomputeOfflineRequirements(String vResult, MobileRules rules) {
    final isClosed = vResult == 'closed';
    final targetMinPhotos =
        isClosed ? rules.visit.closedMinPhotos : rules.visit.minPhotos;
    final takenCount = state.photos.length;
    final photosMissing = math.max(0, targetMinPhotos - takenCount);

    // §3b DUYET-DIEM-BAN-MOI-2026-10-15 (chốt 16/10/2026):
    // Lượt đầu ở điểm bán NV mở trên app: KHÔNG chịu thời gian tối thiểu (seconds_remaining = 0)
    final isNewPendingStore = state.customer is CustomerEntity &&
        (state.customer as CustomerEntity).isPendingApproval;

    var currentReq = state.requirements;
    final currentSec = (isClosed || isNewPendingStore)
        ? 0
        : (currentReq?.secondsRemaining ?? rules.visit.minDurationMinutes * 60);
    final missingForms = isClosed
        ? <MissingFormEntity>[]
        : (currentReq?.missingForms ?? <MissingFormEntity>[]);

    // Giữ danh sách cả khi đóng cửa (chỉ không tính vào satisfied) — đổi lại "mở cửa" lúc ngoại tuyến không mất cổng ④.
    final missingMaterials = currentReq?.missingMaterials ?? <MissingMaterialEntity>[];

    final isTimeOk = isClosed || isNewPendingStore || currentSec <= 0;
    final isFormsOk = isClosed || missingForms.isEmpty;
    final isPhotosOk = photosMissing <= 0;
    final satisfied = isTimeOk && isFormsOk && isPhotosOk && (isClosed || missingMaterials.isEmpty);

    List<String> blockers = [];
    if (!isClosed) {
      if (!isNewPendingStore && currentSec > 0) {
        final minutes = (currentSec / 60).ceil();
        blockers.add('Bạn cần ở lại thêm $minutes phút nữa mới check-out được.');
      }
      if (missingForms.isNotEmpty) {
        blockers.add('Bạn cần hoàn thành ${missingForms.length} biểu mẫu bắt buộc.');
      }
      if (photosMissing > 0) {
        blockers.add('Bạn cần chụp thêm $photosMissing ảnh nữa.');
      }
      if (missingMaterials.isNotEmpty) {
        blockers.add(_missingMaterialsBlocker(missingMaterials));
      }
    } else {
      if (photosMissing > 0) {
        blockers.add(
          'Bạn cần chụp thêm $photosMissing ảnh xác nhận đóng cửa điểm bán.',
        );
      }
    }

    final updated = VisitRequirementsEntity(
      satisfied: satisfied,
      secondsRemaining: (isClosed || isNewPendingStore) ? 0 : currentSec,
      photosMissing: photosMissing,
      missingForms: missingForms,
      missingMaterials: missingMaterials,
      blockers: blockers,
    );

    state = state.copyWith(requirements: updated);
    if (state.visitEntity != null) {
      final updatedVisit = state.visitEntity!.copyWith(
        visitResult: vResult,
        requirements: updated,
      );
      state = state.copyWith(visitEntity: updatedVisit);
      visitRepository.saveActiveVisit(updatedVisit);
    }
  }

  /// Tải dữ liệu điểm bán mặc định / hiện tại nếu chưa được khởi tạo
  Future<void> loadCheckinData() async {
    if (state.checkinData == null) {
      state = state.copyWith(status: CheckInStatus.loading);
    }
    try {
      final now = DateTime.now();
      final localTime = _formatTimeHHmmss(now);

      final data = await getDealerCheckinUseCase();
      state = state.copyWith(
        status: CheckInStatus.loaded,
        checkinData: data,
        checkinTime: state.visitId > 0 && state.checkinTime != '--:--:--'
            ? state.checkinTime
            : localTime,
      );

      final customerId =
          int.tryParse(data.dealer.id.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
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
    stopGeofenceWatcher();
    _elapsedSeconds = 0;
    _targetDoneTime = null;
    _sessionClientUuid = const Uuid().v4();
    _setLiveDuration('00:00:00');
    _cancelRestores();
    VisitProgressStore.clear();
    state = const CheckInState();
  }

  /// Nhãn loại ảnh lượt — MỘT nơi cho ảnh vừa chụp và ảnh nạp lại từ hàng đợi.
  static String _photoTypeLabel(String type) => switch (type) {
        'display' => 'Ảnh trưng bày',
        'store_front' => 'Mặt tiền',
        'closed_store' => 'Ảnh đóng cửa',
        'posm' => 'POSM',
        'document' => 'Tài liệu',
        _ => 'Ảnh chụp',
      };

  /// Khởi động giám sát khoảng cách đến điểm bán (Cảnh báo Geofence Exit)
  void startGeofenceWatcher({
    required double dealerLat,
    required double dealerLng,
    required String dealerName,
    required double allowedRadius,
  }) {
    stopGeofenceWatcher();
    try {
      // Bỏ qua nếu chạy trong môi trường Unit Test thuần chưa khởi tạo ServicesBinding
      try {
        ServicesBinding.instance;
      } catch (_) {
        return;
      }

      _geofenceStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 25, // Chỉ cập nhật khi di chuyển tối thiểu 25m
        ),
      ).listen(
        (Position pos) {
          _checkGeofenceDistance(
            pos: pos,
            dealerLat: dealerLat,
            dealerLng: dealerLng,
            dealerName: dealerName,
            allowedRadius: allowedRadius,
          );
        },
        onError: (err) {
          debugPrint('[CheckInViewModel] Lỗi theo dõi GPS Geofence: $err');
        },
      );
    } catch (e) {
      debugPrint('[CheckInViewModel] Không thể khởi động geofence watcher: $e');
    }
  }

  void _checkGeofenceDistance({
    required Position pos,
    required double dealerLat,
    required double dealerLng,
    required String dealerName,
    required double allowedRadius,
  }) {
    final distanceM = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      dealerLat,
      dealerLng,
    );
    final isOut = distanceM > allowedRadius;

    state = state.copyWith(
      isOutOfGeofence: isOut,
      currentDistanceToDealerM: distanceM,
      allowedGeofenceRadiusM: allowedRadius,
    );

    if (isOut) {
      try {
        HapticFeedback.heavyImpact();
      } catch (_) {}

      if (ref != null) {
        try {
          ref!.read(appNotificationServiceProvider).notifyVisitGeofenceExit(
                dealerName: dealerName,
                distanceMeters: distanceM.round(),
                allowedRadiusMeters: allowedRadius.round(),
              );
        } catch (_) {}
      }
    }
  }

  void stopGeofenceWatcher() {
    _geofenceStreamSubscription?.cancel();
    _geofenceStreamSubscription = null;
    if (ref != null) {
      try {
        ref!.read(appNotificationServiceProvider).cancelVisitGeofenceExitNotification();
      } catch (_) {}
    }
    state = state.copyWith(isOutOfGeofence: false);
  }

  Future<void> loadSurveyForms(int customerId) async {
    try {
      final forms = await getAvailableFormsUseCase(
        kind: 'survey',
        customerId: customerId,
      );
      state = state.copyWith(surveyForms: forms);
    } catch (_) {}
  }

  /// clientUuid của phiên lượt — cha của các mục hàng đợi đi kèm lượt (ảnh, vật tư, check-out).
  String get sessionClientUuid => _sessionClientUuid;

  static String _missingMaterialsBlocker(List<MissingMaterialEntity> missing) =>
      'Chưa kiểm vật tư bắt buộc: ${missing.map((m) => m.name).join(', ')}';

  /// Cập nhật cổng vật tư ④ (#24522). Có [serverRequirements] (phản hồi lưu vật tư) ⇒ dùng nguyên bản server;
  /// không có (ngoại tuyến / bản cache) ⇒ thay danh sách loại còn thiếu rồi tính lại `satisfied` + câu chặn tại máy.
  void applyMaterialRequirements(
    List<MissingMaterialEntity> missing, {
    VisitRequirementsEntity? serverRequirements,
  }) {
    if (serverRequirements != null) {
      _targetDoneTime = serverRequirements.secondsRemaining > 0
          ? DateTime.now().add(Duration(seconds: serverRequirements.secondsRemaining))
          : null;
      state = state.copyWith(requirements: serverRequirements);
      return;
    }
    final req = state.requirements;
    if (req == null) return;
    final isClosed = state.visitResult == 'closed';
    // KHÔNG sửa `blockers` (dò chữ trong câu dễ xoá nhầm câu khác): cổng ④ ở nút check-out đọc thẳng
    // `missingMaterials`, còn câu chặn cũ của server chỉ hiện khi `satisfied` vẫn false.
    final satisfied = (isClosed || req.secondsRemaining <= 0) &&
        (isClosed || req.missingForms.isEmpty) &&
        req.photosMissing <= 0 &&
        (isClosed || missing.isEmpty);
    state = state.copyWith(
      requirements: req.copyWith(missingMaterials: missing, satisfied: satisfied),
    );
  }

  void markSurveySubmitted(int configId) {
    final updated = Set<int>.from(state.submittedSurveyConfigIds)
      ..add(configId);

    var updatedReq = state.requirements;
    if (updatedReq != null) {
      final remainingForms = updatedReq.missingForms
          .where((f) => f.formId != configId)
          .toList();
      final isTimeOk =
          updatedReq.secondsRemaining <= 0 || state.visitResult == 'closed';
      final isFormsOk = remainingForms.isEmpty || state.visitResult == 'closed';
      final isPhotosOk = updatedReq.photosMissing <= 0;
      final newSatisfied =
          isTimeOk && isFormsOk && isPhotosOk && updatedReq.materialsOk(state.visitResult == 'closed');

      List<String> newBlockers = List<String>.from(updatedReq.blockers);
      if (remainingForms.isEmpty) {
        newBlockers.removeWhere(
          (b) =>
              b.toLowerCase().contains('khảo sát') ||
              b.toLowerCase().contains('biểu mẫu'),
        );
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
    final newCId = dealer.customer is CustomerEntity
        ? (dealer.customer as CustomerEntity).id
        : int.tryParse(dealer.id.replaceAll(RegExp(r'[^\d]'), ''));

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
        geofenceRadiusM: dealer.geofenceRadiusM,
      ),
      tasks: const [],
    );

    // Nếu đang có một lượt viếng thăm khác đang mở, không được ghi đè phiên bằng điểm bán mới
    if (state.visitId != 0 &&
        state.visitEntity != null &&
        state.visitEntity!.isOpen) {
      final currentCId = state.visitEntity!.customerId;
      if (newCId != null && currentCId > 0 && currentCId != newCId) {
        debugPrint(
          '[CheckInViewModel] Bỏ qua initCheckinWithDealer: Đang có lượt mở id=${state.visitId} tại customer=$currentCId',
        );
        return;
      }
      // Nếu là cùng điểm bán đang có phiên mở: Giữ nguyên phiên viếng thăm đang mở, không reset state về 0
      if (newCId != null && (currentCId == newCId || currentCId <= 0)) {
        if (currentCId <= 0) {
          state = state.copyWith(
            visitEntity: state.visitEntity!.copyWith(customerId: newCId),
          );
        }
        if (state.checkinData == null) {
          state = state.copyWith(checkinData: initialCheckinData);
        }
        if (_visitTimer == null || !_visitTimer!.isActive) {
          _setupVisitTimer(state.visitEntity?.checkinAt);
        }
        debugPrint(
          '[CheckInViewModel] Giữ nguyên phiên viếng thăm đang mở id=${state.visitId} cho customer=$newCId',
        );
        return;
      }
    }

    final now = DateTime.now();
    final localTime = _formatTimeHHmmss(now);

    // Kiểm tra nếu dealer đã có lượt viếng thăm đang mở (§2.3)
    VisitEntity? existingVisit = (dealer.visit != null && dealer.visit!.isOpen)
        ? dealer.visit
        : null;
    if (existingVisit == null && ref != null && newCId != null) {
      try {
        final routeActive = ref!.read(routeViewModelProvider).activeVisit;
        if (routeActive != null &&
            routeActive.isOpen &&
            routeActive.customerId == newCId) {
          existingVisit = routeActive;
        }
      } catch (_) {}
    }

    if (existingVisit != null) {
      // Cùng lượt đang có trong bộ nhớ mà server không trả uuid ⇒ GIỮ uuid phiên hiện tại (hàng đợi khoá theo nó).
      _sessionClientUuid = existingVisit.clientUuid ??
          (state.visitId == existingVisit.id ? _sessionClientUuid : const Uuid().v4());
      final token = _beginRestore();
      _setupVisitTimer(existingVisit.checkinAt);

      state = CheckInState(
        status: CheckInStatus.loaded,
        checkinData: initialCheckinData,
        checkinTime: existingVisit.checkinAt != null
            ? _formatTimeHHmmss(existingVisit.checkinAt)
            : localTime,
        visitId: existingVisit.id,
        visitEntity: existingVisit,
        requirements: existingVisit.requirements ?? state.requirements,
        // Chỉ giữ ảnh / biểu mẫu trong bộ nhớ khi đúng là CÙNG lượt — không bê của lượt trước sang (rồi bị lưu xuống máy).
        photos: state.visitId == existingVisit.id ? state.photos : const [],
        submittedSurveyConfigIds: state.visitId == existingVisit.id ? state.submittedSurveyConfigIds : const {},
        visitNote: state.visitNote,
        closedNote: existingVisit.closedNote ?? state.closedNote,
        visitResult: existingVisit.visitResult ?? state.visitResult,
        customer: dealer.customer ?? state.customer,
      );

      final customerId =
          newCId ??
          (dealer.customer is CustomerEntity
              ? (dealer.customer as CustomerEntity).id
              : (int.tryParse(dealer.id.replaceAll(RegExp(r'[^\d]'), '')) ??
                    0));
      final resumed = existingVisit;
      unawaited(() async {
        try {
          // Lượt lấy từ danh sách tuyến (server) có thể không mang client_uuid ⇒ lấy uuid của lượt đang mở đã lưu trên máy
          // (cùng id) — ảnh hàng đợi + tiến độ đã lưu đều khoá theo uuid phiên gốc.
          if (resumed.clientUuid == null) {
            try {
              final saved = await visitRepository.getActiveVisit();
              if (saved != null &&
                  saved.id == resumed.id &&
                  state.visitId == resumed.id &&
                  (saved.clientUuid ?? '').isNotEmpty) {
                _sessionClientUuid = saved.clientUuid!;
              }
            } catch (_) {}
          }
          // Người dùng đã rời / mở lượt khác trong lúc chờ ⇒ thôi, không đổ dữ liệu lượt này vào lượt kia.
          if (state.visitId != resumed.id) return;
          await _restoreQueuedPhotos(resumed.id);
          if (state.visitId != resumed.id) return;
          await _restoreLocalProgress(resumed.id, token);
        } finally {
          // Lỗi bất ngờ / rời lượt giữa chừng không được để việc lưu tắt luôn — nhưng chỉ lần khôi phục mới nhất được mở.
          _endRestore(token);
        }
      }());
      loadSurveyForms(customerId);
      refreshRequirements(visitResult: existingVisit.visitResult ?? state.visitResult);
      return;
    }

    // Trường hợp mới bắt đầu check-in
    _sessionClientUuid = const Uuid().v4();
    _cancelRestores();
    _elapsedSeconds = 0;
    _setLiveDuration('00:00:00');
    _startTimer();
    state = CheckInState(
      status: CheckInStatus.loaded,
      checkinData: initialCheckinData,
      checkinTime: localTime,
      customer: dealer.customer,
    );

    final customerId =
        newCId ??
        (dealer.customer is CustomerEntity
            ? (dealer.customer as CustomerEntity).id
            : (int.tryParse(dealer.id.replaceAll(RegExp(r'[^\d]'), '')) ?? 0));
    loadSurveyForms(customerId);
  }

  /// Phục hồi phiên viếng thăm đang mở từ SharedPreferences (hữu ích khi mở app lại offline hoặc vào lại điểm bán)
  Future<bool> restoreActiveVisitIfAvailable([int? forCustomerId]) async {
    if (state.visitId != 0 &&
        state.visitEntity != null &&
        state.visitEntity!.isOpen) {
      if (forCustomerId == null ||
          state.visitEntity!.customerId == forCustomerId) {
        if (state.checkinData == null && state.visitEntity != null) {
          final v = state.visitEntity!;
          final reconstructed = DealerCheckinDataEntity(
            dealer: CheckinDealerEntity(
              id: v.customerId.toString(),
              name: v.customerName,
              address: v.customerAddress ?? '',
              isVip: false,
              distanceMeters: 0,
              visitDuration: '00:00:00',
            ),
            tasks: const [],
          );
          state = state.copyWith(checkinData: reconstructed);
        }
        try {
          final saved = await visitRepository.getActiveVisit();
          if (saved != null && saved.id > 0 && state.visitId < 0) {
            state = state.copyWith(
              visitId: saved.id,
              visitEntity: saved,
            );
          }
        } catch (_) {}
        return true;
      }
    }
    int? token;
    try {
      final saved = await visitRepository.getActiveVisit();
      if (saved != null && saved.isOpen) {
        if (forCustomerId != null && saved.customerId != forCustomerId) {
          return false;
        }
        final localTime = saved.checkinAt != null
            ? _formatTimeHHmmss(saved.checkinAt)
            : _formatTimeHHmmss(DateTime.now());
        _sessionClientUuid = saved.clientUuid ?? _sessionClientUuid;
        token = _beginRestore();
        _setupVisitTimer(saved.checkinAt);

        DealerCheckinDataEntity? checkinData = state.checkinData;
        checkinData ??= DealerCheckinDataEntity(
          dealer: CheckinDealerEntity(
            id: saved.customerId.toString(),
            name: saved.customerName,
            address: saved.customerAddress ?? '',
            isVip: false,
            distanceMeters: 0,
            visitDuration: '00:00:00',
          ),
          tasks: const [],
        );

        state = state.copyWith(
          status: CheckInStatus.loaded,
          checkinData: checkinData,
          visitId: saved.id,
          visitEntity: saved,
          requirements: saved.requirements,
          checkinTime: localTime,
          visitResult: saved.visitResult ?? 'visited',
          closedNote: saved.closedNote ?? '',
        );

        await _restoreQueuedPhotos(saved.id);
        await _restoreLocalProgress(saved.id, token);

        loadSurveyForms(saved.customerId);
        refreshRequirements(visitResult: saved.visitResult ?? 'visited');

        // Tự động khôi phục giám sát khoảng cách nếu lượt viếng thăm đang mở
        final dLat = state.checkinData?.dealer.lat ??
            (state.customer is CustomerEntity ? (state.customer as CustomerEntity).lat : null);
        final dLng = state.checkinData?.dealer.lng ??
            (state.customer is CustomerEntity ? (state.customer as CustomerEntity).lng : null);
        if (saved.isOpen && dLat != null && dLng != null) {
          final radius = activeMobileRules.visit.defaultRadiusM.toDouble();
          startGeofenceWatcher(
            dealerLat: dLat,
            dealerLng: dLng,
            dealerName: saved.customerName.isNotEmpty ? saved.customerName : 'Điểm bán',
            allowedRadius: radius,
          );
        }
        return true;
      }
    } catch (_) {
      // Lỗi giữa chừng (sau _beginRestore) không được để việc lưu tiến độ tắt mãi — chỉ kết thúc ĐÚNG lần của mình
      // (lần khôi phục mới hơn đang chạy thì nó tự mở).
      if (token != null) _endRestore(token);
    }
    return false;
  }

  bool _isNetworkError(dynamic e) {
    if (ref != null) {
      try {
        if (!ref!.read(connectivityProvider).isOnline) return true;
      } catch (_) {}
    }
    if (e is SocketException || e is HttpException || e is NetworkException) {
      return true;
    }
    final str = e.toString().toLowerCase();
    return str.contains('socketexception') ||
        str.contains('networkexception') ||
        str.contains('kết nối mạng') ||
        str.contains('connection refused') ||
        str.contains('network is unreachable') ||
        str.contains('no internet') ||
        str.contains('mất kết nối') ||
        str.contains('connection reset') ||
        str.contains('connection timed out') ||
        str.contains('failed host lookup') ||
        str.contains('connectionerror') ||
        str.contains('clientexception') ||
        str.contains('handshakeexception');
  }

  VisitEntity _createOfflineVisit({
    required int customerId,
    double? lat,
    double? lng,
    double? accuracyM,
    String? address,
    bool? isMockLocation,
    String? note,
    MobileRules? mobileRules,
  }) {
    final now = DateTime.now();
    final tempId = -now.millisecondsSinceEpoch;
    final rules = mobileRules ?? activeMobileRules;
    final isClosed = state.visitResult == 'closed';
    final minDurationMinutes = isClosed ? 0 : rules.visit.minDurationMinutes;
    final minPhotos =
        isClosed ? rules.visit.closedMinPhotos : rules.visit.minPhotos;
    final photosMissing = math.max(0, minPhotos - state.photos.length);

    final customerName = state.customer is CustomerEntity
        ? (state.customer as CustomerEntity).name
        : state.checkinData?.dealer.name ?? 'Điểm bán';
    final customerCode = state.customer is CustomerEntity
        ? (state.customer as CustomerEntity).code
        : state.checkinData?.dealer.id;
    final customerAddress =
        address ??
        (state.customer is CustomerEntity
            ? (state.customer as CustomerEntity).address
            : state.checkinData?.dealer.address);

    // §5b API-DUYET-DIEM-BAN-THAY-DOI-CHO-MOBILE-2026-10-15:
    // Lượt đầu ở điểm bán vừa mở: KHÔNG chịu thời gian tối thiểu (seconds_remaining = 0)
    final isNewPendingStore = state.customer is CustomerEntity &&
        (state.customer as CustomerEntity).isPendingApproval;
    final effectiveMinDuration = isNewPendingStore ? 0 : minDurationMinutes;

    List<String> blockers = [];
    if (!isClosed) {
      if (effectiveMinDuration > 0) {
        blockers.add(
          'Bạn cần ở lại thêm $effectiveMinDuration phút nữa mới check-out được.',
        );
      }
      if (photosMissing > 0) {
        blockers.add('Bạn cần chụp thêm $photosMissing ảnh nữa.');
      }
    } else {
      if (photosMissing > 0) {
        blockers.add(
          'Bạn cần chụp thêm $photosMissing ảnh xác nhận đóng cửa điểm bán.',
        );
      }
    }

    final customerApprovalStatus = state.customer is CustomerEntity
        ? (state.customer as CustomerEntity).approvalStatus
        : 'approved';
    final customerApprovalNote = state.customer is CustomerEntity
        ? (state.customer as CustomerEntity).approvalNote
        : null;

    return VisitEntity(
      id: tempId,
      visitDate:
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      checkinAt: now,
      checkinAtRaw: now.toIso8601String(),
      customerId: customerId,
      customerName: customerName,
      customerCode: customerCode,
      customerAddress: customerAddress,
      clientUuid: _sessionClientUuid,
      visitResult: state.visitResult,
      customerApprovalStatus: customerApprovalStatus,
      customerApprovalNote: customerApprovalNote,
      requirements: VisitRequirementsEntity(
        satisfied: photosMissing <= 0 && effectiveMinDuration <= 0,
        secondsRemaining: effectiveMinDuration * 60,
        photosMissing: photosMissing,
        missingForms: const [],
        blockers: blockers,
      ),
    );
  }

  /// Gọi API check-in thật lên server (§3) hoặc chuyển ngoại tuyến khi mất mạng
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
    // Chặn cả online và offline nếu đang có một lượt viếng thăm khác chưa đóng (§3 Luật 3)
    if (state.visitId != 0 &&
        state.visitEntity != null &&
        state.visitEntity!.isOpen) {
      final currentCId = state.visitEntity!.customerId;
      if (currentCId != customerId) {
        return 'Bạn còn một lượt viếng thăm tại điểm bán khác chưa check-out. Hãy đóng lượt đó trước khi mở lượt mới.';
      }
      debugPrint(
        '[CheckInViewModel] Đã có phiên mở id=${state.visitId} cho customer=$customerId -> Bỏ qua checkin mới',
      );
      return null;
    }
    try {
      final savedActive = await visitRepository.getActiveVisit();
      if (savedActive != null && savedActive.isOpen) {
        if (savedActive.customerId != customerId) {
          return 'Bạn còn một lượt viếng thăm tại điểm bán khác chưa check-out. Hãy đóng lượt đó trước khi mở lượt mới.';
        }
        debugPrint(
          '[CheckInViewModel] Phục hồi phiên mở lưu trữ id=${savedActive.id} cho customer=$customerId -> Bỏ qua checkin mới',
        );
        await restoreActiveVisitIfAvailable(customerId);
        return null;
      }
    } catch (_) {}

    // 1. Kiểm tra khoảng cách Geofence động (lấy từ cache luật, không hardcode)
    MobileRules? mobileRules = ref?.read(mobileRulesProvider);
    try {
      final cached = await MobileRulesNotifier.getCachedRules();
      if (cached != null) {
        mobileRules = cached;
        if (ref != null) {
          ref!.read(mobileRulesProvider.notifier).setRules(cached);
        }
      }
    } catch (_) {}
    final isGeofenceRequired = GeofenceRuleHelper.isGeofenceRequired(
      mobileRules,
    );
    final allowedRadius = GeofenceRuleHelper.resolveAllowedRadius(
      dealer: state.checkinData?.dealer,
      customer: state.customer is CustomerEntity
          ? state.customer as CustomerEntity
          : null,
      rules: mobileRules,
    );

    double? dealerLat = state.checkinData?.dealer.lat;
    double? dealerLng = state.checkinData?.dealer.lng;
    if (dealerLat == null && state.customer is CustomerEntity) {
      final cust = state.customer as CustomerEntity;
      dealerLat = cust.lat;
      dealerLng = cust.lng;
    }

    if (isGeofenceRequired &&
        dealerLat != null &&
        dealerLng != null &&
        lat != null &&
        lng != null) {
      final distanceM = Geolocator.distanceBetween(
        lat,
        lng,
        dealerLat,
        dealerLng,
      );
      if (distanceM > allowedRadius) {
        final distText = distanceM < 1000
            ? '${distanceM.round()}m'
            : '${(distanceM / 1000).toStringAsFixed(1)}km';
        final maxRadiusText = allowedRadius < 1000
            ? '${allowedRadius}m'
            : '${(allowedRadius / 1000).toStringAsFixed(1)}km';
        return 'Bạn đang cách điểm bán $distText. Hãy lại gần hơn (tối đa $maxRadiusText) rồi check-in.';
      }
    }

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

    try {
      var visit = await checkinUseCase(request);
      if (visit.customerId <= 0) {
        visit = visit.copyWith(customerId: customerId);
      }
      if (visit.clientUuid == null || visit.clientUuid!.isEmpty) {
        visit = visit.copyWith(clientUuid: _sessionClientUuid);
      }
      final custName = state.customer is CustomerEntity
          ? (state.customer as CustomerEntity).name
          : (state.checkinData?.dealer.name ?? '');
      if (visit.customerName.isEmpty && custName.isNotEmpty) {
        visit = visit.copyWith(customerName: custName);
      }

      _setupVisitTimer(visit.checkinAt);

      var req = visit.requirements;
      if (req != null && req.secondsRemaining > 0) {
        _targetDoneTime = DateTime.now().add(
          Duration(seconds: req.secondsRemaining),
        );
      } else {
        _targetDoneTime = null;
      }

      final cTime = visit.checkinAt != null
          ? _formatTimeHHmmss(visit.checkinAt)
          : state.checkinTime;

      state = state.copyWith(
        visitId: visit.id,
        visitEntity: visit,
        requirements: req,
        checkinTime: cTime,
        status: CheckInStatus.loaded,
      );

      await visitRepository.saveActiveVisit(visit);
      if (ref != null) {
        try {
          ref!.read(routeViewModelProvider.notifier).setActiveVisit(visit);
        } catch (_) {}
      }

      loadSurveyForms(customerId);
      if (req == null) {
        refreshRequirements();
      }

      // Kích hoạt giám sát Geofence cảnh báo khi nhân viên rời điểm bán
      if (dealerLat != null && dealerLng != null) {
        startGeofenceWatcher(
          dealerLat: dealerLat,
          dealerLng: dealerLng,
          dealerName: custName.isNotEmpty ? custName : (state.checkinData?.dealer.name ?? 'Điểm bán'),
          allowedRadius: allowedRadius.toDouble(),
        );
      }
      return null;
    } catch (e) {
      if (_isNetworkError(e)) {
        // TẠO PHIÊN VIẾNG THĂM NGOẠI TUYẾN
        final offlineVisit = _createOfflineVisit(
          customerId: customerId,
          lat: lat,
          lng: lng,
          accuracyM: accuracyM,
          address: address,
          isMockLocation: isMockLocation,
          note: note,
          mobileRules: mobileRules,
        );

        if (ref != null) {
          try {
            final db = ref!.read(appDatabaseProvider);
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            final offlinePayload = request.toJson();
            offlinePayload['is_offline_sync'] = true;

            // Nếu điểm bán tạo offline (customerId <= 0), gắn customer_client_uuid vào payload
            String? customerClientUuid;
            if (customerId <= 0) {
              if (state.customer is CustomerEntity) {
                customerClientUuid = (state.customer as CustomerEntity).clientUuid;
              } else if (state.customer is Map) {
                customerClientUuid = (state.customer as Map)['client_uuid']?.toString();
              }
              if (customerClientUuid == null) {
                try {
                  final dealerId = state.checkinData?.dealer.id;
                  if (dealerId != null && dealerId.isNotEmpty) {
                    final localCust = await (db.select(db.localCustomers)
                          ..where((tbl) => tbl.code.equals(dealerId))
                          ..limit(1))
                        .getSingleOrNull();
                    customerClientUuid = localCust?.clientUuid;
                  }
                } catch (_) {}
              }
            }

            if (customerClientUuid != null) {
              offlinePayload['customer_client_uuid'] = customerClientUuid;
            }

            await db.enqueue(
              SyncQueueEntriesCompanion(
                entity: const drift.Value('visit'),
                op: const drift.Value('create'),
                clientUuid: drift.Value(_sessionClientUuid),
                parentUuid: const drift.Value.absent(),
                payload: drift.Value(jsonEncode(offlinePayload)),
                state: const drift.Value('pending'),
                createdAt: drift.Value(nowMs),
                createdElapsed: drift.Value(SystemClock.nowMonotonicMs),
                bootId: drift.Value(SystemClock.bootId),
                attempts: const drift.Value(0),
              ),
            );
          } catch (err) {
            debugPrint('[RouteViewModel] Lỗi enqueue offline checkin: $err');
          }
        }

        await visitRepository.saveActiveVisit(offlineVisit);
        await visitRepository.saveLocalVisit(offlineVisit);

        if (ref != null) {
          try {
            ref!.read(routeViewModelProvider.notifier).setActiveVisit(offlineVisit);
          } catch (_) {}
        }

        _setupVisitTimer(offlineVisit.checkinAt);
        if (offlineVisit.requirements != null &&
            offlineVisit.requirements!.secondsRemaining > 0) {
          _targetDoneTime = DateTime.now().add(
            Duration(seconds: offlineVisit.requirements!.secondsRemaining),
          );
        } else {
          _targetDoneTime = null;
        }

        state = state.copyWith(
          visitId: offlineVisit.id,
          visitEntity: offlineVisit,
          requirements: offlineVisit.requirements,
          checkinTime: _formatTimeHHmmss(offlineVisit.checkinAt),
          status: CheckInStatus.loaded,
        );

        loadSurveyForms(customerId);

        // Kích hoạt giám sát Geofence cho phiên ngoại tuyến
        if (dealerLat != null && dealerLng != null) {
          final fallbackName = state.customer is CustomerEntity
              ? (state.customer as CustomerEntity).name
              : (state.checkinData?.dealer.name ?? 'Điểm bán');
          startGeofenceWatcher(
            dealerLat: dealerLat,
            dealerLng: dealerLng,
            dealerName: fallbackName,
            allowedRadius: allowedRadius.toDouble(),
          );
        }
        return null;
      }

      final msg = e
          .toString()
          .replaceAll('ServerException: ', '')
          .replaceAll('AppException: ', '');
      state = state.copyWith(errorMessage: msg);
      return msg;
    }
  }

  void _setupVisitTimer(DateTime? checkinTime) {
    _visitTimer?.cancel();
    if (checkinTime != null) {
      final diff = DateTime.now().difference(checkinTime.toLocal()).inSeconds;
      _elapsedSeconds = diff > 0 ? diff : 0;
    } else {
      _elapsedSeconds = 0;
    }
    _startTimer();
  }

  /// Đồng hồ thời gian thăm — màn check-in hiện bằng `ValueListenableBuilder`, KHÔNG nằm trong state: đưa vào state là
  /// mỗi giây dựng lại cả màn check-in (~1.200 dòng, cả danh sách ảnh).
  final ValueNotifier<String> liveDuration = ValueNotifier('00:00:00');

  void _setLiveDuration(String value) {
    if (mounted) liveDuration.value = value;
  }

  void _startTimer() {
    _visitTimer?.cancel();
    _visitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      final h = (_elapsedSeconds ~/ 3600).toString().padLeft(2, '0');
      final m = ((_elapsedSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
      final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
      _setLiveDuration('$h:$m:$s');

      // Đếm ngược thời gian tối thiểu — state luôn mang số giây THẬT (logic như trước), nhưng chỉ ghi khi có gì đổi:
      // hết thời gian tối thiểu thì không còn ghi mỗi giây (đồng hồ thăm đã ra [liveDuration], không qua state).
      final req = state.requirements;
      if (req != null) {
        int newSec = req.secondsRemaining;
        if (_targetDoneTime != null) {
          final diff = _targetDoneTime!.difference(DateTime.now()).inSeconds;
          newSec = diff > 0 ? diff : 0;
        } else if (newSec > 0) {
          newSec = newSec - 1;
        }

        final isTimeOk = newSec <= 0 || state.visitResult == 'closed';
        final isFormsOk = req.missingForms.isEmpty || state.visitResult == 'closed';
        final isPhotosOk = req.photosMissing <= 0;
        final newSatisfied =
            isTimeOk && isFormsOk && isPhotosOk && req.materialsOk(state.visitResult == 'closed');

        List<String> newBlockers = req.blockers;
        if (newSec <= 0) {
          newBlockers = req.blockers
              .where(
                (b) => !(b.toLowerCase().contains('thời gian') ||
                    b.toLowerCase().contains('giây') ||
                    b.toLowerCase().contains('phút') ||
                    b.toLowerCase().contains('ở lại thêm')),
              )
              .toList();
        }

        final hadSecondsLeft = req.secondsRemaining > 0;
        if (newSec != req.secondsRemaining ||
            newSatisfied != req.satisfied ||
            newBlockers.length != req.blockers.length) {
          state = state.copyWith(
            requirements: req.copyWith(
              secondsRemaining: newSec,
              satisfied: newSatisfied,
              blockers: newBlockers,
            ),
          );
        }

        if (hadSecondsLeft && newSec == 0 && state.visitId > 0) {
          refreshRequirements();
        }
      }

      // Cảnh báo quên Check-out nếu phiên ghé thăm kéo dài hơn 30, 45 hoặc 60 phút
      if ((_elapsedSeconds == 1800 ||
              _elapsedSeconds == 2700 ||
              _elapsedSeconds == 3600) &&
          state.visitId != 0 &&
          (state.visitEntity?.isOpen ?? true)) {
        if (ref != null) {
          try {
            final dealerName = state.customer is CustomerEntity
                ? (state.customer as CustomerEntity).name
                : state.checkinData?.dealer.name ?? 'Điểm bán';
            final minutes = _elapsedSeconds ~/ 60;
            ref!.read(appNotificationServiceProvider).notifyForgotCheckout(
                  dealerName: dealerName,
                  minutes: minutes,
                );
            ref!.invalidate(unreadNotificationCountProvider);
          } catch (_) {}
        }
      }
    });
  }

  /// Tải 1 tấm ảnh lên cho lượt viếng thăm (§4.1) hoặc lưu ngoại tuyến khi mất mạng
  /// Tối ưu UX: Hiển thị ngay lên giao diện và trừ photosMissing (Optimistic UI),
  /// đồng thời upload chạy ngầm không khoá nút chụp hay giao diện người dùng.
  Future<(bool, String?)> uploadPhoto(
    File file, {
    String photoType = 'other',
    double? lat,
    double? lng,
  }) async {
    if (state.visitId == 0) {
      return (false, 'Chưa có lượt viếng thăm hợp lệ');
    }

    // Chuẩn hoá photoType theo đặc tả API (§4.1):
    final apiPhotoType = (photoType == 'closed_store') ? 'store_front' : photoType;

    // 1. Sao lưu file vào thư mục offline_visit_photos lâu dài
    File persistentFile;
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final offlineDir = Directory(p.join(appDocDir.path, 'offline_visit_photos'));
      if (!await offlineDir.exists()) {
        await offlineDir.create(recursive: true);
      }
      final fileName = PhotoWatermarkHelper.keepMarkerName(
        file,
        'visit_photo_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}.jpg',
      );
      persistentFile = await file.copy(p.join(offlineDir.path, fileName));
    } catch (_) {
      persistentFile = file;
    }

    // 2. Tạo bản ghi ảnh lạc quan hiển thị ngay lên UI
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final tempPhoto = VisitPhotoEntity(
      id: tempId,
      token: '',
      url: persistentFile.path,
      localPath: persistentFile.path,
      photoType: apiPhotoType,
      photoTypeLabel: _photoTypeLabel(apiPhotoType),
      photoTypeColor: 'primary',
      takenAt: DateTime.now().toIso8601String(),
    );

    final updatedPhotos = List<VisitPhotoEntity>.from(state.photos)..add(tempPhoto);

    // 3. Trừ photosMissing và cập nhật yêu cầu check-out ngay lập tức
    var currentReq = state.requirements;
    if (currentReq != null) {
      final newPhotosMissing = math.max(0, currentReq.photosMissing - 1);
      final isTimeOk = currentReq.secondsRemaining <= 0 || state.visitResult == 'closed';
      final isFormsOk = currentReq.missingForms.isEmpty || state.visitResult == 'closed';
      final isPhotosOk = newPhotosMissing <= 0;
      final newSatisfied =
          isTimeOk && isFormsOk && isPhotosOk && currentReq.materialsOk(state.visitResult == 'closed');

      List<String> newBlockers = List<String>.from(currentReq.blockers);
      if (newPhotosMissing <= 0) {
        newBlockers.removeWhere(
          (b) => b.toLowerCase().contains('ảnh') || b.toLowerCase().contains('chụp'),
        );
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

    // Nếu phiên ngoại tuyến (visitId < 0) -> Đẩy vào SyncQueueEntries ngay
    if (state.visitId < 0) {
      final queueId = await _enqueueVisitPhotoToDb(
        file: persistentFile,
        photoType: apiPhotoType,
        lat: lat,
        lng: lng,
      );
      if (queueId != null) {
        final idx = state.photos.indexWhere((p) => p.id == tempId);
        if (idx >= 0) {
          final updated = List<VisitPhotoEntity>.from(state.photos);
          updated[idx] = updated[idx].copyWith(id: -queueId);
          state = state.copyWith(photos: updated);
        }
      }
      _recomputeOfflineRequirements(state.visitResult, activeMobileRules);
      return (true, 'Đã lưu ảnh ngoại tuyến trên máy. Ảnh sẽ tự động tải lên khi có mạng lại.');
    }

    try {
      final photo = await uploadVisitPhotoUseCase(
        visitId: state.visitId,
        file: persistentFile,
        photoType: apiPhotoType,
        takenAt: DateTime.now(),
        lat: lat,
        lng: lng,
      );

      // Nếu trong lúc chờ upload, người dùng đã bấm xoá ảnh (ảnh không còn trong state hoặc file đã xoá)
      if (!state.photos.any((p) => p.id == tempId) || !persistentFile.existsSync()) {
        try {
          await deleteVisitPhotoUseCase(visitId: state.visitId, photoId: photo.id);
        } catch (_) {}
        return (true, 'Ảnh đã bị xoá.');
      }

      final idx = state.photos.indexWhere((p) => p.id == tempId);
      if (idx >= 0) {
        final syncedPhotos = List<VisitPhotoEntity>.from(state.photos);
        syncedPhotos[idx] = photo.copyWith(localPath: persistentFile.path);
        state = state.copyWith(photos: syncedPhotos);
      }
      await refreshRequirements();

      return (true, null);
    } catch (e) {
      // 🔴 Nếu người dùng đã xoá ảnh trong lúc chờ tải lên ⇒ không đưa vào hàng đợi offline
      if (!state.photos.any((p) => p.id == tempId) || !persistentFile.existsSync()) {
        return (false, 'Ảnh đã bị xoá.');
      }

      if (_isNetworkError(e)) {
        final queueId = await _enqueueVisitPhotoToDb(
          file: persistentFile,
          photoType: apiPhotoType,
          lat: lat,
          lng: lng,
        );
        if (queueId != null) {
          final idx = state.photos.indexWhere((p) => p.id == tempId);
          if (idx >= 0) {
            final updated = List<VisitPhotoEntity>.from(state.photos);
            updated[idx] = updated[idx].copyWith(id: -queueId);
            state = state.copyWith(photos: updated);
          }
        }
        return (true, 'Đã lưu ảnh ngoại tuyến trên máy. Ảnh sẽ tự động tải lên khi có mạng lại.');
      }

      final rawMsg = e.toString().toLowerCase();
      final isCancelledError = rawMsg.contains('đã bị huỷ') ||
          rawMsg.contains('đã huỷ') ||
          rawMsg.contains('đã bị hủy') ||
          rawMsg.contains('đã hủy') ||
          rawMsg.contains('already cancelled');

      if (isCancelledError) {
        final cancelledVisitId = state.visitId;
        final clientUuid = state.visitEntity?.clientUuid ?? _sessionClientUuid;
        await visitRepository.clearActiveVisit();
        await visitRepository.cancelVisit(cancelledVisitId, clientUuid: clientUuid);
        if (ref != null) {
          try {
            ref!.read(routeViewModelProvider.notifier).markVisitCancelledLocally(
              cancelledVisitId,
              clientUuid: clientUuid,
            );
            ref!.read(routeViewModelProvider.notifier).setActiveVisit(null);
          } catch (_) {}
        }
        return (
          false,
          'VISIT_CANCELLED:Lượt viếng thăm này đã bị huỷ trên hệ thống, không nhận thêm ảnh được.',
        );
      }

      final queueId = await _enqueueVisitPhotoToDb(
        file: persistentFile,
        photoType: apiPhotoType,
        lat: lat,
        lng: lng,
      );
      if (queueId != null) {
        final idx = state.photos.indexWhere((p) => p.id == tempId);
        if (idx >= 0) {
          final updated = List<VisitPhotoEntity>.from(state.photos);
          updated[idx] = updated[idx].copyWith(id: -queueId);
          state = state.copyWith(photos: updated);
        }
      }
      return (true, 'Đã lưu ảnh ngoại tuyến trên máy. Ảnh sẽ tự động tải lên khi có mạng lại.');
    }
  }

  Future<int?> _enqueueVisitPhotoToDb({
    required File file,
    required String photoType,
    double? lat,
    double? lng,
  }) async {
    if (ref == null) return null;
    try {
      final db = ref!.read(appDatabaseProvider);
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final payload = {
        'visit_id': state.visitId,
        'photo_type': photoType,
        'lat': lat,
        'lng': lng,
        'taken_at': DateTime.now().toIso8601String(),
        'is_offline_sync': true,
      };

      return await db.enqueue(
        SyncQueueEntriesCompanion(
          entity: const drift.Value('visit_photo'),
          op: const drift.Value('upload'),
          clientUuid: drift.Value(const Uuid().v4()),
          parentUuid: drift.Value(_sessionClientUuid),
          localPath: drift.Value(file.path),
          payload: drift.Value(jsonEncode(payload)),
          state: const drift.Value('pending'),
          createdAt: drift.Value(nowMs),
          createdElapsed: drift.Value(SystemClock.nowMonotonicMs),
          bootId: drift.Value(SystemClock.bootId),
          attempts: const drift.Value(0),
        ),
      );
    } catch (e) {
      debugPrint('[RouteViewModel] Lỗi enqueue ảnh: $e');
      return null;
    }
  }

  /// Xoá 1 tấm ảnh (§4.2)
  Future<(bool, String?)> deletePhoto(int photoId) async {
    final photo =
        state.photos.where((p) => p.id == photoId).firstOrNull;
    if (state.visitId <= 0 || (photo != null && photo.id < 0)) {
      final updatedPhotos =
          state.photos.where((p) => p.id != photoId).toList();
      if (photo?.localPath != null) {
        try {
          final file = File(photo!.localPath!);
          if (file.existsSync()) await file.delete();
        } catch (_) {}
      }
      // Ảnh nạp lại từ hàng đợi ([_restoreQueuedPhotos], id = -id dòng hàng đợi) hoặc vừa chụp offline: bỏ cả dòng hàng đợi,
      // không thì mở lại app ảnh quay về / lúc có mạng bị lỗi 410 mất file.
      if (photoId < 0 && ref != null) {
        try {
          final db = ref!.read(appDatabaseProvider);
          await (db.delete(db.syncQueueEntries)
                ..where((t) =>
                    (t.id.equals(-photoId) |
                        (photo?.localPath != null && photo!.localPath!.isNotEmpty
                            ? t.localPath.equals(photo.localPath!)
                            : const drift.Constant(false))) &
                    t.entity.equals('visit_photo') &
                    t.parentUuid.equals(_sessionClientUuid) &
                    t.state.equals('pending')))
              .go();
        } catch (_) {}
      }
      state = state.copyWith(photos: updatedPhotos);
      _recomputeOfflineRequirements(state.visitResult, activeMobileRules);
      return (true, null);
    }

    state = state.copyWith(isDeletingPhoto: true);
    try {
      final newReq = await deleteVisitPhotoUseCase(
        visitId: state.visitId,
        photoId: photoId,
      );

      final updatedPhotos =
          state.photos.where((p) => p.id != photoId).toList();
      state = state.copyWith(
        photos: updatedPhotos,
        requirements: newReq,
        isDeletingPhoto: false,
      );
      return (true, null);
    } catch (e) {
      if (_isNetworkError(e)) {
        final updatedPhotos =
            state.photos.where((p) => p.id != photoId).toList();
        state = state.copyWith(
          photos: updatedPhotos,
          isDeletingPhoto: false,
        );
        _recomputeOfflineRequirements(state.visitResult, activeMobileRules);
        return (true, null);
      }
      state = state.copyWith(isDeletingPhoto: false);
      final msg = e
          .toString()
          .replaceAll('ServerException: ', '')
          .replaceAll('AppException: ', '');
      return (false, msg);
    }
  }

  /// Làm mới thông tin điều kiện check-out từ server (§6) hoặc tính toán offline theo rules
  Future<void> refreshRequirements({
    String? visitResult,
    MobileRules? rules,
  }) async {
    final vResult = visitResult ?? state.visitResult;
    final effectiveRules = rules ?? await getEffectiveMobileRules();

    if (state.visitId > 0) {
      try {
        final req = await getVisitRequirementsUseCase(
          state.visitId,
          visitResult: vResult,
        );
        if (req.secondsRemaining > 0) {
          _targetDoneTime = DateTime.now().add(
            Duration(seconds: req.secondsRemaining),
          );
        } else {
          _targetDoneTime = null;
        }
        state = state.copyWith(requirements: req);
        return;
      } catch (e) {
        final rawMsg = e.toString().toLowerCase();
        if (rawMsg.contains('đã bị huỷ') ||
            rawMsg.contains('đã huỷ') ||
            rawMsg.contains('đã bị hủy') ||
            rawMsg.contains('đã hủy') ||
            rawMsg.contains('already cancelled')) {
          final cId = state.visitId;
          final uuid = state.visitEntity?.clientUuid ?? _sessionClientUuid;
          await visitRepository.clearActiveVisit();
          await visitRepository.cancelVisit(cId, clientUuid: uuid);
          if (ref != null) {
            try {
              ref!.read(routeViewModelProvider.notifier).markVisitCancelledLocally(cId, clientUuid: uuid);
              ref!.read(routeViewModelProvider.notifier).setActiveVisit(null);
            } catch (_) {}
          }
          VisitProgressStore.clear();
          state = state.copyWith(visitId: 0, visitEntity: null);
        }
        if (!_isNetworkError(e)) {
          return;
        }
      }
    }

    // Ngoại tuyến (visitId <= 0) hoặc mất mạng: Tự động tính toán theo cached rule
    _recomputeOfflineRequirements(vResult, effectiveRules);
  }

  /// Đổi kết quả viếng thăm: 'visited' (Mở cửa) hoặc 'closed' (Đóng cửa)
  void setVisitResult(String result) {
    if (state.visitResult != result || state.requirements == null) {
      state = state.copyWith(visitResult: result);
      _recomputeOfflineRequirements(result, activeMobileRules);
      refreshRequirements(visitResult: result);
      if (state.visitEntity != null) {
        final updated = state.visitEntity!.copyWith(
          visitResult: result,
          requirements: state.requirements,
        );
        state = state.copyWith(visitEntity: updated);
        visitRepository.saveActiveVisit(updated);
      }
    }
  }

  /// Ghi chú lý do đóng cửa
  void setClosedNote(String note) {
    state = state.copyWith(closedNote: note);
    if (state.visitEntity != null) {
      final updated = state.visitEntity!.copyWith(closedNote: note);
      state = state.copyWith(visitEntity: updated);
      visitRepository.saveActiveVisit(updated);
    }
  }

  /// Ghi chú chuyến ghé viếng thăm
  void setVisitNote(String note) {
    state = state.copyWith(visitNote: note);
  }

  /// Cập nhật server ID khi tiến trình đồng bộ ngầm đưa lượt viếng thăm ngoại tuyến lên server thành công
  void syncServerVisitId(int serverId, {String? clientUuid}) {
    if (state.visitId < 0 &&
        (clientUuid == null ||
            _sessionClientUuid == clientUuid ||
            state.visitEntity?.clientUuid == clientUuid)) {
      debugPrint(
        '[CheckInViewModel] Đồng bộ serverId=$serverId cho phiên offline (trước đó visitId=${state.visitId})',
      );
      final updatedVisit = state.visitEntity?.copyWith(id: serverId);
      state = state.copyWith(
        visitId: serverId,
        visitEntity: updatedVisit,
      );
    }
  }

  /// Lưu trạng thái phiên viếng thăm hiện tại khi người dùng tạm rời màn hình
  Future<void> saveCurrentActiveSession() async {
    if (state.visitId == 0) return;
    try {
      final currentVisit = state.visitEntity ??
          VisitEntity(
            id: state.visitId,
            customerId: state.checkinData?.dealer.id != null
                ? (int.tryParse(
                        state.checkinData!.dealer.id.replaceAll(
                          RegExp(r'[^\d]'),
                          '',
                        ),
                      ) ??
                      0)
                : 0,
            customerName: state.checkinData?.dealer.name ?? '',
            customerAddress: state.checkinData?.dealer.address ?? '',
            clientUuid: _sessionClientUuid,
          );

      final updatedVisit = currentVisit.copyWith(
        visitResult: state.visitResult,
        closedNote: state.closedNote.isNotEmpty ? state.closedNote : null,
        requirements: state.requirements,
        photoCount: state.photos.length,
        clientUuid: _sessionClientUuid,
      );

      state = state.copyWith(visitEntity: updatedVisit);
      await visitRepository.saveActiveVisit(updatedVisit);
      await visitRepository.saveLocalVisit(updatedVisit);

      if (ref != null) {
        try {
          ref!.read(routeViewModelProvider.notifier).setActiveVisit(updatedVisit);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[CheckInViewModel] Lỗi saveCurrentActiveSession: $e');
    }
  }

  /// Thực hiện check-out (§7) hoặc chuyển ngoại tuyến khi mất mạng
  Future<(bool, String?)> checkout({
    double? lat,
    double? lng,
    double? accuracyM,
    int? allowedRadiusMeters,
    bool? requireGeofence,
    bool forceCheckout = false,
  }) async {
    if (state.visitId == 0) {
      return (false, 'Chưa có lượt viếng thăm hợp lệ');
    }

    MobileRules? mobileRules = ref?.read(mobileRulesProvider);
    try {
      final cached = await MobileRulesNotifier.getCachedRules();
      if (cached != null) {
        mobileRules = cached;
      }
    } catch (_) {}
    final isGeofenceRequired =
        requireGeofence ?? GeofenceRuleHelper.isGeofenceRequired(mobileRules);
    final allowedRadius = GeofenceRuleHelper.resolveAllowedRadius(
      dealer: state.checkinData?.dealer,
      customer: state.customer is CustomerEntity
          ? state.customer as CustomerEntity
          : null,
      explicitRadius: allowedRadiusMeters,
      rules: mobileRules,
    );

    // Kiểm tra khoảng cách với điểm bán khi có toạ độ
    double? dealerLat = state.checkinData?.dealer.lat;
    double? dealerLng = state.checkinData?.dealer.lng;
    if (dealerLat == null && state.customer is CustomerEntity) {
      final cust = state.customer as CustomerEntity;
      dealerLat = cust.lat;
      dealerLng = cust.lng;
    }

    if (isGeofenceRequired &&
        dealerLat != null &&
        dealerLng != null &&
        lat != null &&
        lng != null) {
      final distanceM = Geolocator.distanceBetween(
        lat,
        lng,
        dealerLat,
        dealerLng,
      );
      if (distanceM > allowedRadius) {
        if (!forceCheckout) {
          final distText = distanceM < 1000
              ? '${distanceM.round()}m'
              : '${(distanceM / 1000).toStringAsFixed(1)}km';
          final maxRadiusText = allowedRadius < 1000
              ? '${allowedRadius}m'
              : '${(allowedRadius / 1000).toStringAsFixed(1)}km';
          return (
            false,
            'Khoảng cách hiện tại ($distText) vượt quá phạm vi cho phép (tối đa $maxRadiusText). Vui lòng di chuyển đến gần điểm bán để thực hiện check-out.',
          );
        } else {
          debugPrint(
            '[CheckInViewModel] Checkout ngoài bán kính ($distanceM m > $allowedRadius m) - người dùng đã xác nhận gắn cờ vi phạm theo API 13/10/2026',
          );
        }
      }
    }

    state = state.copyWith(status: CheckInStatus.checkingOut);
    final request = CheckoutRequestModel(
      visitResult: state.visitResult,
      closedNote: state.visitResult == 'closed' ? state.closedNote : null,
      note: state.visitNote.isNotEmpty ? state.visitNote : null,
      lat: lat,
      lng: lng,
      accuracyM: accuracyM,
      clientTime: DateTime.now().toIso8601String(),
      clientBootId: SystemClock.bootId,
    );

    // Nếu phiên bắt đầu ngoại tuyến (visitId < 0):
    // 1. Kiểm tra xem đã có serverId được đồng bộ từ hàng đợi hay chưa
    if (state.visitId < 0) {
      try {
        final savedActive = await visitRepository.getActiveVisit();
        if (savedActive != null && savedActive.id > 0) {
          state = state.copyWith(
            visitId: savedActive.id,
            visitEntity: state.visitEntity?.copyWith(id: savedActive.id),
          );
        }
      } catch (_) {}
    }
    if (state.visitId < 0 && ref != null) {
      try {
        final db = ref!.read(appDatabaseProvider);
        final entry = await db.getEntryByClientUuid(_sessionClientUuid);
        if (entry != null && entry.serverId != null && entry.serverId! > 0) {
          final sId = entry.serverId!;
          state = state.copyWith(
            visitId: sId,
            visitEntity: state.visitEntity?.copyWith(id: sId),
          );
        }
      } catch (_) {}
    }

    // 2. Nếu thiết bị đang có mạng nhưng lượt viếng thăm offline chưa đồng bộ:
    // Thử đồng bộ ngay để lấy serverId rồi check-out online trực tiếp
    if (state.visitId < 0 && ref != null) {
      try {
        final isOnline = ref!.read(connectivityProvider).isOnline;
        if (isOnline) {
          // Lượt gửi đang chạy thì syncQueue trả về rỗng ngay ⇒ CHỜ nó xong trước rồi mới ép gửi.
          final sync = ref!.read(syncServiceProvider);
          await sync.waitUntilIdle().timeout(visitMaterialFlushTimeout, onTimeout: () {});
          await sync.syncQueue(force: true);
          final db = ref!.read(appDatabaseProvider);
          final entry = await db.getEntryByClientUuid(_sessionClientUuid);
          if (entry != null && entry.serverId != null && entry.serverId! > 0) {
            final sId = entry.serverId!;
            state = state.copyWith(
              visitId: sId,
              visitEntity: state.visitEntity?.copyWith(id: sId),
            );
          } else {
            final savedActive = await visitRepository.getActiveVisit();
            if (savedActive != null && savedActive.id > 0) {
              state = state.copyWith(
                visitId: savedActive.id,
                visitEntity: state.visitEntity?.copyWith(id: savedActive.id),
              );
            }
          }
        }
      } catch (err) {
        debugPrint('[CheckInViewModel] Checkout pre-sync error: $err');
      }
    }

    // 2b. Thao tác vật tư của lượt PHẢI lên server trước check-out (#24522: server từ chối thao tác sau giờ ra, cổng ④
    // đòi chúng). Còn mục chưa gửi được ⇒ check-out đi hàng đợi, nơi nó đứng chờ sau thao tác vật tư của lượt.
    if (state.visitId > 0 && ref != null) {
      try {
        if (ref!.read(connectivityProvider).isOnline &&
            !await ref!.read(syncServiceProvider).flushVisitMaterials(_sessionClientUuid)) {
          return await _checkoutOffline(request: request, lat: lat, lng: lng);
        }
      } catch (err) {
        debugPrint('[CheckInViewModel] Đẩy thao tác vật tư trước check-out lỗi: $err');
      }
    }

    // 3. Nếu vẫn không có serverId (đang offline hoàn toàn hoặc chưa sync được) -> Chuyển sang check-out ngoại tuyến
    if (state.visitId < 0) {
      return _checkoutOffline(request: request, lat: lat, lng: lng);
    }

    try {
      final completedVisit = await checkoutUseCase(visitId: state.visitId, request: request);

      _visitTimer?.cancel();
      stopGeofenceWatcher();
      await visitRepository.clearActiveVisit();
      await visitRepository.saveLocalVisit(completedVisit);
      if (ref != null) {
        try {
          ref!.read(routeViewModelProvider.notifier).setActiveVisit(null);
          ref!
              .read(routeViewModelProvider.notifier)
              .loadRouteDetail(isRefresh: true);
        } catch (_) {}
        try {
          ref!.read(routeViewModelProvider.notifier).checkProximitySuggestion(
                userLat: lat,
                userLng: lng,
              );
        } catch (_) {}
        try {
          // Tính và làm mới quãng đường di chuyển tức thì ngay khi hoàn thành viếng thăm
          ref!.read(travelViewModelProvider.notifier).loadMyTravel(refresh: true);
        } catch (_) {}
      }
      state = state.copyWith(
        status: CheckInStatus.checkedOut,
        visitEntity: completedVisit,
      );
      return (true, null);
    } catch (e) {
      final rawMsg = e.toString().toLowerCase();
      // Nếu server trả về lỗi lượt đã bị huỷ (§4.1 HUY-LUOT-VIENG-THAM)
      if (rawMsg.contains('đã bị huỷ') ||
          rawMsg.contains('đã huỷ') ||
          rawMsg.contains('đã bị hủy') ||
          rawMsg.contains('đã hủy') ||
          rawMsg.contains('already cancelled')) {
        _visitTimer?.cancel();
        stopGeofenceWatcher();
        await visitRepository.clearActiveVisit();
        await visitRepository.cancelVisit(state.visitId, clientUuid: _sessionClientUuid);
        if (ref != null) {
          try {
            ref!.read(routeViewModelProvider.notifier).markVisitCancelledLocally(
              state.visitId,
              clientUuid: _sessionClientUuid,
            );
            ref!.read(routeViewModelProvider.notifier).setActiveVisit(null);
            ref!
                .read(routeViewModelProvider.notifier)
                .loadRouteDetail(isRefresh: true);
          } catch (_) {}
        }
        resetSession();
        return (
          false,
          'VISIT_CANCELLED:Lượt viếng thăm này đã bị huỷ trên hệ thống, không check-out được.',
        );
      }

      // Nếu server trả về 422 "đã check-out rồi" / "đã đóng" thì coi là thành công (§9)
      if (rawMsg.contains('đã check-out rồi') ||
          rawMsg.contains('đã check out') ||
          rawMsg.contains('đã checkout') ||
          rawMsg.contains('đã đóng') ||
          rawMsg.contains('already checked out') ||
          rawMsg.contains('already closed')) {
        _visitTimer?.cancel();
        stopGeofenceWatcher();
        await visitRepository.clearActiveVisit();
        if (ref != null) {
          try {
            ref!.read(routeViewModelProvider.notifier).setActiveVisit(null);
            ref!
                .read(routeViewModelProvider.notifier)
                .loadRouteDetail(isRefresh: true);
          } catch (_) {}
          try {
            ref!.read(travelViewModelProvider.notifier).loadMyTravel(refresh: true);
          } catch (_) {}
        }
        state = state.copyWith(
          status: CheckInStatus.checkedOut,
          visitEntity: state.visitEntity?.copyWith(checkoutAt: DateTime.now()),
        );
        return (true, null);
      }

      // Nếu gặp lỗi mạng -> Lưu check-out vào hàng đợi ngoại tuyến
      if (_isNetworkError(e)) {
        return _checkoutOffline(request: request, lat: lat, lng: lng);
      }

      final msg = rawMsg
          .replaceAll('ServerException: ', '')
          .replaceAll('AppException: ', '');
      state = state.copyWith(status: CheckInStatus.loaded, errorMessage: msg);
      return (false, msg);
    }
  }

  Future<(bool, String?)> _checkoutOffline({
    required CheckoutRequestModel request,
    double? lat,
    double? lng,
  }) async {
    try {
      if (ref != null) {
        final db = ref!.read(appDatabaseProvider);
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        final checkoutPayload = request.toJson();
        checkoutPayload['is_offline_sync'] = true;
        checkoutPayload['visit_id'] = state.visitId;

        await db.enqueue(
          SyncQueueEntriesCompanion(
            entity: const drift.Value('visit'),
            op: const drift.Value('checkout'),
            clientUuid: drift.Value(const Uuid().v4()),
            parentUuid: drift.Value(_sessionClientUuid),
            payload: drift.Value(jsonEncode(checkoutPayload)),
            state: const drift.Value('pending'),
            createdAt: drift.Value(nowMs),
            createdElapsed: drift.Value(SystemClock.nowMonotonicMs),
            bootId: drift.Value(SystemClock.bootId),
            attempts: const drift.Value(0),
          ),
        );
      }

      final now = DateTime.now();
      final currentVisit =
          state.visitEntity ??
          VisitEntity(
            id: state.visitId,
            customerId: state.checkinData?.dealer.id != null
                ? int.tryParse(
                        state.checkinData!.dealer.id.replaceAll(
                          RegExp(r'[^\d]'),
                          '',
                        ),
                      ) ??
                      0
                : 0,
          );
      final completedVisit = currentVisit.copyWith(
        checkoutAt: now,
        checkoutAtRaw: now.toIso8601String(),
        visitResult: state.visitResult,
        closedNote: state.visitResult == 'closed' ? state.closedNote : null,
        checkoutLat: lat,
        checkoutLng: lng,
      );

      await visitRepository.saveLocalVisit(completedVisit);
      await visitRepository.clearActiveVisit();

      _visitTimer?.cancel();
      stopGeofenceWatcher();
      state = state.copyWith(
        status: CheckInStatus.checkedOut,
        visitEntity: completedVisit,
      );
      if (ref != null) {
        try {
          ref!.read(routeViewModelProvider.notifier).setActiveVisit(null);
          ref!.read(routeViewModelProvider.notifier).loadRouteDetail(isRefresh: true);
        } catch (_) {}
        try {
          ref!.read(routeViewModelProvider.notifier).checkProximitySuggestion(
                userLat: lat,
                userLng: lng,
              );
        } catch (_) {}
        try {
          final isOnline = ref!.read(connectivityProvider).isOnline;
          if (isOnline) {
            unawaited(ref!.read(syncServiceProvider).syncQueue());
          }
        } catch (_) {}
      }
      return (true, null);
    } catch (err) {
      state = state.copyWith(status: CheckInStatus.loaded);
      return (
        false,
        'Không thể lưu kết thúc ghé thăm: ${StringUtils.formatUserFriendlyError(err)}',
      );
    }
  }

  /// Huỷ lượt check-in (§3.4 HUY-LUOT-VIENG-THAM-2026-09-30.md)
  Future<(bool, String?)> cancelVisit() async {
    final clientUuid = state.visitEntity?.clientUuid ?? _sessionClientUuid;
    int effectiveVisitId = state.visitId;

    // 1. Kiểm tra trong AppDatabase xem lượt này đã từng được đưa vào sync_queue chưa
    SyncQueueEntry? visitEntry;
    if (ref != null) {
      try {
        final db = ref!.read(appDatabaseProvider);
        visitEntry = await db.findVisitQueueEntry(clientUuid);
        // Nếu entry đã được sync lên server thành công (state == 'done') và có serverId, cập nhật effectiveVisitId
        if (visitEntry != null &&
            visitEntry.serverId != null &&
            visitEntry.serverId! > 0) {
          effectiveVisitId = visitEntry.serverId!;
        }
      } catch (err) {
        debugPrint('[CheckInViewModel] Lỗi kiểm tra syncQueue khi hủy: $err');
      }
    }

    // 2. Trường hợp A: Lượt chưa tạo trên máy chủ (hoặc mới chỉ nằm trong sync_queue ở trạng thái pending)
    // Theo §5.1 HUY-LUOT-VIENG-THAM-2026-09-30.md:
    // "Lượt chưa kịp đồng bộ thì app xoá thẳng bản ghi cục bộ, đừng gọi check-in rồi gọi huỷ"
    if (effectiveVisitId <= 0 &&
        (visitEntry == null || visitEntry.state == 'pending')) {
      if (ref != null) {
        try {
          final db = ref!.read(appDatabaseProvider);
          // Xoá toàn bộ tác vụ pending/sending của lượt này (create visit, upload ảnh, checkout) — kèm tệp ảnh của chúng
          await db.deletePendingVisitQueue(clientUuid);
        } catch (err) {
          debugPrint('[CheckInViewModel] Lỗi xoá queue khi hủy lượt: $err');
        }
      }

      // Xoá các file ảnh trong state (nếu có)
      for (final photo in state.photos) {
        if (photo.localPath != null) {
          try {
            final f = File(photo.localPath!);
            if (f.existsSync()) await f.delete();
          } catch (_) {}
        }
      }

      // Dọn sạch active visit và local visit
      await visitRepository.clearActiveVisit();
      await visitRepository.removeLocalVisit(
        effectiveVisitId,
        clientUuid: clientUuid,
      );

      _visitTimer?.cancel();
      resetSession();
      return (true, null);
    }

    // 3. Trường hợp B: Lượt đã có trên máy chủ (effectiveVisitId > 0)
    // Cần gọi API huỷ lượt trên server. Nếu đang mất mạng (offline), đưa tác vụ huỷ vào sync_queue!
    if (effectiveVisitId > 0) {
      try {
        await cancelVisitUseCase(effectiveVisitId, clientUuid: clientUuid);

        // Huỷ thành công trên server: dọn dẹp các queue pending liên quan (như upload ảnh dở)
        if (ref != null) {
          try {
            final db = ref!.read(appDatabaseProvider);
            await db.deletePendingVisitQueue(clientUuid);
          } catch (_) {}
        }

        await visitRepository.clearActiveVisit();
        await visitRepository.cancelVisit(
          effectiveVisitId,
          clientUuid: clientUuid,
        );

        _visitTimer?.cancel();
        resetSession();
        return (true, null);
      } catch (e) {
        final rawMsg = e.toString().toLowerCase();
        // Server idempotent (§3.4): Nếu đã huỷ trước đó thì coi là thành công
        final isAlreadyCancelled =
            rawMsg.contains('đã bị huỷ') ||
            rawMsg.contains('đã huỷ') ||
            rawMsg.contains('đã bị hủy') ||
            rawMsg.contains('đã hủy') ||
            rawMsg.contains('already cancelled') ||
            rawMsg.contains('404');

        // Trường hợp lượt đã check-out trên máy chủ (lỗi 422: lượt viếng thăm này đã check out rồi, không hủy được nữa)
        final isAlreadyCheckedOut =
            rawMsg.contains('đã check out') ||
            rawMsg.contains('đã checkout') ||
            rawMsg.contains('đã check-out') ||
            rawMsg.contains('không hủy được nữa') ||
            rawMsg.contains('không huỷ được nữa') ||
            rawMsg.contains('không hủy được') ||
            rawMsg.contains('không huỷ được') ||
            rawMsg.contains('already checked out') ||
            rawMsg.contains('already closed');

        if (isAlreadyCancelled || isAlreadyCheckedOut) {
          if (ref != null) {
            try {
              final db = ref!.read(appDatabaseProvider);
              await db.deletePendingVisitQueue(clientUuid);
            } catch (_) {}
            try {
              if (isAlreadyCancelled) {
                ref!
                    .read(routeViewModelProvider.notifier)
                    .markVisitCancelledLocally(
                      effectiveVisitId,
                      clientUuid: clientUuid,
                    );
              } else {
                ref!.read(routeViewModelProvider.notifier).setActiveVisit(null);
                ref!
                    .read(routeViewModelProvider.notifier)
                    .loadRouteDetail(isRefresh: true);
              }
            } catch (_) {}
          }
          await visitRepository.clearActiveVisit();
          if (isAlreadyCancelled) {
            await visitRepository.cancelVisit(
              effectiveVisitId,
              clientUuid: clientUuid,
            );
          }
          _visitTimer?.cancel();
          stopGeofenceWatcher();
          resetSession();
          return (
            true,
            isAlreadyCheckedOut
                ? 'Lượt viếng thăm này đã check-out trước đó trên hệ thống. Đã đóng phiên.'
                : null,
          );
        }

        // Nếu là lỗi mạng (offline khi huỷ lượt đã tạo trên server):
        // Enqueue op 'cancel' vào hàng đợi đồng bộ để server huỷ khi có mạng lại (§3.4)
        if (_isNetworkError(e)) {
          if (ref != null) {
            try {
              final db = ref!.read(appDatabaseProvider);
              // Xoá các queue upload ảnh pending của lượt đã huỷ
              await db.deletePendingVisitQueue(clientUuid);

              final nowMs = DateTime.now().millisecondsSinceEpoch;
              await db.enqueue(
                SyncQueueEntriesCompanion(
                  entity: const drift.Value('visit'),
                  op: const drift.Value('cancel'),
                  clientUuid: drift.Value(const Uuid().v4()),
                  parentUuid: drift.Value(clientUuid),
                  payload: drift.Value(
                    jsonEncode({'visit_id': effectiveVisitId}),
                  ),
                  state: const drift.Value('pending'),
                  createdAt: drift.Value(nowMs),
                  createdElapsed: drift.Value(SystemClock.nowMonotonicMs),
                  bootId: drift.Value(SystemClock.bootId),
                  attempts: const drift.Value(0),
                ),
              );
            } catch (err) {
              debugPrint('[CheckInViewModel] Lỗi enqueue offline cancel: $err');
            }

            try {
              ref!
                  .read(routeViewModelProvider.notifier)
                  .markVisitCancelledLocally(
                    effectiveVisitId,
                    clientUuid: clientUuid,
                  );
            } catch (_) {}
          }

          await visitRepository.clearActiveVisit();
          try {
            final all = await visitRepository.getAllLocalVisits();
            final idx = all.indexWhere(
              (v) =>
                  v.id == effectiveVisitId ||
                  (v.clientUuid != null && v.clientUuid == clientUuid),
            );
            if (idx >= 0) {
              final updated = all[idx].copyWith(
                cancelledAt: DateTime.now(),
                cancelledAtRaw: DateTime.now().toIso8601String(),
              );
              await visitRepository.saveLocalVisit(updated);
            }
          } catch (_) {}

          _visitTimer?.cancel();
          resetSession();
          return (true, null);
        }

        final msg = rawMsg
            .replaceAll('ServerException: ', '')
            .replaceAll('AppException: ', '');
        return (false, msg);
      }
    }

    // Fallback cho trường hợp bất định
    await visitRepository.clearActiveVisit();
    await visitRepository.removeLocalVisit(
      effectiveVisitId,
      clientUuid: clientUuid,
    );
    _visitTimer?.cancel();
    resetSession();
    return (true, null);
  }

  @override
  void dispose() {
    _visitTimer?.cancel();
    liveDuration.dispose();
    super.dispose();
  }
}
