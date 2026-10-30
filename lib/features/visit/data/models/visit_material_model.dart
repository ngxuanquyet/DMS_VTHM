import 'dart:convert';

import '../../../forms/data/models/market_form_model.dart';
import '../../../forms/domain/entities/market_form_entity.dart';
import '../../domain/entities/visit_requirements_entity.dart';

/// Mô hình dữ liệu mục "Vật tư" của lượt viếng thăm (#24522).
///
/// Hợp đồng API (nguồn chuẩn): `docs/reference/internal-api/API-VAT-TU-MOBILE-2026-10-30.md` của repo One.
/// - `GET  /dms/visits/{id}/materials`  → [VisitMaterialsData]
/// - `POST /dms/visits/{id}/materials`  → [MaterialSaveResponse] (luôn 200 khi lô hợp lệ — đọc `ok` từng phần tử)

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

/// Đọc `condition_counts`: dòng có `id` là OBJECT (`{}` khi rỗng), dòng trống là `null`.
/// Phòng hờ server/PHP trả `[]` cho mảng rỗng ⇒ coi như `{}`.
Map<String, int>? parseConditionCounts(dynamic raw) {
  if (raw == null) return null;
  if (raw is List) return <String, int>{};
  if (raw is Map) {
    final out = <String, int>{};
    raw.forEach((k, v) {
      final n = _toInt(v);
      if (n != null) out[k.toString()] = n;
    });
    return out;
  }
  return null;
}

