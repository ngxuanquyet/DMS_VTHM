/// Mô hình lệnh "Xin vị trí ngay" theo §3 API-VI-TRI-NHAN-VIEN-MOBILE-2026-10-09.md
class LocationPendingRequestModel {
  final int id;
  final String requestedBy;
  final String requestedAt;
  final String expiresAt;
  final String status;
  final String statusLabel;
  final bool isOpen;
  final String? reason;

  const LocationPendingRequestModel({
    required this.id,
    required this.requestedBy,
    required this.requestedAt,
    required this.expiresAt,
    required this.status,
    required this.statusLabel,
    this.isOpen = true,
    this.reason,
  });

  /// Kiểm tra xem lệnh đã quá hạn chưa
  bool isExpired([DateTime? referenceTime]) {
    final now = referenceTime ?? DateTime.now();
    try {
      final parsed = DateTime.tryParse(expiresAt);
      if (parsed != null) {
        return now.isAfter(parsed);
      }
      // Hỗ trợ định dạng "2026-10-09 16:49:11+07"
      final normalized = expiresAt.replaceFirst(' ', 'T');
      final parsedNorm = DateTime.tryParse(normalized);
      if (parsedNorm != null) {
        return now.isAfter(parsedNorm);
      }
    } catch (_) {}
    return false;
  }

  factory LocationPendingRequestModel.fromJson(Map<String, dynamic> json) {
    return LocationPendingRequestModel(
      id: json['id'] as int,
      requestedBy: json['requested_by'] as String? ?? 'Quản lý',
      requestedAt: json['requested_at'] as String? ?? '',
      expiresAt: json['expires_at'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      statusLabel: json['status_label'] as String? ?? 'Chờ lấy vị trí',
      isOpen: json['is_open'] == true,
      reason: json['reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requested_by': requestedBy,
      'requested_at': requestedAt,
      'expires_at': expiresAt,
      'status': status,
      'status_label': statusLabel,
      'is_open': isOpen,
      if (reason != null) 'reason': reason,
    };
  }
}
