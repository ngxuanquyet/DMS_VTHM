import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../../core/utils/system_clock.dart';
import '../../domain/entities/customer_entity.dart';
import '../utils/customer_payload_helper.dart';

class CustomerLocalDataSource {
  final AppDatabase _db;
  static const _uuid = Uuid();

  CustomerLocalDataSource(this._db);

  /// Thêm mới điểm bán ngoại tuyến (§1 BB-1, BB-2, BB-3, §3.1 & §7)
  /// - Sinh client_uuid v4 ngay lúc nhập
  /// - Ghi vào SQLite (LocalCustomers)
  /// - Đẩy vào hàng đợi sync_queue (SyncQueueEntries)
  Future<CustomerEntity> createCustomerOffline(Map<String, dynamic> data) async {
    // 1. Sinh client_uuid LÚC NHẬP (BB-2: một lần duy nhất, không sinh lại lúc gửi)
    final clientUuid = _uuid.v4();
    final now = DateTime.now();
    // ISO-8601 có múi giờ tường minh (§6.5)
    final clientTimeIso = '${now.toIso8601String()}+07:00';
    final nowMs = now.millisecondsSinceEpoch;

    final name = (data['name'] ?? 'Điểm bán mới').toString().trim();
    final nameUnaccent = StringUtils.toUnaccentedLower(name);
    final phone = (data['phone'] ?? '').toString().trim();
    final contactName = (data['contact_name'] ?? data['contact_person'] ?? data['contactPerson'] ?? '').toString().trim();
    final contactTitle = data['contact_title']?.toString().trim();
    final address = (data['address'] ?? '').toString().trim();
    final deliveryAddress = data['delivery_address']?.toString().trim();
    final provinceName = data['province_name']?.toString().trim();
    final wardName = data['ward_name']?.toString().trim();
    final email = data['email']?.toString().trim();
    final birthday = data['birthday']?.toString().trim();
    final type = (data['type'] ?? data['customer_type_name'] ?? data['customer_type_code'] ?? '').toString().trim();

    int regionId = 1;
    if (data['region_id'] != null) {
      regionId = int.tryParse(data['region_id'].toString()) ?? 1;
    }
    int? customerTypeId = data['customer_type_id'] != null ? int.tryParse(data['customer_type_id'].toString()) : null;
    int? customerGroupId = data['customer_group_id'] != null ? int.tryParse(data['customer_group_id'].toString()) : null;
    int? channelId = data['channel_id'] != null ? int.tryParse(data['channel_id'].toString()) : null;
    int? geofenceRadiusM = data['geofence_radius_m'] != null ? int.tryParse(data['geofence_radius_m'].toString()) : null;

    // route_ids bắt buộc với nhân viên thị trường (spec 22/09/2026)
    List<int> routeIds = [];
    if (data['route_ids'] is List) {
      routeIds = (data['route_ids'] as List)
          .map((e) => int.tryParse(e.toString()))
          .whereType<int>()
          .toList();
    } else if (data['route_id'] != null) {
      final parsedRouteId = int.tryParse(data['route_id'].toString());
      if (parsedRouteId != null) routeIds.add(parsedRouteId);
    }
    if (routeIds.isEmpty) {
      routeIds = [1];
    }

    final route = (data['route'] ?? (routeIds.isNotEmpty ? 'Tuyến ${routeIds.first}' : 'Tuyến 1')).toString().trim();

    double? lat;
    if (data['lat'] != null) {
      lat = double.tryParse(data['lat'].toString());
    }
    double? lng;
    if (data['lng'] != null) {
      lng = double.tryParse(data['lng'].toString());
    }

    // 🔴 Sử dụng CustomerPayloadHelper đóng gói payload chuẩn theo hợp đồng 30/09/2026:
    // - Chỉ đúng 25 khoá gốc được phép
    // - Không client_boot_id, queued_seconds
    // - Toàn bộ ô động (mw_*) gom vào 'data'
    // - lat/lng đi thành cặp
    // - route_ids là List<int>
    final payloadMap = CustomerPayloadHelper.buildCustomerApiPayload(
      sourceData: data,
      clientUuid: clientUuid,
      isOfflineSync: true,
    );

    final dynamicData = payloadMap['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(payloadMap['data'] as Map<String, dynamic>)
        : <String, dynamic>{};

    final photoTokens = (payloadMap['photo_tokens'] as List<String>?) ?? [];
    final photoToken = payloadMap['photo_token']?.toString();

    // Mã hiển thị tạm thời trên UI/SQLite trước khi server cấp mã thật
    final tempCode = 'PENDING_${clientUuid.substring(0, 6).toUpperCase()}';

    // 2. Ghi SQLite (LocalCustomers)
    await _db.insertOrUpdateCustomer(
      LocalCustomersCompanion(
        clientUuid: Value(clientUuid),
        code: Value(tempCode),
        name: Value(name),
        nameUnaccent: Value(nameUnaccent),
        regionId: Value(regionId),
        customerTypeId: Value(customerTypeId),
        channelId: Value(channelId),
        type: Value(type),
        route: Value(route),
        address: Value(address),
        provinceName: Value(provinceName),
        wardName: Value(wardName),
        contactPerson: Value(contactName),
        contactTitle: Value(contactTitle),
        phone: Value(phone),
        email: Value(email),
        lat: Value(lat),
        lng: Value(lng),
        geofenceRadiusM: Value(geofenceRadiusM),
        status: const Value('active'),
        approvalStatus: const Value('pending'), // §5.4
        syncStatus: const Value('pending'),
        dynamicFieldsJson: Value(jsonEncode({
          ...dynamicData,
          if (deliveryAddress != null && deliveryAddress.isNotEmpty) 'delivery_address': deliveryAddress,
          if (birthday != null && birthday.isNotEmpty) 'birthday': birthday,
          if (customerGroupId != null) 'customer_group_id': customerGroupId,
          'routes': [route],
          'route_ids': routeIds,
          if (photoTokens.isNotEmpty) 'photo_tokens': photoTokens,
          if (photoTokens.isNotEmpty) 'photo_urls': photoTokens,
          if (photoTokens.isNotEmpty) 'photo_url': photoTokens.first,
          if (photoToken != null && photoToken.isNotEmpty) 'photo_token': photoToken,
        })),
        createdAt: Value(clientTimeIso),
      ),
    );

    // 3. Đẩy vào hàng đợi sync_queue (§3.1)
    await _db.enqueue(
      SyncQueueEntriesCompanion(
        entity: const Value('customer'),
        op: const Value('create'),
        clientUuid: Value(clientUuid),
        parentUuid: const Value(null),
        payload: Value(jsonEncode(payloadMap)),
        state: const Value('pending'),
        attempts: const Value(0),
        nextAttemptAt: Value(nowMs),
        createdAt: Value(nowMs),
        createdElapsed: Value(SystemClock.nowMonotonicMs), // monotonic ms (§9.1)
        bootId: Value(SystemClock.bootId),
      ),
    );

    // 4. Trả về CustomerEntity để cập nhật tức thì trên UI
    return CustomerEntity(
      id: 0, // Tạm thời 0 cho đến khi server cấp ID thật
      code: tempCode,
      name: name,
      type: type,
      route: route,
      routes: [route],
      routeIds: routeIds,
      address: address,
      contactPerson: contactName,
      contactTitle: contactTitle,
      phone: phone,
      email: email,
      lat: lat,
      lng: lng,
      status: 'active',
      approvalStatus: 'pending',
      syncStatus: 'pending',
      clientUuid: clientUuid,
      createdAt: clientTimeIso,
      dynamicFields: dynamicData,
      photoUrl: photoTokens.isNotEmpty ? photoTokens.first : photoToken,
      photoUrls: photoTokens.isNotEmpty ? photoTokens : (photoToken != null && photoToken.isNotEmpty ? [photoToken] : const []),
    );
  }

  /// Đọc danh sách điểm bán từ SQLite cục bộ, hỗ trợ tìm kiếm không dấu (§7.4)
  Future<List<CustomerEntity>> getLocalCustomers({String? query}) async {
    final List<LocalCustomer> rows;
    if (query != null && query.trim().isNotEmpty) {
      final unaccentedQuery = StringUtils.toUnaccentedLower(query);
      rows = await _db.searchLocalCustomers(unaccentedQuery);
    } else {
      rows = await _db.getAllLocalCustomers();
    }

    return rows.map(_mapRowToEntity).toList();
  }

  /// Cập nhật cache từ server về SQLite khi có mạng (không ghi đè các bản ghi đang pending)
  /// [reconcile]: Nếu true, tự động xóa các khách hàng đã đồng bộ trên SQLite nhưng không còn tồn tại trên server
  Future<void> cacheRemoteCustomers(List<CustomerEntity> remoteList, {bool reconcile = false}) async {
    for (final remote in remoteList) {
      final clientUuid = remote.clientUuid ?? 'server_${remote.id}';
      final nameUnaccent = StringUtils.toUnaccentedLower(remote.name);

      await _db.insertOrUpdateCustomer(
        LocalCustomersCompanion(
          id: Value(remote.id),
          clientUuid: Value(clientUuid),
          code: Value(remote.code),
          name: Value(remote.name),
          nameUnaccent: Value(nameUnaccent),
          type: Value(remote.type),
          customerTypeId: Value(remote.customerTypeId),
          channelName: Value(remote.channelName),
          channelId: Value(remote.channelId),
          regionId: Value(remote.regionId),
          route: Value(remote.route),
          address: Value(remote.address),
          provinceName: Value(remote.provinceName),
          wardName: Value(remote.wardName),
          contactPerson: Value(remote.contactPerson),
          contactTitle: Value(remote.contactTitle),
          phone: Value(remote.phone),
          email: Value(remote.email),
          lat: Value(remote.lat),
          lng: Value(remote.lng),
          geofenceRadiusM: Value(remote.geofenceRadiusM),
          status: Value(remote.status),
          approvalStatus: Value(remote.approvalStatus),
          syncStatus: const Value('synced'),
          dynamicFieldsJson: Value(jsonEncode({
            ...remote.dynamicFields,
            if (remote.routes.isNotEmpty) 'routes': remote.routes,
            if (remote.routeIds.isNotEmpty) 'route_ids': remote.routeIds,
            if (remote.photoUrl != null) 'photo_url': remote.photoUrl,
            if (remote.photoUrls.isNotEmpty) 'photo_urls': remote.photoUrls,
          })),
          createdAt: Value(remote.createdAt),
          updatedAt: Value(remote.updatedAt),
        ),
      );
    }

    if (reconcile) {
      final activeIds = remoteList.map((e) => e.id).where((id) => id > 0).toList();
      await _db.deleteSyncedCustomersNotIn(activeIds);
    }
  }

  /// Xóa điểm bán khỏi SQLite cục bộ
  Future<void> deleteCustomerLocal(int id) async {
    await _db.deleteCustomerById(id);
  }

  /// Xóa bản ghi điểm bán chờ đồng bộ khỏi SQLite và hủy hàng đợi sync
  Future<void> deletePendingCustomer(String clientUuid) async {
    await _db.deletePendingCustomer(clientUuid);
  }

  /// Xóa sạch các khách hàng đã đồng bộ khỏi SQLite (dùng khi cần dọn cache cũ nhiễm tên tỉnh/mock data)
  Future<void> clearSyncedCustomers() async {
    await _db.deleteSyncedCustomersNotIn(const []);
  }

  CustomerEntity _mapRowToEntity(LocalCustomer row) {
    Map<String, dynamic> dynFields = {};
    try {
      if (row.dynamicFieldsJson.isNotEmpty) {
        dynFields = jsonDecode(row.dynamicFieldsJson) as Map<String, dynamic>;
      }
    } catch (_) {}

    String? localPhotoUrl;
    List<String> localPhotoUrls = [];
    if (dynFields['photo_urls'] is List) {
      localPhotoUrls = (dynFields['photo_urls'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (dynFields['photo_tokens'] is List) {
      localPhotoUrls = (dynFields['photo_tokens'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (localPhotoUrls.isNotEmpty) {
      localPhotoUrl = localPhotoUrls.first;
    } else if (dynFields['photo_url'] != null && dynFields['photo_url'].toString().trim().isNotEmpty) {
      localPhotoUrl = dynFields['photo_url'].toString().trim();
      localPhotoUrls = [localPhotoUrl];
    } else if (dynFields['photo_token'] != null && dynFields['photo_token'].toString().trim().isNotEmpty) {
      localPhotoUrl = dynFields['photo_token'].toString().trim();
      localPhotoUrls = [localPhotoUrl];
    }

    List<String> localRoutes = [];
    if (dynFields['routes'] is List) {
      localRoutes = (dynFields['routes'] as List)
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => !CustomerEntity.isInvalidOrProvinceRoute(e, provinceName: row.provinceName))
          .toList();
    }
    if (localRoutes.isEmpty && !CustomerEntity.isInvalidOrProvinceRoute(row.route, provinceName: row.provinceName)) {
      localRoutes = [row.route.trim()];
    }

    final resolvedRowRoute = localRoutes.isNotEmpty
        ? localRoutes.first
        : (CustomerEntity.isInvalidOrProvinceRoute(row.route, provinceName: row.provinceName)
            ? 'Chưa phân tuyến'
            : row.route.trim());

    List<int> localRouteIds = [];
    if (dynFields['route_ids'] is List) {
      localRouteIds = (dynFields['route_ids'] as List)
          .map((e) => int.tryParse(e.toString()))
          .whereType<int>()
          .toList();
    }

    Color accent = const Color(0xFF10B981);
    if (row.type.contains('NPP') || row.type.contains('Cấp 1')) {
      accent = const Color(0xFF3B82F6);
    } else if (row.type.contains('Siêu thị')) {
      accent = const Color(0xFF8B5CF6);
    }

    return CustomerEntity(
      id: row.id ?? 0,
      code: row.code,
      name: row.name,
      customerTypeId: row.customerTypeId,
      type: row.type.isNotEmpty ? row.type : (row.channelName ?? 'Đại lý'),
      channelId: row.channelId,
      channelName: row.channelName,
      regionId: row.regionId,
      route: resolvedRowRoute,
      routes: localRoutes,
      routeIds: localRouteIds,
      address: row.address,
      provinceName: row.provinceName,
      wardName: row.wardName,
      contactPerson: row.contactPerson,
      contactTitle: row.contactTitle,
      phone: row.phone,
      email: row.email,
      lat: row.lat,
      lng: row.lng,
      geofenceRadiusM: row.geofenceRadiusM,
      status: row.status,
      approvalStatus: row.approvalStatus,
      syncStatus: row.syncStatus,
      clientUuid: row.clientUuid,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      accentColor: accent,
      dynamicFields: dynFields,
      photoUrl: localPhotoUrl,
      photoUrls: localPhotoUrls,
    );
  }
}
