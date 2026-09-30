class CheckinRequestModel {
  final int customerId;
  final double? lat;
  final double? lng;
  final double? accuracyM;
  final String? address;
  final bool? isMockLocation;
  final String clientUuid;
  final String? clientTime;
  final double? kmDeclared;
  final String? note;
  final Map<String, dynamic>? deviceInfo;
  final bool? isOfflineSync;
  final int? queuedSeconds;
  final String? clientBootId;

  const CheckinRequestModel({
    required this.customerId,
    this.lat,
    this.lng,
    this.accuracyM,
    this.address,
    this.isMockLocation,
    required this.clientUuid,
    this.clientTime,
    this.kmDeclared,
    this.note,
    this.deviceInfo,
    this.isOfflineSync,
    this.queuedSeconds,
    this.clientBootId,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'customer_id': customerId,
      'client_uuid': clientUuid,
    };
    if (lat != null) data['lat'] = lat;
    if (lng != null) data['lng'] = lng;
    if (accuracyM != null) data['accuracy_m'] = accuracyM;
    if (address != null && address!.isNotEmpty) data['address'] = address;
    if (isMockLocation != null) data['is_mock_location'] = isMockLocation;
    if (clientTime != null) data['client_time'] = clientTime;
    if (kmDeclared != null) data['km_declared'] = kmDeclared;
    if (note != null && note!.isNotEmpty) data['note'] = note;
    if (deviceInfo != null) data['device_info'] = deviceInfo;
    if (isOfflineSync != null) data['is_offline_sync'] = isOfflineSync;
    if (queuedSeconds != null) data['queued_seconds'] = queuedSeconds;
    if (clientBootId != null && clientBootId!.isNotEmpty) data['client_boot_id'] = clientBootId;

    return data;
  }
}
