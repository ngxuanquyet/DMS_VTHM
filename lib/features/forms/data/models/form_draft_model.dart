import 'dart:convert';

/// Model biểu diễn một bản nháp biểu mẫu thị trường được lưu cục bộ
class FormDraft {
  final String id;
  final int configId;
  final String configName;
  final String configCode;
  final String kind; // 'collect' | 'survey'
  final int? customerId;
  final int? visitId;
  final String? dealerName;
  final Map<String, dynamic> answers;
  final DateTime updatedAt;

  FormDraft({
    required this.id,
    required this.configId,
    required this.configName,
    required this.configCode,
    required this.kind,
    this.customerId,
    this.visitId,
    this.dealerName,
    required this.answers,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'config_id': configId,
        'config_name': configName,
        'config_code': configCode,
        'kind': kind,
        'customer_id': customerId,
        'visit_id': visitId,
        'dealer_name': dealerName,
        'answers': answers,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory FormDraft.fromJson(Map<String, dynamic> json) => FormDraft(
        id: json['id'] as String,
        configId: (json['config_id'] as num).toInt(),
        configName: json['config_name'] as String? ?? '',
        configCode: json['config_code'] as String? ?? '',
        kind: json['kind'] as String? ?? 'collect',
        customerId: json['customer_id'] != null
            ? (json['customer_id'] as num).toInt()
            : null,
        visitId: json['visit_id'] != null
            ? (json['visit_id'] as num).toInt()
            : null,
        dealerName: json['dealer_name'] as String?,
        answers: Map<String, dynamic>.from(json['answers'] as Map? ?? {}),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
            DateTime.now(),
      );

  String toRawJson() => jsonEncode(toJson());

  factory FormDraft.fromRawJson(String raw) =>
      FormDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
