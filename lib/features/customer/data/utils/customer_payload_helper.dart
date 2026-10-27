import 'package:uuid/uuid.dart';

/// Danh sách trắng 25 khoá gốc duy nhất được chấp nhận ở POST /crm/customers
/// theo đặc tả specs/api/API-TAO-DIEM-BAN-HOP-DONG-HIEN-HANH-2026-09-30.md (§2).
/// BẤT KỲ KHOÁ NÀO KHÁC Ở GỐC BODY ĐỀU BỊ SERVER TỪ CHỐI 422!
const Set<String> kAllowedCustomerRootKeys = {
  'name',
  'region_id',
  'customer_type_id',
  'customer_group_id',
  // #23682: bỏ `channel_id` (kênh MobiWork cũ) — server bỏ qua từ 19/10/2026, sẽ gỡ ở bước 2.
  'status',
  'address',
  'delivery_address',
  'province_name',
  'ward_name',
  // Tỉnh/xã theo danh mục (#24072) — app mới gửi id; `*_name` chỉ còn cho dữ liệu hàng đợi đời cũ.
  'province_id',
  'ward_id',
  'contact_name',
  'contact_title',
  'phone',
  'email',
  'birthday',
  'coords',
  'lat',
  'lng',
  'geofence_radius_m',
  'photo_file_id',
  'photo_token',
  'photo_tokens',
  'client_uuid',
  'is_offline_sync',
  'route_ids',
  // Kênh + tuyến tự khai nhân viên chọn khi tạo (chốt 21/10/2026) — server kiểm trong cặp phòng người tạo.
  'own_channel_ids',
  'territory_code',
  // Bước nối khách ERP (#24327) — server đọc, không phải ô động.
  'erp_links',
  'erp_link_unknown',
  'data',
};

/// Các khoá cấm tuyệt đối không được lấy từ dữ liệu nguồn để gửi lên POST /crm/customers
/// (kể cả ở gốc body lẫn bên trong map `data`).
/// Ngoại lệ (nghiệp vụ 21/10/2026): `queued_seconds`/`client_time`/`client_boot_id` được SyncService gắn
/// thẳng vào body khi gửi từ hàng đợi ngoại tuyến (đo bằng đồng hồ hàng đợi §9.1) — helper này không sinh chúng.
const Set<String> kForbiddenCustomerKeys = {
  // #23682: kênh MobiWork cũ — gỡ khỏi khoá gốc thì PHẢI cấm ở đây, nếu không vòng gom ô động coi nó là ô động
  // và gửi lên trong `data`.
  'channel_id',
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
  'local_photo_paths',
  'localPhotoPaths',
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
  // Nguồn cặp tỉnh/xã (#24072) — server tự đặt, đọc từ hồ sơ để hiện nhãn; gửi lên (kể cả trong `data`) là 422.
  'geo_source',
};

