import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/sync/sync_service.dart';
import '../../domain/entities/customer_dynamic_column.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/customer_meta_entity.dart';
import '../../domain/repositories/customer_repository.dart';
import '../datasources/customer_local_data_source.dart';
import '../services/customer_api_service.dart';
import '../utils/customer_payload_helper.dart';

final customerApiServiceProvider = Provider<CustomerApiService>((ref) {
  return CustomerApiService(ref.read(apiClientProvider));
});

final customerLocalDataSourceProvider = Provider<CustomerLocalDataSource>((ref) {
  final db = ref.read(appDatabaseProvider);
  return CustomerLocalDataSource(db);
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepositoryImpl(
    ref.read(customerApiServiceProvider),
    ref.read(customerLocalDataSourceProvider),
    ref.read(syncServiceProvider),
    ref,
  );
});

class CustomerRepositoryImpl implements CustomerRepository {
  final CustomerApiService _apiService;
  final CustomerLocalDataSource _localDataSource;
  final SyncService _syncService;
  final Ref? _ref;
  final bool Function()? _isOnlineChecker;

  List<CustomerEntity> _cachedCustomers = [];
  List<CustomerDynamicColumn> _cachedColumns = [];
  CustomerMetaData? _cachedMeta;

  CustomerRepositoryImpl(
    this._apiService,
    this._localDataSource,
    this._syncService, [
    this._ref,
    this._isOnlineChecker,
  ]);

  bool get _isOnline => _isOnlineChecker != null
      ? _isOnlineChecker()
      : (_ref?.read(connectivityProvider).isOnline ?? true);

  @override
  Future<List<CustomerEntity>> getCustomers({
    int page = 1,
    int perPage = 200,
    String? query,
    bool forceRefresh = false,
  }) async {
    // 1. Khi thiết bị ngoại tuyến (không có mạng) -> tải trực tiếp từ SQLite cục bộ
    if (!_isOnline) {
      final localList = await _localDataSource.getLocalCustomers(query: query);
      if (localList.isNotEmpty) {
        _cachedCustomers = localList;
        return localList;
      }
      if (_cachedCustomers.isNotEmpty) {
        return _cachedCustomers;
      }
      throw AppException('Không có kết nối mạng và chưa có dữ liệu điểm bán lưu trên máy');
    }

    // 2. Khi thiết bị trực tuyến (Online):
    // Nếu không bắt buộc tải mới (forceRefresh = false) và đã có sẵn dữ liệu cục bộ -> trả về ngay và đồng bộ ngầm
    if (!forceRefresh) {
      try {
        final localList = await _localDataSource.getLocalCustomers(query: query);
        if (localList.isNotEmpty) {
          _cachedCustomers = localList;
          // Kích hoạt làm mới và ghi đè cache ngầm từ máy chủ
          unawaited(_fetchRemoteAndCache(page, perPage, query));
          return localList;
        }
      } catch (_) {}
    }

    // 3. Tải từ API server khi forceRefresh = true hoặc khi SQLite chưa có dữ liệu
    try {
      final response = await _apiService.getMineCustomers(
        page: page,
        perPage: perPage,
        q: query,
        context: 'mobile',
      );

      _cachedColumns = response.dynamicColumns;

      // Lưu cache vào SQLite cục bộ (tự động ghi đè và dọn dẹp các khách hàng đã bị xóa trên server)
      await _localDataSource.cacheRemoteCustomers(
        response.data,
        reconcile: query == null || query.isEmpty,
      );

      // Đọc lại từ SQLite để gộp cả các khách hàng offline vừa tạo đang chờ đồng bộ
      final mergedList = await _localDataSource.getLocalCustomers(query: query);
      _cachedCustomers = mergedList;
      return _cachedCustomers;
    } catch (_) {
      // Khi API lỗi hoặc rớt mạng giữa chừng -> Sử dụng SQLite cục bộ đã lưu trước đó
      final localList = await _localDataSource.getLocalCustomers(query: query);
      if (localList.isNotEmpty) {
        _cachedCustomers = localList;
        return localList;
      }
      if (_cachedCustomers.isNotEmpty) {
        return _cachedCustomers;
      }
      rethrow;
    }
  }

