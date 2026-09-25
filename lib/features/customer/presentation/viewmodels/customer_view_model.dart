import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/map/goong_providers.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../route/data/services/route_api_service.dart';
import '../../../route/presentation/viewmodels/route_view_model.dart';
import '../../data/repositories/customer_repository_impl.dart';
import '../../domain/entities/customer_dynamic_column.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/customer_meta_entity.dart';
import '../../domain/repositories/customer_repository.dart';

enum CustomerFilterTab {
  all,
  pendingSync,
  today,
  visited,
  pending,
}

class CustomerState {
  final List<CustomerEntity> allCustomers;
  final List<CustomerDynamicColumn> dynamicColumns;
  final CustomerMetaData meta;
  final String searchQuery;
  final CustomerFilterTab selectedTab;
  final String? selectedRoute;
  final List<String> assignedRoutes;
  final String? selectedCustomerType;
  final String? selectedChannel;
  final bool isLoading;
  final String? errorMessage;
  final bool isSortedByDistance;

  const CustomerState({
    this.allCustomers = const [],
    this.dynamicColumns = const [],
    this.meta = const CustomerMetaData(),
    this.searchQuery = '',
    this.selectedTab = CustomerFilterTab.all,
    this.selectedRoute,
    this.assignedRoutes = const [],
    this.selectedCustomerType,
    this.selectedChannel,
    this.isLoading = false,
    this.errorMessage,
    this.isSortedByDistance = false,
  });

  CustomerState copyWith({
    List<CustomerEntity>? allCustomers,
    List<CustomerDynamicColumn>? dynamicColumns,
    CustomerMetaData? meta,
    String? searchQuery,
    CustomerFilterTab? selectedTab,
    String? selectedRoute,
    bool clearRoute = false,
    List<String>? assignedRoutes,
    String? selectedCustomerType,
    bool clearCustomerType = false,
    String? selectedChannel,
    bool clearChannel = false,
    bool? isLoading,
    String? errorMessage,
    bool? isSortedByDistance,
  }) {
    return CustomerState(
      allCustomers: allCustomers ?? this.allCustomers,
      dynamicColumns: dynamicColumns ?? this.dynamicColumns,
      meta: meta ?? this.meta,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTab: selectedTab ?? this.selectedTab,
      selectedRoute: clearRoute ? null : (selectedRoute ?? this.selectedRoute),
      assignedRoutes: assignedRoutes ?? this.assignedRoutes,
      selectedCustomerType: clearCustomerType ? null : (selectedCustomerType ?? this.selectedCustomerType),
      selectedChannel: clearChannel ? null : (selectedChannel ?? this.selectedChannel),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSortedByDistance: isSortedByDistance ?? this.isSortedByDistance,
    );
  }

  int get totalCount => allCustomers.length;
  int get pendingSyncCount => allCustomers.where((c) => c.syncStatus == 'pending').length;
  int get todayCount => allCustomers.where((c) => c.isToday).length;
  int get visitedCount => allCustomers.where((c) => c.visitStatus == CustomerVisitStatus.visited).length;
  int get pendingCount => allCustomers.where((c) => c.visitStatus == CustomerVisitStatus.pending).length;

  int get activeFiltersCount {
    int count = 0;
    if (selectedTab != CustomerFilterTab.all) count++;
    if (selectedRoute != null && selectedRoute != 'Tất cả tuyến') count++;
    if (selectedCustomerType != null && selectedCustomerType != 'Tất cả loại') count++;
    if (selectedChannel != null && selectedChannel != 'Tất cả kênh') count++;
    return count;
  }

  List<String> get availableRoutes {
    final set = <String>{'Tất cả tuyến'};
    // 1. Tuyến được giao cho nhân viên thị trường (GET /dms/routes/mine)
    for (final r in assignedRoutes) {
      final trimmed = r.trim();
      if (!CustomerEntity.isInvalidOrProvinceRoute(trimmed)) {
        set.add(trimmed);
      }
    }
    // 2. Tuyến thực tế của khách hàng
    for (final c in allCustomers) {
      if (c.routes.isNotEmpty) {
        for (final r in c.routes) {
          final trimmed = r.trim();
          if (!CustomerEntity.isInvalidOrProvinceRoute(trimmed, provinceName: c.provinceName)) {
            set.add(trimmed);
          }
        }
      } else if (!CustomerEntity.isInvalidOrProvinceRoute(c.route, provinceName: c.provinceName)) {
        set.add(c.route.trim());
      }
    }
    return set.toList();
  }

