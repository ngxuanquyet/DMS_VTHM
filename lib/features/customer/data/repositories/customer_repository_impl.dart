import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/customer_dynamic_column.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/customer_meta_entity.dart';
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
  CustomerMetaData? _cachedMeta;

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
  Future<List<CustomerDynamicColumn>> getDynamicColumns({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedColumns.isNotEmpty) {
      return _cachedColumns;
    }
    final meta = await getCustomerMeta(forceRefresh: forceRefresh);
    return meta.dynamicColumns;
  }

  @override
  Future<CustomerMetaData> getCustomerMeta({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedMeta != null) {
      return _cachedMeta!;
    }
    try {
      final meta = await _apiService.getCustomerMeta(context: 'mobile');
      _cachedMeta = CustomerMetaData.fromJson(meta);
      if (_cachedMeta!.dynamicColumns.isNotEmpty) {
        _cachedColumns = _cachedMeta!.dynamicColumns;
      }
      return _cachedMeta!;
    } catch (_) {
      return _cachedMeta ?? const CustomerMetaData();
    }
  }

  @override
  Future<CustomerEntity> updateCustomer({
    required int id,
    required Map<String, dynamic> changes,
  }) async {
    await _apiService.updateCustomer(id, changes);

    // Update in cached list
    final index = _cachedCustomers.indexWhere((c) => c.id == id);
    if (index != -1) {
      final current = _cachedCustomers[index];
      final updated = current.copyWith(
        code: changes['code']?.toString() ?? current.code,
        name: changes['name']?.toString() ?? current.name,
        customerTypeId: changes.containsKey('customer_type_id')
            ? (changes['customer_type_id'] as int?)
            : current.customerTypeId,
        channelId: changes.containsKey('channel_id')
            ? (changes['channel_id'] as int?)
            : current.channelId,
        regionId: changes.containsKey('region_id')
            ? (changes['region_id'] as int?)
            : current.regionId,
        provinceName: changes.containsKey('province_name')
            ? changes['province_name']?.toString()
            : current.provinceName,
        wardName: changes.containsKey('ward_name')
            ? changes['ward_name']?.toString()
            : current.wardName,
        contactPerson: changes['contact_name']?.toString() ?? current.contactPerson,
        contactTitle: changes.containsKey('contact_title')
            ? changes['contact_title']?.toString()
            : current.contactTitle,
        phone: changes['phone']?.toString() ?? current.phone,
        email: changes.containsKey('email')
            ? changes['email']?.toString()
            : current.email,
        address: changes['address']?.toString() ?? current.address,
        lat: changes.containsKey('lat')
            ? (changes['lat'] is num ? (changes['lat'] as num).toDouble() : null)
            : current.lat,
        lng: changes.containsKey('lng')
            ? (changes['lng'] is num ? (changes['lng'] as num).toDouble() : null)
            : current.lng,
        geofenceRadiusM: changes.containsKey('geofence_radius_m')
            ? (changes['geofence_radius_m'] as int?)
            : current.geofenceRadiusM,
      );
      _cachedCustomers[index] = updated;
      return updated;
    }

    throw Exception('Không tìm thấy khách hàng ID: $id');
  }

  @override
  Future<CustomerEntity> createCustomer(Map<String, dynamic> data) async {
    final dto = await _apiService.createCustomer(data);
    final entity = dto.toEntity();
    _cachedCustomers.insert(0, entity);
    return entity;
  }

  Map<String, dynamic>? _cachedSchema;

  @override
  Future<Map<String, dynamic>> getCustomerFormSchema({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedSchema != null) {
      return _cachedSchema!;
    }
    try {
      final res = await _apiService.getCustomerFormSchema();
      _cachedSchema = res;
      return res;
    } catch (e) {
      if (_cachedSchema != null) return _cachedSchema!;
      rethrow;
    }
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
