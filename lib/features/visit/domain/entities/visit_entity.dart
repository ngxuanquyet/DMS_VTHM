import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import 'visit_requirements_entity.dart';

/// Loại lượt viếng thăm (`visit_kind`) — nghiệp vụ 21/10/2026.
const String kVisitKindCheckin = 'checkin';
const String kVisitKindNewOutlet = 'new_outlet';

class VisitEntity {
  final int id;
  final String? visitDate;
  final DateTime? checkinAt;
  final String? checkinAtRaw;
  final DateTime? checkoutAt;
  final String? checkoutAtRaw;
  final DateTime? cancelledAt;
  final String? cancelledAtRaw;
  final int? durationSeconds;
  final int customerId;
  final String customerName;
  final String? customerCode;
  final String? customerAddress;
  final int? routeId;
  final String? routeName;
  final bool isOnRoute;
  final String? visitResult; // 'visited' | 'closed'
  final String? visitResultLabel; // Nhãn server phát: 'Điểm bán mở cửa', 'Điểm bán đóng cửa' (§2.1 SPEC-2026-10-18)
  final String? visitResultColor; // Màu Bootstrap: 'success', 'warning', 'danger', 'info', etc. (§2.1 SPEC-2026-10-18)
  final String? closedNote;
  final int photoCount;
  final int formCount;
  final List<String> photoUrls;
  final VisitRequirementsEntity? requirements;
  final double? checkoutLat;
  final double? checkoutLng;
  final String? clientUuid;

  /// Quãng đường đi ĐẾN điểm bán của lượt đó (tính bằng mét).
  /// 0 = thiếu mốc · null = chưa tính · số = đã tính (§4.4 SPEC-2026-10-08)
  final num? travelM;

  /// Khoảng cách tới điểm bán lúc Check-in (mét)
  final double? distanceToCustomerM;

  /// Cờ nằm trong bán kính lúc Check-in: true = trong vùng · false = ngoài vùng · null = chưa tính được
  final bool? isWithinGeofence;

  /// Khoảng cách tới điểm bán lúc Check-out (mét) (§1 SPEC-2026-10-13). null = chưa tính được
  final double? checkoutDistanceM;

  /// Cờ nằm trong bán kính lúc Check-out (§1 SPEC-2026-10-13).
  /// true = trong vùng · false = ngoài vùng (gắn cờ) · null = chưa tính được
  final bool? isCheckoutWithinGeofence;

  /// Cờ Check-out sang ngày hôm sau (§4 SPEC-2026-10-15).
  /// true = ngày bấm check-out (giờ VN) khác visit_date. Lượt còn mở luôn false. Không bao giờ null.
  final bool isCheckoutOtherDay;

  /// Trạng thái phê duyệt của điểm bán gắn với lượt viếng thăm này (§5 API-DUYET-DIEM-BAN-THAY-DOI-CHO-MOBILE-2026-10-15).
  /// 'pending' | 'approved' | 'rejected'
  final String customerApprovalStatus;

  /// Lý do từ chối điểm bán (nếu có) gắn với lượt viếng thăm này (§3c SPEC-2026-10-15 chốt 16/10/2026).
  final String? customerApprovalNote;

  /// Loại lượt (nghiệp vụ 21/10/2026): 'checkin' = lượt check-in/check-out thường ·
  /// 'new_outlet' = lượt server tự ghi khi nhân viên tạo điểm bán mới (đã đóng sẵn, thời gian ở lại 0).
  final String visitKind;

  /// Nhãn loại lượt server phát: 'Lượt check-in' | 'Tạo điểm bán'
  final String? visitKindLabel;

  /// Màu Bootstrap của nhãn loại lượt: 'secondary' | 'info'
  final String? visitKindColor;

  const VisitEntity({
    required this.id,
    this.visitDate,
    this.checkinAt,
    this.checkinAtRaw,
    this.checkoutAt,
    this.checkoutAtRaw,
    this.cancelledAt,
    this.cancelledAtRaw,
    this.durationSeconds,
    required this.customerId,
    this.customerName = '',
    this.customerCode,
    this.customerAddress,
    this.routeId,
    this.routeName,
    this.isOnRoute = true,
    this.visitResult,
    this.closedNote,
    this.photoCount = 0,
    this.formCount = 0,
    this.photoUrls = const [],
    this.requirements,
    this.checkoutLat,
    this.checkoutLng,
    this.clientUuid,
    this.travelM,
    this.distanceToCustomerM,
    this.isWithinGeofence,
    this.checkoutDistanceM,
    this.isCheckoutWithinGeofence,
    this.isCheckoutOtherDay = false,
    this.customerApprovalStatus = 'approved',
    this.customerApprovalNote,
    this.visitResultLabel,
    this.visitResultColor,
    this.visitKind = kVisitKindCheckin,
    this.visitKindLabel,
    this.visitKindColor,
  });

