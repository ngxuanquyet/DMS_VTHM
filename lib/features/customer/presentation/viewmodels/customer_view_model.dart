import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/map/goong_providers.dart';
import '../../data/models/customer_model.dart';
import '../../domain/entities/customer_entity.dart';

enum CustomerFilterTab {
  all,
  today,
  visited,
  pending,
}

class CustomerState {
  final List<CustomerEntity> allCustomers;
  final String searchQuery;
  final CustomerFilterTab selectedTab;
  final bool isLoading;

  const CustomerState({
    this.allCustomers = kMockCustomers,
    this.searchQuery = '',
    this.selectedTab = CustomerFilterTab.all,
    this.isLoading = false,
  });

  CustomerState copyWith({
    List<CustomerEntity>? allCustomers,
    String? searchQuery,
    CustomerFilterTab? selectedTab,
    bool? isLoading,
  }) {
    return CustomerState(
      allCustomers: allCustomers ?? this.allCustomers,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTab: selectedTab ?? this.selectedTab,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  int get totalCount => allCustomers.length;
  int get todayCount => allCustomers.where((c) => c.isToday).length;
  int get visitedCount => allCustomers.where((c) => c.visitStatus == CustomerVisitStatus.visited).length;
  int get pendingCount => allCustomers.where((c) => c.visitStatus == CustomerVisitStatus.pending).length;
}

final customerViewModelProvider =
    StateNotifierProvider.autoDispose<CustomerViewModel, CustomerState>((ref) {
  return CustomerViewModel();
});

class CustomerViewModel extends StateNotifier<CustomerState> {
  CustomerViewModel() : super(const CustomerState());

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void selectTab(CustomerFilterTab tab) {
    state = state.copyWith(selectedTab: tab);
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
          c.route.toLowerCase().contains(query);
    }).toList();
  }

  // 3. Tính khoảng cách và sắp xếp từ gần đến xa
  final result = list.map((customer) {
    double? distance;
    if (livePoint != null) {
      distance = Geolocator.distanceBetween(
        livePoint.lat,
        livePoint.lng,
        customer.lat,
        customer.lng,
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