  List<String> get availableCustomerTypes {
    final set = <String>{'Tất cả loại'};
    for (final ct in meta.customerTypes) {
      if (ct.name.trim().isNotEmpty) set.add(ct.name.trim());
    }
    for (final c in allCustomers) {
      if (c.type.trim().isNotEmpty) set.add(c.type.trim());
    }
    return set.toList();
  }

  List<String> get availableChannels {
    final set = <String>{'Tất cả kênh'};
    for (final ch in meta.channels) {
      if (ch.name.trim().isNotEmpty) set.add(ch.name.trim());
    }
    for (final c in allCustomers) {
      if (c.channelName != null && c.channelName!.trim().isNotEmpty) {
        set.add(c.channelName!.trim());
      }
    }
    return set.toList();
  }
}

final customerViewModelProvider =
    StateNotifierProvider.autoDispose<CustomerViewModel, CustomerState>((ref) {
  final repository = ref.read(customerRepositoryProvider);
  final routeApiService = ref.read(routeApiServiceProvider);
  return CustomerViewModel(repository, routeApiService: routeApiService);
});

class CustomerViewModel extends StateNotifier<CustomerState> {
  final CustomerRepository _repository;
  final RouteApiService? routeApiService;

  CustomerViewModel(
    this._repository, {
    this.routeApiService,
  }) : super(const CustomerState()) {
    loadCustomers();
  }

