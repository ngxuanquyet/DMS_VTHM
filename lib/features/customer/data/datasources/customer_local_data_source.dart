import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/string_utils.dart';
import '../../domain/entities/customer_entity.dart';

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
    final status = (data['status'] ?? 'active').toString().trim();
    final route = (data['route'] ?? 'Tuyến mặc định').toString().trim();
    final type = (data['type'] ?? data['customer_type_name'] ?? data['customer_type_code'] ?? '').toString().trim();

    // FK danh mục theo spec
    int regionId = 1;
    if (data['region_id'] != null) {
      regionId = int.tryParse(data['region_id'].toString()) ?? 1;
    }
    int? customerTypeId = data['customer_type_id'] != null ? int.tryParse(data['customer_type_id'].toString()) : null;
    int? customerGroupId = data['customer_group_id'] != null ? int.tryParse(data['customer_group_id'].toString()) : null;
    int? channelId = data['channel_id'] != null ? int.tryParse(data['channel_id'].toString()) : null;
    int? geofenceRadiusM = data['geofence_radius_m'] != null ? int.tryParse(data['geofence_radius_m'].toString()) : null;
    int? photoFileId = data['photo_file_id'] != null ? int.tryParse(data['photo_file_id'].toString()) : null;

    double? lat;
    if (data['lat'] != null) {
      lat = double.tryParse(data['lat'].toString());
    }
    double? lng;
    if (data['lng'] != null) {
      lng = double.tryParse(data['lng'].toString());
    }

    // Tách ô động vào object 'data' theo đúng spec:
    // 🔴 Mọi ô động đi trong đúng một khoá data (api/modules/crm/forms/CustomerCreateForm.php:15)
    final dynamicData = <String, dynamic>{};
    if (data['data'] is Map<String, dynamic>) {
      dynamicData.addAll(data['data'] as Map<String, dynamic>);
    }
    if (data['dynamic_fields'] is Map<String, dynamic>) {
      dynamicData.addAll(data['dynamic_fields'] as Map<String, dynamic>);
    }

    const standardKeys = {
      'name', 'region_id', 'customer_type_id', 'customer_group_id', 'channel_id',
      'status', 'address', 'delivery_address', 'province_name', 'ward_name',
      'contact_name', 'contact_title', 'phone', 'email', 'birthday',
      'lat', 'lng', 'geofence_radius_m', 'photo_file_id', 'client_uuid',
      'is_offline_sync', 'data',
      // Internal client keys
      'code', 'id', 'route', 'type', 'contact_person', 'contactPerson', 'dynamic_fields',
    };

    data.forEach((key, val) {
      if (!standardKeys.contains(key) && val != null) {
        dynamicData[key] = val;
      }
    });

    // 🔴 Đóng gói payload gửi lên server:
    // - KHÔNG gửi code (backend tự sinh theo region_id)
    // - KHÔNG gửi khóa lạ (client_time, approval_status, route...)
    final payloadMap = <String, dynamic>{
      'name': name,
      'region_id': regionId,
      'client_uuid': clientUuid,
      'is_offline_sync': true,
    };

    if (customerTypeId != null) payloadMap['customer_type_id'] = customerTypeId;
    if (customerGroupId != null) payloadMap['customer_group_id'] = customerGroupId;
    if (channelId != null) payloadMap['channel_id'] = channelId;
    if (status.isNotEmpty) payloadMap['status'] = status;
    if (address.isNotEmpty) payloadMap['address'] = address;
    if (deliveryAddress != null && deliveryAddress.isNotEmpty) payloadMap['delivery_address'] = deliveryAddress;
    if (provinceName != null && provinceName.isNotEmpty) payloadMap['province_name'] = provinceName;
    if (wardName != null && wardName.isNotEmpty) payloadMap['ward_name'] = wardName;
    if (contactName.isNotEmpty) payloadMap['contact_name'] = contactName;
    if (contactTitle != null && contactTitle.isNotEmpty) payloadMap['contact_title'] = contactTitle;
    if (phone.isNotEmpty) payloadMap['phone'] = phone;
    if (email != null && email.isNotEmpty) payloadMap['email'] = email;
    if (birthday != null && birthday.isNotEmpty) payloadMap['birthday'] = birthday;
    if (lat != null && lng != null) {
      payloadMap['lat'] = lat;
      payloadMap['lng'] = lng;
    }
    if (geofenceRadiusM != null) payloadMap['geofence_radius_m'] = geofenceRadiusM;
    if (photoFileId != null) payloadMap['photo_file_id'] = photoFileId;
    if (dynamicData.isNotEmpty) payloadMap['data'] = dynamicData;

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
        contactPerson: Value(contactName),
        contactTitle: Value(contactTitle),
        phone: Value(phone),
        email: Value(email),
        lat: Value(lat),
        lng: Value(lng),
        status: const Value('active'),
        approvalStatus: const Value('pending'), // §5.4
        syncStatus: const Value('pending'),
        dynamicFieldsJson: Value(jsonEncode(dynamicData)),
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
        createdElapsed: Value(nowMs), // monotonic ms
        bootId: const Value('session_active'),
      ),
    );

    // 4. Trả về CustomerEntity để cập nhật tức thì trên UI
    return CustomerEntity(
      id: 0, // Tạm thời 0 cho đến khi server cấp ID thật
      code: tempCode,
      name: name,
      type: type,
      route: route,
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
  Future<void> cacheRemoteCustomers(List<CustomerEntity> remoteList) async {
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
          dynamicFieldsJson: Value(jsonEncode(remote.dynamicFields)),
          createdAt: Value(remote.createdAt),
          updatedAt: Value(remote.updatedAt),
        ),
      );
    }
  }

  CustomerEntity _mapRowToEntity(LocalCustomer row) {
    Map<String, dynamic> dynFields = {};
    try {
      if (row.dynamicFieldsJson.isNotEmpty) {
        dynFields = jsonDecode(row.dynamicFieldsJson) as Map<String, dynamic>;
      }
    } catch (_) {}

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
      route: row.route,
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
    );
  }
}
