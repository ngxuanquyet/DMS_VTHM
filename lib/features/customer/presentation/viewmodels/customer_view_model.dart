import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/map/goong_providers.dart';
import '../../data/repositories/customer_repository_impl.dart';
import '../../domain/entities/customer_dynamic_column.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/customer_meta_entity.dart';
import '../../domain/repositories/customer_repository.dart';

enum CustomerFilterTab {
  all,
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
  final bool isLoading;
  final String? errorMessage;

  const CustomerState({
    this.allCustomers = const [],
    this.dynamicColumns = const [],
    this.meta = const CustomerMetaData(),
    this.searchQuery = '',
    this.selectedTab = CustomerFilterTab.all,
    this.isLoading = false,
    this.errorMessage,
  });

  CustomerState copyWith({
    List<CustomerEntity>? allCustomers,
    List<CustomerDynamicColumn>? dynamicColumns,
    CustomerMetaData? meta,
    String? searchQuery,
    CustomerFilterTab? selectedTab,
    bool? isLoading,
    String? errorMessage,
  }) {
    return CustomerState(
      allCustomers: allCustomers ?? this.allCustomers,
      dynamicColumns: dynamicColumns ?? this.dynamicColumns,
      meta: meta ?? this.meta,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTab: selectedTab ?? this.selectedTab,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  int get totalCount => allCustomers.length;
  int get todayCount => allCustomers.where((c) => c.isToday).length;
  int get visitedCount => allCustomers.where((c) => c.visitStatus == CustomerVisitStatus.visited).length;
  int get pendingCount => allCustomers.where((c) => c.visitStatus == CustomerVisitStatus.pending).length;
}

final customerViewModelProvider =
    StateNotifierProvider.autoDispose<CustomerViewModel, CustomerState>((ref) {
  final repository = ref.read(customerRepositoryProvider);
  return CustomerViewModel(repository);
});

class CustomerViewModel extends StateNotifier<CustomerState> {
  final CustomerRepository _repository;

  CustomerViewModel(this._repository) : super(const CustomerState()) {
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

      state = state.copyWith(
        allCustomers: customers,
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
      case CustomerFilterTab.today:
        return c.isToday;
      case CustomerFilterTab.visited:
        return c.visitStatus == CustomerVisitStatus.visited;
      case CustomerFilterTab.pending:
        return c.visitStatus == CustomerVisitStatus.pending;
    }
  }).toList();

  // 2. Lọc theo từ khóa tìm kiếm
  final query = state.searchQuery.trim().toLowerCase();
  if (query.isNotEmpty) {
    list = list.where((c) {
      return c.name.toLowerCase().contains(query) ||
          c.code.toLowerCase().contains(query) ||
          c.phone.replaceAll(' ', '').contains(query) ||
          c.address.toLowerCase().contains(query) ||
          c.route.toLowerCase().contains(query) ||
          (c.contactTitle != null && c.contactTitle!.toLowerCase().contains(query));
    }).toList();
  }

  // 3. Tính khoảng cách và sắp xếp từ gần đến xa
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

  if (livePoint != null) {
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

  const CustomerWithDistance({
    required this.customer,
    this.distanceMeters,
  });

  String get formattedDistance {
    if (distanceMeters == null) return '—';
    if (distanceMeters! < 1000) {
      return '${distanceMeters!.round()} m';
    }
    return '${(distanceMeters! / 1000).toStringAsFixed(1)} km';
  }
}
