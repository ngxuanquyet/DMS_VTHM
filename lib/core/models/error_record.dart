import 'dart:convert';

/// Đại diện cho một bản ghi lỗi trong hệ thống DMS VTHM
class ErrorRecord {
  final String id; // Ví dụ: ERR-VISIT-422-C301
  final DateTime timestamp;
  final String module; // AUTH, VISIT, CUST, ATTEND, LOC, NET, SYS
  final int? statusCode;
  final String? serverCode;
  final String message;
  final String? endpoint;
  final String? method;
  final dynamic requestData;
  final dynamic responseData;
  final String? curlCommand;
  final String? username;
  final String? deviceInfo;
  final String? stackTrace;
  final double? lat;
  final double? lng;
  bool sentToTelegram;

  ErrorRecord({
    required this.id,
    required this.timestamp,
    required this.module,
    this.statusCode,
    this.serverCode,
    required this.message,
    this.endpoint,
    this.method,
    this.requestData,
    this.responseData,
    this.curlCommand,
    this.username,
    this.deviceInfo,
    this.stackTrace,
    this.lat,
    this.lng,
    this.sentToTelegram = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'module': module,
      'statusCode': statusCode,
      'serverCode': serverCode,
      'message': message,
      'endpoint': endpoint,
      'method': method,
      'requestData': requestData is String ? requestData : (requestData != null ? jsonEncode(requestData) : null),
      'responseData': responseData is String ? responseData : (responseData != null ? jsonEncode(responseData) : null),
      'curlCommand': curlCommand,
      'username': username,
      'deviceInfo': deviceInfo,
      'stackTrace': stackTrace,
      'lat': lat,
      'lng': lng,
      'sentToTelegram': sentToTelegram,
    };
  }

  factory ErrorRecord.fromJson(Map<String, dynamic> json) {
    dynamic reqData = json['requestData'];
    if (reqData is String) {
      try {
        reqData = jsonDecode(reqData);
      } catch (_) {}
    }
    dynamic resData = json['responseData'];
    if (resData is String) {
      try {
        resData = jsonDecode(resData);
      } catch (_) {}
    }

    return ErrorRecord(
      id: json['id'] as String? ?? 'ERR-SYS-000-0000',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      module: json['module'] as String? ?? 'SYS',
      statusCode: json['statusCode'] as int?,
      serverCode: json['serverCode'] as String?,
      message: json['message'] as String? ?? 'Lỗi không xác định',
      endpoint: json['endpoint'] as String?,
      method: json['method'] as String?,
      requestData: reqData,
      responseData: resData,
      curlCommand: json['curlCommand'] as String?,
      username: json['username'] as String?,
      deviceInfo: json['deviceInfo'] as String?,
      stackTrace: json['stackTrace'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      sentToTelegram: json['sentToTelegram'] as bool? ?? false,
    );
  }
}
