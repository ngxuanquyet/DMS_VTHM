import 'visit_material_model.dart';

/// GĐ1b (#24526) — vật tư khai LÚC TẠO điểm bán. Hợp đồng: `API-VAT-TU-MOBILE-2026-10-30.md` §4 (repo One).
///
/// `GET /dms/material-create-catalog` trả danh mục + luật "Tạo điểm bán" đã khớp TRỤC NGƯỜI (server tính); app tự khớp
/// TRỤC ĐIỂM BÁN với điểm bán đang tạo ([ruleAppliesToNewOutlet]) — chạy được khi mất mạng.

List<int>? _intList(dynamic raw) {
  if (raw is! List || raw.isEmpty) return null; // null / [] = không giới hạn trục đó
  return raw.map((e) => e is num ? e.toInt() : int.tryParse(e.toString())).whereType<int>().toList();
}

List<String>? _strList(dynamic raw) {
  if (raw is! List || raw.isEmpty) return null;
  return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
}

/// Một luật "Tạo điểm bán". Cột `null` = không giới hạn theo trục đó.
class MaterialCreateRule {
  final int id;

  /// null = MỌI loại đang bật trong danh mục.
  final List<int>? materialTypeIds;
  final List<int>? customerTypeIds;
  final List<int>? regionIds;
  final List<int>? salesChannelIds;
  final List<String>? territoryCodes;

  const MaterialCreateRule({
    required this.id,
    this.materialTypeIds,
    this.customerTypeIds,
    this.regionIds,
    this.salesChannelIds,
    this.territoryCodes,
  });

  factory MaterialCreateRule.fromJson(Map<String, dynamic> json) => MaterialCreateRule(
        id: json['id'] is num ? (json['id'] as num).toInt() : int.tryParse(json['id']?.toString() ?? '') ?? 0,
        materialTypeIds: _intList(json['material_type_ids']),
        customerTypeIds: _intList(json['customer_type_ids']),
        regionIds: _intList(json['region_ids']),
        salesChannelIds: _intList(json['sales_channel_ids']),
        territoryCodes: _strList(json['territory_codes']),
      );
}

/// Một cặp (kênh, tuyến Bravo) của điểm bán — vế null = điểm bán chưa khai vế đó.
class OutletChannelTerritoryPair {
  final int? channelId;
  final String? territoryCode;

  const OutletChannelTerritoryPair(this.channelId, this.territoryCode);
}

/// Cặp kênh × tuyến của điểm bán đang tạo từ ô Kênh (một / nhiều) + ô Tuyến (một mã). Không chọn gì ⇒ không có cặp.
List<OutletChannelTerritoryPair> pairsOfNewOutlet(dynamic ownChannelIds, dynamic territoryCode) {
  final channels = (ownChannelIds is List ? ownChannelIds : (ownChannelIds == null ? const [] : [ownChannelIds]))
      .map((e) => int.tryParse(e.toString()))
      .whereType<int>()
      .toSet()
      .toList();
  final territory = territoryCode?.toString().trim() ?? '';
  final t = territory.isEmpty ? null : territory;
  if (channels.isEmpty) return t == null ? const [] : [OutletChannelTerritoryPair(null, t)];
  return channels.map((c) => OutletChannelTerritoryPair(c, t)).toList();
}

/// Luật áp cho điểm bán đang tạo khi MỌI trục khác null đều chứa giá trị của điểm bán; trục Kênh × Tuyến khớp theo CẶP
/// (như `DmsAudienceMatcher::pairCondition` của server): luật trúng khi cả hai cột null, HOẶC có ít nhất một cặp của
/// điểm bán thoả cả hai cột (cột null = không giới hạn; vế cặp null chỉ lọt qua cột null). Không biết thì không đòi.
bool ruleAppliesToNewOutlet(
  MaterialCreateRule rule, {
  int? customerTypeId,
  int? regionId,
  List<OutletChannelTerritoryPair> pairs = const [],
}) {
  bool axis(List<int>? allowed, int? value) => allowed == null || (value != null && allowed.contains(value));
  if (!axis(rule.customerTypeIds, customerTypeId)) return false;
  if (!axis(rule.regionIds, regionId)) return false;

  final channels = rule.salesChannelIds;
  final territories = rule.territoryCodes;
  if (channels == null && territories == null) return true;
  for (final p in pairs) {
    final channelOk = channels == null || (p.channelId != null && channels.contains(p.channelId));
    final territoryOk = territories == null || (p.territoryCode != null && territories.contains(p.territoryCode));
    if (channelOk && territoryOk) return true;
  }
  return false;
}

/// Dữ liệu `GET /dms/material-create-catalog`.
class MaterialCreateCatalog {
  final List<OutletMaterialType> types;
  final List<MaterialCondition> conditions;
  final List<MaterialCreateRule> rules;

  /// `data.catalog` thô — để dựng cache vật tư cho điểm bán vừa tạo.
  final Map<String, dynamic> rawCatalog;

  const MaterialCreateCatalog({
    this.types = const [],
    this.conditions = const [],
    this.rules = const [],
    this.rawCatalog = const {},
  });

  factory MaterialCreateCatalog.fromJson(Map<String, dynamic> json) {
    final base = VisitMaterialsData.fromJson({'catalog': json['catalog']});
    final rawRules = json['create_rules'];
    return MaterialCreateCatalog(
      types: base.types,
      conditions: base.conditions,
      rules: rawRules is List
          ? rawRules.whereType<Map>().map((r) => MaterialCreateRule.fromJson(Map<String, dynamic>.from(r))).toList()
          : const [],
      rawCatalog: json['catalog'] is Map ? Map<String, dynamic>.from(json['catalog'] as Map) : const {},
    );
  }

  OutletMaterialType? typeById(int id) {
    for (final t in types) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Loại bắt buộc khi tạo điểm bán = hợp `material_type_ids` của các luật áp (null = mọi loại đang bật), theo thứ tự
  /// danh mục; loại không còn trong danh mục đang bật thì bỏ.
  List<OutletMaterialType> requiredTypesFor({
    int? customerTypeId,
    int? regionId,
    List<OutletChannelTerritoryPair> pairs = const [],
  }) {
    var all = false;
    final ids = <int>{};
    for (final r in rules) {
      if (!ruleAppliesToNewOutlet(r, customerTypeId: customerTypeId, regionId: regionId, pairs: pairs)) continue;
      if (r.materialTypeIds == null) {
        all = true;
        break;
      }
      ids.addAll(r.materialTypeIds!);
    }
    return types.where((t) => t.isActive && (all || ids.contains(t.id))).toList();
  }
}

/// Loại bắt buộc còn thiếu (chưa có thao tác `add` nào — khai SL 0 vẫn tính là đã khai).
List<OutletMaterialType> missingCreateMaterials(List<OutletMaterialType> required, Iterable<MaterialOperation> ops) {
  final declared = ops.map((o) => o.materialTypeId).toSet();
  return required.where((t) => !declared.contains(t.id)).toList();
}

/// Khoá `materials` của thân `POST /crm/customers` — mỗi phần tử khuôn §2, chỉ `add`, `client_uuid` sinh lúc bấm.
/// Ảnh phải ĐÃ đổi ra token ([resolveOperationPhotos]) trước khi gọi.
List<Map<String, dynamic>> createMaterialsPayload(Iterable<MaterialOperation> ops) =>
    ops.where((o) => o.action == MaterialAction.add).map((o) => o.toItemJson()).toList();