  Future<void> loadCustomers({bool isRefresh = false}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final customers = await _repository.getCustomers(
        forceRefresh: isRefresh,
        query: state.searchQuery.isNotEmpty ? state.searchQuery : null,
      );
      final meta = await _repository.getCustomerMeta(forceRefresh: isRefresh);

      List<String> assignedRouteNames = [];
      final routeMap = <int, String>{};
      if (routeApiService != null) {
        try {
          final myRoutes = await routeApiService!.getMyRoutes();
          for (final r in myRoutes) {
            final trimmed = r.name.trim();
            if (trimmed.isNotEmpty) {
              assignedRouteNames.add(trimmed);
              routeMap[r.id] = trimmed;
            }
          }
        } catch (_) {}
      }

      final resolvedCustomers = customers.map((c) {
        final cleanRoutes = c.routes
            .where((r) => !CustomerEntity.isInvalidOrProvinceRoute(r, provinceName: c.provinceName))
            .toList();
        final hasValidRoutes = cleanRoutes.isNotEmpty;

        if (!hasValidRoutes && c.routeIds.isNotEmpty && routeMap.isNotEmpty) {
          final mappedNames = c.routeIds.map((id) => routeMap[id]).whereType<String>().toList();
          if (mappedNames.isNotEmpty) {
            return c.copyWith(
              routes: mappedNames,
              route: mappedNames.join(', '),
            );
          }
        }
        if (!hasValidRoutes) {
          final isRouteClean = !CustomerEntity.isInvalidOrProvinceRoute(c.route, provinceName: c.provinceName);
          return c.copyWith(
            routes: isRouteClean ? [c.route] : const [],
            route: isRouteClean ? c.route : 'Chưa phân tuyến',
          );
        }
        return c.copyWith(
          routes: cleanRoutes,
          route: cleanRoutes.join(', '),
        );
      }).toList();

      state = state.copyWith(
        allCustomers: resolvedCustomers,
        assignedRoutes: assignedRouteNames,
        dynamicColumns: meta.dynamicColumns.isNotEmpty ? meta.dynamicColumns : state.dynamicColumns,
        meta: meta,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tải danh sách điểm bán: ${e.toString()}',
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void selectTab(CustomerFilterTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  void selectRoute(String? route) {
    state = state.copyWith(selectedRoute: route, clearRoute: route == null);
  }

  void selectCustomerType(String? type) {
    state = state.copyWith(selectedCustomerType: type, clearCustomerType: type == null);
  }

  void selectChannel(String? channel) {
    state = state.copyWith(selectedChannel: channel, clearChannel: channel == null);
  }

  void resetFilters() {
    state = state.copyWith(
      selectedTab: CustomerFilterTab.all,
      clearRoute: true,
      clearCustomerType: true,
      clearChannel: true,
    );
  }

  void toggleSortByDistance([bool? value]) {
    state = state.copyWith(
      isSortedByDistance: value ?? !state.isSortedByDistance,
    );
  }

  Future<void> updateCustomer(int id, Map<String, dynamic> changes) async {
    try {
      final updated = await _repository.updateCustomer(id: id, changes: changes);
      final list = List<CustomerEntity>.from(state.allCustomers);
      final index = list.indexWhere((c) => c.id == id);
      if (index != -1) {
        list[index] = updated;
        state = state.copyWith(allCustomers: list);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deletePendingCustomer(String clientUuid) async {
    try {
      final success = await _repository.deletePendingCustomer(clientUuid);
      if (success) {
        final list = List<CustomerEntity>.from(state.allCustomers)
          ..removeWhere((c) => c.clientUuid == clientUuid);
        state = state.copyWith(allCustomers: list);
      }
      return success;
    } catch (_) {
      return false;
    }
  }
}

/// Provider trả về danh sách khách hàng đã được lọc và sắp xếp theo vị trí gần nhất
final filteredCustomersProvider = Provider.autoDispose<List<CustomerWithDistance>>((ref) {
  final state = ref.watch(customerViewModelProvider);
  final livePoint = ref.watch(currentPointProvider).value;

  // 1. Lọc theo tab
  var list = state.allCustomers.where((c) {
    switch (state.selectedTab) {
      case CustomerFilterTab.all:
        return true;
      case CustomerFilterTab.pendingSync:
        return c.syncStatus == 'pending';
      case CustomerFilterTab.today:
        return c.isToday;
      case CustomerFilterTab.visited:
        return c.visitStatus == CustomerVisitStatus.visited;
      case CustomerFilterTab.pending:
        return c.visitStatus == CustomerVisitStatus.pending;
    }
  }).toList();

  // 2. Lọc theo Tuyến khách hàng
  if (state.selectedRoute != null && state.selectedRoute != 'Tất cả tuyến') {
    list = list.where((c) {
      if (c.routes.isNotEmpty) {
        return c.routes.any((r) => r.trim() == state.selectedRoute) || c.route.trim() == state.selectedRoute;
      }
      return c.route.trim() == state.selectedRoute;
    }).toList();
  }

  // 3. Lọc theo Loại khách hàng
  if (state.selectedCustomerType != null && state.selectedCustomerType != 'Tất cả loại') {
    list = list.where((c) => c.type == state.selectedCustomerType).toList();
  }

  // 4. Lọc theo Kênh bán hàng
  if (state.selectedChannel != null && state.selectedChannel != 'Tất cả kênh') {
    list = list.where((c) => c.channelName == state.selectedChannel).toList();
  }

  // 5. Lọc theo từ khóa tìm kiếm (hỗ trợ không dấu §7.4)
  final rawQuery = state.searchQuery.trim();
  if (rawQuery.isNotEmpty) {
    final query = StringUtils.toUnaccentedLower(rawQuery);
    list = list.where((c) {
      return StringUtils.toUnaccentedLower(c.name).contains(query) ||
          c.code.toLowerCase().contains(query) ||
          c.phone.replaceAll(' ', '').contains(query) ||
          StringUtils.toUnaccentedLower(c.address).contains(query) ||
          StringUtils.toUnaccentedLower(c.route).contains(query) ||
          c.routes.any((r) => StringUtils.toUnaccentedLower(r).contains(query)) ||
          (c.contactTitle != null && StringUtils.toUnaccentedLower(c.contactTitle).contains(query));
    }).toList();
  }

  // 3. Tính khoảng cách và sắp xếp từ gần đến xa khi bật isSortedByDistance
  final result = list.map((customer) {
    double? distance;
    if (livePoint != null && customer.hasCoordinates) {
      distance = Geolocator.distanceBetween(
        livePoint.lat,
        livePoint.lng,
        customer.lat!,
        customer.lng!,
      );
    }
    return CustomerWithDistance(customer: customer, distanceMeters: distance);
  }).toList();

  if (state.isSortedByDistance && livePoint != null) {
    result.sort((a, b) {
      if (a.distanceMeters == null && b.distanceMeters == null) return 0;
      if (a.distanceMeters == null) return 1;
      if (b.distanceMeters == null) return -1;
      return a.distanceMeters!.compareTo(b.distanceMeters!);
    });
  }

  return result;
});

class CustomerWithDistance {
  final CustomerEntity customer;
  final double? distanceMeters;
  final String formattedDistance;

  CustomerWithDistance({
    required this.customer,
    this.distanceMeters,
  }) : formattedDistance = _formatDistance(distanceMeters);

  static String _formatDistance(double? d) {
    if (d == null) return '—';
    if (d < 1000) {
      return '${d.round()} m';
    }
    return '${(d / 1000).toStringAsFixed(1)} km';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerWithDistance &&
          runtimeType == other.runtimeType &&
          customer == other.customer &&
          distanceMeters == other.distanceMeters;

  @override
  int get hashCode => customer.hashCode ^ (distanceMeters?.hashCode ?? 0);
}