  bool get isCustomerApproved => customerApprovalStatus == 'approved';

  /// Lượt "Tạo điểm bán" (server tự ghi, đã đóng) — không có thao tác check-out/huỷ.
  bool get isNewOutlet => visitKind == kVisitKindNewOutlet;

  /// Ánh xạ màu Bootstrap từ server sang Color của Flutter (§2.1 & §2.3 SPEC-2026-10-18)
  Color? get resultBootstrapColor => bootstrapColorOf(visitResultColor);

  /// Màu nhãn loại lượt (visit_kind_color)
  Color? get visitKindBootstrapColor => bootstrapColorOf(visitKindColor);

  /// Ánh xạ mã màu Bootstrap server phát sang Color — dùng chung cho mọi nhãn của lượt viếng thăm.
  static Color? bootstrapColorOf(String? bootstrapColor) {
    switch (bootstrapColor?.toLowerCase()) {
      case 'success':
        return const Color(0xFF16A34A);
      case 'warning':
        return const Color(0xFFD97706);
      case 'danger':
        return const Color(0xFFDC2626);
      case 'info':
        return const Color(0xFF0284C7);
      case 'secondary':
      case 'muted':
        return const Color(0xFF6B7280);
      case 'primary':
        return const Color(0xFF006E15);
      default:
        return null;
    }
  }

  /// Chuỗi hiển thị km tuân thủ 3 trạng thái (§3 SPEC-2026-10-08):
  /// - null: "—" (chưa tính)
  /// - 0: "0 km" (thiếu mốc để đo)
  /// - số > 0: "X.X km" (đã tính xong)
  String get travelKmFormatted {
    if (travelM == null) return '—';
    if (travelM == 0) return '0 km';
    final km = travelM! / 1000.0;
    return '${km.toStringAsFixed(1)} km';
  }

  /// Hiển thị khoảng cách lúc check-out tuân thủ 3 trạng thái (§3 SPEC-2026-10-13):
  /// - null: "—" (không hiện 0)
  /// - < 1000m: "X m"
  /// - >= 1000m: "X.X km"
  String get checkoutDistanceFormatted {
    if (checkoutDistanceM == null) return '—';
    if (checkoutDistanceM! < 1000) return '${checkoutDistanceM!.round()} m';
    return '${(checkoutDistanceM! / 1000.0).toStringAsFixed(1)} km';
  }

  /// Hiển thị khoảng cách lúc check-in:
  String get checkinDistanceFormatted {
    if (distanceToCustomerM == null) return '—';
    if (distanceToCustomerM! < 1000) return '${distanceToCustomerM!.round()} m';
    return '${(distanceToCustomerM! / 1000.0).toStringAsFixed(1)} km';
  }

  /// Trạng thái quãng đường: null = pending/chưa tính, 0 = thiếu mốc, > 0 = đã tính
  bool get hasTravelCalculated => travelM != null && travelM! > 0;
  bool get isTravelMissingAnchor => travelM == 0;
  bool get isTravelPending => travelM == null;

  /// Phiên viếng thăm đang mở (chưa hoàn thành check-out và chưa huỷ).
  /// Lượt "Tạo điểm bán" luôn coi là đã đóng.
  bool get isOpen => checkoutAt == null && cancelledAt == null && !isNewOutlet;

  /// Đã huỷ lượt viếng thăm (§3.1 HUY-LUOT-VIENG-THAM-2026-09-30)
  bool get isCancelled => cancelledAt != null;

  /// Đã hoàn thành check-out (lượt "Tạo điểm bán" tính là đã hoàn tất)
  bool get isCompleted => (checkoutAt != null || isNewOutlet) && cancelledAt == null;