  Future<void> _fetchRemoteAndCache(int page, int perPage, String? query) async {
    try {
      final response = await _apiService.getMineCustomers(
        page: page,
        perPage: perPage,
        q: query,
        context: 'mobile',
      );
      _cachedColumns = response.dynamicColumns;
      await _localDataSource.cacheRemoteCustomers(
        response.data,
        reconcile: query == null || query.isEmpty,
      );
      final mergedList = await _localDataSource.getLocalCustomers(query: query);
      _cachedCustomers = mergedList;
    } catch (_) {}
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

    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cachedJson = prefs.getString('cached_customer_meta');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
          _cachedMeta = CustomerMetaData.fromJson(decoded);
          if (_cachedMeta!.dynamicColumns.isNotEmpty) {
            _cachedColumns = _cachedMeta!.dynamicColumns;
          }
          unawaited(_refreshMetaInBackground());
          return _cachedMeta!;
        } catch (_) {}
      }
    }

    try {
      final meta = await _apiService.getCustomerMeta(context: 'mobile');
      if (meta.isNotEmpty) {
        _cachedMeta = CustomerMetaData.fromJson(meta);
        if (_cachedMeta!.dynamicColumns.isNotEmpty) {
          _cachedColumns = _cachedMeta!.dynamicColumns;
        }
        await prefs.setString('cached_customer_meta', jsonEncode(meta));
        return _cachedMeta!;
      }
    } catch (_) {
      if (_cachedMeta != null) return _cachedMeta!;
      final cachedJson = prefs.getString('cached_customer_meta');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
          _cachedMeta = CustomerMetaData.fromJson(decoded);
          return _cachedMeta!;
        } catch (_) {}
      }
    }

    return _cachedMeta ?? kDefaultCustomerMeta;
  }

  Future<void> _refreshMetaInBackground() async {
    try {
      final meta = await _apiService.getCustomerMeta(context: 'mobile');
      if (meta.isNotEmpty) {
        _cachedMeta = CustomerMetaData.fromJson(meta);
        if (_cachedMeta!.dynamicColumns.isNotEmpty) {
          _cachedColumns = _cachedMeta!.dynamicColumns;
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_customer_meta', jsonEncode(meta));
      }
    } catch (_) {}
  }

  @override
  Future<CustomerEntity> updateCustomer({
    required int id,
    required Map<String, dynamic> changes,
    String? clientUuid,
  }) async {
    // Nếu là bản ghi tạo offline (id <= 0 hoặc có clientUuid không bắt đầu bằng server_)
    final isLocalRecord = id <= 0 || (clientUuid != null && !clientUuid.startsWith('server_'));
    if (isLocalRecord) {
      String? targetUuid = clientUuid;
      if (targetUuid == null && id <= 0) {
        final found = _cachedCustomers.where((c) => c.id == id && c.clientUuid != null).firstOrNull;
        targetUuid = found?.clientUuid;
      }

      if (targetUuid != null) {
        final updated = await _localDataSource.updateCustomerOffline(targetUuid, changes);
        final index = _cachedCustomers.indexWhere((c) => c.clientUuid == targetUuid);
        if (index != -1) {
          _cachedCustomers[index] = updated;
        } else {
          _cachedCustomers.add(updated);
        }

        // Tự động kích hoạt đồng bộ lại ngay nếu thiết bị có kết nối mạng
        unawaited(_syncService.syncQueue());
        return updated;
      }
    }

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
        contactPerson: changes['contact_name']?.toString() ??
            changes['contact_person']?.toString() ??
            current.contactPerson,
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
    final isOnline = _isOnline;

    if (isOnline) {
      try {
        final cleanPayload = await _prepareCleanCustomerPayload(data);
        final dto = await _apiService.createCustomer(cleanPayload);

        final serverId = dto.id > 0 ? dto.id : 0;
        final serverCode = dto.code.isNotEmpty ? dto.code : '';

        if (serverId > 0) {
          final entity = _buildSyncedCustomerEntity(
            data: data,
            serverId: serverId,
            serverCode: serverCode,
            cleanPayload: cleanPayload,
          );

          await _localDataSource.cacheRemoteCustomers([entity]);
          _cachedCustomers.removeWhere((c) =>
              (entity.clientUuid != null && c.clientUuid == entity.clientUuid) ||
              (entity.id > 0 && c.id == entity.id));
          _cachedCustomers.insert(0, entity);
          return entity;
        }
      } catch (e) {
        debugPrint('[CustomerRepositoryImpl] Lỗi khi tạo online ($e)');
        // 🔴 Theo spec 30/09 §7: Lỗi 4xx (400 <= statusCode < 500, trừ 408/429) là hỏng vĩnh viễn (validate thất bại).
        // TUYỆT ĐỐI không fallback sang ghi offline để tránh tạo rác và làm tắc hàng đợi SyncQueue!
        if (e is AppException &&
            e.statusCode != null &&
            e.statusCode! >= 400 &&
            e.statusCode! < 500 &&
            e.statusCode != 408 &&
            e.statusCode != 429) {
          rethrow;
        }
      }
    }

    // 1. Ghi máy trước, sinh client_uuid lúc nhập (BB-1, BB-2)
    final localEntity = await _localDataSource.createCustomerOffline(data);
    _cachedCustomers.insert(0, localEntity);

    // 2. Kích hoạt tiến trình đồng bộ ngầm nếu có mạng (BB-1: Single Write Path)
    unawaited(_syncService.syncQueue());

    return localEntity;
  }

  Future<Map<String, dynamic>> _prepareCleanCustomerPayload(Map<String, dynamic> data) async {
    // 1. Tải ảnh lên server để lấy token nếu đang là đường dẫn cục bộ
    final resolvedTokens = <String>[];
    final rawTokens = data['photo_tokens'] ?? data['photo_token'] ?? data['photo_file_id'] ?? data['photo'];
    if (rawTokens is List) {
      for (final item in rawTokens) {
        final itemStr = item.toString().trim();
        if (itemStr.isEmpty) continue;
        if (itemStr.length == 32 && !itemStr.contains('/') && !itemStr.contains(r'\')) {
          resolvedTokens.add(itemStr);
        } else {
          try {
            final uploadRes = await _apiService.uploadCustomerPhoto(itemStr);
            if (uploadRes['token'] != null) {
              resolvedTokens.add(uploadRes['token'].toString().trim());
            }
          } catch (_) {}
        }
      }
    } else if (rawTokens != null) {
      final itemStr = rawTokens.toString().trim();
      if (itemStr.isNotEmpty) {
        if (itemStr.length == 32 && !itemStr.contains('/') && !itemStr.contains(r'\')) {
          resolvedTokens.add(itemStr);
        } else {
          try {
            final uploadRes = await _apiService.uploadCustomerPhoto(itemStr);
            if (uploadRes['token'] != null) {
              resolvedTokens.add(uploadRes['token'].toString().trim());
            }
          } catch (_) {}
        }
      }
    }

    // 2. Sử dụng CustomerPayloadHelper để xây dựng payload chuẩn 25 khoá gốc
    return CustomerPayloadHelper.buildCustomerApiPayload(
      sourceData: data,
      resolvedPhotoTokens: resolvedTokens.isNotEmpty ? resolvedTokens : null,
      isOfflineSync: false,
    );
  }

  CustomerEntity _buildSyncedCustomerEntity({
    required Map<String, dynamic> data,
    required int serverId,
    required String serverCode,
    required Map<String, dynamic> cleanPayload,
  }) {
    final name = (data['name'] ?? 'Điểm bán mới').toString().trim();
    final address = (data['address'] ?? '').toString().trim();
    final phone = (data['phone'] ?? '').toString().trim();
    final contactName = (data['contact_name'] ?? data['contact_person'] ?? data['contactPerson'] ?? '').toString().trim();
    final contactTitle = data['contact_title']?.toString().trim();
    final type = (data['type'] ?? data['customer_type_name'] ?? '').toString().trim();
    final route = (data['route'] ?? data['route_name'] ?? 'Tuyến mặc định').toString().trim();
    final routeIds = (cleanPayload['route_ids'] as List<int>?) ?? [];
    final clientUuid = cleanPayload['client_uuid']?.toString();
    final photoToken = cleanPayload['photo_token']?.toString();

    final regionId = cleanPayload['region_id'] is int
        ? cleanPayload['region_id'] as int
        : int.tryParse(cleanPayload['region_id']?.toString() ?? '') ?? 1;

    final customerTypeId = cleanPayload['customer_type_id'] is int
        ? cleanPayload['customer_type_id'] as int
        : int.tryParse(cleanPayload['customer_type_id']?.toString() ?? '');

    final channelId = cleanPayload['channel_id'] is int
        ? cleanPayload['channel_id'] as int
        : int.tryParse(cleanPayload['channel_id']?.toString() ?? '');

    final channelName = (data['channel_name'] ?? '').toString().trim();

    double? lat;
    if (cleanPayload['lat'] != null) lat = double.tryParse(cleanPayload['lat'].toString());
    double? lng;
    if (cleanPayload['lng'] != null) lng = double.tryParse(cleanPayload['lng'].toString());

    final now = DateTime.now();
    final clientTimeIso = '${now.toIso8601String()}+07:00';

    return CustomerEntity(
      id: serverId,
      code: serverCode,
      name: name,
      type: type,
      customerTypeId: customerTypeId,
      channelId: channelId,
      channelName: channelName.isNotEmpty ? channelName : null,
      regionId: regionId,
      route: route,
      routes: [route],
      routeIds: routeIds,
      address: address,
      contactPerson: contactName,
      contactTitle: contactTitle,
      phone: phone,
      lat: lat,
      lng: lng,
      status: 'active',
      approvalStatus: 'approved',
      syncStatus: 'synced',
      clientUuid: clientUuid,
      photoUrl: photoToken,
      photoUrls: photoToken != null ? [photoToken] : const [],
      createdAt: clientTimeIso,
      updatedAt: clientTimeIso,
    );
  }

  @override
  Future<CustomerEntity> getCustomerDetail(int id) async {
    try {
      final dto = await _apiService.getCustomerDetail(id);
      final entity = dto.toEntity();
      unawaited(_localDataSource.cacheRemoteCustomers([entity]));
      final index = _cachedCustomers.indexWhere((c) => c.id == id);
      if (index != -1) {
        _cachedCustomers[index] = entity;
      }
      return entity;
    } catch (_) {
      final index = _cachedCustomers.indexWhere((c) => c.id == id);
      if (index != -1) {
        return _cachedCustomers[index];
      }
      try {
        final localList = await _localDataSource.getLocalCustomers();
        return localList.firstWhere((c) => c.id == id);
      } catch (_) {}
      rethrow;
    }
  }

  Map<String, dynamic>? _cachedSchema;

  @override
  Future<Map<String, dynamic>> getCustomerFormSchema({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedSchema != null) {
      return _cachedSchema!;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final cachedJson = prefs.getString('cached_customer_form_schema');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          _cachedSchema = jsonDecode(cachedJson) as Map<String, dynamic>;
          unawaited(_refreshSchemaInBackground());
          return _cachedSchema!;
        } catch (_) {}
      }
    }

    try {
      final res = await _apiService.getCustomerFormSchema();
      _cachedSchema = res;
      await prefs.setString('cached_customer_form_schema', jsonEncode(res));
      return res;
    } catch (e) {
      if (_cachedSchema != null) return _cachedSchema!;
      final cachedJson = prefs.getString('cached_customer_form_schema');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          _cachedSchema = jsonDecode(cachedJson) as Map<String, dynamic>;
          return _cachedSchema!;
        } catch (_) {}
      }
      // Offline fallback: Trả về schema mặc định khi không có mạng và chưa từng lưu cache
      _cachedSchema = kDefaultCustomerFormSchema;
      return kDefaultCustomerFormSchema;
    }
  }

  Future<void> _refreshSchemaInBackground() async {
    try {
      final res = await _apiService.getCustomerFormSchema();
      _cachedSchema = res;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_customer_form_schema', jsonEncode(res));
    } catch (_) {}
  }

  @override
  Future<Map<String, dynamic>> uploadCustomerPhoto(String filePath) async {
    return _apiService.uploadCustomerPhoto(filePath);
  }

  @override
  Future<bool> deleteCustomer(int id) async {
    try {
      await _apiService.deleteCustomer(id);
    } catch (_) {}

    await _localDataSource.deleteCustomerLocal(id);
    _cachedCustomers.removeWhere((c) => c.id == id);
    return true;
  }

  @override
  Future<bool> deletePendingCustomer(String clientUuid) async {
    await _localDataSource.deletePendingCustomer(clientUuid);
    _cachedCustomers.removeWhere((c) => c.clientUuid == clientUuid);
    return true;
  }
}