/// Danh sách các trường cố định (fixed) theo schema/hợp đồng gửi ở gốc body
const Set<String> kCustomerFixedKeys = {
  'name',
  'region_id',
  'customer_type_id',
  'customer_group_id',
  // #23682: bỏ `channel_id` (kênh MobiWork cũ) — server bỏ qua từ 19/10/2026, sẽ gỡ ở bước 2.
  'status',
  'address',
  'delivery_address',
  'province_name',
  'ward_name',
  // Tỉnh/xã theo danh mục (#24072) — app mới gửi id; `*_name` chỉ còn cho dữ liệu hàng đợi đời cũ.
  'province_id',
  'ward_id',
  'contact_name',
  'contact_title',
  'phone',
  'email',
  'birthday',
  'coords',
  'lat',
  'lng',
  'geofence_radius_m',
  'photo_file_id',
  'photo_token',
  'photo_tokens',
  'client_uuid',
  'is_offline_sync',
  'route_ids',
  'own_channel_ids',
  'territory_code',
  // Bước nối khách ERP (#24327) — server đọc, không phải ô động.
  'erp_links',
  'erp_link_unknown',
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

    // 2. Khu vực (region_id) - Bắt buộc. KHÔNG tự điền khu vực khi người dùng chưa chọn: id 1 là một khu vực
    // thật, mã điểm bán sinh theo nó sẽ sai vùng. Thiếu thì để server trả đúng câu "thiếu khu vực".
    int? regionId;
    if (sourceData['region_id'] != null) {
      regionId = int.tryParse(sourceData['region_id'].toString());
    }
    if (regionId != null) payload['region_id'] = regionId;

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
    // KHÔNG tự điền tuyến khi người dùng chưa chọn: id 1 là một tuyến thật trên prod — điểm bán bị gắn nhầm
    // tuyến. Gửi mảng rỗng để server trả đúng câu "chọn ít nhất một tuyến".
    payload['route_ids'] = routeIds;

    // 4. Định danh ngoại tuyến & cờ đồng bộ
    final finalClientUuid = clientUuid ??
        sourceData['client_uuid']?.toString() ??
        const Uuid().v4();
    payload['client_uuid'] = finalClientUuid;

    if (isOfflineSync || sourceData['is_offline_sync'] == true) {
      payload['is_offline_sync'] = true;
    }

    // 5. Toạ độ GPS: ô cứng 'coords' ({lat, lng, accuracy, mock}) theo spec 15/10/2026
    // 🔴 Gửi CẢ coords lẫn lat/lng trong một lượt => 422 ở coords. Tuyệt đối chỉ gửi coords!
    if (sourceData.containsKey('coords')) {
      final rawCoords = sourceData['coords'];
      if (rawCoords is Map) {
        final cLat = rawCoords['lat'] is num
            ? (rawCoords['lat'] as num).toDouble()
            : double.tryParse(rawCoords['lat']?.toString() ?? '');
        final cLng = rawCoords['lng'] is num
            ? (rawCoords['lng'] as num).toDouble()
            : double.tryParse(rawCoords['lng']?.toString() ?? '');
        final cAcc = rawCoords['accuracy'] is num
            ? (rawCoords['accuracy'] as num).toDouble()
            : double.tryParse(rawCoords['accuracy']?.toString() ?? '');
        final cMock = rawCoords['mock'] == true;

        if (cLat != null && cLng != null) {
          payload['coords'] = {
            'lat': double.parse(cLat.toStringAsFixed(7)),
            'lng': double.parse(cLng.toStringAsFixed(7)),
            if (cAcc != null) 'accuracy': double.parse(cAcc.toStringAsFixed(1)),
            'mock': cMock,
          };
        } else {
          payload['coords'] = null;
        }
      } else if (rawCoords == null) {
        payload['coords'] = null;
      }
      payload.remove('lat');
      payload.remove('lng');
    } else {
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
    }

    // 6. Bán kính hàng rào địa lý (geofence_radius_m)
    if (sourceData['geofence_radius_m'] != null) {
      final radius = int.tryParse(sourceData['geofence_radius_m'].toString());
      if (radius != null) {
        payload['geofence_radius_m'] = radius;
      }
    }

    // 7. Các trường phân loại: customer_type_id, customer_group_id
    // Spec 20/10/2026 (§3): Bỏ gửi channel_id (server tự gán theo phòng người tạo)
    if (sourceData['customer_type_id'] != null) {
      final tId = int.tryParse(sourceData['customer_type_id'].toString());
      if (tId != null) payload['customer_type_id'] = tId;
    }
    if (sourceData['customer_group_id'] != null) {
      final gId = int.tryParse(sourceData['customer_group_id'].toString());
      if (gId != null) payload['customer_group_id'] = gId;
    }

    // 7b. Kênh + tuyến tự khai (chốt 21/10/2026): gửi khi nhân viên chọn; vắng ⇒ server gán theo phòng người tạo.
    final rawOwnChannels = sourceData['own_channel_ids'];
    if (rawOwnChannels is List) {
      final ids = rawOwnChannels.map((e) => int.tryParse(e.toString())).whereType<int>().toSet().toList();
      if (ids.isNotEmpty) payload['own_channel_ids'] = ids;
    } else if (rawOwnChannels != null) {
      final id = int.tryParse(rawOwnChannels.toString());
      if (id != null) payload['own_channel_ids'] = [id];
    }
    final territory = sourceData['territory_code']?.toString().trim() ?? '';
    if (territory.isNotEmpty) payload['territory_code'] = territory;

    // 7c. Bước nối khách ERP (#24327): `[{code, role, match_reason}]` + cờ "Chưa xác định NPP". Chỉ gửi khi màn tạo có chạy
    // bước nối (khoá có mặt) — server chỉ bắt buộc khi thấy khoá `erp_links`.
    if (sourceData.containsKey('erp_links')) {
      final raw = sourceData['erp_links'];
      payload['erp_links'] = raw is List
          ? raw
              .whereType<Map>()
              .where((m) => (m['code']?.toString().trim() ?? '').isNotEmpty && m['role'] != null)
              .map((m) => {
                    'code': m['code'].toString().trim(),
                    'role': m['role'].toString(),
                    if (m['match_reason'] != null) 'match_reason': m['match_reason'].toString(),
                  })
              .toList()
          : <Map<String, dynamic>>[];
      payload['erp_link_unknown'] = sourceData['erp_link_unknown'] == true;
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
    // Tỉnh/xã (#24072): có id ⇒ gửi id, KHÔNG gửi kèm chữ (server từ chối gửi cả hai — mà hồ sơ đọc về có sẵn cả
    // `province_name` lẫn `province_id`). Không có id (dữ liệu hàng đợi tạo bởi bản app cũ) ⇒ gửi chữ, server tự dịch.
    final provinceId = int.tryParse(sourceData['province_id']?.toString() ?? '');
    final wardId = int.tryParse(sourceData['ward_id']?.toString() ?? '');
    if (provinceId != null || wardId != null) {
      if (provinceId != null) payload['province_id'] = provinceId;
      if (wardId != null) payload['ward_id'] = wardId;
    } else {
      addStringIfNotEmpty('province_name', sourceData['province_name']);
      addStringIfNotEmpty('ward_name', sourceData['ward_name']);
    }
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
          sourceData['photo_file_id'] ??
          sourceData['photo'] ??
          sourceData['photos'] ??
          sourceData['local_photo_paths'];
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

    // Thu thập các trường động còn lại từ gốc sourceData (nếu không nằm trong fixed keys và không nằm trong forbidden keys)
    sourceData.forEach((key, val) {
      if (kCustomerFixedKeys.contains(key) ||
          kForbiddenCustomerKeys.contains(key) ||
          key == 'data' ||
          val == null) {
        return;
      }
      dynamicMap[key] = val;
    });

    // Tuyệt đối loại bỏ bất kỳ khoá cấm/khoá nội bộ nào lọt vào dynamicMap
    dynamicMap.removeWhere((k, _) => kForbiddenCustomerKeys.contains(k) || kCustomerFixedKeys.contains(k));

    if (dynamicMap.isNotEmpty) {
      payload['data'] = dynamicMap;
    }

    // 11. BẢO VỆ NGHIÊM NGẶT CUỐI CÙNG (§1, §2):
    // Chỉ giữ lại các khoá thuộc kAllowedCustomerRootKeys ở gốc body
    payload.removeWhere((k, _) => !kAllowedCustomerRootKeys.contains(k));

    return payload;
  }
}