  factory VisitEntity.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic val) {
      if (val == null) return null;
      var str = val.toString().trim();
      if (str.isEmpty || str == 'null') return null;
      try {
        str = str.replaceAll(' ', 'T');
        if (RegExp(r'[\+\-]\d{2}$').hasMatch(str)) {
          str = '$str:00';
        }
        return DateTime.parse(str).toLocal();
      } catch (_) {
        try {
          final cleanIso = str.replaceAll('+07', '+07:00').replaceAll('-07', '-07:00');
          return DateTime.parse(cleanIso).toLocal();
        } catch (_) {
          return null;
        }
      }
    }

    double? parseNullableDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      final str = val.toString().trim();
      if (str.isEmpty || str == 'null') return null;
      return double.tryParse(str);
    }

    bool? parseNullableBool(dynamic val) {
      if (val == null) return null;
      if (val == true || val == 1 || val == '1' || val == 'true') return true;
      if (val == false || val == 0 || val == '0' || val == 'false') return false;
      return null;
    }

    final rawCheckin = json['checkin_at']?.toString();
    final parsedCheckin = parseDateTime(rawCheckin);

    final rawCheckout = json['checkout_at']?.toString();
    final parsedCheckout = parseDateTime(rawCheckout);

    final rawCancelled = json['cancelled_at']?.toString();
    final parsedCancelled = parseDateTime(rawCancelled);

    VisitRequirementsEntity? req;
    if (json['requirements'] is Map<String, dynamic>) {
      req = VisitRequirementsEntity.fromJson(json['requirements'] as Map<String, dynamic>);
    }

    List<String> urls = [];
    if (json['photo_urls'] is List) {
      urls = (json['photo_urls'] as List).map((u) {
        final str = u.toString().trim();
        // §11.5: gộp cả ảnh app (đường dẫn tương đối /dms/visit-photos/public/<token>) và MobiWork (URL tuyệt đối)
        if (str.startsWith('http://') || str.startsWith('https://')) return str;
        if (str.startsWith('/')) return '${AppConstants.baseUrl}$str';
        return '${AppConstants.baseUrl}/$str';
      }).toList();
    }

    return VisitEntity(
      id: json['id'] is num
          ? (json['id'] as num).toInt()
          : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      visitDate: json['visit_date']?.toString(),
      checkinAt: parsedCheckin,
      checkinAtRaw: rawCheckin,
      checkoutAt: parsedCheckout,
      checkoutAtRaw: rawCheckout,
      cancelledAt: parsedCancelled,
      cancelledAtRaw: rawCancelled,
      durationSeconds: json['duration_seconds'] is num
          ? (json['duration_seconds'] as num).toInt()
          : int.tryParse(json['duration_seconds']?.toString() ?? ''),
      customerId: json['customer_id'] is num
          ? (json['customer_id'] as num).toInt()
          : (int.tryParse(json['customer_id']?.toString() ?? '') ?? 0),
      customerName: json['customer_name']?.toString() ?? '',
      customerCode: json['customer_code']?.toString() ?? json['code']?.toString(),
      customerAddress: json['customer_address']?.toString() ?? json['address']?.toString(),
      routeId: json['route_id'] is num
          ? (json['route_id'] as num).toInt()
          : int.tryParse(json['route_id']?.toString() ?? ''),
      routeName: json['route_name']?.toString() ?? json['route']?.toString(),
      isOnRoute: json['is_on_route'] == null ? true : json['is_on_route'] == true,
      visitResult: json['visit_result']?.toString(),
      closedNote: json['closed_note']?.toString(),
      photoCount: json['photo_count'] is num
          ? (json['photo_count'] as num).toInt()
          : (int.tryParse(json['photo_count']?.toString() ?? '') ?? 0),
      formCount: json['form_count'] is num
          ? (json['form_count'] as num).toInt()
          : (int.tryParse(json['form_count']?.toString() ?? '') ?? 0),
      photoUrls: urls,
      requirements: req,
      checkoutLat: json['checkout_lat'] != null
          ? double.tryParse(json['checkout_lat'].toString())
          : null,
      checkoutLng: json['checkout_lng'] != null
          ? double.tryParse(json['checkout_lng'].toString())
          : null,
      clientUuid: json['client_uuid']?.toString(),
      travelM: json['travel_m'] is num
          ? (json['travel_m'] as num)
          : (json['travel_m'] != null ? num.tryParse(json['travel_m'].toString()) : null),
      distanceToCustomerM: parseNullableDouble(json['distance_to_customer_m']),
      isWithinGeofence: parseNullableBool(json['is_within_geofence']),
      checkoutDistanceM: parseNullableDouble(json['checkout_distance_m']),
      isCheckoutWithinGeofence: parseNullableBool(json['is_checkout_within_geofence']),
      isCheckoutOtherDay: json['is_checkout_other_day'] == true,
      customerApprovalStatus: json['customer_approval_status']?.toString() ?? 'approved',
      customerApprovalNote: json['customer_approval_note']?.toString(),
      visitResultLabel: json['visit_result_label']?.toString(),
      visitResultColor: json['visit_result_color']?.toString(),
      visitKind: json['visit_kind']?.toString() ?? kVisitKindCheckin,
      visitKindLabel: json['visit_kind_label']?.toString(),
      visitKindColor: json['visit_kind_color']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'visit_date': visitDate,
        'checkin_at': checkinAtRaw,
        'checkout_at': checkoutAtRaw,
        'cancelled_at': cancelledAtRaw,
        'duration_seconds': durationSeconds,
        'customer_id': customerId,
        'customer_name': customerName,
        'customer_code': customerCode,
        'customer_address': customerAddress,
        'route_id': routeId,
        'route_name': routeName,
        'is_on_route': isOnRoute,
        'visit_result': visitResult,
        'closed_note': closedNote,
        'photo_count': photoCount,
        'form_count': formCount,
        'photo_urls': photoUrls,
        'requirements': requirements?.toJson(),
        'checkout_lat': checkoutLat,
        'checkout_lng': checkoutLng,
        'client_uuid': clientUuid,
        'travel_m': travelM,
        'distance_to_customer_m': distanceToCustomerM,
        'is_within_geofence': isWithinGeofence,
        'checkout_distance_m': checkoutDistanceM,
        'is_checkout_within_geofence': isCheckoutWithinGeofence,
        'is_checkout_other_day': isCheckoutOtherDay,
        'customer_approval_status': customerApprovalStatus,
        'customer_approval_note': customerApprovalNote,
        'visit_result_label': visitResultLabel,
        'visit_result_color': visitResultColor,
        'visit_kind': visitKind,
        'visit_kind_label': visitKindLabel,
        'visit_kind_color': visitKindColor,
      };

  VisitEntity copyWith({
    int? id,
    String? visitDate,
    DateTime? checkinAt,
    String? checkinAtRaw,
    DateTime? checkoutAt,
    String? checkoutAtRaw,
    DateTime? cancelledAt,
    String? cancelledAtRaw,
    int? durationSeconds,
    int? customerId,
    String? customerName,
    String? customerCode,
    String? customerAddress,
    int? routeId,
    String? routeName,
    bool? isOnRoute,
    String? visitResult,
    String? closedNote,
    int? photoCount,
    int? formCount,
    List<String>? photoUrls,
    VisitRequirementsEntity? requirements,
    double? checkoutLat,
    double? checkoutLng,
    String? clientUuid,
    num? travelM,
    double? distanceToCustomerM,
    bool? isWithinGeofence,
    double? checkoutDistanceM,
    bool? isCheckoutWithinGeofence,
    bool? isCheckoutOtherDay,
    String? customerApprovalStatus,
    String? customerApprovalNote,
    String? visitResultLabel,
    String? visitResultColor,
    String? visitKind,
    String? visitKindLabel,
    String? visitKindColor,
  }) {
    return VisitEntity(
      id: id ?? this.id,
      visitDate: visitDate ?? this.visitDate,
      checkinAt: checkinAt ?? this.checkinAt,
      checkinAtRaw: checkinAtRaw ?? this.checkinAtRaw,
      checkoutAt: checkoutAt ?? this.checkoutAt,
      checkoutAtRaw: checkoutAtRaw ?? this.checkoutAtRaw,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledAtRaw: cancelledAtRaw ?? this.cancelledAtRaw,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerCode: customerCode ?? this.customerCode,
      customerAddress: customerAddress ?? this.customerAddress,
      routeId: routeId ?? this.routeId,
      routeName: routeName ?? this.routeName,
      isOnRoute: isOnRoute ?? this.isOnRoute,
      visitResult: visitResult ?? this.visitResult,
      closedNote: closedNote ?? this.closedNote,
      photoCount: photoCount ?? this.photoCount,
      formCount: formCount ?? this.formCount,
      photoUrls: photoUrls ?? this.photoUrls,
      requirements: requirements ?? this.requirements,
      checkoutLat: checkoutLat ?? this.checkoutLat,
      checkoutLng: checkoutLng ?? this.checkoutLng,
      clientUuid: clientUuid ?? this.clientUuid,
      travelM: travelM ?? this.travelM,
      distanceToCustomerM: distanceToCustomerM ?? this.distanceToCustomerM,
      isWithinGeofence: isWithinGeofence ?? this.isWithinGeofence,
      checkoutDistanceM: checkoutDistanceM ?? this.checkoutDistanceM,
      isCheckoutWithinGeofence: isCheckoutWithinGeofence ?? this.isCheckoutWithinGeofence,
      isCheckoutOtherDay: isCheckoutOtherDay ?? this.isCheckoutOtherDay,
      customerApprovalStatus: customerApprovalStatus ?? this.customerApprovalStatus,
      customerApprovalNote: customerApprovalNote ?? this.customerApprovalNote,
      visitResultLabel: visitResultLabel ?? this.visitResultLabel,
      visitResultColor: visitResultColor ?? this.visitResultColor,
      visitKind: visitKind ?? this.visitKind,
      visitKindLabel: visitKindLabel ?? this.visitKindLabel,
      visitKindColor: visitKindColor ?? this.visitKindColor,
    );
  }
}
