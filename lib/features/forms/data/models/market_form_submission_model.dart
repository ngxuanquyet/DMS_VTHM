import 'package:uuid/uuid.dart';

/// DTO nộp phiếu biểu mẫu thị trường qua POST /dms/form-submissions
class MarketFormSubmissionModel {
  final int configId;
  final int? visitId; // Bắt buộc với 'survey', KHÔNG ĐƯỢC GỬI với 'collect'
  final int? customerId; // Bắt buộc với 'survey', tuỳ chọn với 'collect'
  final Map<String, dynamic> answers; // Khoá = resolved.code, bỏ khoá nếu rỗng, không gửi null
  final double? submitLat;
  final double? submitLng;
  final String? submitAddress;
  final String clientUuid; // UUID v4 sinh bởi app chống trùng lặp
  final String clientTime; // ISO-8601 kèm múi giờ (+07:00)
  final bool isOfflineSync;

  MarketFormSubmissionModel({
    required this.configId,
    this.visitId,
    this.customerId,
    required this.answers,
    this.submitLat,
    this.submitLng,
    this.submitAddress,
    String? clientUuid,
    String? clientTime,
    this.isOfflineSync = false,
  })  : clientUuid = clientUuid ?? const Uuid().v4(),
        clientTime = clientTime ?? _formatIsoWithOffset(DateTime.now());

  /// Chuẩn hóa câu trả lời:
  /// - Loại bỏ các biến ngữ cảnh bắt đầu bằng '@' (như @customer.*) (§4)
  /// - Loại bỏ các trường thuộc nhóm trình bày (heading, divider, note) (§6)
  /// - Loại bỏ các trường đang ẩn nếu có `allowedCodes` (§5, §9)
  /// - Loại bỏ các giá trị rỗng (null, '', [], {})
  static Map<String, dynamic> sanitizeAnswers(
    Map<String, dynamic> rawAnswers, {
    Set<String> presentationCodes = const {},
    Set<String>? allowedCodes,
  }) {
    final Map<String, dynamic> clean = {};

    rawAnswers.forEach((key, value) {
      if (key.startsWith('@')) return;
      if (presentationCodes.contains(key)) return;
      if (allowedCodes != null && !allowedCodes.contains(key)) return;
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      if (value is List && value.isEmpty) return;
      if (value is Map && value.isEmpty) return;

      clean[key] = value;
    });

    return clean;
  }

  static String _formatIsoWithOffset(DateTime dt) {
    final offset = dt.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final iso = dt.toIso8601String().split('.').first;
    return '$iso$sign$hours:$minutes';
  }

  factory MarketFormSubmissionModel.fromJson(Map<String, dynamic> json) {
    return MarketFormSubmissionModel(
      configId: json['config_id'] as int? ?? 0,
      visitId: json['visit_id'] as int?,
      customerId: json['customer_id'] as int?,
      answers: json['answers'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['answers'] as Map)
          : {},
      submitLat: (json['submit_lat'] as num?)?.toDouble(),
      submitLng: (json['submit_lng'] as num?)?.toDouble(),
      submitAddress: json['submit_address']?.toString(),
      clientUuid: json['client_uuid']?.toString(),
      clientTime: json['client_time']?.toString(),
      isOfflineSync: json['is_offline_sync'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'config_id': configId,
      if (visitId != null) 'visit_id': visitId,
      if (customerId != null) 'customer_id': customerId,
      'answers': answers,
      if (submitLat != null) 'submit_lat': submitLat,
      if (submitLng != null) 'submit_lng': submitLng,
      if (submitAddress != null) 'submit_address': submitAddress,
      'client_uuid': clientUuid,
      'client_time': clientTime,
      'is_offline_sync': isOfflineSync,
    };
    return map;
  }
}

/// Kết quả trả về sau khi nộp biểu mẫu thành công
class MarketFormSubmitResult {
  final bool success;
  final String message;
  final int? submissionId;

  const MarketFormSubmitResult({
    required this.success,
    required this.message,
    this.submissionId,
  });

  factory MarketFormSubmitResult.fromJson(Map<String, dynamic> json) {
    int? id;
    if (json['data'] is Map<String, dynamic>) {
      id = json['data']['id'] as int?;
    }
    return MarketFormSubmitResult(
      success: json['success'] == true,
      message: json['message']?.toString() ?? 'Đã nộp biểu mẫu thành công',
      submissionId: id,
    );
  }
}
