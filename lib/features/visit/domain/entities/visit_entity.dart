import '../../../../core/constants/app_constants.dart';
import 'visit_requirements_entity.dart';

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
  final int? routeId;
  final bool isOnRoute;
  final String? visitResult; // 'visited' | 'closed'
  final int photoCount;
  final int formCount;
  final List<String> photoUrls;
  final VisitRequirementsEntity? requirements;
  final double? checkoutLat;
  final double? checkoutLng;

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
    this.routeId,
    this.isOnRoute = true,
    this.visitResult,
    this.photoCount = 0,
    this.formCount = 0,
    this.photoUrls = const [],
    this.requirements,
    this.checkoutLat,
    this.checkoutLng,
  });

  /// Phiên viếng thăm đang mở (chưa hoàn thành check-out và chưa huỷ)
  bool get isOpen => checkoutAt == null && cancelledAt == null;

  /// Đã huỷ lượt viếng thăm (§3.1 HUY-LUOT-VIENG-THAM-2026-09-30)
  bool get isCancelled => cancelledAt != null;

  /// Đã hoàn thành check-out
  bool get isCompleted => checkoutAt != null && cancelledAt == null;

  factory VisitEntity.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic val) {
      if (val == null) return null;
      final str = val.toString().trim();
      if (str.isEmpty) return null;
      try {
        final normalized = str.replaceAllMapped(RegExp(r'\s+([\+\-]\d{2})'), (m) => m[1]!);
        return DateTime.parse(normalized).toLocal();
      } catch (_) {
        return null;
      }
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
      routeId: json['route_id'] is num
          ? (json['route_id'] as num).toInt()
          : int.tryParse(json['route_id']?.toString() ?? ''),
      isOnRoute: json['is_on_route'] == null ? true : json['is_on_route'] == true,
      visitResult: json['visit_result']?.toString(),
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
        'route_id': routeId,
        'is_on_route': isOnRoute,
        'visit_result': visitResult,
        'photo_count': photoCount,
        'form_count': formCount,
        'photo_urls': photoUrls,
        'requirements': requirements?.toJson(),
        'checkout_lat': checkoutLat,
        'checkout_lng': checkoutLng,
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
    int? routeId,
    bool? isOnRoute,
    String? visitResult,
    int? photoCount,
    int? formCount,
    List<String>? photoUrls,
    VisitRequirementsEntity? requirements,
    double? checkoutLat,
    double? checkoutLng,
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
      routeId: routeId ?? this.routeId,
      isOnRoute: isOnRoute ?? this.isOnRoute,
      visitResult: visitResult ?? this.visitResult,
      photoCount: photoCount ?? this.photoCount,
      formCount: formCount ?? this.formCount,
      photoUrls: photoUrls ?? this.photoUrls,
      requirements: requirements ?? this.requirements,
      checkoutLat: checkoutLat ?? this.checkoutLat,
      checkoutLng: checkoutLng ?? this.checkoutLng,
    );
  }
}
