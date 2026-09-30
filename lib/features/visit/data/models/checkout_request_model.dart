class CheckoutRequestModel {
  final String visitResult; // 'visited' | 'closed'
  final String? closedNote;
  final double? lat;
  final double? lng;
  final double? accuracyM;
  final String? clientTime;
  final int? queuedSeconds;
  final String? clientBootId;
  final bool? isOfflineSync;

  const CheckoutRequestModel({
    required this.visitResult,
    this.closedNote,
    this.lat,
    this.lng,
    this.accuracyM,
    this.clientTime,
    this.queuedSeconds,
    this.clientBootId,
    this.isOfflineSync,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'visit_result': visitResult,
    };
    if (visitResult == 'closed' && closedNote != null && closedNote!.isNotEmpty) {
      data['closed_note'] = closedNote;
    }
    if (lat != null) data['lat'] = lat;
    if (lng != null) data['lng'] = lng;
    if (accuracyM != null) data['accuracy_m'] = accuracyM;
    if (clientTime != null) data['client_time'] = clientTime;
    if (queuedSeconds != null) data['queued_seconds'] = queuedSeconds;
    if (clientBootId != null && clientBootId!.isNotEmpty) data['client_boot_id'] = clientBootId;
    if (isOfflineSync != null) data['is_offline_sync'] = isOfflineSync;

    return data;
  }
}
