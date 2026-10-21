import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import 'visit_entity.dart';

/// Entity tóm tắt một lượt viếng thăm trong lịch sử của điểm bán (§2.4 SPEC 16/10/2026)
/// GET /dms/customers/{customerId}/visit-history
class VisitHistoryItemEntity {
  final int id;
  final String? visitDate;
  final String? checkinAt;
  final String? checkoutAt;
  final int? durationSeconds;
  final int? userId;
  final String employeeName;
  final int customerId;
  final String? customerCode;
  final String? customerName;
  final String? visitResult; // 'visited' | 'closed'
  final String? visitResultLabel; // 'Điểm bán mở cửa', 'Điểm bán đóng cửa'
  final String? visitResultColor; // 'success', 'warning', 'danger'
  final String? closedNote;
  final String? note;
  final bool isFirstVisit;
  final int photoCount;
  final int formCount;
  final String customerApprovalStatus;
  final String? customerApprovalNote;
  final String visitKind; // 'checkin' | 'new_outlet' (nghiệp vụ 21/10/2026)
  final String? visitKindLabel; // 'Lượt check-in' | 'Tạo điểm bán'
  final String? visitKindColor; // 'secondary' | 'info'

  const VisitHistoryItemEntity({
    required this.id,
    this.visitDate,
    this.checkinAt,
    this.checkoutAt,
    this.durationSeconds,
    this.userId,
    required this.employeeName,
    required this.customerId,
    this.customerCode,
    this.customerName,
    this.visitResult,
    this.visitResultLabel,
    this.visitResultColor,
    this.closedNote,
    this.note,
    this.isFirstVisit = false,
    this.photoCount = 0,
    this.formCount = 0,
    this.customerApprovalStatus = 'approved',
    this.customerApprovalNote,
    this.visitKind = kVisitKindCheckin,
    this.visitKindLabel,
    this.visitKindColor,
  });

  /// Lượt "Tạo điểm bán": server tự ghi, đã đóng sẵn, thời gian ở lại 0.
  bool get isNewOutlet => visitKind == kVisitKindNewOutlet;

  Color? get visitKindBootstrapColor => VisitEntity.bootstrapColorOf(visitKindColor);

  bool get isOpen => checkoutAt == null && !isNewOutlet;
  bool get isClosedStore => visitResult == 'closed';

  String get formattedDuration {
    if (durationSeconds == null || durationSeconds! <= 0) {
      return isOpen ? 'Đang mở' : '—';
    }
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    if (minutes > 0) {
      return '$minutes phút $seconds giây';
    }
    return '$seconds giây';
  }

  factory VisitHistoryItemEntity.fromJson(Map<String, dynamic> json) {
    return VisitHistoryItemEntity(
      id: json['id'] is num ? (json['id'] as num).toInt() : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      visitDate: json['visit_date']?.toString(),
      checkinAt: json['checkin_at']?.toString(),
      checkoutAt: json['checkout_at']?.toString(),
      durationSeconds: json['duration_seconds'] is num
          ? (json['duration_seconds'] as num).toInt()
          : int.tryParse(json['duration_seconds']?.toString() ?? ''),
      userId: json['user_id'] is num
          ? (json['user_id'] as num).toInt()
          : int.tryParse(json['user_id']?.toString() ?? ''),
      employeeName: json['employee_name']?.toString() ?? 'Nhân viên',
      customerId: json['customer_id'] is num
          ? (json['customer_id'] as num).toInt()
          : (int.tryParse(json['customer_id']?.toString() ?? '') ?? 0),
      customerCode: json['customer_code']?.toString(),
      customerName: json['customer_name']?.toString(),
      visitResult: json['visit_result']?.toString(),
      visitResultLabel: json['visit_result_label']?.toString(),
      visitResultColor: json['visit_result_color']?.toString(),
      closedNote: (json['closed_note'] ?? json['closed_reason'] ?? json['reason'])?.toString(),
      note: (json['note'] ?? json['notes'] ?? json['checkout_note'] ?? json['checkin_note'] ?? json['comment'] ?? json['description'])?.toString(),
      isFirstVisit: json['is_first_visit'] == true,
      photoCount: json['photo_count'] is num
          ? (json['photo_count'] as num).toInt()
          : (int.tryParse(json['photo_count']?.toString() ?? '') ?? 0),
      formCount: json['form_count'] is num
          ? (json['form_count'] as num).toInt()
          : (int.tryParse(json['form_count']?.toString() ?? '') ?? 0),
      customerApprovalStatus: json['customer_approval_status']?.toString() ?? 'approved',
      customerApprovalNote: json['customer_approval_note']?.toString(),
      visitKind: json['visit_kind']?.toString() ?? kVisitKindCheckin,
      visitKindLabel: json['visit_kind_label']?.toString(),
      visitKindColor: json['visit_kind_color']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'visit_date': visitDate,
        'checkin_at': checkinAt,
        'checkout_at': checkoutAt,
        'duration_seconds': durationSeconds,
        'user_id': userId,
        'employee_name': employeeName,
        'customer_id': customerId,
        'customer_code': customerCode,
        'customer_name': customerName,
        'visit_result': visitResult,
        'visit_result_label': visitResultLabel,
        'visit_result_color': visitResultColor,
        'closed_note': closedNote,
        'note': note,
        'is_first_visit': isFirstVisit,
        'photo_count': photoCount,
        'form_count': formCount,
        'customer_approval_status': customerApprovalStatus,
        'customer_approval_note': customerApprovalNote,
        'visit_kind': visitKind,
        'visit_kind_label': visitKindLabel,
        'visit_kind_color': visitKindColor,
      };
}

/// Dữ liệu biểu mẫu đã nộp trong lượt viếng thăm lịch sử (§2.4)
class VisitHistoryFormEntity {
  final int id;
  final int formId;
  final String formName;
  final String? kind;
  final String? submittedAt;
  final Map<String, dynamic> answers;
  final Map<String, dynamic>? formSchemaSnapshot;
  final Map<String, dynamic>? answerLabels; // id -> "Tên (mã)"
  final Map<String, dynamic>? answerPhotos; // token -> relative path

