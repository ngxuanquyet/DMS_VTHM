import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/rules/mobile_rules_model.dart';
import '../../../../core/rules/mobile_rules_service.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../../core/utils/system_clock.dart';
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
import '../../../visit/domain/entities/visit_entity.dart';
import '../../../visit/domain/entities/visit_photo_entity.dart';
import '../../../visit/domain/repositories/visit_repository.dart';
import '../../../visit/domain/usecases/visit_usecases.dart';
import '../states/route_state.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/network/connectivity_provider.dart';

import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/rules/geofence_rule_helper.dart';
import '../../../../core/services/app_notification_service.dart';
import '../../../notifications/presentation/viewmodels/notifications_view_model.dart';
import '../../../visit/domain/entities/visit_requirements_entity.dart';

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
      return RouteViewModel(
        customerRepository: customerRepository,
        getRouteDetailUseCase: getRouteDetailUseCase,
        getTodayVisitsUseCase: getTodayVisitsUseCase,
        visitRepository: visitRepository,
        routeApiService: routeApiService,
        ref: ref,
      );
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
    state = state.copyWith(searchQuery: query);
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

  Future<void> loadRouteDetail({bool isRefresh = false}) async {
    state = state.copyWith(status: RouteStatus.loading);
    try {
      // 1. Fetch user's customers from customer repository
      final customers = await customerRepository.getCustomers(
        forceRefresh: isRefresh,
      );

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
            } else {
              activeVisit = saved;
            }
          }
        } catch (_) {}
      }

      // 3. Trích xuất danh sách tuyến từ API tuyến của tài khoản (getMyRoutes) và khách hàng
      final Set<String> routeSet = {'Tất cả tuyến'};
      final routeMap = <int, String>{};

      if (routeApiService != null) {
        try {
          final myRoutes = await routeApiService!.getMyRoutes(
            forceRefresh: isRefresh,
          );
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
          for (final r in cleanRoutes) {
            routeSet.add(r);
          }
          return c;
        }
        if (c.routeIds.isNotEmpty && routeMap.isNotEmpty) {
          final mappedNames = c.routeIds
              .map((id) => routeMap[id])
              .whereType<String>()
              .toList();
          if (mappedNames.isNotEmpty) {
            for (final r in mappedNames) {
              routeSet.add(r);
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
              routeSet.add(p);
            }
          }
        }
        return c;
      }).toList();

      _rawCustomers = resolvedCustomers;
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
      for (final c in resolvedCustomers) {
        final t = c.type.trim();
        if (t.isNotEmpty && t != 'Tất cả' && t != 'Tất cả loại') {
          typeSet.add(t);
        }
      }
      final customerTypes = typeSet.toList()..sort();

      final customerStatuses = resolvedCustomers
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

      if (!mounted) return;
      state = state.copyWith(
        availableRoutes: availableRoutes,
        availableCustomerTypes: customerTypes,
        availableCustomerStatuses: customerStatuses,
        selectedRoute: selectedRoute,
        todayVisits: todayVisits,
        activeVisit: activeVisit,
        clearActiveVisit: activeVisit == null,
      );

      _recomputeRouteDetail();
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        status: RouteStatus.error,
        errorMessage: e.toString().replaceAll('AppException: ', ''),
      );
    }
  }

  void _recomputeRouteDetail() {
    if (!mounted) return;
    // 1. Lọc theo tuyến được chọn
    var filtered = _rawCustomers;
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
            (c.contactTitle != null &&
                StringUtils.toUnaccentedLower(c.contactTitle).contains(query));
      }).toList();
    }

    // Sort by distance if enabled
    if (state.isSortedByDistance &&
        state.userLat != null &&
        state.userLng != null) {
      filtered = List.from(filtered);
      filtered.sort((a, b) {
        if (!a.hasCoordinates && !b.hasCoordinates) return 0;
        if (!a.hasCoordinates) return 1;
        if (!b.hasCoordinates) return -1;
        final distA = Geolocator.distanceBetween(
          state.userLat!,
          state.userLng!,
          a.lat!,
          a.lng!,
        );
        final distB = Geolocator.distanceBetween(
          state.userLat!,
          state.userLng!,
          b.lat!,
          b.lng!,
        );
        return distA.compareTo(distB);
      });
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

    // Tự động kích hoạt nhắc nhở lộ trình đầu ngày và cảnh báo tiến độ tuyến
    if (ref != null && total > 0) {
      () async {
        try {
          final now = DateTime.now();
          final hour = now.hour;
          final routeName = state.selectedRoute.isNotEmpty && state.selectedRoute != 'Tất cả tuyến'
              ? state.selectedRoute
              : 'Tuyến hôm nay';

          final notifService = ref!.read(appNotificationServiceProvider);

          // Nhắc lộ trình đầu ngày (07:00 - 11:00) và Nhắc Chấm công Vào ca nếu chưa vào ca
          if (hour >= 7 && hour < 11) {
            final hasIn = await notifService.checkHasCheckedInToday();
            if (!hasIn && now.weekday != DateTime.sunday) {
              await notifService.notifyAttendanceCheckinReminder(isLate: hour >= 8);
            }

            await notifService.notifyRouteBriefing(
              totalDealers: total,
              routeName: routeName,
            );
            ref!.invalidate(unreadNotificationCountProvider);
          }

          // Cảnh báo tiến độ tuyến (Khung trưa 11:15 - 13:00 và Chiều 15:00 - 17:00)
          if (completed < total) {
            if (hour >= 11 && hour < 13) {
              await notifService.notifyRouteProgress(
                completed: completed,
                total: total,
                period: 'Trưa',
              );
              ref!.invalidate(unreadNotificationCountProvider);
            } else if (hour >= 15 && hour < 17) {
              await notifService.notifyRouteProgress(
                completed: completed,
                total: total,
                period: 'Chiều',
              );
              ref!.invalidate(unreadNotificationCountProvider);
            }
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
    this.ref,
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
      final localTime = _formatTimeHHmmss(now);

      final data = await getDealerCheckinUseCase();
      state = state.copyWith(
        status: CheckInStatus.loaded,
        checkinData: data,
        checkinTime: state.visitId > 0 && state.checkinTime != '--:--:--'
            ? state.checkinTime
            : localTime,
        liveVisitDuration: state.liveVisitDuration,
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
    _elapsedSeconds = 0;
    _targetDoneTime = null;
    _sessionClientUuid = const Uuid().v4();
    state = const CheckInState(liveVisitDuration: '00:00:00');
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
      final newSatisfied = isTimeOk && isFormsOk && isPhotosOk;

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
        debugPrint(
          '[CheckInViewModel] Giữ nguyên phiên viếng thăm đang mở id=${state.visitId} cho customer=$newCId',
        );
        return;
      }
    }

    final now = DateTime.now();
    final localTime = _formatTimeHHmmss(now);

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
      _sessionClientUuid = existingVisit.clientUuid ?? const Uuid().v4();
      _setupVisitTimer(existingVisit.checkinAt);

      state = CheckInState(
        status: CheckInStatus.loaded,
        checkinData: initialCheckinData,
        checkinTime: existingVisit.checkinAt != null
            ? _formatTimeHHmmss(existingVisit.checkinAt)
            : localTime,
        liveVisitDuration: state.liveVisitDuration,
        visitId: existingVisit.id,
        visitEntity: existingVisit,
        requirements: existingVisit.requirements,
        customer: dealer.customer,
      );

      final customerId =
          newCId ??
          (dealer.customer is CustomerEntity
              ? (dealer.customer as CustomerEntity).id
              : (int.tryParse(dealer.id.replaceAll(RegExp(r'[^\d]'), '')) ??
                    0));
      loadSurveyForms(customerId);
      refreshRequirements();
      return;
    }

    // Trường hợp mới bắt đầu check-in
    _sessionClientUuid = const Uuid().v4();
    _elapsedSeconds = 0;
    _startTimer();
    state = CheckInState(
      status: CheckInStatus.loaded,
      checkinData: initialCheckinData,
      checkinTime: localTime,
      liveVisitDuration: '00:00:00',
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
        return true;
      }
    }
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
        _setupVisitTimer(saved.checkinAt);
        state = state.copyWith(
          status: CheckInStatus.loaded,
          visitId: saved.id,
          visitEntity: saved,
          requirements: saved.requirements,
          checkinTime: localTime,
        );
        loadSurveyForms(saved.customerId);
        refreshRequirements();
        return true;
      }
    } catch (_) {}
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
    final minDurationMinutes = mobileRules?.visit.minDurationMinutes ?? 5;
    final minPhotos = mobileRules?.visit.minPhotos ?? 2;

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
      requirements: VisitRequirementsEntity(
        satisfied: false,
        secondsRemaining: minDurationMinutes * 60,
        photosMissing: minPhotos,
        missingForms: const [],
        blockers: [
          if (minDurationMinutes > 0)
            'Bạn cần ở lại thêm $minDurationMinutes phút nữa mới check-out được.',
          if (minPhotos > 0) 'Bạn cần chụp thêm $minPhotos ảnh nữa.',
        ],
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

    // 2. Kiểm tra cờ giả lập vị trí GPS nếu luật yêu cầu chặn
    if ((mobileRules?.visit.blockOnMockLocation ?? false) &&
        (isMockLocation == true)) {
      return 'Thiết bị đang sử dụng phần mềm giả lập vị trí GPS. Vui lòng tắt ứng dụng giả lập để check-in.';
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

            await db.enqueue(
              SyncQueueEntriesCompanion(
                entity: const drift.Value('visit'),
                op: const drift.Value('create'),
                clientUuid: drift.Value(_sessionClientUuid),
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

        _setupVisitTimer(offlineVisit.checkinAt);
        if (offlineVisit.requirements != null &&
            offlineVisit.requirements!.secondsRemaining > 0) {
          _targetDoneTime = DateTime.now().add(
            Duration(seconds: offlineVisit.requirements!.secondsRemaining),
          );
        }

        state = state.copyWith(
          visitId: offlineVisit.id,
          visitEntity: offlineVisit,
          requirements: offlineVisit.requirements,
          checkinTime: _formatTimeHHmmss(offlineVisit.checkinAt),
          status: CheckInStatus.loaded,
        );

        loadSurveyForms(customerId);
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
        final isFormsOk =
            updatedReq.missingForms.isEmpty || state.visitResult == 'closed';
        final isPhotosOk = updatedReq.photosMissing <= 0;
        final newSatisfied = isTimeOk && isFormsOk && isPhotosOk;

        List<String> newBlockers = List<String>.from(updatedReq.blockers);
        if (newSec <= 0) {
          newBlockers.removeWhere(
            (b) =>
                b.toLowerCase().contains('thời gian') ||
                b.toLowerCase().contains('giây') ||
                b.toLowerCase().contains('phút') ||
                b.toLowerCase().contains('ở lại thêm'),
          );
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
  Future<(bool, String?)> uploadPhoto(
    File file, {
    String photoType = 'other',
    double? lat,
    double? lng,
  }) async {
    if (state.visitId == 0) {
      return (false, 'Chưa có lượt viếng thăm hợp lệ');
    }
    state = state.copyWith(isUploadingPhoto: true);

    // Nếu phiên hiện tại là ngoại tuyến (visitId < 0) -> Lưu ảnh ngoại tuyến ngay
    if (state.visitId < 0) {
      return _savePhotoOffline(
        file: file,
        photoType: photoType,
        lat: lat,
        lng: lng,
      );
    }

    try {
      final photo = await uploadVisitPhotoUseCase(
        visitId: state.visitId,
        file: file,
        photoType: photoType,
        takenAt: DateTime.now(),
        lat: lat,
        lng: lng,
      );

      final updatedPhotos = List<VisitPhotoEntity>.from(state.photos)
        ..add(photo);
      var currentReq = state.requirements;
      if (currentReq != null && !photo.duplicate) {
        final newPhotosMissing = math.max(0, currentReq.photosMissing - 1);
        final isTimeOk =
            currentReq.secondsRemaining <= 0 || state.visitResult == 'closed';
        final isFormsOk =
            currentReq.missingForms.isEmpty || state.visitResult == 'closed';
        final isPhotosOk = newPhotosMissing <= 0;
        final newSatisfied = isTimeOk && isFormsOk && isPhotosOk;

        List<String> newBlockers = List<String>.from(currentReq.blockers);
        if (newPhotosMissing <= 0) {
          newBlockers.removeWhere(
            (b) =>
                b.toLowerCase().contains('ảnh') ||
                b.toLowerCase().contains('chụp'),
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

      await refreshRequirements();

      if (photo.duplicate) {
        return (
          true,
          'Ảnh này đã có trong lượt viếng thăm, không thêm gì thêm.',
        );
      }
      return (true, null);
    } catch (e) {
      if (_isNetworkError(e)) {
        return _savePhotoOffline(
          file: file,
          photoType: photoType,
          lat: lat,
          lng: lng,
        );
      }
      state = state.copyWith(isUploadingPhoto: false);
      final msg = e
          .toString()
          .replaceAll('ServerException: ', '')
          .replaceAll('AppException: ', '');
      return (false, msg);
    }
  }

  Future<(bool, String?)> _savePhotoOffline({
    required File file,
    required String photoType,
    double? lat,
    double? lng,
  }) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final offlineDir = Directory(
        p.join(appDocDir.path, 'offline_visit_photos'),
      );
      if (!await offlineDir.exists()) {
        await offlineDir.create(recursive: true);
      }
      final fileName =
          'visit_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final persistentFile = await file.copy(p.join(offlineDir.path, fileName));

      if (ref != null) {
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

        await db.enqueue(
          SyncQueueEntriesCompanion(
            entity: const drift.Value('visit_photo'),
            op: const drift.Value('upload'),
            clientUuid: drift.Value(const Uuid().v4()),
            parentUuid: drift.Value(_sessionClientUuid),
            localPath: drift.Value(persistentFile.path),
            payload: drift.Value(jsonEncode(payload)),
            state: const drift.Value('pending'),
            createdAt: drift.Value(nowMs),
            createdElapsed: drift.Value(SystemClock.nowMonotonicMs),
            bootId: drift.Value(SystemClock.bootId),
            attempts: const drift.Value(0),
          ),
        );
      }

      final photo = VisitPhotoEntity(
        id: -DateTime.now().millisecondsSinceEpoch,
        token: '',
        url: persistentFile.path,
        photoType: photoType,
        photoTypeLabel: photoType == 'display'
            ? 'Ảnh trưng bày'
            : (photoType == 'store_front' ? 'Mặt tiền' : 'Ảnh chụp'),
        photoTypeColor: 'primary',
        takenAt: DateTime.now().toIso8601String(),
        localPath: persistentFile.path,
      );

      final updatedPhotos = List<VisitPhotoEntity>.from(state.photos)
        ..add(photo);
      var currentReq = state.requirements;
      if (currentReq != null) {
        final newPhotosMissing = math.max(0, currentReq.photosMissing - 1);
        final isTimeOk =
            currentReq.secondsRemaining <= 0 || state.visitResult == 'closed';
        final isFormsOk =
            currentReq.missingForms.isEmpty || state.visitResult == 'closed';
        final isPhotosOk = newPhotosMissing <= 0;
        final newSatisfied = isTimeOk && isFormsOk && isPhotosOk;

        List<String> newBlockers = List<String>.from(currentReq.blockers);
        if (newPhotosMissing <= 0) {
          newBlockers.removeWhere(
            (b) =>
                b.toLowerCase().contains('ảnh') ||
                b.toLowerCase().contains('chụp'),
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

      return (
        true,
        'Đã lưu ảnh ngoại tuyến trên máy. Ảnh sẽ tự động tải lên khi có mạng lại.',
      );
    } catch (err) {
      state = state.copyWith(isUploadingPhoto: false);
      return (
        false,
        'Không thể lưu ảnh trên máy: ${StringUtils.formatUserFriendlyError(err)}',
      );
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
      final msg = e
          .toString()
          .replaceAll('ServerException: ', '')
          .replaceAll('AppException: ', '');
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
        _targetDoneTime = DateTime.now().add(
          Duration(seconds: req.secondsRemaining),
        );
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
      state = state.copyWith(visitResult: result, requirements: currentReq);
      refreshRequirements(visitResult: result);
    }
  }

  /// Ghi chú lý do đóng cửa
  void setClosedNote(String note) {
    state = state.copyWith(closedNote: note);
  }

  /// Thực hiện check-out (§7) hoặc chuyển ngoại tuyến khi mất mạng
  Future<(bool, String?)> checkout({
    double? lat,
    double? lng,
    double? accuracyM,
    int? allowedRadiusMeters,
    bool? requireGeofence,
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
      }
    }

    state = state.copyWith(status: CheckInStatus.checkingOut);
    final request = CheckoutRequestModel(
      visitResult: state.visitResult,
      closedNote: state.visitResult == 'closed' ? state.closedNote : null,
      lat: lat,
      lng: lng,
      accuracyM: accuracyM,
      clientTime: DateTime.now().toIso8601String(),
      clientBootId: SystemClock.bootId,
    );

    // Nếu phiên bắt đầu ngoại tuyến (visitId < 0) -> Check-out offline ngay
    if (state.visitId < 0) {
      return _checkoutOffline(request: request, lat: lat, lng: lng);
    }

    try {
      await checkoutUseCase(visitId: state.visitId, request: request);

      _visitTimer?.cancel();
      state = state.copyWith(status: CheckInStatus.checkedOut);
      if (ref != null) {
        try {
          ref!.read(routeViewModelProvider.notifier).checkProximitySuggestion(
                userLat: lat,
                userLng: lng,
              );
        } catch (_) {}
      }
      return (true, null);
    } catch (e) {
      final rawMsg = e.toString().toLowerCase();
      // Nếu server trả về 422 "đã check-out rồi" / "đã đóng" thì coi là thành công (§9)
      if (rawMsg.contains('đã check-out rồi') ||
          rawMsg.contains('đã check out') ||
          rawMsg.contains('đã checkout') ||
          rawMsg.contains('đã đóng') ||
          rawMsg.contains('already checked out') ||
          rawMsg.contains('already closed')) {
        _visitTimer?.cancel();
        await visitRepository.clearActiveVisit();
        if (ref != null) {
          try {
            ref!.read(routeViewModelProvider.notifier).setActiveVisit(null);
            ref!
                .read(routeViewModelProvider.notifier)
                .loadRouteDetail(isRefresh: true);
          } catch (_) {}
        }
        state = state.copyWith(status: CheckInStatus.checkedOut);
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
      state = state.copyWith(
        status: CheckInStatus.checkedOut,
        visitEntity: completedVisit,
      );
      if (ref != null) {
        try {
          ref!.read(routeViewModelProvider.notifier).checkProximitySuggestion(
                userLat: lat,
                userLng: lng,
              );
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
          // Xoá các file ảnh chụp offline trên ổ đĩa
          final photoPaths = await db.getPendingVisitPhotoPaths(clientUuid);
          for (final path in photoPaths) {
            try {
              final f = File(path);
              if (f.existsSync()) await f.delete();
            } catch (_) {}
          }
          // Xoá toàn bộ tác vụ pending/sending của lượt này (create visit, upload ảnh, checkout)
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
    super.dispose();
  }
}
