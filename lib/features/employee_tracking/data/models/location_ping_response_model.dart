import 'location_pending_request_model.dart';

/// Phản hồi của POST /dms/locations/ping theo §2
class LocationPingResponseModel {
  final bool success;
  final String message;
  final int saved;
  final int duplicated;
  final int? answeredRequestId;
  final int nextIntervalSec;
  final LocationPendingRequestModel? pendingRequest;

  const LocationPingResponseModel({
    required this.success,
    required this.message,
    required this.saved,
    required this.duplicated,
    this.answeredRequestId,
    this.nextIntervalSec = 180,
    this.pendingRequest,
  });

  factory LocationPingResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return LocationPingResponseModel(
      success: json['success'] == true,
      message: json['message'] as String? ?? '',
      saved: data['saved'] as int? ?? 0,
      duplicated: data['duplicated'] as int? ?? 0,
      answeredRequestId: data['answered_request_id'] as int?,
      nextIntervalSec: data['next_interval_sec'] as int? ?? 180,
      pendingRequest: data['pending_request'] != null
          ? LocationPendingRequestModel.fromJson(data['pending_request'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Phản hồi của GET /dms/locations/pending theo §3
class LocationPendingResponseModel {
  final bool success;
  final bool enabled;
  final int nextIntervalSec;
  final LocationPendingRequestModel? pendingRequest;

  const LocationPendingResponseModel({
    required this.success,
    required this.enabled,
    this.nextIntervalSec = 180,
    this.pendingRequest,
  });

  factory LocationPendingResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return LocationPendingResponseModel(
      success: json['success'] == true,
      enabled: data['enabled'] == true,
      nextIntervalSec: data['next_interval_sec'] as int? ?? 180,
      pendingRequest: data['pending_request'] != null
          ? LocationPendingRequestModel.fromJson(data['pending_request'] as Map<String, dynamic>)
          : null,
    );
  }
}
