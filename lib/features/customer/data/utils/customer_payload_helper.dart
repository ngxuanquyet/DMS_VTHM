import 'package:uuid/uuid.dart';

/// Danh sách trắng 25 khoá gốc duy nhất được chấp nhận ở POST /crm/customers
/// theo đặc tả specs/api/API-TAO-DIEM-BAN-HOP-DONG-HIEN-HANH-2026-09-30.md (§2).
/// BẤT KỲ KHOÁ NÀO KHÁC Ở GỐC BODY ĐỀU BỊ SERVER TỪ CHỐI 422!
const Set<String> kAllowedCustomerRootKeys = {
  'name',
  'region_id',
  'customer_type_id',
  'customer_group_id',
  'channel_id',
  'status',
  'address',
  'delivery_address',
  'province_name',
  'ward_name',
  'contact_name',
  'contact_title',
  'phone',
  'email',
  'birthday',
  'lat',
  'lng',
  'geofence_radius_m',
  'photo_file_id',
  'photo_token',
  'photo_tokens',
  'client_uuid',
  'is_offline_sync',
  'route_ids',
  'data',
};

/// Các khoá cấm tuyệt đối không được gửi lên POST /crm/customers
/// (kể cả ở gốc body lẫn bên trong map `data`).
const Set<String> kForbiddenCustomerKeys = {
  'client_boot_id',
  'queued_seconds',
  'client_time',
  'code',
  'id',
  'approval_status',
  'created_by_code',
  'created_by_name',
  'custom_labels',
  'customer_type_name',
  'customer_type_code',
  'channel_name',
  'channel_code',
  'region_name',
  'region_code',
  'route_name',
  'route_code',
  'route',
  'route_id',
  'type',
  'contact_person',
  'contactPerson',
  'photo',
  'photos',
  'photo_url',
  'photo_urls',
  'dynamic_fields',
  'sync_status',
  'syncStatus',
  'created_at',
  'updated_at',
  'createdElapsed',
  'bootId',
  'temp_code',
  'mobiwork_id',
  'legacy_source',
  'legacy_key',
};

/// Danh sách các trường cố định (fixed) theo schema/hợp đồng gửi ở gốc body
const Set<String> kCustomerFixedKeys = {
  'name',
  'region_id',
  'customer_type_id',
  'customer_group_id',
  'channel_id',
  'status',
  'address',
  'delivery_address',
  'province_name',
  'ward_name',
  'contact_name',
  'contact_title',
  'phone',
  'email',
  'birthday',
  'lat',
  'lng',
  'geofence_radius_m',
  'photo_file_id',
  'photo_token',
  'photo_tokens',
  'client_uuid',
  'is_offline_sync',
  'route_ids',
};