/// Chuỗi trông như token ảnh 32-hex của `POST /dms/form-photos` (không phải đường dẫn tệp trên máy).
bool isPhotoToken(String s) => s.length == 32 && !s.contains('/') && !s.contains(r'\');

/// Tình trạng vật tư (danh mục `catalog.conditions`).
class MaterialCondition {
  final String code;
  final String name;
  final String color; // mã màu Bootstrap
  final bool isPresent; // false = "Mất" — không còn tại điểm

  const MaterialCondition({
    required this.code,
    required this.name,
    this.color = 'secondary',
    this.isPresent = true,
  });

  factory MaterialCondition.fromJson(Map<String, dynamic> json) => MaterialCondition(
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        color: json['color']?.toString() ?? 'secondary',
        isPresent: json['is_present'] != false,
      );
}

/// Loại vật tư (danh mục `catalog.types`; cũng là `items[].type`).
class OutletMaterialType {
  final int id;
  final String code;
  final String name;
  final String unit;
  final bool requirePhoto;
  final bool isActive;

  /// Schema biểu mẫu chi tiết của loại (cùng định dạng `schema` của `GET /dms/forms/available`); null = không có chi tiết.
  final Map<String, dynamic>? schema;

  const OutletMaterialType({
    required this.id,
    this.code = '',
    required this.name,
    this.unit = '',
    this.requirePhoto = false,
    this.isActive = true,
    this.schema,
  });

  factory OutletMaterialType.fromJson(Map<String, dynamic> json) => OutletMaterialType(
        id: _toInt(json['id']) ?? 0,
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        unit: json['unit']?.toString() ?? '',
        requirePhoto: json['require_photo'] == true,
        isActive: json['is_active'] != false,
        schema: json['schema'] is Map ? Map<String, dynamic>.from(json['schema'] as Map) : null,
      );

  /// Các ô chi tiết — đọc bằng đúng bộ đọc schema của biểu mẫu thị trường.
  List<MarketFormBlockEntity> get detailBlocks =>
      schema == null ? const [] : MarketFormSchemaModel.fromJson(schema!).toEntity().blocks;
}

/// Ảnh lần kiểm gần nhất.
class MaterialPhoto {
  final String token;
  final String url;

  const MaterialPhoto({required this.token, this.url = ''});

  factory MaterialPhoto.fromJson(Map<String, dynamic> json) =>
      MaterialPhoto(token: json['token']?.toString() ?? '', url: json['url']?.toString() ?? '');
}

/// Một dòng vật tư tại điểm bán. `id == null` = loại bắt buộc điểm bán CHƯA từng khai (dòng trống).
class OutletMaterialItem {
  final int? id;
  final int materialTypeId;
  final OutletMaterialType type;
  final Map<String, int>? conditionCounts;
  final int? quantity;
  final Map<String, dynamic>? details;
  final String? asOf;
  final String? lastUserName;
  final List<MaterialPhoto> lastPhotos;
  final bool isRequired;
  final bool checkedInVisit;

  const OutletMaterialItem({
    this.id,
    required this.materialTypeId,
    required this.type,
    this.conditionCounts,
    this.quantity,
    this.details,
    this.asOf,
    this.lastUserName,
    this.lastPhotos = const [],
    this.isRequired = false,
    this.checkedInVisit = false,
  });

  /// Dòng trống: loại bắt buộc chưa khai.
  bool get isBlank => id == null;

  /// Đã khai "không có" (SL 0) — hiện mờ.
  bool get isEmptyQuantity => !isBlank && (quantity ?? 0) == 0;

  factory OutletMaterialItem.fromJson(Map<String, dynamic> json) {
    final typeId = _toInt(json['material_type_id']) ?? 0;
    final rawType = json['type'];
    final lastUser = json['last_user'];
    return OutletMaterialItem(
      id: _toInt(json['id']),
      materialTypeId: typeId,
      type: rawType is Map
          ? OutletMaterialType.fromJson(Map<String, dynamic>.from(rawType))
          : OutletMaterialType(id: typeId, name: '#$typeId'),
      conditionCounts: parseConditionCounts(json['condition_counts']),
      quantity: _toInt(json['quantity']),
      details: json['details'] is Map ? Map<String, dynamic>.from(json['details'] as Map) : null,
      asOf: json['as_of']?.toString(),
      lastUserName: lastUser is Map ? lastUser['name']?.toString() : null,
      lastPhotos: json['last_photos'] is List
          ? (json['last_photos'] as List)
              .whereType<Map>()
              .map((p) => MaterialPhoto.fromJson(Map<String, dynamic>.from(p)))
              .toList()
          : const [],
      isRequired: json['is_required'] == true,
      checkedInVisit: json['checked_in_visit'] == true,
    );
  }

  OutletMaterialItem copyWith({
    int? id,
    Map<String, int>? conditionCounts,
    int? quantity,
    Map<String, dynamic>? details,
    bool? checkedInVisit,
  }) =>
      OutletMaterialItem(
        id: id ?? this.id,
        materialTypeId: materialTypeId,
        type: type,
        conditionCounts: conditionCounts ?? this.conditionCounts,
        quantity: quantity ?? this.quantity,
        details: details ?? this.details,
        asOf: asOf,
        lastUserName: lastUserName,
        lastPhotos: lastPhotos,
        isRequired: isRequired,
        checkedInVisit: checkedInVisit ?? this.checkedInVisit,
      );
}

/// Phản hồi `GET /dms/visits/{id}/materials` (phần `data`).
class VisitMaterialsData {
  final List<OutletMaterialType> types;
  final List<MaterialCondition> conditions;
  final List<OutletMaterialItem> items;
  final List<int> requiredTypeIds;
  final List<MissingMaterialEntity> missingRequired;

  const VisitMaterialsData({
    this.types = const [],
    this.conditions = const [],
    this.items = const [],
    this.requiredTypeIds = const [],
    this.missingRequired = const [],
  });

  factory VisitMaterialsData.fromJson(Map<String, dynamic> json) {
    final catalog = json['catalog'] is Map ? Map<String, dynamic>.from(json['catalog'] as Map) : const {};
    List<Map<String, dynamic>> maps(dynamic raw) =>
        raw is List ? raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : const [];
    return VisitMaterialsData(
      types: maps(catalog['types']).map(OutletMaterialType.fromJson).toList(),
      conditions: maps(catalog['conditions']).map(MaterialCondition.fromJson).toList(),
      items: maps(json['items']).map(OutletMaterialItem.fromJson).toList(),
      requiredTypeIds: json['required_type_ids'] is List
          ? (json['required_type_ids'] as List).map(_toInt).whereType<int>().toList()
          : const [],
      missingRequired: maps(json['missing_required']).map(MissingMaterialEntity.fromJson).toList(),
    );
  }

  /// Loại cho nút "+ Thêm loại vật tư": loại đang bật trong danh mục, trừ loại đã có dòng (có `id`) tại điểm.
  List<OutletMaterialType> get addableTypes {
    final existing = items.where((i) => !i.isBlank).map((i) => i.materialTypeId).toSet();
    return types.where((t) => t.isActive && !existing.contains(t.id)).toList();
  }

  OutletMaterialType? typeById(int id) {
    for (final t in types) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Loại bắt buộc chưa kiểm trong lượt — tính lại từ [items] (sau khi áp thao tác của máy).
  List<MissingMaterialEntity> get missingAfterLocal {
    final checked = items.where((i) => i.checkedInVisit).map((i) => i.materialTypeId).toSet();
    return missingRequired.where((m) => !checked.contains(m.materialTypeId)).toList();
  }

  /// Bản cache của lượt TRƯỚC dùng cho lượt mới: chưa loại nào "đã kiểm", và mọi loại bắt buộc đều còn thiếu.
  VisitMaterialsData resetForNewVisit() {
    String nameOf(int id) {
      for (final i in items) {
        if (i.materialTypeId == id) return i.type.name;
      }
      return typeById(id)?.name ?? '#$id';
    }

    return VisitMaterialsData(
      types: types,
      conditions: conditions,
      items: items.map((i) => i.copyWith(checkedInVisit: false)).toList(),
      requiredTypeIds: requiredTypeIds,
      missingRequired: requiredTypeIds.map((id) => MissingMaterialEntity(materialTypeId: id, name: nameOf(id))).toList(),
    );
  }

  VisitMaterialsData copyWith({List<OutletMaterialItem>? items}) => VisitMaterialsData(
        types: types,
        conditions: conditions,
        items: items ?? this.items,
        requiredTypeIds: requiredTypeIds,
        missingRequired: missingRequired,
      );
}

/// Bốn thao tác của lô `POST /dms/visits/{id}/materials`.
enum MaterialAction {
  add('add'),
  update('update'),
  confirm('confirm'),
  remove('remove');

  final String apiValue;
  const MaterialAction(this.apiValue);

  static MaterialAction? fromApi(String? v) {
    for (final a in MaterialAction.values) {
      if (a.apiValue == v) return a;
    }
    return null;
  }
}

/// Một thao tác vật tư — `client_uuid` sinh LÚC BẤM (BB-2), gửi lại bao nhiêu lần cũng dùng chung uuid này.
class MaterialOperation {
  final String clientUuid;
  final int materialTypeId;
  final MaterialAction action;
  final Map<String, int>? conditionCounts;
  final Map<String, dynamic>? details;

  /// Token 32-hex hoặc đường dẫn ảnh trên máy (chưa tải được) — đường dẫn được đổi ra token trước khi gửi.
  final List<String> photos;
  final String? reason;

  const MaterialOperation({
    required this.clientUuid,
    required this.materialTypeId,
    required this.action,
    this.conditionCounts,
    this.details,
    this.photos = const [],
    this.reason,
  });

  /// Phần tử `items[i]` đúng hợp đồng: chỉ gửi khoá mà thao tác cần.
  Map<String, dynamic> toItemJson({bool? isOfflineSync, int? queuedSeconds}) {
    final m = <String, dynamic>{
      'client_uuid': clientUuid,
      'material_type_id': materialTypeId,
      'action': action.apiValue,
    };
    switch (action) {
      case MaterialAction.add:
      case MaterialAction.update:
        // Object rỗng phải ra `{}` (không phải `[]`) — Map rỗng của Dart mã hoá đúng là `{}`.
        m['condition_counts'] = Map<String, int>.from(conditionCounts ?? const {});
        if (details != null && details!.isNotEmpty) m['details'] = details;
        if (photos.isNotEmpty) m['photos'] = photos;
        break;
      case MaterialAction.confirm:
        break;
      case MaterialAction.remove:
        m['reason'] = reason ?? '';
        m['photos'] = photos;
        break;
    }
    if (isOfflineSync != null) m['is_offline_sync'] = isOfflineSync;
    if (isOfflineSync == true) m['queued_seconds'] = queuedSeconds;
    return m;
  }

  Map<String, dynamic> toJson() => {
        'client_uuid': clientUuid,
        'material_type_id': materialTypeId,
        'action': action.apiValue,
        'condition_counts': conditionCounts,
        'details': details,
        'photos': photos,
        'reason': reason,
      };

  factory MaterialOperation.fromJson(Map<String, dynamic> json) => MaterialOperation(
        clientUuid: json['client_uuid']?.toString() ?? '',
        materialTypeId: _toInt(json['material_type_id']) ?? 0,
        action: MaterialAction.fromApi(json['action']?.toString()) ?? MaterialAction.confirm,
        conditionCounts: parseConditionCounts(json['condition_counts']),
        details: json['details'] is Map ? Map<String, dynamic>.from(json['details'] as Map) : null,
        photos: json['photos'] is List ? (json['photos'] as List).map((e) => e.toString()).toList() : const [],
        reason: json['reason']?.toString(),
      );

  MaterialOperation withPhotos(List<String> resolved, {Map<String, dynamic>? details}) => MaterialOperation(
        clientUuid: clientUuid,
        materialTypeId: materialTypeId,
        action: action,
        conditionCounts: conditionCounts,
        details: details ?? this.details,
        photos: resolved,
        reason: reason,
      );

  /// Còn ảnh nằm trên máy (ở `photos` hoặc ô ảnh trong `details`) chưa đổi ra token.
  bool get hasLocalPhotos {
    if (photos.any((p) => !isPhotoToken(p))) return true;
    for (final v in (details ?? const {}).values) {
      if (v is List && v.any((p) => p is String && !isPhotoToken(p))) return true;
    }
    return false;
  }
}

/// Thân lô `POST /dms/visits/{id}/materials`.
///
/// Trực tuyến: `is_offline_sync=false`, `queued_seconds=null`. Hàng đợi: `queued_seconds` ghi ở TỪNG phần tử (phần tử
/// thắng cấp lô) vì mỗi thao tác nằm chờ một khoảng khác nhau.
Map<String, dynamic> buildMaterialsRequest(
  List<Map<String, dynamic>> items, {
  required bool isOfflineSync,
  int? queuedSeconds,
  DateTime? clientTime,
}) =>
    {
      'items': items,
      'is_offline_sync': isOfflineSync,
      'queued_seconds': isOfflineSync ? queuedSeconds : null,
      'client_time': (clientTime ?? DateTime.now()).toIso8601String(),
    };

/// Kết quả một phần tử của lô.
class MaterialSaveResult {
  final String? clientUuid;
  final bool ok;
  final String? error;
  final int? logId;
  final int? outletMaterialId;

  const MaterialSaveResult({this.clientUuid, required this.ok, this.error, this.logId, this.outletMaterialId});

  factory MaterialSaveResult.fromJson(Map<String, dynamic> json) => MaterialSaveResult(
        clientUuid: json['client_uuid']?.toString(),
        ok: json['ok'] == true,
        error: json['error']?.toString(),
        logId: _toInt(json['log_id']),
        outletMaterialId: _toInt(json['outlet_material_id']),
      );
}

/// Phản hồi lô: `results` theo đúng thứ tự gửi + `requirements` sau khi ghi.
class MaterialSaveResponse {
  final List<MaterialSaveResult> results;
  final VisitRequirementsEntity? requirements;

  const MaterialSaveResponse({this.results = const [], this.requirements});

  factory MaterialSaveResponse.fromJson(dynamic body) {
    final data = body is Map && body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : const {};
    final raw = data['results'];
    return MaterialSaveResponse(
      results: raw is List
          ? raw.whereType<Map>().map((r) => MaterialSaveResult.fromJson(Map<String, dynamic>.from(r))).toList()
          : const [],
      requirements: data['requirements'] is Map
          ? VisitRequirementsEntity.fromJson(Map<String, dynamic>.from(data['requirements'] as Map))
          : null,
    );
  }

  /// Kết quả của thao tác [clientUuid]; server có thể trả `client_uuid: null` cho phần tử hỏng ⇒ rơi về vị trí [index].
  MaterialSaveResult? resultFor(String clientUuid, int index) {
    for (final r in results) {
      if (r.clientUuid == clientUuid) return r;
    }
    return index >= 0 && index < results.length ? results[index] : null;
  }
}

/// Áp một thao tác (đã gửi được hoặc đang nằm hàng đợi) lên danh sách hiện có — để màn hình và cổng check-out ngoại
/// tuyến thấy ngay "đã kiểm", không chờ server.
VisitMaterialsData applyMaterialOperation(VisitMaterialsData data, MaterialOperation op, {int? outletMaterialId}) {
  final items = List<OutletMaterialItem>.from(data.items);
  final idx = items.indexWhere((i) => i.materialTypeId == op.materialTypeId);
  OutletMaterialItem base;
  if (idx >= 0) {
    base = items[idx];
  } else {
    final type = data.typeById(op.materialTypeId) ?? OutletMaterialType(id: op.materialTypeId, name: '#${op.materialTypeId}');
    base = OutletMaterialItem(materialTypeId: op.materialTypeId, type: type);
  }
  // id âm = dòng đã khai trên máy, chưa có id server.
  final newId = outletMaterialId ?? base.id ?? -op.materialTypeId;
  OutletMaterialItem next;
  switch (op.action) {
    case MaterialAction.confirm:
      next = base.copyWith(checkedInVisit: true);
      break;
    case MaterialAction.add:
    case MaterialAction.update:
      final counts = Map<String, int>.from(op.conditionCounts ?? const {});
      final mergedDetails = <String, dynamic>{...?base.details, ...?op.details};
      next = base.copyWith(
        id: newId,
        conditionCounts: counts,
        quantity: counts.values.fold<int>(0, (a, b) => a + b),
        details: mergedDetails,
        checkedInVisit: true,
      );
      break;
    case MaterialAction.remove:
      next = base.copyWith(id: newId, conditionCounts: const {}, quantity: 0, checkedInVisit: true);
      break;
  }
  if (idx >= 0) {
    items[idx] = next;
  } else {
    items.add(next);
  }
  return data.copyWith(items: items);
}

/// Đọc payload một dòng hàng đợi `visit_material` (dạng `{visit_id, dealer_name, op: {...}}`).
MaterialOperation? materialOperationFromQueuePayload(String payload) {
  try {
    final p = jsonDecode(payload);
    if (p is Map && p['op'] is Map) {
      return MaterialOperation.fromJson(Map<String, dynamic>.from(p['op'] as Map));
    }
  } catch (_) {}
  return null;
}
