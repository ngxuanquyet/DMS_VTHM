import 'visit_material_model.dart';

/// Mục "Vật tư" ở màn chi tiết điểm bán (#24707) — CHỈ XEM, ngoài lượt viếng thăm.
///
/// Hợp đồng API (nguồn chuẩn): `docs/reference/internal-api/API-VAT-TU-MOBILE-2026-10-30.md` của repo One.
/// - `GET /dms/customers/{id}/materials`        → [OutletMaterialsSnapshot]
/// - `GET /dms/customers/{id}/material-history` → danh sách [OutletMaterialLogEntry] (phân trang, mới nhất trước)

int? _toInt(dynamic v) => materialToInt(v);

Map<String, String> _labels(dynamic raw) {
  if (raw is! Map) return const {};
  return {for (final e in raw.entries) e.key.toString(): e.value?.toString() ?? ''};
}

String? _personName(dynamic raw) {
  if (raw is! Map) return null;
  final n = raw['name']?.toString().trim() ?? '';
  return n.isEmpty ? null : n;
}

/// Tham chiếu loại gọn (`material_type`) → [OutletMaterialType] không schema.
OutletMaterialType _typeRef(dynamic raw) {
  final m = raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
  final id = _toInt(m['id']) ?? 0;
  final name = m['name']?.toString() ?? '';
  return OutletMaterialType(
    id: id,
    code: m['code']?.toString() ?? '',
    name: name.isNotEmpty ? name : '#$id',
    unit: m['unit']?.toString() ?? '',
    isActive: m['deleted'] != true,
  );
}

/// `conditions` dạng map `{mã: {name, color, is_present}}` → danh sách theo thứ tự server.
List<MaterialCondition> parseConditionMap(dynamic raw) {
  if (raw is! Map) return const [];
  return [
    for (final e in raw.entries)
      if (e.value is Map)
        MaterialCondition.fromJson({...Map<String, dynamic>.from(e.value as Map), 'code': e.key.toString()}),
  ];
}

/// Loại theo server ([serverType]: tên, đơn vị, cờ còn dùng — luôn mới) ghép `schema` của loại cùng id trong danh mục đã
/// lưu trên máy ([catalogType], có thể cũ) — schema chỉ để đọc nhãn ô / nhãn lựa chọn / ô ảnh.
OutletMaterialType withCatalogSchema(OutletMaterialType serverType, OutletMaterialType? catalogType) {
  if (catalogType?.schema == null) return serverType;
  return OutletMaterialType(
    id: serverType.id,
    code: serverType.code,
    name: serverType.name,
    unit: serverType.unit,
    isActive: serverType.isActive,
    schema: catalogType!.schema,
  );
}

/// Một dòng hiện trạng vật tư của điểm bán.
class OutletMaterialView {
  final OutletMaterialType type;
  final Map<String, int> conditionCounts;
  final int quantity;
  final Map<String, dynamic>? details;

  /// Mã ô chi tiết → nhãn (biểu mẫu hiện hành của loại).
  final Map<String, String> detailLabels;
  final String? asOf;
  final int? lastVisitId;
  final String? lastUserName;

  /// Đang ẩn vì điểm bán bị từ chối duyệt.
  final bool hidden;

  const OutletMaterialView({
    required this.type,
    this.conditionCounts = const {},
    this.quantity = 0,
    this.details,
    this.detailLabels = const {},
    this.asOf,
    this.lastVisitId,
    this.lastUserName,
    this.hidden = false,
  });

  factory OutletMaterialView.fromJson(Map<String, dynamic> json) => OutletMaterialView(
        type: _typeRef(json['material_type']),
        conditionCounts: parseConditionCounts(json['condition_counts']) ?? const {},
        quantity: _toInt(json['quantity']) ?? 0,
        details: json['details'] is Map ? Map<String, dynamic>.from(json['details'] as Map) : null,
        detailLabels: _labels(json['detail_labels']),
        asOf: json['as_of']?.toString(),
        lastVisitId: _toInt(json['last_visit_id']),
        lastUserName: _personName(json['last_user']),
        hidden: json['hidden'] == true,
      );
}

/// Hiện trạng vật tư của một điểm bán.
class OutletMaterialsSnapshot {
  final List<OutletMaterialView> items;
  final List<MaterialCondition> conditions;

  const OutletMaterialsSnapshot({this.items = const [], this.conditions = const []});

