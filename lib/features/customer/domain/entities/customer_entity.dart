import 'package:flutter/material.dart';
import '../../../../core/map/goong_models.dart';

enum CustomerVisitStatus {
  visited,
  pending,
  notScheduled,
}

class CustomerAssigneeEntity {
  final String employeeCode;
  final bool isPrimary;

  const CustomerAssigneeEntity({
    required this.employeeCode,
    this.isPrimary = false,
  });

  factory CustomerAssigneeEntity.fromJson(Map<String, dynamic> json) {
    return CustomerAssigneeEntity(
      employeeCode: json['employee_code']?.toString() ?? '',
      isPrimary: json['is_primary'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'employee_code': employeeCode,
    'is_primary': isPrimary,
  };
}

class CustomerEntity {
  final int id;
  final String code;
  final String name;
  final int? customerTypeId;
  final String type;
  final int? channelId;
  final String? channelName;
  final int? regionId;
  final String route;
  final String address;
  final String? provinceName;
  final String? wardName;
  final String contactPerson;
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
  final bool isToday;
  final CustomerVisitStatus visitStatus;
  final Color accentColor;
  final Map<String, dynamic> dynamicFields;
  final List<CustomerAssigneeEntity> assignees;

  const CustomerEntity({
    required this.id,
    required this.code,
    required this.name,
    this.customerTypeId,
    required this.type,
    this.channelId,
    this.channelName,
    this.regionId,
    required this.route,
    required this.address,
    this.provinceName,
    this.wardName,
    required this.contactPerson,
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
    this.isToday = true,
    this.visitStatus = CustomerVisitStatus.pending,
    this.accentColor = const Color(0xFF10B981),
    this.dynamicFields = const {},
    this.assignees = const [],
  });

  bool get hasCoordinates => lat != null && lng != null;

  GoongLatLng? get toGoongLatLng =>
      hasCoordinates ? GoongLatLng(lat!, lng!) : null;

  CustomerEntity copyWith({
    int? id,
    String? code,
    String? name,
    int? customerTypeId,
    String? type,
    int? channelId,
    String? channelName,
    int? regionId,
    String? route,
    String? address,
    String? provinceName,
    String? wardName,
    String? contactPerson,
    String? contactTitle,
    String? phone,
    String? email,
    double? lat,
    double? lng,
    int? geofenceRadiusM,
    String? status,
    String? approvalStatus,
    String? createdByName,
    String? updatedByName,
    String? createdAt,
    String? updatedAt,
    bool? isToday,
    CustomerVisitStatus? visitStatus,
    Color? accentColor,
    Map<String, dynamic>? dynamicFields,
    List<CustomerAssigneeEntity>? assignees,
  }) {
    return CustomerEntity(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      customerTypeId: customerTypeId ?? this.customerTypeId,
      type: type ?? this.type,
      channelId: channelId ?? this.channelId,
      channelName: channelName ?? this.channelName,
      regionId: regionId ?? this.regionId,
      route: route ?? this.route,
      address: address ?? this.address,
      provinceName: provinceName ?? this.provinceName,
      wardName: wardName ?? this.wardName,
      contactPerson: contactPerson ?? this.contactPerson,
      contactTitle: contactTitle ?? this.contactTitle,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      geofenceRadiusM: geofenceRadiusM ?? this.geofenceRadiusM,
      status: status ?? this.status,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      createdByName: createdByName ?? this.createdByName,
      updatedByName: updatedByName ?? this.updatedByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isToday: isToday ?? this.isToday,
      visitStatus: visitStatus ?? this.visitStatus,
      accentColor: accentColor ?? this.accentColor,
      dynamicFields: dynamicFields ?? this.dynamicFields,
      assignees: assignees ?? this.assignees,
    );
  }
}