/// Dữ liệu phân loại mặc định cho trường hợp chạy offline ngay từ lần cài đặt đầu tiên
const CustomerMetaData kDefaultCustomerMeta = CustomerMetaData(
  customerTypes: [
    CustomerCategoryItem(id: 1, code: 'DL', name: 'Đại lý', color: '#10B981'),
    CustomerCategoryItem(id: 2, code: 'C1', name: 'Đại lý C1', color: '#059669'),
    CustomerCategoryItem(id: 3, code: 'C2', name: 'Đại lý C2', color: '#047857'),
    CustomerCategoryItem(id: 4, code: 'NPP', name: 'Nhà phân phối', color: '#2563EB'),
    CustomerCategoryItem(id: 5, code: 'ST', name: 'Siêu thị / Tiện lợi', color: '#7C3AED'),
    CustomerCategoryItem(id: 6, code: 'BL', name: 'Điểm bán lẻ', color: '#D97706'),
    CustomerCategoryItem(id: 7, code: 'NM', name: 'Nhà máy / Cơ sở SX', color: '#4B5563'),
  ],
  channels: [
    CustomerCategoryItem(id: 1, code: 'GT', name: 'GT (Truyền thống)'),
    CustomerCategoryItem(id: 2, code: 'MT', name: 'MT (Hiện đại)'),
    CustomerCategoryItem(id: 3, code: 'KA', name: 'KA (Trọng điểm)'),
    CustomerCategoryItem(id: 4, code: 'HORECA', name: 'Horeca'),
  ],
  regions: [
    CustomerCategoryItem(id: 8, code: '08', name: '08 - Miền Trung'),
    CustomerCategoryItem(id: 62, code: '62', name: '62 - Vĩnh Phúc'),
    CustomerCategoryItem(id: 1, code: '01', name: '01 - Hà Nội'),
  ],
  provinces: [
    CustomerProvinceItem(provinceName: 'Tỉnh Vĩnh Phúc'),
    CustomerProvinceItem(provinceName: 'Thành phố Hà Nội'),
    CustomerProvinceItem(provinceName: 'Tỉnh Phú Thọ'),
    CustomerProvinceItem(provinceName: 'Tỉnh Thái Nguyên'),
  ],
  dynamicColumns: [],
);

