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
  final int? geofenceRadiusM;
  final String status;
  final String approvalStatus;
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
    required this.address,
    this.provinceName,
    this.wardName,
    this.contactName,
    this.contactTitle,
    required this.phone,
    this.email,
    this.lat,
    this.lng,
    this.geofenceRadiusM,
    this.status = 'active',
    this.approvalStatus = 'approved',
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

    // Safely parse latitude & longitude (can be string "21.322", num 21.322, or null)
    double? parseCoord(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String && value.trim().isNotEmpty) {
        return double.tryParse(value.trim());
      }
      return null;
    }

    final lat = parseCoord(json['lat']);
    final lng = parseCoord(json['lng']);

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
      final dynTuyen = dynamicMap['tuyen'] ?? dynamicMap['route'] ?? dynamicMap['tuyen_ban_hang'] ?? dynamicMap['mw_tuyen'];
      if (dynTuyen != null && dynTuyen.toString().trim().isNotEmpty) {
        parsedRouteName = dynTuyen.toString().trim();
      }
    }

    if (parsedRouteName != null && parsedRouteName.isNotEmpty && !parsedRoutes.contains(parsedRouteName)) {
      parsedRoutes.insert(0, parsedRouteName);
    }

    final rawProvinceName = json['province_name']?.toString();
    final validRoutes = parsedRoutes
        .where((r) => !CustomerEntity.isInvalidOrProvinceRoute(r, provinceName: rawProvinceName))
        .toList();

    final validRouteName = (parsedRouteName != null &&
            !CustomerEntity.isInvalidOrProvinceRoute(parsedRouteName, provinceName: rawProvinceName))
        ? parsedRouteName
        : (validRoutes.isNotEmpty ? validRoutes.first : null);

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
      regionName: json['region_name']?.toString(),
      route: validRouteName,
      routes: validRoutes,
      routeIds: parsedRouteIds,
      address: json['address']?.toString() ?? '',
      provinceName: json['province_name']?.toString(),
      wardName: json['ward_name']?.toString(),
      contactName: json['contact_name']?.toString(),
      contactTitle: json['contact_title']?.toString(),
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      lat: lat,
      lng: lng,
      geofenceRadiusM: json['geofence_radius_m'] is int
          ? json['geofence_radius_m'] as int
          : int.tryParse(json['geofence_radius_m']?.toString() ?? ''),
      status: json['status']?.toString() ?? 'active',
      approvalStatus: json['approval_status']?.toString() ?? 'approved',
      clientUuid: json['client_uuid']?.toString(),
      createdByName: json['created_by_name']?.toString(),
      updatedByName: json['updated_by_name']?.toString(),
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

    final resolvedRoute = routes.isNotEmpty
        ? routes.first
        : (route != null && route!.trim().isNotEmpty
            ? route!.trim()
            : (routeIds.isNotEmpty ? 'Tuyến ${routeIds.first}' : 'Chưa phân tuyến'));

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
      route: resolvedRoute,
      routes: routes.isNotEmpty ? routes : (route != null && route!.trim().isNotEmpty ? [route!.trim()] : const []),
      routeIds: routeIds,
      address: address,
      provinceName: provinceName,
      wardName: wardName,
      contactPerson: contactName?.isNotEmpty == true ? contactName! : 'Chưa cập nhật',
      contactTitle: contactTitle,
      phone: phone.isNotEmpty ? phone : 'Chưa có SĐT',
      email: email,
      lat: lat,
      lng: lng,
      geofenceRadiusM: geofenceRadiusM,
      status: status,
      approvalStatus: approvalStatus,
      syncStatus: 'synced',
      clientUuid: clientUuid,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isToday: true,
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
