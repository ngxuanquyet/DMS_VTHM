import 'package:flutter/material.dart';
import '../../domain/entities/customer_dynamic_column.dart';
import '../../domain/entities/customer_entity.dart';

class CustomerDto {
  final int id;
  final String code;
  final String name;
  final int? customerTypeId;
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
  final String? createdByName;
  final String? updatedByName;
  final String? createdAt;
  final String? updatedAt;
  final Map<String, dynamic> dynamicFields;
  final List<CustomerAssigneeEntity> assignees;

  const CustomerDto({
    required this.id,
    required this.code,
    required this.name,
    this.customerTypeId,
    this.customerTypeName,
    this.channelId,
    this.channelName,
    this.regionId,
    this.regionName,
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
    this.createdByName,
    this.updatedByName,
    this.createdAt,
    this.updatedAt,
    this.dynamicFields = const {},
    this.assignees = const [],
  });

  factory CustomerDto.fromJson(Map<String, dynamic> json) {
    // Safely parse int ID
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;

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

    // Safely parse dynamic fields (always map in specs)
    Map<String, dynamic> dynamicMap = {};
    if (json['dynamic'] is Map) {
      dynamicMap = Map<String, dynamic>.from(json['dynamic'] as Map);
    } else if (json['dynamic_fields'] is Map) {
      dynamicMap = Map<String, dynamic>.from(json['dynamic_fields'] as Map);
    }

    // Safely parse assignees
    List<CustomerAssigneeEntity> assigneesList = [];
    if (json['assignees'] is List) {
      assigneesList = (json['assignees'] as List)
          .whereType<Map<String, dynamic>>()
          .map((item) => CustomerAssigneeEntity.fromJson(item))
          .toList();
    }

    return CustomerDto(
      id: id,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      customerTypeId: json['customer_type_id'] is int
          ? json['customer_type_id'] as int
          : int.tryParse(json['customer_type_id']?.toString() ?? ''),
      customerTypeName: json['customer_type_name']?.toString(),
      channelId: json['channel_id'] is int
          ? json['channel_id'] as int
          : int.tryParse(json['channel_id']?.toString() ?? ''),
      channelName: json['channel_name']?.toString(),
      regionId: json['region_id'] is int
          ? json['region_id'] as int
          : int.tryParse(json['region_id']?.toString() ?? ''),
      regionName: json['region_name']?.toString(),
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
      createdByName: json['created_by_name']?.toString(),
      updatedByName: json['updated_by_name']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      dynamicFields: dynamicMap,
      assignees: assigneesList,
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

    return CustomerEntity(
      id: id,
      code: code,
      name: name,
      customerTypeId: customerTypeId,
      type: customerTypeName ?? (channelName ?? 'Điểm bán'),
      channelId: channelId,
      channelName: channelName,
      regionId: regionId,
      route: regionName ?? (provinceName ?? 'Tuyến thị trường'),
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
      createdByName: createdByName,
      updatedByName: updatedByName,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isToday: true,
      visitStatus: CustomerVisitStatus.pending,
      accentColor: accentColor,
      dynamicFields: dynamicFields,
      assignees: assignees,
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

    List<CustomerEntity> customers = [];
    if (json['data'] is List) {
      customers = (json['data'] as List)
          .whereType<Map<String, dynamic>>()
          .map((item) => CustomerDto.fromJson(item).toEntity())
          .toList();
    }

    final meta = json['meta'] as Map<String, dynamic>? ?? {};
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