  factory OutletMaterialsSnapshot.fromJson(Map<String, dynamic> json) => OutletMaterialsSnapshot(
        items: (json['items'] is List ? json['items'] as List : const [])
            .whereType<Map>()
            .map((e) => OutletMaterialView.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        conditions: parseConditionMap(json['conditions']),
      );
}

/// Một dòng lịch sử thay đổi vật tư.
class OutletMaterialLogEntry {
  final int id;
  final OutletMaterialType type;
  final String action;
  final String actionLabel;
  final String actionColor;
  final Map<String, int> conditionCounts;
  final int quantity;
  final Map<String, dynamic>? details;
  final Map<String, String> detailLabels;

  /// `{mã tình trạng: [cũ, mới]}`.
  final Map<String, (int, int)> countChanges;

  /// `{mã ô: [cũ, mới]}`.
  final Map<String, (dynamic, dynamic)> detailChanges;
  final String? reason;
  final List<MaterialPhoto> photos;
  final int? visitId;
  final String? userName;
  final String? recordedAt;

  const OutletMaterialLogEntry({
    required this.id,
    required this.type,
    required this.action,
    this.actionLabel = '',
    this.actionColor = 'secondary',
    this.conditionCounts = const {},
    this.quantity = 0,
    this.details,
    this.detailLabels = const {},
    this.countChanges = const {},
    this.detailChanges = const {},
    this.reason,
    this.photos = const [],
    this.visitId,
    this.userName,
    this.recordedAt,
  });

  factory OutletMaterialLogEntry.fromJson(Map<String, dynamic> json) {
    final changes = json['changes'] is Map ? Map<String, dynamic>.from(json['changes'] as Map) : const {};
    final countChanges = <String, (int, int)>{};
    if (changes['counts'] is Map) {
      (changes['counts'] as Map).forEach((k, v) {
        if (v is List && v.length == 2) countChanges[k.toString()] = (_toInt(v[0]) ?? 0, _toInt(v[1]) ?? 0);
      });
    }
    final detailChanges = <String, (dynamic, dynamic)>{};
    if (changes['details'] is Map) {
      (changes['details'] as Map).forEach((k, v) {
        if (v is List && v.length == 2) detailChanges[k.toString()] = (v[0], v[1]);
      });
    }
    final action = json['action']?.toString() ?? '';
    final reason = json['reason']?.toString().trim() ?? '';
    return OutletMaterialLogEntry(
      id: _toInt(json['id']) ?? 0,
      type: _typeRef(json['material_type']),
      action: action,
      actionLabel: json['action_label']?.toString() ?? action,
      actionColor: json['action_color']?.toString() ?? 'secondary',
      conditionCounts: parseConditionCounts(json['condition_counts']) ?? const {},
      quantity: _toInt(json['quantity']) ?? 0,
      details: json['details'] is Map ? Map<String, dynamic>.from(json['details'] as Map) : null,
      detailLabels: _labels(json['detail_labels']),
      countChanges: countChanges,
      detailChanges: detailChanges,
      reason: reason.isEmpty ? null : reason,
      photos: (json['photos'] is List ? json['photos'] as List : const [])
          .whereType<Map>()
          .map((e) => MaterialPhoto.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      visitId: _toInt(json['visit_id']),
      userName: _personName(json['user']),
      recordedAt: json['recorded_at']?.toString(),
    );
  }
}

/// Một trang lịch sử.
class OutletMaterialHistoryPage {
  final List<OutletMaterialLogEntry> items;
  final int currentPage;
  final int pageCount;

  const OutletMaterialHistoryPage({this.items = const [], this.currentPage = 1, this.pageCount = 1});

  bool get hasMore => currentPage < pageCount;

  factory OutletMaterialHistoryPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] is Map ? Map<String, dynamic>.from(json['meta'] as Map) : const <String, dynamic>{};
    return OutletMaterialHistoryPage(
      items: (json['data'] is List ? json['data'] as List : const [])
          .whereType<Map>()
          .map((e) => OutletMaterialLogEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      currentPage: _toInt(meta['currentPage']) ?? 1,
      pageCount: _toInt(meta['pageCount']) ?? 1,
    );
  }
}

/// Loại vật tư có thao tác còn chờ gửi: thao tác ghi trong cache điểm bán ([outletEntry] — khoá `ops`, do màn Vật tư
/// của lượt ghi) mà [openUuids] (hàng đợi pending/sending) còn giữ.
Set<int> pendingMaterialTypeIds(Map<String, dynamic>? outletEntry, Set<String> openUuids) {
  final out = <int>{};
  final ops = outletEntry?['ops'];
  if (ops is! List || openUuids.isEmpty) return out;
  for (final o in ops) {
    if (o is! Map || o['op'] is! Map) continue;
    final op = o['op'] as Map;
    if (!openUuids.contains(op['client_uuid'])) continue;
    final id = _toInt(op['material_type_id']);
    if (id != null) out.add(id);
  }
  return out;
}
