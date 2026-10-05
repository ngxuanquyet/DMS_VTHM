import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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

    // 🔴 Trích xuất toàn bộ ảnh điểm bán (token 32-hex hoặc đường dẫn tệp cục bộ)
    final List<String> extractedPhotos = [];
    void extractFrom(dynamic val) {
      if (val == null) return;
      if (val is List) {
        for (final item in val) {
          extractFrom(item);
        }
      } else if (val is String) {
        final trimmed = val.trim();
        if (trimmed.isNotEmpty && !extractedPhotos.contains(trimmed)) {
          extractedPhotos.add(trimmed);
        }
      }
    }

    extractFrom(data['photo_tokens']);
    extractFrom(data['photo_token']);
    extractFrom(data['photo_file_id']);
    extractFrom(data['photo']);
    extractFrom(data['photos']);
    extractFrom(data['local_photo_paths']);
    if (data['data'] is Map) {
      final dyn = data['data'] as Map;
      extractFrom(dyn['photo_tokens']);
      extractFrom(dyn['photo_token']);
      extractFrom(dyn['photo_file_id']);
      extractFrom(dyn['photo']);
      extractFrom(dyn['photos']);
      for (final entry in dyn.entries) {
        final k = entry.key.toString().toLowerCase();
        if (k.contains('photo') || k.contains('anh') || k.contains('image')) {
          extractFrom(entry.value);
        }
      }
    }

    final List<String> existingTokens = [];
    final List<String> localPhotoPaths = [];

    for (final pStr in extractedPhotos) {
      if (pStr.length == 32 && !pStr.contains('/') && !pStr.contains(r'\')) {
        existingTokens.add(pStr);
      } else {
        localPhotoPaths.add(pStr);
      }
    }

    // Sao chép các tệp ảnh offline vào bộ lưu trữ vĩnh viễn của app để tránh bị OS xóa cache
    final List<String> permanentPhotoPaths = [];
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final offlinePhotosDir = Directory(p.join(docDir.path, 'offline_customer_photos'));
      if (!await offlinePhotosDir.exists()) {
        await offlinePhotosDir.create(recursive: true);
      }

      for (int i = 0; i < localPhotoPaths.length; i++) {
        final rawPath = localPhotoPaths[i];
        String cleanPath = rawPath;
        if (cleanPath.startsWith('file://')) {
          try {
            cleanPath = Uri.parse(cleanPath).toFilePath();
          } catch (_) {
            cleanPath = cleanPath.replaceFirst('file://', '');
          }
        }
        final srcFile = File(cleanPath);
        if (await srcFile.exists()) {
          final ext = p.extension(cleanPath).isNotEmpty ? p.extension(cleanPath) : '.jpg';
          final destPath = p.join(offlinePhotosDir.path, '${clientUuid}_photo_$i$ext');
          final copiedFile = await srcFile.copy(destPath);
          permanentPhotoPaths.add(copiedFile.path);
        } else {
          permanentPhotoPaths.add(rawPath);
        }
      }
    } catch (e) {
      debugPrint('[CustomerLocalDataSource] Không thể copy ảnh vào thư mục offline: $e');
      permanentPhotoPaths.addAll(localPhotoPaths);
    }

    final List<String> allPhotos = [...existingTokens, ...permanentPhotoPaths];

    // 🔴 Sử dụng CustomerPayloadHelper đóng gói payload chuẩn theo hợp đồng 30/09/2026:
    // - Chỉ đúng 25 khoá gốc được phép
    // - Không client_boot_id, queued_seconds
    // - Toàn bộ ô động (mw_*) gom vào 'data'
    // - lat/lng đi thành cặp
    // - route_ids là List<int>
    final payloadMap = CustomerPayloadHelper.buildCustomerApiPayload(
      sourceData: data,
      resolvedPhotoTokens: existingTokens.isNotEmpty ? existingTokens : null,
      clientUuid: clientUuid,
      isOfflineSync: true,
    );

    final dynamicData = payloadMap['data'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(payloadMap['data'] as Map<String, dynamic>)
        : <String, dynamic>{};

    // Chuẩn bị payload cho hàng đợi sync_queue: lưu cả danh sách ảnh cục bộ để SyncService upload khi có mạng
    final queuePayload = Map<String, dynamic>.from(payloadMap);
    if (allPhotos.isNotEmpty) {
      queuePayload['photo_tokens'] = allPhotos;
      queuePayload['photo_token'] = allPhotos.first;
      queuePayload['photo_file_id'] = allPhotos;
      queuePayload['photo'] = allPhotos.first;
      if (permanentPhotoPaths.isNotEmpty) {
        queuePayload['local_photo_paths'] = permanentPhotoPaths;
      }
    }

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
          if (allPhotos.isNotEmpty) 'photo_tokens': allPhotos,
          if (allPhotos.isNotEmpty) 'photo_urls': allPhotos,
          if (allPhotos.isNotEmpty) 'photo_url': allPhotos.first,
          if (allPhotos.isNotEmpty) 'photo_token': allPhotos.first,
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
        payload: Value(jsonEncode(queuePayload)),
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
      photoUrl: allPhotos.isNotEmpty ? allPhotos.first : null,
      photoUrls: allPhotos,
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

  /// Cập nhật thông tin điểm bán offline/lỗi và làm mới hàng đợi đồng bộ
  Future<CustomerEntity> updateCustomerOffline(
    String clientUuid,
    Map<String, dynamic> changes,
  ) async {
    final existingRows = await (_db.select(_db.localCustomers)
          ..where((tbl) => tbl.clientUuid.equals(clientUuid)))
        .get();

    if (existingRows.isEmpty) {
      throw Exception('Không tìm thấy bản ghi khách hàng offline với UUID: $clientUuid');
    }

    final existing = existingRows.first;
    Map<String, dynamic> dynFields = {};
    try {
      if (existing.dynamicFieldsJson.isNotEmpty) {
        dynFields = jsonDecode(existing.dynamicFieldsJson) as Map<String, dynamic>;
      }
    } catch (_) {}

    // 1. Phân giải các trường cập nhật
    final name = changes['name']?.toString() ?? existing.name;
    final nameUnaccent = StringUtils.toUnaccentedLower(name);
    final code = changes['code']?.toString() ?? existing.code;
    final customerTypeId = changes.containsKey('customer_type_id')
        ? (changes['customer_type_id'] as int?)
        : existing.customerTypeId;
    final channelId = changes.containsKey('channel_id')
        ? (changes['channel_id'] as int?)
        : existing.channelId;
    final regionId = changes.containsKey('region_id')
        ? (changes['region_id'] as int?)
        : existing.regionId;
    final provinceName = changes.containsKey('province_name')
        ? changes['province_name']?.toString()
        : existing.provinceName;
    final wardName = changes.containsKey('ward_name')
        ? changes['ward_name']?.toString()
        : existing.wardName;
    final contactPerson = changes['contact_name']?.toString() ??
        changes['contact_person']?.toString() ??
        existing.contactPerson;
    final contactTitle = changes.containsKey('contact_title')
        ? changes['contact_title']?.toString()
        : existing.contactTitle;
    final phone = changes['phone']?.toString() ?? existing.phone;
    final email = changes.containsKey('email')
        ? changes['email']?.toString()
        : existing.email;
    final address = changes['address']?.toString() ?? existing.address;
    final lat = changes.containsKey('lat')
        ? (changes['lat'] is num ? (changes['lat'] as num).toDouble() : null)
        : existing.lat;
    final lng = changes.containsKey('lng')
        ? (changes['lng'] is num ? (changes['lng'] as num).toDouble() : null)
        : existing.lng;

    if (changes['data'] is Map<String, dynamic>) {
      dynFields.addAll(changes['data'] as Map<String, dynamic>);
    }

    if (changes['photo_tokens'] is List) {
      final photos = (changes['photo_tokens'] as List).map((e) => e.toString()).toList();
      dynFields['photo_tokens'] = photos;
      dynFields['photo_urls'] = photos;
      if (photos.isNotEmpty) {
        dynFields['photo_url'] = photos.first;
      }
    } else if (changes['photos'] is List) {
      final photos = (changes['photos'] as List).map((e) => e.toString()).toList();
      dynFields['photo_tokens'] = photos;
      dynFields['photo_urls'] = photos;
      if (photos.isNotEmpty) {
        dynFields['photo_url'] = photos.first;
      }
    }

    final nowIso = DateTime.now().toIso8601String();

    // 2. Ghi đè vào SQLite LocalCustomers: chuyển syncStatus về 'pending', approvalStatus về 'pending'
    await (_db.update(_db.localCustomers)..where((tbl) => tbl.clientUuid.equals(clientUuid))).write(
      LocalCustomersCompanion(
        name: Value(name),
        nameUnaccent: Value(nameUnaccent),
        code: Value(code),
        customerTypeId: Value(customerTypeId),
        channelId: Value(channelId),
        regionId: Value(regionId),
        provinceName: Value(provinceName),
        wardName: Value(wardName),
        contactPerson: Value(contactPerson),
        contactTitle: Value(contactTitle),
        phone: Value(phone),
        email: Value(email),
        address: Value(address),
        lat: Value(lat),
        lng: Value(lng),
        dynamicFieldsJson: Value(jsonEncode(dynFields)),
        syncStatus: const Value('pending'),
        approvalStatus: const Value('pending'),
        updatedAt: Value(nowIso),
      ),
    );

    // 3. Cập nhật payload trong hàng đợi sync_queue và hồi phục trạng thái từ dead/error về pending
    final queueEntries = await (_db.select(_db.syncQueueEntries)
          ..where((tbl) => tbl.clientUuid.equals(clientUuid) & tbl.entity.equals('customer')))
        .get();

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (queueEntries.isNotEmpty) {
      final entry = queueEntries.first;
      Map<String, dynamic> queuePayload = {};
      try {
        queuePayload = jsonDecode(entry.payload) as Map<String, dynamic>;
      } catch (_) {}

      // Trộn các thay đổi mới vào queuePayload
      queuePayload['name'] = name;
      queuePayload['code'] = code;
      if (customerTypeId != null) queuePayload['customer_type_id'] = customerTypeId;
      if (channelId != null) queuePayload['channel_id'] = channelId;
      if (regionId != null) queuePayload['region_id'] = regionId;
      if (provinceName != null) queuePayload['province_name'] = provinceName;
      if (wardName != null) queuePayload['ward_name'] = wardName;
      if (contactPerson.isNotEmpty) queuePayload['contact_name'] = contactPerson;
      if (contactTitle != null) queuePayload['contact_title'] = contactTitle;
      if (phone.isNotEmpty) queuePayload['phone'] = phone;
      if (email != null) queuePayload['email'] = email;
      if (address.isNotEmpty) queuePayload['address'] = address;
      if (lat != null) queuePayload['lat'] = lat;
      if (lng != null) queuePayload['lng'] = lng;
      if (changes['data'] is Map) {
        final existingData = queuePayload['data'] is Map ? (queuePayload['data'] as Map) : {};
        queuePayload['data'] = {...existingData, ...(changes['data'] as Map)};
      }
      if (changes['photo_tokens'] is List) {
        queuePayload['photo_tokens'] = changes['photo_tokens'];
      } else if (changes['photos'] is List) {
        queuePayload['photo_tokens'] = changes['photos'];
      }

      await (_db.update(_db.syncQueueEntries)..where((tbl) => tbl.id.equals(entry.id))).write(
        SyncQueueEntriesCompanion(
          payload: Value(jsonEncode(queuePayload)),
          state: const Value('pending'),
          attempts: const Value(0),
          nextAttemptAt: Value(nowMs),
          lastError: const Value(null),
        ),
      );
    } else {
      // Nếu chưa có trong sync_queue, tạo mục mới
      final queuePayload = {
        'name': name,
        'code': code,
        'customer_type_id': customerTypeId,
        'channel_id': channelId,
        'region_id': regionId,
        'province_name': provinceName,
        'ward_name': wardName,
        'contact_name': contactPerson,
        'contact_title': contactTitle,
        'phone': phone,
        'email': email,
        'address': address,
        'lat': lat,
        'lng': lng,
        'route': existing.route,
        'routes': [existing.route],
        'data': dynFields,
      };

      await _db.enqueue(
        SyncQueueEntriesCompanion(
          entity: const Value('customer'),
          op: const Value('create'),
          clientUuid: Value(clientUuid),
          payload: Value(jsonEncode(queuePayload)),
          state: const Value('pending'),
          attempts: const Value(0),
          nextAttemptAt: Value(nowMs),
          createdAt: Value(nowMs),
          createdElapsed: Value(SystemClock.nowMonotonicMs),
          bootId: Value(SystemClock.bootId),
        ),
      );
    }

    // 4. Lấy bản ghi vừa cập nhật và trả về CustomerEntity
    final updatedRows = await (_db.select(_db.localCustomers)
          ..where((tbl) => tbl.clientUuid.equals(clientUuid)))
        .get();

    return _mapRowToEntity(updatedRows.first);
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