  const VisitHistoryFormEntity({
    required this.id,
    required this.formId,
    required this.formName,
    this.kind,
    this.submittedAt,
    this.answers = const {},
    this.formSchemaSnapshot,
    this.answerLabels,
    this.answerPhotos,
  });

  factory VisitHistoryFormEntity.fromJson(Map<String, dynamic> json) {
    return VisitHistoryFormEntity(
      id: json['id'] is num ? (json['id'] as num).toInt() : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      formId: json['form_id'] is num ? (json['form_id'] as num).toInt() : (int.tryParse(json['form_id']?.toString() ?? '') ?? 0),
      formName: json['form_name']?.toString() ?? 'Biểu mẫu',
      kind: json['kind']?.toString(),
      submittedAt: json['submitted_at']?.toString(),
      answers: json['answers'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['answers'] as Map)
          : {},
      formSchemaSnapshot: json['form_schema_snapshot'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['form_schema_snapshot'] as Map)
          : null,
      answerLabels: json['answer_labels'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['answer_labels'] as Map)
          : null,
      answerPhotos: json['answer_photos'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['answer_photos'] as Map)
          : null,
    );
  }
}

/// Chi tiết đầy đủ một lượt viếng thăm lịch sử (§2.4)
/// GET /dms/customers/{customerId}/visit-history/{visitId}
class VisitHistoryDetailEntity {
  final VisitHistoryItemEntity item;
  final List<String> photoUrls;
  final List<VisitHistoryFormEntity> forms;

  const VisitHistoryDetailEntity({
    required this.item,
    this.photoUrls = const [],
    this.forms = const [],
  });

  /// URL đầy đủ của ảnh theo quy ước §11.5:
  /// - URL tuyệt đối (MobiWork http/https): giữ nguyên
  /// - Đường dẫn tương đối (App /dms/visit-photos/public/...): ghép baseUrl
  List<String> get fullPhotoUrls {
    return photoUrls.map((p) {
      final trimmed = p.trim();
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return trimmed;
      }
      if (trimmed.startsWith('/')) {
        return '${AppConstants.baseUrl}$trimmed';
      }
      return '${AppConstants.baseUrl}/$trimmed';
    }).toList();
  }

  factory VisitHistoryDetailEntity.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> itemMap = json;
    if (json['item'] is Map<String, dynamic>) {
      itemMap = Map<String, dynamic>.from(json['item'] as Map);
      if (itemMap['note'] == null && json['note'] != null) itemMap['note'] = json['note'];
      if (itemMap['closed_note'] == null && json['closed_note'] != null) itemMap['closed_note'] = json['closed_note'];
    } else if (json['visit'] is Map<String, dynamic>) {
      itemMap = Map<String, dynamic>.from(json['visit'] as Map);
      if (itemMap['note'] == null && json['note'] != null) itemMap['note'] = json['note'];
      if (itemMap['closed_note'] == null && json['closed_note'] != null) itemMap['closed_note'] = json['closed_note'];
    }
    final item = VisitHistoryItemEntity.fromJson(itemMap);

    List<String> photos = [];
    if (json['photo_urls'] is List) {
      photos = (json['photo_urls'] as List).map((e) => e.toString()).toList();
    }

    List<VisitHistoryFormEntity> formsList = [];
    if (json['forms'] is List) {
      formsList = (json['forms'] as List)
          .whereType<Map<String, dynamic>>()
          .map((f) => VisitHistoryFormEntity.fromJson(f))
          .toList();
    }

    return VisitHistoryDetailEntity(
      item: item,
      photoUrls: photos,
      forms: formsList,
    );
  }
}

/// Phân trang và metadata lịch sử viếng thăm (§2.4)
class CustomerVisitHistoryResponse {
  final List<VisitHistoryItemEntity> items;
  final int total;
  final int currentPage;
  final int pageSize;
  final int pageCount;
  final String? dateFrom;
  final String? dateTo;

  const CustomerVisitHistoryResponse({
    this.items = const [],
    this.total = 0,
    this.currentPage = 1,
    this.pageSize = 20,
    this.pageCount = 1,
    this.dateFrom,
    this.dateTo,
  });

  factory CustomerVisitHistoryResponse.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] is Map<String, dynamic> ? json['meta'] as Map<String, dynamic> : <String, dynamic>{};
    final dataList = json['data'] is List ? json['data'] as List : <dynamic>[];

    final items = dataList
        .whereType<Map<String, dynamic>>()
        .map((e) => VisitHistoryItemEntity.fromJson(e))
        .toList();

    return CustomerVisitHistoryResponse(
      items: items,
      total: meta['total'] is num ? (meta['total'] as num).toInt() : items.length,
      currentPage: meta['currentPage'] is num ? (meta['currentPage'] as num).toInt() : 1,
      pageSize: meta['pageSize'] is num ? (meta['pageSize'] as num).toInt() : 20,
      pageCount: meta['pageCount'] is num ? (meta['pageCount'] as num).toInt() : 1,
      dateFrom: meta['date_from']?.toString(),
      dateTo: meta['date_to']?.toString(),
    );
  }
}