class CustomerPayloadHelper {
  /// Xây dựng payload chuẩn chỉ, nghiêm ngặt cho POST /crm/customers.
  /// Tuân thủ 100% hợp đồng hiện hành 30/09/2026.
  static Map<String, dynamic> buildCustomerApiPayload({
    required Map<String, dynamic> sourceData,
    List<String>? resolvedPhotoTokens,
    String? clientUuid,
    bool isOfflineSync = false,
  }) {
    final payload = <String, dynamic>{};
    final dynamicMap = <String, dynamic>{};

    // 1. Tên điểm bán (name) - Bắt buộc
    final rawName = sourceData['name']?.toString().trim();
    if (rawName != null && rawName.isNotEmpty) {
      payload['name'] = rawName;
    }

    // 2. Khu vực (region_id) - Bắt buộc (int, mặc định 1 nếu không truyền)
    int? regionId;
    if (sourceData['region_id'] != null) {
      regionId = int.tryParse(sourceData['region_id'].toString());
    }
    payload['region_id'] = regionId ?? 1;

    // 3. Tuyến bán hàng (route_ids) - Bắt buộc với nhân viên thị trường (List<int>)
    List<int> routeIds = [];
    final rawRouteIds = sourceData['route_ids'] ?? sourceData['route_id'];
    if (rawRouteIds is List) {
      routeIds = rawRouteIds
          .map((e) => int.tryParse(e.toString()))
          .whereType<int>()
          .toList();
    } else if (rawRouteIds != null) {
      final parsed = int.tryParse(rawRouteIds.toString());
      if (parsed != null) routeIds = [parsed];
    }
    if (routeIds.isEmpty) {
      routeIds = [1];
    }
    payload['route_ids'] = routeIds;

    // 4. Định danh ngoại tuyến & cờ đồng bộ
    final finalClientUuid = clientUuid ??
        sourceData['client_uuid']?.toString() ??
        const Uuid().v4();
    payload['client_uuid'] = finalClientUuid;

    if (isOfflineSync || sourceData['is_offline_sync'] == true) {
      payload['is_offline_sync'] = true;
    }

    // 5. Toạ độ GPS (lat, lng) - Phải đi thành cặp theo §2 & §6
    double? lat;
    double? lng;
    if (sourceData['lat'] != null) {
      lat = double.tryParse(sourceData['lat'].toString());
    }
    if (sourceData['lng'] != null) {
      lng = double.tryParse(sourceData['lng'].toString());
    }
    if (lat != null && lng != null) {
      payload['lat'] = lat;
      payload['lng'] = lng;
    }

    // 6. Bán kính hàng rào địa lý (geofence_radius_m)
    if (sourceData['geofence_radius_m'] != null) {
      final radius = int.tryParse(sourceData['geofence_radius_m'].toString());
      if (radius != null) {
        payload['geofence_radius_m'] = radius;
      }
    }

    // 7. Các trường phân loại: customer_type_id, customer_group_id, channel_id
    // Lưu ý: Không gửi status (server mặc định là 'active', gửi lên bị 422)
    if (sourceData['customer_type_id'] != null) {
      final tId = int.tryParse(sourceData['customer_type_id'].toString());
      if (tId != null) payload['customer_type_id'] = tId;
    }
    if (sourceData['customer_group_id'] != null) {
      final gId = int.tryParse(sourceData['customer_group_id'].toString());
      if (gId != null) payload['customer_group_id'] = gId;
    }
    if (sourceData['channel_id'] != null) {
      final cId = int.tryParse(sourceData['channel_id'].toString());
      if (cId != null) payload['channel_id'] = cId;
    }

    // 8. Thông tin liên hệ & địa chỉ (fixed fields)
    void addStringIfNotEmpty(String key, dynamic value) {
      if (value != null) {
        final str = value.toString().trim();
        if (str.isNotEmpty) {
          payload[key] = str;
        }
      }
    }

    addStringIfNotEmpty('phone', sourceData['phone']);
    addStringIfNotEmpty('address', sourceData['address']);
    addStringIfNotEmpty('delivery_address', sourceData['delivery_address']);
    addStringIfNotEmpty('province_name', sourceData['province_name']);
    addStringIfNotEmpty('ward_name', sourceData['ward_name']);
    addStringIfNotEmpty(
      'contact_name',
      sourceData['contact_name'] ?? sourceData['contact_person'] ?? sourceData['contactPerson'],
    );
    addStringIfNotEmpty('contact_title', sourceData['contact_title']);
    addStringIfNotEmpty('email', sourceData['email']);
    addStringIfNotEmpty('birthday', sourceData['birthday']);

    // 9. Ảnh điểm bán: photo_tokens & photo_token
    List<String> tokens = [];
    if (resolvedPhotoTokens != null && resolvedPhotoTokens.isNotEmpty) {
      tokens = resolvedPhotoTokens;
    } else {
      final rawTokens = sourceData['photo_tokens'] ??
          sourceData['photo_token'] ??
          sourceData['photo_file_id'];
      if (rawTokens is List) {
        tokens = rawTokens
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty && e.length == 32 && !e.contains('/') && !e.contains(r'\'))
            .toList();
      } else if (rawTokens != null) {
        final t = rawTokens.toString().trim();
        if (t.isNotEmpty && t.length == 32 && !t.contains('/') && !t.contains(r'\')) {
          tokens = [t];
        }
      }
    }

    if (tokens.isNotEmpty) {
      payload['photo_tokens'] = tokens;
      payload['photo_token'] = tokens.first;
    }

    // 10. Xử lý ô động (dynamic fields) - BẮT BUỘC nằm trong `data` theo §3 & §6!
    if (sourceData['data'] is Map) {
      final srcMap = Map<String, dynamic>.from(sourceData['data'] as Map);
      srcMap.forEach((k, v) {
        if (!kForbiddenCustomerKeys.contains(k) && v != null) {
          dynamicMap[k] = v;
        }
      });
    }
    if (sourceData['dynamic_fields'] is Map) {
      final srcMap = Map<String, dynamic>.from(sourceData['dynamic_fields'] as Map);
      srcMap.forEach((k, v) {
        if (!kForbiddenCustomerKeys.contains(k) && v != null) {
          dynamicMap[k] = v;
        }
      });
    }

    // Thu thập tất cả các trường không thuộc kCustomerFixedKeys và không thuộc kForbiddenCustomerKeys
    sourceData.forEach((key, val) {
      if (kCustomerFixedKeys.contains(key) ||
          kForbiddenCustomerKeys.contains(key) ||
          key == 'data' ||
          val == null) {
        return;
      }
      // Các trường động (bao gồm mw_ma_erp, mw_khach_hang_vthm, mw_nhan_1, mw_huyen, mw_hinh_anh, mw_nhan_3, mw_nhan_2)
      // đưa vào dynamicMap!
      dynamicMap[key] = val;
    });

    if (dynamicMap.isNotEmpty) {
      payload['data'] = dynamicMap;
    }

    // 11. BẢO VỆ NGHIÊM NGẶT CUỐI CÙNG (§1, §2):
    // Chỉ giữ lại các khoá thuộc kAllowedCustomerRootKeys ở gốc body
    payload.removeWhere((k, _) => !kAllowedCustomerRootKeys.contains(k));

    return payload;
  }
}
