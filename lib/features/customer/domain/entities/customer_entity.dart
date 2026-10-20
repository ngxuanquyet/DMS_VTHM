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

/// Thực thể Kênh ERP Bravo theo đặc tả kỹ thuật ngày 20/10/2026
class ErpChannelEntity {
  final int id;
  final String code;
  final String name;

  const ErpChannelEntity({
    required this.id,
    required this.code,
    required this.name,
  });

  factory ErpChannelEntity.fromJson(Map<String, dynamic> json) {
    return ErpChannelEntity(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ErpChannelEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ code.hashCode ^ name.hashCode;
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
  final String? regionName;
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
  final bool? coordsMock;
  final int? geofenceRadiusM;
  final String status;
  final String approvalStatus;
  final String? approvalLabel;
  final String? approvalColor;
  final String? approvalNote;
  final String? approvalAt;
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

  /// Kênh và Tuyến kinh doanh Bravo (Spec 20/10/2026)
  final List<ErpChannelEntity> erpChannels;
  final List<String> territories;
  final bool erpLinked;
  final String? territoryCode;
  final List<int> ownChannelIds;

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
    this.regionName,
    required this.route,
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
    required this.contactPerson,
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
    this.syncStatus = 'synced',
    this.clientUuid,
    this.createdByName,
    this.updatedByName,
    this.createdAt,
    this.updatedAt,
    this.isToday = false,
    this.visitStatus = CustomerVisitStatus.pending,
    this.accentColor = const Color(0xFF10B981),
    this.dynamicFields = const {},
    this.assignees = const [],
    this.photoUrl,
    this.photoUrls = const [],
  });

