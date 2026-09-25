import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
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
  final int? customerGroupId;
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
  final String syncStatus; // 'synced' | 'pending' | 'error'
  final String? clientUuid;
  final String? createdByName;
  final String? updatedByName;
  final String? createdAt;
  final String? updatedAt;
  final bool isToday;
  final CustomerVisitStatus visitStatus;
  final Color accentColor;
  final Map<String, dynamic> dynamicFields;
  final List<CustomerAssigneeEntity> assignees;

  /// Tuyến đường thực tế của khách hàng (API routes[] / route_ids[])
  final List<String> routes;
  final List<int> routeIds;

  /// Ảnh đại diện và bộ ảnh điểm bán theo spec 23/09/2026
  final String? photoUrl;
  final List<String> photoUrls;

  const CustomerEntity({
    required this.id,
    required this.code,
    required this.name,
    this.customerTypeId,
    this.customerGroupId,
    required this.type,
    this.channelId,
    this.channelName,
    this.regionId,
    required this.route,
    this.routes = const [],
    this.routeIds = const [],
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
    this.syncStatus = 'synced',
    this.clientUuid,
    this.createdByName,
    this.updatedByName,
    this.createdAt,
    this.updatedAt,
    this.isToday = true,
    this.visitStatus = CustomerVisitStatus.pending,
    this.accentColor = const Color(0xFF10B981),
    this.dynamicFields = const {},
    this.assignees = const [],
    this.photoUrl,
    this.photoUrls = const [],
  });

  /// URL đầy đủ của ảnh đại diện (đã ghép host API nếu đường dẫn tương đối theo spec 23/09/2026)
  String? get fullPhotoUrl {
    final raw = (photoUrls.isNotEmpty ? photoUrls.first : photoUrl)?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '${AppConstants.baseUrl}$raw';
    return '${AppConstants.baseUrl}/$raw';
  }

  /// Danh sách URL đầy đủ của tất cả ảnh điểm bán
  List<String> get fullPhotoUrls {
    final urls = photoUrls.isNotEmpty
        ? photoUrls
        : (photoUrl != null && photoUrl!.trim().isNotEmpty
            ? [photoUrl!.trim()]
            : <String>[]);
    return urls.map((raw) {
      final u = raw.trim();
      if (u.startsWith('http://') || u.startsWith('https://')) return u;
      if (u.startsWith('/')) return '${AppConstants.baseUrl}$u';
      return '${AppConstants.baseUrl}/$u';
    }).toList();
  }

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
    List<String>? routes,
    List<int>? routeIds,
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
    String? syncStatus,
    String? clientUuid,
    String? createdByName,
    String? updatedByName,
    String? createdAt,
    String? updatedAt,
    bool? isToday,
    CustomerVisitStatus? visitStatus,
    Color? accentColor,
    Map<String, dynamic>? dynamicFields,
    List<CustomerAssigneeEntity>? assignees,
    String? photoUrl,
    List<String>? photoUrls,
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
      routes: routes ?? this.routes,
      routeIds: routeIds ?? this.routeIds,
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
      syncStatus: syncStatus ?? this.syncStatus,
      clientUuid: clientUuid ?? this.clientUuid,
      createdByName: createdByName ?? this.createdByName,
      updatedByName: updatedByName ?? this.updatedByName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isToday: isToday ?? this.isToday,
      visitStatus: visitStatus ?? this.visitStatus,
      accentColor: accentColor ?? this.accentColor,
      dynamicFields: dynamicFields ?? this.dynamicFields,
      assignees: assignees ?? this.assignees,
      photoUrl: photoUrl ?? this.photoUrl,
      photoUrls: photoUrls ?? this.photoUrls,
    );
  }

  /// Kiểm tra xem một chuỗi có phải là tên tỉnh/thành, khu vực hành chính, hoặc mock data cũ (thay vì tuyến bán hàng thực tế)
  static bool isInvalidOrProvinceRoute(String? routeName, {String? provinceName}) {
    if (routeName == null) return true;
    final trimmed = routeName.trim();
    if (trimmed.isEmpty ||
        trimmed == 'Chưa phân tuyến' ||
        trimmed == 'Tất cả tuyến' ||
        trimmed == 'Tuyến mặc định') {
      return true;
    }

    final lower = trimmed.toLowerCase();

    // 1. Tiền tố tỉnh / thành phố / mã vùng
    if (lower.startsWith('tỉnh ') ||
        lower.startsWith('thành phố ') ||
        lower.startsWith('tp. ') ||
        lower.startsWith('tp ') ||
        lower.startsWith('t. ') ||
        RegExp(r'^\d{2,4}\s*-\s*').hasMatch(lower)) {
      return true;
    }

    // 2. Trùng hoặc chứa provinceName của khách hàng
    if (provinceName != null && provinceName.trim().isNotEmpty) {
      final pLower = provinceName.trim().toLowerCase();
      if (lower == pLower ||
          lower == 'tỉnh $pLower' ||
          lower == 'thành phố $pLower' ||
          pLower.contains(lower)) {
        return true;
      }
    }

    // 3. Mock data cũ có chứa địa danh quận/huyện/thị xã thay vì tuyến bán hàng
    const staleKeywords = [
      'phúc yên',
      'vĩnh yên',
      'bình xuyên',
      'sóc sơn',
      'xuân hòa',
      'hương canh',
      'tiền châu',
      'đồng sơn',
      'hùng vương',
    ];
    for (final kw in staleKeywords) {
      if (lower.contains(kw)) {
        return true;
      }
    }

    // 4. Danh sách các tỉnh/thành phố phổ biến tại Việt Nam
    const provinces = [
      'an giang', 'bà rịa', 'vũng tàu', 'bắc giang', 'bắc kạn', 'bạc liêu',
      'bắc ninh', 'bến tre', 'bình định', 'bình dương', 'bình phước', 'bình thuận',
      'cà mau', 'cần thơ', 'cao bằng', 'đà nẵng', 'đắk lắk', 'đắk nông',
      'điện biên', 'đồng nai', 'đồng tháp', 'gia lai', 'hà giang', 'hà nam',
      'hà nội', 'hà tĩnh', 'hải dương', 'hải phòng', 'hậu giang', 'hòa bình',
      'hưng yên', 'khánh hòa', 'kiên giang', 'kon tum', 'lai châu', 'lâm đồng',
      'lạng sơn', 'lào cai', 'long an', 'nam định', 'nghệ an', 'ninh bình',
      'ninh thuận', 'phú thọ', 'phú yên', 'quảng bình', 'quảng nam', 'quảng ngãi',
      'quảng ninh', 'quảng trị', 'sóc trăng', 'sơn la', 'tây ninh', 'thái bình',
      'thái nguyên', 'thanh hóa', 'thừa thiên huế', 'tiền giang', 'trà vinh',
      'tuyên quang', 'vĩnh long', 'vĩnh phúc', 'yên bái', 'hồ chí minh', 'tphcm'
    ];
    for (final p in provinces) {
      if (lower == p || lower == 'tỉnh $p' || lower == 'thành phố $p') {
        return true;
      }
    }

    return false;
  }
}

