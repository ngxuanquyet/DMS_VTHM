import 'package:flutter/material.dart';
import '../../domain/entities/customer_dynamic_column.dart';
import '../../domain/entities/customer_entity.dart';

class CustomerDto {
  final int id;
  final String code;
  final String name;
  final int? customerTypeId;
  final int? customerGroupId;
  final String? customerTypeName;
  final int? channelId;
  final String? channelName;
  final int? regionId;
  final String? regionName;
  final String address;
  final String? provinceName;
  final String? wardName;
  final String? contactName;
  final String? contactTitle;
  final String phone;
  final String? email;
  final double? lat;
  final double? lng;
  final bool? coordsMock;
  final int? geofenceRadiusM;
  final String status;
  final String approvalStatus;
  final String? approvalLabel;
  final String? approvalColor;
  final String? approvalNote;
  final String? approvalAt;
  final String? clientUuid;
  final String? createdByName;
  final String? updatedByName;
  final String? createdAt;
  final String? updatedAt;
  final Map<String, dynamic> dynamicFields;
  final List<CustomerAssigneeEntity> assignees;
  final String? photoUrl;
  final List<String> photoUrls;
  final String? route;
  final List<String> routes;
  final List<int> routeIds;

  /// Kênh và Tuyến kinh doanh Bravo (Spec 20/10/2026)
  final List<ErpChannelEntity> erpChannels;
  final List<String> territories;
  final bool erpLinked;
  final String? territoryCode;
  final List<int> ownChannelIds;

  const CustomerDto({
    required this.id,
    required this.code,
    required this.name,
    this.customerTypeId,
    this.customerGroupId,
    this.customerTypeName,
    this.channelId,
    this.channelName,
    this.regionId,
    this.regionName,
    this.route,
    this.routes = const [],
    this.routeIds = const [],
    this.erpChannels = const [],
    this.territories = const [],
    this.erpLinked = false,
    this.territoryCode,
    this.ownChannelIds = const [],
    required this.address,
    this.provinceName,
    this.wardName,
    this.contactName,
    this.contactTitle,
    required this.phone,
    this.email,
    this.lat,
    this.lng,
    this.coordsMock,
    this.geofenceRadiusM,
    this.status = 'active',
    this.approvalStatus = 'approved',
    this.approvalLabel,
    this.approvalColor,
    this.approvalNote,
    this.approvalAt,
    this.clientUuid,
    this.createdByName,
    this.updatedByName,
    this.createdAt,
    this.updatedAt,
    this.dynamicFields = const {},
    this.assignees = const [],
    this.photoUrl,
    this.photoUrls = const [],
  });

  factory CustomerDto.fromJson(Map<String, dynamic> json, {Map<int, String>? customerTypeMap}) {
    // Safely parse int ID
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;

    // Safely parse dynamic fields (always map in specs)
    Map<String, dynamic> dynamicMap = {};
    if (json['dynamic'] is Map) {
      dynamicMap = Map<String, dynamic>.from(json['dynamic'] as Map);
    } else if (json['dynamic_fields'] is Map) {
      dynamicMap = Map<String, dynamic>.from(json['dynamic_fields'] as Map);
    }
    // Tỉnh/xã theo danh mục (#24072) giữ trong dynamicFields: màn sửa nạp mọi khoá ở đây làm giá trị ban đầu của ô cứng
    // `province_id`/`ward_id`, SQLite lưu kèm (`dynamicFieldsJson`) nên offline vẫn còn. Payload lọc lại khoá cố định / cấm
    // (`customer_payload_helper`), nên chúng không lọt vào `data`.
    for (final k in const ['province_id', 'ward_id', 'geo_source']) {
      if (json[k] != null) dynamicMap[k] = json[k];
    }

    final rawCustomerTypeId = json['customer_type_id'] is int
        ? json['customer_type_id'] as int
        : int.tryParse(json['customer_type_id']?.toString() ?? '');

    final rawCustomerGroupId = json['customer_group_id'] is int
        ? json['customer_group_id'] as int
        : int.tryParse(json['customer_group_id']?.toString() ?? '') ??
            (dynamicMap['customer_group_id'] != null
                ? int.tryParse(dynamicMap['customer_group_id'].toString())
                : null);

    // Đọc đa dạng các khóa tên loại điểm bán từ server
    String? parsedTypeName = json['customer_type_name']?.toString() ??
        json['customer_type_code']?.toString() ??
        json['customer_type']?.toString() ??
        json['type']?.toString() ??
        json['loai_kh']?.toString();

    // Nếu server không trả tên loại trực tiếp, tra cứu qua customer_type_id trong meta
    if ((parsedTypeName == null || parsedTypeName.trim().isEmpty) &&
        rawCustomerTypeId != null &&
        customerTypeMap != null) {
      parsedTypeName = customerTypeMap[rawCustomerTypeId];
    }

    // Safely parse latitude & longitude & coords (Theo spec 15/10/2026: coords: {lat, lng, mock})
    double? parseCoord(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String && value.trim().isNotEmpty) {
        return double.tryParse(value.trim());
      }
      return null;
    }