/// Cấu hình biểu mẫu mặc định cho trường hợp chưa từng kết nối internet
const Map<String, dynamic> kDefaultCustomerFormSchema = {
  'data': {
    'form': {
      'name': 'Hồ sơ điểm bán',
      'code': 'customer_form',
    },
    'version': '1.0.0 (offline default)',
    'fields': [
      {
        'code': 'name',
        'label': 'Tên điểm bán',
        'type': 'text',
        'placeholder': 'Nhập tên cửa hàng, đại lý...',
        'is_required': true,
        'section': 'Thông tin chung',
      },
      {
        'code': 'customer_type_id',
        'label': 'Loại điểm bán',
        'type': 'single_choice',
        'is_required': true,
        'section': 'Thông tin chung',
      },
      {
        'code': 'channel_id',
        'label': 'Kênh bán hàng',
        'type': 'single_choice',
        'is_required': false,
        'section': 'Thông tin chung',
      },
      {
        'code': 'region_id',
        'label': 'Khu vực quản lý (Region - bắt buộc để sinh mã)',
        'type': 'single_choice',
        'is_required': true,
        'section': 'Thông tin chung',
      },
      {
        'code': 'contact_name',
        'label': 'Người liên hệ',
        'type': 'text',
        'placeholder': 'Họ và tên chủ cửa hàng...',
        'is_required': false,
        'section': 'Thông tin liên hệ',
      },
      {
        'code': 'contact_title',
        'label': 'Chức vụ / Vai trò',
        'type': 'text',
        'placeholder': 'Chủ đại lý, Quản lý...',
        'is_required': false,
        'section': 'Thông tin liên hệ',
      },
      {
        'code': 'phone',
        'label': 'Số điện thoại',
        'type': 'text',
        'placeholder': '09xxxxxxxx',
        'is_required': false,
        'section': 'Thông tin liên hệ',
      },
      {
        'code': 'address',
        'label': 'Địa chỉ giao dịch',
        'type': 'long_text',
        'placeholder': 'Số nhà, tên đường, phường/xã, quận/huyện...',
        'is_required': false,
        'section': 'Địa chỉ & Vị trí',
      },
      {
        'code': 'lat_lng',
        'label': 'Tọa độ GPS điểm bán',
        'type': 'gps',
        'is_required': false,
        'section': 'Địa chỉ & Vị trí',
      },
      {
        'code': 'photo_file_id',
        'label': 'Ảnh điểm bán',
        'type': 'image',
        'max': 10,
        'max_files': 10,
        'is_required': false,
        'allow_gallery': false,
        'helper_text': 'Chụp tối đa 10 ảnh thực tế điểm bán từ máy ảnh',
        'section': 'Hình ảnh điểm bán',
      },
    ],
  },
};
