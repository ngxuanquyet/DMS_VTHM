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
  final String? parentUuid; // UUID của lượt viếng thăm cha nếu đi cùng lượt offline
  final bool isOfflineSync;
  final Map<String, List<String>>? localPhotoPaths; // §5: Đường dẫn ảnh gốc trên máy phục vụ tải lại khi cần

  MarketFormSubmissionModel({
    required this.configId,
    this.visitId,
    this.customerId,
    required this.answers,
    this.submitLat,
    this.submitLng,
    this.submitAddress,
    this.parentUuid,
    String? clientUuid,
    String? clientTime,
    this.isOfflineSync = false,
    this.localPhotoPaths,
  })  : clientUuid = clientUuid ?? const Uuid().v4(),
        clientTime = clientTime ?? _formatIsoWithOffset(DateTime.now());

  /// Chuẩn hóa câu trả lời:
  /// - Loại bỏ các biến ngữ cảnh bắt đầu bằng '@' (như @customer.*) (§4)
  /// - Loại bỏ các trường thuộc nhóm trình bày (heading, divider, note) (§6)
  /// - Loại bỏ các trường đang ẩn nếu có `allowedCodes` (§5, §9)
  /// - Loại bỏ các giá trị rỗng (null, '', [], {})
  /// - Tự bọc trường ảnh thành mảng token `["<token>"]` nếu lỡ truyền chuỗi (§3)
  static Map<String, dynamic> sanitizeAnswers(
    Map<String, dynamic> rawAnswers, {
    Set<String> presentationCodes = const {},
    Set<String>? allowedCodes,
    Set<String>? imageCodes,
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

      // §3: LUÔN gửi mảng cho ô ảnh, kể cả khi chỉ có một ảnh: ["<token>"]
      if (imageCodes != null && imageCodes.contains(key)) {
        if (value is String) {
          clean[key] = [value];
          return;
        } else if (value is List) {
          final list = value.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
          if (list.isNotEmpty) {
            clean[key] = list;
          }
          return;
        }
      }

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
    Map<String, List<String>>? parsedLocalPhotos;
    if (json['_local_photo_paths'] is Map) {
      final rawMap = json['_local_photo_paths'] as Map;
      parsedLocalPhotos = rawMap.map((k, v) => MapEntry(
            k.toString(),
            v is List ? v.map((e) => e.toString()).toList() : <String>[],
          ));
    }

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
      parentUuid: json['parent_uuid']?.toString(),
      clientUuid: json['client_uuid']?.toString(),
      clientTime: json['client_time']?.toString(),
      isOfflineSync: json['is_offline_sync'] == true,
      localPhotoPaths: parsedLocalPhotos,
    );
  }

  Map<String, dynamic> toJson({bool includeInternal = false}) {
    final map = <String, dynamic>{
      'config_id': configId,
      if (visitId != null) 'visit_id': visitId,
      if (customerId != null) 'customer_id': customerId,
      if (parentUuid != null) 'parent_uuid': parentUuid,
      'answers': answers,
      if (submitLat != null) 'submit_lat': submitLat,
      if (submitLng != null) 'submit_lng': submitLng,
      if (submitAddress != null) 'submit_address': submitAddress,
      'client_uuid': clientUuid,
      'client_time': clientTime,
      'is_offline_sync': isOfflineSync,
      if (includeInternal && localPhotoPaths != null) '_local_photo_paths': localPhotoPaths,
    };
    return map;
  }
}

/// Kết quả trả về sau khi nộp biểu mẫu thành công
class MarketFormSubmitResult {
  final bool success;
  final String message;
  final int? submissionId;
  final bool isDuplicate; // §3: duplicate: true khi gửi lại cùng client_uuid

  const MarketFormSubmitResult({
    required this.success,
    required this.message,
    this.submissionId,
    this.isDuplicate = false,
  });

  factory MarketFormSubmitResult.fromJson(Map<String, dynamic> json) {
    int? id;
    bool duplicate = false;
    if (json['data'] is Map<String, dynamic>) {
      id = json['data']['id'] as int?;
      duplicate = json['data']['duplicate'] == true;
    }
    // §3 & §9: Gửi lại cùng client_uuid => server trả duplicate: true, app coi đây là thành công
    final isSuccess = json['success'] == true || duplicate;

    return MarketFormSubmitResult(
      success: isSuccess,
      message: json['message']?.toString() ?? 'Đã nộp biểu mẫu thành công',
      submissionId: id,
      isDuplicate: duplicate,
    );
  }
}

/// Chi tiết phiếu đã nộp trả về từ GET /dms/form-submissions/{id} (§4.3)
class MarketFormSubmissionDetailModel {
  final int id;
  final int configId;
  final int? visitId;
  final int? customerId;
  final Map<String, dynamic> answers;
  final Map<String, String> answerPhotos; // map token -> url xem công khai (§4.3)
  final String? clientUuid;
  final String? createdAt;

  const MarketFormSubmissionDetailModel({
    required this.id,
    required this.configId,
    this.visitId,
    this.customerId,
    required this.answers,
    this.answerPhotos = const {},
    this.clientUuid,
    this.createdAt,
  });

  factory MarketFormSubmissionDetailModel.fromJson(Map<String, dynamic> json) {
    Map<String, String> photos = {};
    if (json['answer_photos'] is Map) {
      final rawPhotos = json['answer_photos'] as Map;
      rawPhotos.forEach((k, v) {
        if (k != null && v != null) {
          photos[k.toString()] = v.toString();
        }
      });
    }

    return MarketFormSubmissionDetailModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      configId: (json['config_id'] as num?)?.toInt() ?? 0,
      visitId: (json['visit_id'] as num?)?.toInt(),
      customerId: (json['customer_id'] as num?)?.toInt(),
      answers: json['answers'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['answers'] as Map)
          : {},
      answerPhotos: photos,
      clientUuid: json['client_uuid']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  /// §4.3 & §9: Trả về đường xem công khai nếu còn tồn tại, hoặc null nếu tệp đã mất
  String? getPhotoUrl(String token) {
    return answerPhotos[token];
  }

  /// §4.3 & §9: Token có trong answers mà vắng trong answer_photos nghĩa là tệp đã mất
  bool isPhotoMissing(String token) {
    return !answerPhotos.containsKey(token);
  }
}
