import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/customer_dynamic_column.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/repositories/customer_repository.dart';
import '../models/customer_model.dart';
import '../services/customer_api_service.dart';

final customerApiServiceProvider = Provider<CustomerApiService>((ref) {
  return CustomerApiService(ref.read(apiClientProvider));
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepositoryImpl(ref.read(customerApiServiceProvider));
});

class CustomerRepositoryImpl implements CustomerRepository {
  final CustomerApiService _apiService;
  List<CustomerEntity> _cachedCustomers = [];
  List<CustomerDynamicColumn> _cachedColumns = [];

  CustomerRepositoryImpl(this._apiService);

  @override
  Future<List<CustomerEntity>> getCustomers({
    int page = 1,
    int perPage = 200,
    String? query,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedCustomers.isNotEmpty && (query == null || query.isEmpty)) {
      return _cachedCustomers;
    }

    try {
      final response = await _apiService.getMineCustomers(
        page: page,
        perPage: perPage,
        q: query,
        context: 'mobile',
      );

      _cachedColumns = response.dynamicColumns;

      if (response.data.isNotEmpty) {
        if (query == null || query.isEmpty) {
          _cachedCustomers = response.data;
        }
        return response.data;
      }
    } catch (_) {
      // If API fails (e.g. offline, 403 prod not assigned yet), gracefully use fallback cache/mock
    }

    if (_cachedCustomers.isEmpty) {
      _cachedCustomers = List.from(kMockCustomers);
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      return _cachedCustomers.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.code.toLowerCase().contains(q) ||
            c.phone.replaceAll(' ', '').contains(q) ||
            c.address.toLowerCase().contains(q);
      }).toList();
    }

    return _cachedCustomers;
  }

  @override
  Future<List<CustomerDynamicColumn>> getDynamicColumns() async {
    if (_cachedColumns.isNotEmpty) {
      return _cachedColumns;
    }
    try {
      final meta = await _apiService.getCustomerMeta(context: 'mobile');
      if (meta['dynamicColumns'] is List) {
        _cachedColumns = (meta['dynamicColumns'] as List)
            .whereType<Map<String, dynamic>>()
            .map((e) => CustomerDynamicColumn.fromJson(e))
            .toList();
      }
    } catch (_) {}
    return _cachedColumns;
  }

  @override
  Future<CustomerEntity> updateCustomer({
    required int id,
    required Map<String, dynamic> changes,
  }) async {
    try {
      await _apiService.updateCustomer(id, changes);
    } catch (_) {
      // Allow local update if network is unavailable
    }

    // Update in cached list
    final index = _cachedCustomers.indexWhere((c) => c.id == id);
    if (index != -1) {
      final current = _cachedCustomers[index];
      final updated = current.copyWith(
        contactPerson: changes['contact_name']?.toString() ?? current.contactPerson,
        contactTitle: changes['contact_title']?.toString() ?? current.contactTitle,
        phone: changes['phone']?.toString() ?? current.phone,
        address: changes['address']?.toString() ?? current.address,
        lat: changes['lat'] is num ? (changes['lat'] as num).toDouble() : current.lat,
        lng: changes['lng'] is num ? (changes['lng'] as num).toDouble() : current.lng,
      );
      _cachedCustomers[index] = updated;
      return updated;
    }

    throw Exception('Không tìm thấy khách hàng ID: $id');
  }

  @override
  Future<bool> deleteCustomer(int id) async {
    try {
      await _apiService.deleteCustomer(id);
    } catch (_) {}

    _cachedCustomers.removeWhere((c) => c.id == id);
    return true;
  }
}