    final rawCoords = json['coords'] is Map ? json['coords'] as Map : null;
    final lat = parseCoord(rawCoords?['lat']) ?? parseCoord(json['lat']);
    final lng = parseCoord(rawCoords?['lng']) ?? parseCoord(json['lng']);
    final coordsMock = rawCoords?['mock'] is bool
        ? rawCoords!['mock'] as bool
        : (json['coords_mock'] == true ? true : null);

    // Safely parse assignees
    List<CustomerAssigneeEntity> assigneesList = [];
    if (json['assignees'] is List) {
      assigneesList = (json['assignees'] as List)
          .whereType<Map<String, dynamic>>()
          .map((item) => CustomerAssigneeEntity.fromJson(item))
          .toList();
    }

    // Safely parse photo_url and photo_urls (API spec 23/09/2026)
    final parsedPhotoUrl = json['photo_url']?.toString();
    List<String> parsedPhotoUrls = [];
    if (json['photo_urls'] is List) {
      parsedPhotoUrls = (json['photo_urls'] as List)
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (parsedPhotoUrls.isEmpty && parsedPhotoUrl != null && parsedPhotoUrl.trim().isNotEmpty) {
      parsedPhotoUrls = [parsedPhotoUrl.trim()];
    }

    // Safely parse customer routes & route_ids (API spec: routes[], route_ids[], route_name)
    List<String> parsedRoutes = [];
    List<int> parsedRouteIds = [];
    String? parsedRouteName;

    if (json['route_name'] != null && json['route_name'].toString().trim().isNotEmpty) {
      parsedRouteName = json['route_name'].toString().trim();
    } else if (json['route'] != null && json['route'] is String && json['route'].toString().trim().isNotEmpty) {
      parsedRouteName = json['route'].toString().trim();
    } else if (json['route'] != null && json['route'] is Map) {
      final rMap = json['route'] as Map;
      final name = (rMap['name'] ?? rMap['route_name'] ?? rMap['title'] ?? rMap['code'])?.toString().trim();
      if (name != null && name.isNotEmpty) {
        parsedRouteName = name;
      }
      final rId = rMap['id'] is int ? rMap['id'] as int : int.tryParse(rMap['id']?.toString() ?? '');
      if (rId != null && !parsedRouteIds.contains(rId)) {
        parsedRouteIds.add(rId);
      }
    } else if (json['routeName'] != null && json['routeName'].toString().trim().isNotEmpty) {
      parsedRouteName = json['routeName'].toString().trim();
    }

    if (json['routes'] is List) {
      for (final item in json['routes'] as List) {
        if (item is Map) {
          final id = item['id'] is int ? item['id'] as int : int.tryParse(item['id']?.toString() ?? '');
          if (id != null && !parsedRouteIds.contains(id)) {
            parsedRouteIds.add(id);
          }
          final name = (item['name'] ?? item['route_name'] ?? item['code'])?.toString().trim();
          if (name != null && name.isNotEmpty && !parsedRoutes.contains(name)) {
            parsedRoutes.add(name);
          }
        } else if (item is String && item.trim().isNotEmpty) {
          final name = item.trim();
          if (!parsedRoutes.contains(name)) parsedRoutes.add(name);
        } else if (item is num) {
          final id = item.toInt();
          if (!parsedRouteIds.contains(id)) parsedRouteIds.add(id);
        }
      }
    }

    if (json['route_names'] is List) {
      for (final item in json['route_names'] as List) {
        final name = item?.toString().trim();
        if (name != null && name.isNotEmpty && !parsedRoutes.contains(name)) {
          parsedRoutes.add(name);
        }
      }
    }

    if (json['route_ids'] is List) {
      for (final item in json['route_ids'] as List) {
        final id = item is int ? item : int.tryParse(item?.toString() ?? '');
        if (id != null && !parsedRouteIds.contains(id)) {
          parsedRouteIds.add(id);
        }
      }
    } else if (json['route_id'] != null) {
      final id = json['route_id'] is int ? json['route_id'] as int : int.tryParse(json['route_id']?.toString() ?? '');
      if (id != null && !parsedRouteIds.contains(id)) {
        parsedRouteIds.add(id);
      }
    }

    if (parsedRoutes.isEmpty && parsedRouteName == null) {
      final dynTuyen = dynamicMap['tuyen'] ??
          dynamicMap['route'] ??
          dynamicMap['tuyen_ban_hang'] ??
          dynamicMap['mw_tuyen'] ??
          dynamicMap['route_name'] ??
          dynamicMap['routes'];
      if (dynTuyen is String && dynTuyen.trim().isNotEmpty) {
        parsedRouteName = dynTuyen.trim();
      } else if (dynTuyen is Map) {
        final name = (dynTuyen['name'] ?? dynTuyen['route_name'] ?? dynTuyen['title'])?.toString().trim();
        if (name != null && name.isNotEmpty) parsedRouteName = name;
        final id = dynTuyen['id'] is int ? dynTuyen['id'] as int : int.tryParse(dynTuyen['id']?.toString() ?? '');
        if (id != null && !parsedRouteIds.contains(id)) parsedRouteIds.add(id);
      } else if (dynTuyen is List) {
        for (final item in dynTuyen) {
          if (item is String && item.trim().isNotEmpty && !parsedRoutes.contains(item.trim())) {
            parsedRoutes.add(item.trim());
          } else if (item is Map) {
            final name = (item['name'] ?? item['route_name'] ?? item['title'])?.toString().trim();
            if (name != null && name.isNotEmpty && !parsedRoutes.contains(name)) parsedRoutes.add(name);
            final id = item['id'] is int ? item['id'] as int : int.tryParse(item['id']?.toString() ?? '');
            if (id != null && !parsedRouteIds.contains(id)) parsedRouteIds.add(id);
          }
        }
      }
    }

    if (parsedRouteName != null && parsedRouteName.isNotEmpty && !parsedRoutes.contains(parsedRouteName)) {
      parsedRoutes.insert(0, parsedRouteName);
    }

    final rawProvinceName = json['province_name']?.toString();
    final validRoutes = parsedRoutes
        .where((r) => !CustomerEntity.isInvalidOrProvinceRoute(r, provinceName: rawProvinceName))
        .toList();

    final effectiveRoutes = validRoutes.isNotEmpty
        ? validRoutes
        : parsedRoutes.where((r) => r.trim() != 'Chưa phân tuyến' && r.trim() != 'Tất cả tuyến').toList();

    final validRouteName = (parsedRouteName != null &&
            !CustomerEntity.isInvalidOrProvinceRoute(parsedRouteName, provinceName: rawProvinceName))
        ? parsedRouteName
        : (effectiveRoutes.isNotEmpty ? effectiveRoutes.first : (parsedRouteName?.trim() != 'Chưa phân tuyến' ? parsedRouteName : null));

    final rawCreatedByName = json['created_by_name']?.toString().trim() ??
        json['creator_name']?.toString().trim() ??
        dynamicMap['created_by_name']?.toString().trim();
    final rawCreatedByCode = json['created_by_code']?.toString().trim() ??
        json['created_by']?.toString().trim() ??
        dynamicMap['created_by_code']?.toString().trim();
    final String? resolvedCreatedBy = (rawCreatedByName != null && rawCreatedByName.isNotEmpty)
        ? ((rawCreatedByCode != null && rawCreatedByCode.isNotEmpty && !rawCreatedByName.contains(rawCreatedByCode))
            ? '$rawCreatedByName ($rawCreatedByCode)'
            : rawCreatedByName)
        : (rawCreatedByCode != null && rawCreatedByCode.isNotEmpty ? rawCreatedByCode : null);

    final rawUpdatedByName = json['updated_by_name']?.toString().trim() ??
        json['updater_name']?.toString().trim() ??
        dynamicMap['updated_by_name']?.toString().trim();
    final rawUpdatedByCode = json['updated_by_code']?.toString().trim() ??
        json['updated_by']?.toString().trim() ??
        dynamicMap['updated_by_code']?.toString().trim();
    final String? resolvedUpdatedBy = (rawUpdatedByName != null && rawUpdatedByName.isNotEmpty)
        ? ((rawUpdatedByCode != null && rawUpdatedByCode.isNotEmpty && !rawUpdatedByName.contains(rawUpdatedByCode))
            ? '$rawUpdatedByName ($rawUpdatedByCode)'
            : rawUpdatedByName)
        : (rawUpdatedByCode != null && rawUpdatedByCode.isNotEmpty ? rawUpdatedByCode : null);

    // Kênh ERP và Tuyến Bravo theo Spec 20/10/2026
    List<ErpChannelEntity> parsedErpChannels = [];
    final rawErpChannels = json['erp_channels'] ?? dynamicMap['erp_channels'];
    if (rawErpChannels is List) {
      for (final item in rawErpChannels) {
        if (item is Map<String, dynamic>) {
          parsedErpChannels.add(ErpChannelEntity.fromJson(item));
        } else if (item is Map) {
          parsedErpChannels.add(ErpChannelEntity.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    List<String> parsedTerritories = [];
    final rawTerritories = json['territories'] ?? dynamicMap['territories'];
    if (rawTerritories is List) {
      parsedTerritories = rawTerritories
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final bool parsedErpLinked = json['erp_linked'] == true || dynamicMap['erp_linked'] == true;
    final String? parsedTerritoryCode = (json['territory_code'] ?? dynamicMap['territory_code'])?.toString();

    List<int> parsedOwnChannelIds = [];
    final rawOwnChannelIds = json['own_channel_ids'] ?? dynamicMap['own_channel_ids'];
    if (rawOwnChannelIds is List) {
      parsedOwnChannelIds = rawOwnChannelIds
          .map((e) => int.tryParse(e.toString()))
          .whereType<int>()
          .toList();
    }

    return CustomerDto(
      id: id,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      customerTypeId: rawCustomerTypeId,
      customerGroupId: rawCustomerGroupId,
      customerTypeName: parsedTypeName,
      channelId: json['channel_id'] is int
          ? json['channel_id'] as int
          : int.tryParse(json['channel_id']?.toString() ?? ''),
      channelName: json['channel_name']?.toString(),
      regionId: json['region_id'] is int
          ? json['region_id'] as int
          : int.tryParse(json['region_id']?.toString() ?? ''),
      regionName: json['region_name']?.toString() ??
          json['region']?.toString() ??
          (json['data'] is Map ? json['data']['region_name']?.toString() ?? json['data']['region']?.toString() : null),
      route: validRouteName,
      routes: validRoutes,
      routeIds: parsedRouteIds,
      erpChannels: parsedErpChannels,
      territories: parsedTerritories,
      erpLinked: parsedErpLinked,
      territoryCode: parsedTerritoryCode,
      ownChannelIds: parsedOwnChannelIds,
      address: json['address']?.toString() ?? '',
      provinceName: json['province_name']?.toString(),
      wardName: json['ward_name']?.toString(),
      contactName: json['contact_name']?.toString(),
      contactTitle: json['contact_title']?.toString(),
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      lat: lat,
      lng: lng,
      coordsMock: coordsMock,
      geofenceRadiusM: json['geofence_radius_m'] is int
          ? json['geofence_radius_m'] as int
          : int.tryParse(json['geofence_radius_m']?.toString() ?? ''),
      status: json['status']?.toString() ?? 'active',
      approvalStatus: json['approval_status']?.toString() ?? 'approved',
      approvalLabel: json['approval_label']?.toString(),
      approvalColor: json['approval_color']?.toString(),
      approvalNote: json['approval_note']?.toString(),
      approvalAt: json['approval_at']?.toString(),
      clientUuid: json['client_uuid']?.toString(),
      createdByName: resolvedCreatedBy,
      updatedByName: resolvedUpdatedBy,
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      dynamicFields: dynamicMap,
      assignees: assigneesList,
      photoUrl: parsedPhotoUrl,
      photoUrls: parsedPhotoUrls,
    );
  }

  CustomerEntity toEntity() {
    Color accentColor;
    switch (customerTypeName?.toLowerCase()) {
      case 'nhà phân phối':
      case 'npp':
        accentColor = const Color(0xFF3B82F6); // Blue
        break;
      case 'đại lý cấp 1':
      case 'đại lý c1':
      case 'đại lý c2':
      case 'đại lý':
        accentColor = const Color(0xFF10B981); // Emerald
        break;
      case 'siêu thị':
      case 'ka':
        accentColor = const Color(0xFF8B5CF6); // Purple
        break;
      case 'nhà máy':
        accentColor = const Color(0xFFF59E0B); // Amber
        break;
      default:
        accentColor = const Color(0xFF10B981); // Emerald default
    }

    final resolvedType = (customerTypeName != null && customerTypeName!.trim().isNotEmpty)
        ? customerTypeName!.trim()
        : (channelName != null && channelName!.trim().isNotEmpty
            ? channelName!.trim()
            : 'Đại lý');

    final resolvedRoute = (route != null && route!.trim().isNotEmpty && route!.trim() != 'Chưa phân tuyến')
        ? route!.trim()
        : (routes.isNotEmpty
            ? routes.first
            : (routeIds.isNotEmpty ? 'Tuyến ${routeIds.join(', ')}' : 'Chưa phân tuyến'));

    return CustomerEntity(
      id: id,
      code: code,
      name: name,
      customerTypeId: customerTypeId,
      customerGroupId: customerGroupId,
      type: resolvedType,
      channelId: channelId,
      channelName: channelName,
      regionId: regionId,
      regionName: regionName,
      route: resolvedRoute,
      routes: routes.isNotEmpty ? routes : (route != null && route!.trim().isNotEmpty ? [route!.trim()] : const []),
      routeIds: routeIds,
      erpChannels: erpChannels,
      territories: territories,
      erpLinked: erpLinked,
      territoryCode: territoryCode,
      ownChannelIds: ownChannelIds,
      address: address,
      provinceName: provinceName,
      wardName: wardName,
      contactPerson: contactName?.isNotEmpty == true ? contactName! : 'Chưa cập nhật',
      contactTitle: contactTitle,
      phone: phone.isNotEmpty ? phone : 'Chưa có SĐT',
      email: email,
      lat: lat,
      lng: lng,
      coordsMock: coordsMock,
      geofenceRadiusM: geofenceRadiusM,
      status: status,
      approvalStatus: approvalStatus,
      approvalLabel: approvalLabel,
      approvalColor: approvalColor,
      approvalNote: approvalNote,
      approvalAt: approvalAt,
      syncStatus: 'synced',
      clientUuid: clientUuid,
      createdByName: createdByName,
      updatedByName: updatedByName,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isToday: CustomerEntity.isSameDayOfWeek(
            CustomerEntity.extractDayOfWeekFromName(resolvedRoute),
            DateTime.now().weekday,
          ) ||
          routes.any(
            (r) => CustomerEntity.isSameDayOfWeek(
              CustomerEntity.extractDayOfWeekFromName(r),
              DateTime.now().weekday,
            ),
          ),
      visitStatus: CustomerVisitStatus.pending,
      accentColor: accentColor,
      dynamicFields: dynamicFields,
      assignees: assignees,
      photoUrl: photoUrl,
      photoUrls: photoUrls,
    );
  }
}

class CustomerApiResponse {
  final bool success;
  final String message;
  final List<CustomerEntity> data;
  final int total;
  final int currentPage;
  final int pageSize;
  final int pageCount;
  final List<CustomerDynamicColumn> dynamicColumns;

  const CustomerApiResponse({
    required this.success,
    required this.message,
    required this.data,
    required this.total,
    required this.currentPage,
    required this.pageSize,
    required this.pageCount,
    required this.dynamicColumns,
  });

  factory CustomerApiResponse.fromJson(Map<String, dynamic> json) {
    final success = json['success'] == true;
    final message = json['message']?.toString() ?? '';
    final meta = json['meta'] as Map<String, dynamic>? ?? {};

    // Xây dựng map tra cứu danh mục loại khách hàng: id -> name/code
    final Map<int, String> typeMap = {};
    if (meta['customerTypes'] is List) {
      for (final item in meta['customerTypes'] as List) {
        if (item is Map<String, dynamic>) {
          final id = item['id'] is int ? item['id'] as int : int.tryParse(item['id']?.toString() ?? '');
          final name = (item['name'] ?? item['code'])?.toString().trim();
          if (id != null && name != null && name.isNotEmpty) {
            typeMap[id] = name;
          }
        }
      }
    }

    List<CustomerEntity> customers = [];
    if (json['data'] is List) {
      customers = (json['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map((item) => CustomerDto.fromJson(item, customerTypeMap: typeMap).toEntity())
          .toList();
    }

    final total = meta['total'] is int ? meta['total'] as int : int.tryParse(meta['total']?.toString() ?? '') ?? customers.length;
    final currentPage = meta['currentPage'] is int ? meta['currentPage'] as int : 1;
    final pageSize = meta['pageSize'] is int ? meta['pageSize'] as int : 100;
    final pageCount = meta['pageCount'] is int ? meta['pageCount'] as int : 1;

    List<CustomerDynamicColumn> dynamicCols = [];
    if (meta['dynamicColumns'] is List) {
      dynamicCols = (meta['dynamicColumns'] as List)
          .whereType<Map<String, dynamic>>()
          .map((item) => CustomerDynamicColumn.fromJson(item))
          .toList();
    }

    return CustomerApiResponse(
      success: success,
      message: message,
      data: customers,
      total: total,
      currentPage: currentPage,
      pageSize: pageSize,
      pageCount: pageCount,
      dynamicColumns: dynamicCols,
    );
  }
}