  /// Hiển thị Kênh và Tuyến theo Bravo (Spec 20/10/2026: Gợi ý `KPP, KBL · MN2`)
  String get channelTerritoryDisplay {
    final channelsStr = erpChannels
        .map((c) => c.code.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .join(', ');
    final territoriesStr = territories
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .join(', ');

    if (channelsStr.isNotEmpty && territoriesStr.isNotEmpty) {
      return '$channelsStr · $territoriesStr';
    } else if (channelsStr.isNotEmpty) {
      return channelsStr;
    } else if (territoriesStr.isNotEmpty) {
      return territoriesStr;
    }
    // Fallback: nếu chưa có kênh Bravo (chưa sync hoặc bản ghi cũ), dùng channelName cũ nếu có
    if (channelName != null && channelName!.trim().isNotEmpty) {
      return channelName!.trim();
    }
    return '';
  }

  bool get isPendingApproval => approvalStatus == 'pending';
  bool get isRejectedApproval => approvalStatus == 'rejected';
  bool get isApproved =>
      approvalStatus == 'approved' ||
      (approvalStatus != 'pending' && approvalStatus != 'rejected');

  /// Nhãn hiển thị trạng thái duyệt (theo spec 15/10/2026: ưu tiên approval_label từ server)
  String get displayApprovalLabel {
    if (approvalLabel != null && approvalLabel!.trim().isNotEmpty) {
      return approvalLabel!;
    }
    if (isPendingApproval) return 'Chờ duyệt';
    if (isRejectedApproval) return 'Bị từ chối';
    return 'Đã duyệt';
  }

  /// Màu trạng thái duyệt (theo spec 15/10/2026: bootstrap warning/danger/success)
  Color get approvalBadgeColor {
    switch (approvalColor?.toLowerCase()) {
      case 'warning':
        return const Color(0xFFF59E0B);
      case 'danger':
        return const Color(0xFFEF4444);
      case 'success':
        return const Color(0xFF10B981);
      default:
        if (isPendingApproval) return const Color(0xFFF59E0B);
        if (isRejectedApproval) return const Color(0xFFEF4444);
        return const Color(0xFF10B981);
    }
  }

  /// Kiểm tra xem đường dẫn ảnh có phải là tệp cục bộ trên máy không
  static bool isLocalFilePath(String path) {
    final p = path.trim();
    if (p.isEmpty) return false;
    if (p.startsWith('file://')) return true;
    if (p.contains(r':\') || p.contains(r':/')) return true; // Windows
    if (p.startsWith('/data/') ||
        p.startsWith('/var/') ||
        p.startsWith('/private/') ||
        p.startsWith('/storage/emulated/')) {
      return true;
    }
    if (p.contains('offline_customer_photos') ||
        p.contains('image_picker') ||
        p.contains('cache') ||
        p.contains('tmp')) {
      return true;
    }
    return false;
  }

  /// URL đầy đủ của ảnh đại diện (đã ghép host API nếu đường dẫn tương đối theo spec 23/09/2026)
  String? get fullPhotoUrl {
    final raw = (photoUrls.isNotEmpty ? photoUrls.first : photoUrl)?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (isLocalFilePath(raw)) return raw;
    if (raw.length == 32 && !raw.contains('/') && !raw.contains(r'\')) {
      return '${AppConstants.baseUrl}/crm/customer-photos/public/$raw';
    }
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
      if (isLocalFilePath(u)) return u;
      if (u.length == 32 && !u.contains('/') && !u.contains(r'\')) {
        return '${AppConstants.baseUrl}/crm/customer-photos/public/$u';
      }
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
    String? regionName,
    String? route,
    List<String>? routes,
    List<int>? routeIds,
    List<ErpChannelEntity>? erpChannels,
    List<String>? territories,
    bool? erpLinked,
    String? territoryCode,
    List<int>? ownChannelIds,
    String? address,
    String? provinceName,
    String? wardName,
    String? contactPerson,
    String? contactTitle,
    String? phone,
    String? email,
    double? lat,
    double? lng,
    bool? coordsMock,
    int? geofenceRadiusM,
    String? status,
    String? approvalStatus,
    String? approvalLabel,
    String? approvalColor,
    String? approvalNote,
    String? approvalAt,
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
      regionName: regionName ?? this.regionName,
      route: route ?? this.route,
      routes: routes ?? this.routes,
      routeIds: routeIds ?? this.routeIds,
      erpChannels: erpChannels ?? this.erpChannels,
      territories: territories ?? this.territories,
      erpLinked: erpLinked ?? this.erpLinked,
      territoryCode: territoryCode ?? this.territoryCode,
      ownChannelIds: ownChannelIds ?? this.ownChannelIds,
      address: address ?? this.address,
      provinceName: provinceName ?? this.provinceName,
      wardName: wardName ?? this.wardName,
      contactPerson: contactPerson ?? this.contactPerson,
      contactTitle: contactTitle ?? this.contactTitle,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      coordsMock: coordsMock ?? this.coordsMock,
      geofenceRadiusM: geofenceRadiusM ?? this.geofenceRadiusM,
      status: status ?? this.status,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      approvalLabel: approvalLabel ?? this.approvalLabel,
      approvalColor: approvalColor ?? this.approvalColor,
      approvalNote: approvalNote ?? this.approvalNote,
      approvalAt: approvalAt ?? this.approvalAt,
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

  /// Trích xuất thứ trong tuần từ tên tuyến (1: Thứ 2 ... 6: Thứ 7, 7: Chủ nhật)
  static int? extractDayOfWeekFromName(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final normalized = text
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll('.', ' ')
        .trim();

    if (normalized.contains('chủ nhật') ||
        normalized.contains('chu nhat') ||
        RegExp(r'\bcn\b').hasMatch(normalized)) {
      return 7;
    }
    if (normalized.contains('thứ 2') ||
        normalized.contains('thu 2') ||
        normalized.contains('thứ hai') ||
        normalized.contains('thu hai') ||
        RegExp(r'\bt\s*2\b').hasMatch(normalized)) {
      return 1;
    }
    if (normalized.contains('thứ 3') ||
        normalized.contains('thu 3') ||
        normalized.contains('thứ ba') ||
        normalized.contains('thu ba') ||
        RegExp(r'\bt\s*3\b').hasMatch(normalized)) {
      return 2;
    }
    if (normalized.contains('thứ 4') ||
        normalized.contains('thu 4') ||
        normalized.contains('thứ tư') ||
        normalized.contains('thu tu') ||
        RegExp(r'\bt\s*4\b').hasMatch(normalized)) {
      return 3;
    }
    if (normalized.contains('thứ 5') ||
        normalized.contains('thu 5') ||
        normalized.contains('thứ năm') ||
        normalized.contains('thu nam') ||
        RegExp(r'\bt\s*5\b').hasMatch(normalized)) {
      return 4;
    }
    if (normalized.contains('thứ 6') ||
        normalized.contains('thu 6') ||
        normalized.contains('thứ sáu') ||
        normalized.contains('thu sau') ||
        RegExp(r'\bt\s*6\b').hasMatch(normalized)) {
      return 5;
    }
    if (normalized.contains('thứ 7') ||
        normalized.contains('thu 7') ||
        normalized.contains('thứ bảy') ||
        normalized.contains('thu bay') ||
        RegExp(r'\bt\s*7\b').hasMatch(normalized)) {
      return 6;
    }
    return null;
  }

  /// Kiểm tra xem 2 giá trị thứ trong tuần có khớp nhau không (xử lý CN: 7 trong Dart, 0 trên DB/API)
  static bool isSameDayOfWeek(int? dayA, int? dayB) {
    if (dayA == null || dayB == null) return false;
    if (dayA == dayB) return true;
    if ((dayA == 7 && dayB == 0) || (dayA == 0 && dayB == 7)) return true;
    return false;
  }

  /// Kiểm tra khách hàng có thuộc tuyến của ngày trong tuần chỉ định không
  bool matchesDayOfWeek(int targetDay, {List<dynamic> userRoutes = const []}) {
    // 1. Kiểm tra qua routeIds với danh sách tuyến userRoutes
    for (final id in routeIds) {
      for (final ur in userRoutes) {
        final urId = ur.id is int ? ur.id as int : int.tryParse(ur.id.toString());
        if (urId == id) {
          final visitDay = ur.visitDayOfWeek as int?;
          if (isSameDayOfWeek(visitDay, targetDay)) return true;
          if (extractDayOfWeekFromName(ur.name?.toString()) == targetDay) return true;
          if (extractDayOfWeekFromName(ur.code?.toString()) == targetDay) return true;
        }
      }
    }

    // 2. Kiểm tra qua danh sách routes của khách hàng
    for (final rName in routes) {
      if (extractDayOfWeekFromName(rName) == targetDay) return true;
      for (final ur in userRoutes) {
        if (ur.name?.toString().trim() == rName.trim()) {
          final visitDay = ur.visitDayOfWeek as int?;
          if (isSameDayOfWeek(visitDay, targetDay)) return true;
          if (extractDayOfWeekFromName(ur.name?.toString()) == targetDay) return true;
        }
      }
    }

    // 3. Kiểm tra qua chuỗi route
    if (route.isNotEmpty) {
      final parts = route.split(',').map((e) => e.trim());
      for (final p in parts) {
        if (extractDayOfWeekFromName(p) == targetDay) return true;
        for (final ur in userRoutes) {
          if (ur.name?.toString().trim() == p) {
            final visitDay = ur.visitDayOfWeek as int?;
            if (isSameDayOfWeek(visitDay, targetDay)) return true;
            if (extractDayOfWeekFromName(ur.name?.toString()) == targetDay) return true;
          }
        }
      }
    }

    // 4. Kiểm tra dynamicFields
    final dynDay = dynamicFields['visit_day_of_week'] ??
        dynamicFields['thu'] ??
        dynamicFields['ngay_tuan'];
    if (dynDay != null) {
      final parsedDay = int.tryParse(dynDay.toString());
      if (parsedDay != null && isSameDayOfWeek(parsedDay, targetDay)) return true;
      if (extractDayOfWeekFromName(dynDay.toString()) == targetDay) return true;
    }

    return false;
  }
}


