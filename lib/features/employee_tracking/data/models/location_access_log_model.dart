/// Bản ghi nhật ký "Ai đã xem vị trí của tôi" theo §5 API-VI-TRI-NHAN-VIEN-MOBILE-2026-10-09.md
class LocationAccessLogItemModel {
  final int id;
  final String requestedByName;
  final String requestedAt;
  final String status; // 'pending' | 'delivered' | 'answered' | 'expired'
  final String statusLabel;
  final String? reason;
  final int? answeredPingId;

  const LocationAccessLogItemModel({
    required this.id,
    required this.requestedByName,
    required this.requestedAt,
    required this.status,
    required this.statusLabel,
    this.reason,
    this.answeredPingId,
  });

  factory LocationAccessLogItemModel.fromJson(Map<String, dynamic> json) {
    return LocationAccessLogItemModel(
      id: json['id'] as int,
      requestedByName: json['requested_by_name'] as String? ?? 'Quản lý',
      requestedAt: json['requested_at'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      statusLabel: json['status_label'] as String? ?? 'Chờ xử lý',
      reason: json['reason'] as String?,
      answeredPingId: json['answered_ping_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requested_by_name': requestedByName,
      'requested_at': requestedAt,
      'status': status,
      'status_label': statusLabel,
      if (reason != null) 'reason': reason,
      if (answeredPingId != null) 'answered_ping_id': answeredPingId,
    };
  }
}

class LocationAccessLogPaginationMeta {
  final int total;
  final int currentPage;
  final int pageSize;
  final int pageCount;

  const LocationAccessLogPaginationMeta({
    required this.total,
    required this.currentPage,
    required this.pageSize,
    required this.pageCount,
  });

  factory LocationAccessLogPaginationMeta.fromJson(Map<String, dynamic> json) {
    return LocationAccessLogPaginationMeta(
      total: json['total'] as int? ?? 0,
      currentPage: json['currentPage'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 20,
      pageCount: json['pageCount'] as int? ?? 1,
    );
  }
}

class LocationAccessLogResponseModel {
  final bool success;
  final List<LocationAccessLogItemModel> items;
  final LocationAccessLogPaginationMeta meta;

  const LocationAccessLogResponseModel({
    required this.success,
    required this.items,
    required this.meta,
  });

  factory LocationAccessLogResponseModel.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] as List<dynamic>? ?? [])
        .map((e) => LocationAccessLogItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final metaJson = json['meta'] as Map<String, dynamic>? ?? {};

    return LocationAccessLogResponseModel(
      success: json['success'] == true,
      items: list,
      meta: LocationAccessLogPaginationMeta.fromJson(metaJson),
    );
  }
}
