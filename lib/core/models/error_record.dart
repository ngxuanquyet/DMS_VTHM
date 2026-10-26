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
  /// Máy chủ đã nhận lỗi này chưa (`POST /dms/client-errors`) — chưa thì còn trong hàng đợi gửi bù.
  bool sentToServer;

  /// Khoá tài khoản (`cacheAccountKey` — `usr_user.id`) đang đăng nhập lúc lỗi xảy ra; `null` = lỗi trước khi đăng nhập.
  ///
  /// Máy chủ gán lỗi cho người đứng sau PHIÊN gửi, nên hàng đợi chỉ được gửi lỗi của chính người đang đăng nhập —
  /// máy dùng chung, A gặp lỗi rồi đăng xuất, B đăng nhập: lỗi của A không được đứng tên B.
  final String? ownerAccountKey;

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
    this.sentToServer = false,
    this.ownerAccountKey,
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
      'sentToServer': sentToServer,
      'ownerAccountKey': ownerAccountKey,
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
      // Bản ghi của bản app cũ (chưa có khoá này — đã đi Telegram, không rõ của ai) coi như ĐÃ gửi: không đẩy hàng loạt
      // lịch sử cũ lên máy chủ dưới tên người đăng nhập đầu tiên sau khi cập nhật.
      sentToServer: json['sentToServer'] as bool? ?? true,
      ownerAccountKey: json['ownerAccountKey']?.toString(),
    );
  }
}
