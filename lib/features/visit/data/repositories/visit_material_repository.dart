import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/utils/offline_photo_store.dart';
import '../../../../core/utils/system_clock.dart';
import '../../../forms/presentation/viewmodels/forms_view_model.dart';
import '../../domain/entities/visit_requirements_entity.dart';
import '../models/material_create_rules.dart';
import '../models/outlet_material_view_model.dart';
import '../models/visit_material_model.dart';
import '../services/visit_material_api_service.dart';

final visitMaterialApiServiceProvider = Provider<VisitMaterialApiService>((ref) {
  return VisitMaterialApiService(ref.watch(apiClientProvider));
});

final visitMaterialRepositoryProvider = Provider<VisitMaterialRepository>((ref) {
  return VisitMaterialRepository(ref);
});

/// Tiền tố khoá cache danh mục + hiện trạng vật tư theo điểm bán — xoá khi đăng xuất (auth_repository_impl).
const String visitMaterialsCachePrefix = 'dms_visit_materials_';

/// Khoá cache danh mục + loại bắt buộc của lần GET gần nhất (không theo điểm bán) — dùng khi điểm bán chưa có cache.
/// Cùng tiền tố [visitMaterialsCachePrefix] nên cũng bị xoá khi đăng xuất.
const String visitMaterialsLastCatalogKey = '${visitMaterialsCachePrefix}_last_catalog';

/// Bản lưu mục Vật tư ở chi tiết điểm bán (#24707): hiện trạng / trang 1 lịch sử từng loại. Cùng tiền tố
/// [visitMaterialsCachePrefix] ⇒ xoá khi đăng xuất; KHÔNG mang thao tác (`ops`) ⇒ [forgetCachedMaterialOp] bỏ qua.
const String visitMaterialsOutletViewPrefix = '${visitMaterialsCachePrefix}view_';
const String visitMaterialsOutletHistoryPrefix = '${visitMaterialsCachePrefix}history_';

/// Trần số bản lưu hiện trạng / lịch sử giữ trên máy (bỏ bản cũ nhất theo `fetched_at`) — trần kỹ thuật chống phình tệp
/// SharedPreferences (nạp cả tệp vào RAM lúc mở app), không phải nghiệp vụ: NV xem lại vài chục điểm bán gần nhất là đủ.
const int outletViewCacheMax = 60;
const int outletHistoryCacheMax = 120;

/// Lối thoát cho thao tác vật tư lỗi máy chủ (5xx / phản hồi sai — mất mạng KHÔNG tính) trong hàng đợi: bỏ cuộc (dead)
/// chỉ khi ĐỦ [visitMaterialMaxServerFailures] lần lỗi liên tiếp VÀ chuỗi lỗi đã kéo dài ≥ [visitMaterialGiveUpAfter].
/// Check-out của lượt phải chờ thao tác vật tư ([AppDatabase.isCheckoutHeld]); không có lối thoát thì lỗi tất
/// định giữ check-out mãi ⇒ lượt treo trên server, check-in lượt sau và đăng xuất bị chặn. Cần CẢ HAI điều kiện vì
/// "Đồng bộ ngay" / kéo làm mới / đẩy trước check-out bỏ qua lịch thử lại: chỉ đếm số lần thì vài phút API 502 lúc
/// triển khai + NV kéo làm mới 10 lần là thao tác chết oan. 30 phút đủ qua một lần máy chủ khởi động lại / triển khai,
/// đủ ngắn để NV còn ở gần điểm bán khi thấy "Lỗi đồng bộ". Luật chống kẹt của hàng đợi trên máy, không phải nghiệp vụ.
const int visitMaterialMaxServerFailures = 10;
const Duration visitMaterialGiveUpAfter = Duration(minutes: 30);

/// Hai lỗi máy chủ cách nhau quá khoảng này thì KHÔNG còn là "liên tiếp" — bắt đầu chuỗi mới. Lớn hơn trần lịch thử lại
/// (5 phút) cộng biên: máy ngoại tuyến / tắt máy vài giờ giữa hai lỗi không được tính thành "đã lỗi 30 phút".
const Duration visitMaterialFailureChainGap = Duration(minutes: 10);

/// Trần chờ đẩy thao tác vật tư trước check-out trực tuyến — quá trần thì check-out đi hàng đợi (vẫn đứng sau vật tư),
/// nút check-out không quay mãi.
const Duration visitMaterialFlushTimeout = Duration(seconds: 20);

Map<String, dynamic>? _payloadMap(String payload) {
  try {
    final p = jsonDecode(payload);
    if (p is Map) return Map<String, dynamic>.from(p);
  } catch (_) {}
  return null;
}

/// Số lần lỗi máy chủ liên tiếp đã ghi trong payload hàng đợi (khoá `_server_failures`; không bị "Đồng bộ ngay" đặt
/// lại như `attempts`).
int visitMaterialServerFailures(String payload) {
  final v = _payloadMap(payload)?['_server_failures'];
  return v is num ? v.toInt() : 0;
}

/// Ghi một lần lỗi của thao tác vật tư vào payload. [serverError] = máy chủ trả lỗi (5xx / phản hồi sai); false = lỗi
/// mạng / tạm khác ⇒ chuỗi lỗi máy chủ bị cắt (đặt lại). Trả payload mới (giữ nguyên khi không đổi / payload hỏng) và
/// có nên bỏ cuộc không.
(String, bool) recordVisitMaterialFailure(String payload, {required bool serverError, required int nowMs}) {
  final p = _payloadMap(payload);
  if (p == null) return (payload, false);
  if (!serverError) {
    if (!p.containsKey('_server_failures') && !p.containsKey('_server_failure_first_ms')) return (payload, false);
    p
      ..remove('_server_failures')
      ..remove('_server_failure_first_ms')
      ..remove('_server_failure_last_ms');
    return (jsonEncode(p), false);
  }
  final last = p['_server_failure_last_ms'] is num ? (p['_server_failure_last_ms'] as num).toInt() : null;
  // Khoảng nghỉ dài (ngoại tuyến, tắt máy — không có lần gửi nào để cắt chuỗi) ⇒ chuỗi cũ hết hiệu lực. Payload xếp hàng
  // từ bản app trước (có mốc đầu, THIẾU mốc gần nhất) cũng coi là đứt — không biết lần lỗi cuối là khi nào.
  final broken = last == null
      ? p.containsKey('_server_failure_first_ms')
      : nowMs - last > visitMaterialFailureChainGap.inMilliseconds;
  final failures = (broken || p['_server_failures'] is! num ? 0 : (p['_server_failures'] as num).toInt()) + 1;
  final first = !broken && p['_server_failure_first_ms'] is num ? (p['_server_failure_first_ms'] as num).toInt() : nowMs;
  p['_server_failures'] = failures;
  p['_server_failure_first_ms'] = first;
  p['_server_failure_last_ms'] = nowMs;
  final out = jsonEncode(p);
  return (out, serverFailureChainExhausted(out));
}

/// Chuỗi lỗi máy chủ ghi trong payload (bằng [recordVisitMaterialFailure]) đã tới trần bỏ cuộc chưa: ĐỦ
/// [visitMaterialMaxServerFailures] lần VÀ kéo dài ≥ [visitMaterialGiveUpAfter]. Dùng chung cho thao tác vật tư (bỏ cuộc ⇒
/// dead) và ảnh/phiếu của lượt (thôi giữ check-out, mục vẫn thử lại). Có [nowMs]: lần hỏng cuối cách quá
/// [visitMaterialFailureChainGap] thì chuỗi đã đứt (máy ngoại tuyến lâu, chưa thử lại) ⇒ không tính — cùng luật ghi chuỗi.
bool serverFailureChainExhausted(String payload, {int? nowMs}) {
  final p = _payloadMap(payload);
  if (p == null) return false;
  final failures = p['_server_failures'] is num ? (p['_server_failures'] as num).toInt() : 0;
  final first = p['_server_failure_first_ms'];
  final last = p['_server_failure_last_ms'];
  if (first is! num || last is! num) return false;
  if (nowMs != null && nowMs - last > visitMaterialFailureChainGap.inMilliseconds) return false;
  return failures >= visitMaterialMaxServerFailures && last - first >= visitMaterialGiveUpAfter.inMilliseconds;
}

/// Gỡ thao tác [clientUuid] khỏi `ops` của bản cache điểm bán; trả null nếu không có gì đổi.
Map<String, dynamic>? removeOpFromCacheEntry(Map<String, dynamic> entry, String clientUuid) {
  if (entry['ops'] is! List) return null;
  final ops = List<dynamic>.from(entry['ops'] as List);
  final before = ops.length;
  ops.removeWhere((o) => o is Map && o['op'] is Map && (o['op'] as Map)['client_uuid'] == clientUuid);
  if (ops.length == before) return null;
  return {...entry, 'ops': ops};
}

/// Server từ chối thao tác vật tư (mục hàng đợi thành dead) ⇒ gỡ nó khỏi cache MỌI điểm bán NGAY — không dựa vào dòng
/// dead còn trong DB (NV bấm "Xoá" / "Xoá hết lỗi" là dòng mất, op bị từ chối sẽ sống lại thành "đã kiểm").
Future<void> forgetCachedMaterialOp(String clientUuid) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith(visitMaterialsCachePrefix)).toList()) {
      if (key == visitMaterialsLastCatalogKey || key == visitMaterialsCreateCatalogKey) continue;
      if (key.startsWith(visitMaterialsOutletViewPrefix) || key.startsWith(visitMaterialsOutletHistoryPrefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null) continue;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) continue;
      final next = removeOpFromCacheEntry(Map<String, dynamic>.from(decoded), clientUuid);
      if (next != null) await prefs.setString(key, jsonEncode(next));
    }
  } catch (e) {
    debugPrint('[VisitMaterial] Gỡ thao tác bị từ chối khỏi cache lỗi: $e');
  }
}

/// Cache danh mục + luật "Tạo điểm bán" (GĐ1b #24526) — dùng khi mất mạng; cùng tiền tố ⇒ xoá khi đăng xuất.
const String visitMaterialsCreateCatalogKey = '${visitMaterialsCachePrefix}_create_catalog';

/// Thao tác vật tư lúc tạo điểm bán (khoá `materials` của payload tạo, dạng [MaterialOperation.toJson]) ⇒ đổi ảnh trên
/// máy ra token qua [upload] (cùng luồng ảnh thao tác vật tư của lượt). Lỗi tải ảnh được ném ra (hàng đợi thử lại).
Future<List<Map<String, dynamic>>> resolveCreateMaterials(
  dynamic raw,
  Future<String?> Function(File file) upload,
) async {
  if (raw is! List) return const [];
  final out = <Map<String, dynamic>>[];
  for (final m in raw.whereType<Map>()) {
    final op = MaterialOperation.fromJson(Map<String, dynamic>.from(m));
    out.add((await resolveOperationPhotos(op, upload)).toJson());
  }
  return out;
}

/// Bọc [upload] cho lượt tạo điểm bán TỪ HÀNG ĐỢI: ảnh vật tư bị `/dms/form-photos` từ chối (4xx) ⇒ bỏ ảnh đó (ghi
/// log), KHÔNG ném — nếu ném thì cả mục tạo điểm bán thành dead ⇒ MẤT điểm bán. Cùng hướng server (lượt ngoại tuyến bỏ
/// thao tác sai, vẫn tạo điểm bán). Lỗi mạng / 5xx vẫn ném để thử lại.
Future<String?> Function(File file) skipRejectedMaterialPhotos(Future<String> Function(File file) upload) =>
    (file) async {
      try {
        return await upload(file);
      } on AppException catch (e) {
        final code = e.statusCode;
        // 401 (phiên hết hạn), 408 (quá giờ), 429 (quá tải) là lỗi TẠM ⇒ ném để thử lại, không bỏ ảnh vĩnh viễn.
        if (code != null && code >= 400 && code < 500 && code != 401 && code != 408 && code != 429) {
          debugPrint('[VisitMaterial] Ảnh vật tư bị từ chối ($code), bỏ ảnh, vẫn tạo điểm bán: ${e.message}');
          return null;
        }
        rethrow;
      }
    };

/// Bản cache điểm bán cho điểm bán VỪA TẠO kèm vật tư: danh mục của form tạo + các thao tác đã khai (đã được server nhận
/// cùng lượt tạo). Loại bắt buộc của luật VIẾNG THĂM chưa biết ⇒ đánh dấu `required_unknown` (màn lượt đầu cảnh báo,
/// không coi là đủ / không chặn cứng).
Map<String, dynamic> createdOutletCacheEntry(Map<String, dynamic> rawCatalog, List<MaterialOperation> ops) => {
      'visit_client_uuid': null,
      'data': {
        'catalog': rawCatalog,
        'items': const [],
        'required_unknown': true,
      },
      'ops': [
        for (final op in ops) {'visit': 'create', 'op': op.toJson(), 'ok': true},
      ],
    };

/// Ghi [createdOutletCacheEntry] cho điểm bán [customerId] (nếu chưa có cache thật từ GET).
Future<void> cacheCreatedOutletMaterials(int customerId, List<MaterialOperation> ops) async {
  if (customerId <= 0 || ops.isEmpty) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    final key = '$visitMaterialsCachePrefix$customerId';
    if (prefs.getString(key) != null) return;
    final rawCat = prefs.getString(visitMaterialsCreateCatalogKey);
    final decoded = rawCat == null ? null : jsonDecode(rawCat);
    final catalog = decoded is Map && decoded['catalog'] is Map
        ? Map<String, dynamic>.from(decoded['catalog'] as Map)
        : <String, dynamic>{};
    await prefs.setString(key, jsonEncode(createdOutletCacheEntry(catalog, ops)));
  } catch (e) {
    debugPrint('[VisitMaterial] Lưu cache vật tư điểm bán mới lỗi: $e');
  }
}

/// Kết quả nạp danh mục tạo điểm bán.
class CreateCatalogLoadResult {
  final MaterialCreateCatalog? catalog;
  final bool forbidden;
  final bool fromCache;

  const CreateCatalogLoadResult({this.catalog, this.forbidden = false, this.fromCache = false});
}

/// Kết quả dựng từ cache.
class CachedMaterials {
  final VisitMaterialsData data;
  final bool requiredFromOtherOutlet;

  const CachedMaterials(this.data, {this.requiredFromOtherOutlet = false});
}

/// Ghi thêm một thao tác vào bản cache điểm bán `{visit_client_uuid, data, ops: [{visit, op, ok}]}` (tạo mới nếu chưa
/// có). [serverOk] = server đã trả `ok:true` ⇒ khi dựng lại được áp thẳng, không so mốc giờ.
Map<String, dynamic> appendOpToCacheEntry(
  Map<String, dynamic>? entry,
  String visitClientUuid,
  MaterialOperation op, {
  bool serverOk = false,
}) {
  final out = Map<String, dynamic>.from(entry ?? const {'visit_client_uuid': null, 'data': null});
  final ops = (out['ops'] is List ? List<dynamic>.from(out['ops'] as List) : <dynamic>[])
    ..removeWhere((o) => o is Map && o['op'] is Map && (o['op'] as Map)['client_uuid'] == op.clientUuid)
    ..add({'visit': visitClientUuid, 'op': op.toJson(), 'ok': serverOk});
  out['ops'] = ops;
  return out;
}

/// Thao tác còn chờ gửi (pending/sending) áp lên dữ liệu GET vừa tải — GET chưa biết chúng.
VisitMaterialsData overlayPendingQueue(VisitMaterialsData data, List<SyncQueueEntry> entries) {
  var out = data;
  for (final e in entries) {
    if (e.state != 'pending' && e.state != 'sending') continue;
    final op = materialOperationFromQueuePayload(e.payload);
    if (op != null) out = applyMaterialOperation(out, op);
  }
  return out;
}

/// Dựng mục Vật tư từ cache (ngoại tuyến / lượt chưa lên server):
/// 1. nền = GET gần nhất của điểm bán; chưa có ⇒ danh mục của lần GET gần nhất ở điểm bán khác, KHÔNG kèm loại bắt
///    buộc (luật theo loại điểm bán — chỉ cảnh báo, không chặn cứng); không có cả hai ⇒ null (màn báo "chưa tải được");
/// 2. thao tác của lượt TRƯỚC đã ghi thêm vào cache ⇒ áp, rồi xoá cờ "đã kiểm" ([VisitMaterialsData.resetForNewVisit])
///    nếu nền là của lượt khác;
/// 3. thao tác của lượt NÀY (cache + hàng đợi) ⇒ áp.
/// Thao tác bị server từ chối (mục hàng đợi dead — [deadUuids], kể cả của lượt trước) bị bỏ ở mọi bước.
CachedMaterials? materialsFromCache({
  Map<String, dynamic>? outletEntry,
  Map<String, dynamic>? lastCatalog,
  required String visitClientUuid,
  List<SyncQueueEntry> queueEntries = const [],
  Set<String> deadUuids = const {},
}) {
  VisitMaterialsData data;
  var fromOther = false;
  var sameVisit = false;
  if (outletEntry != null && outletEntry['data'] is Map) {
    data = VisitMaterialsData.fromJson(Map<String, dynamic>.from(outletEntry['data'] as Map));
    sameVisit = outletEntry['visit_client_uuid'] == visitClientUuid;
    // Cache dựng lúc tạo điểm bán: chưa biết loại bắt buộc của luật viếng thăm ⇒ cảnh báo như điểm bán khác.
    if ((outletEntry['data'] as Map)['required_unknown'] == true) fromOther = true;
  } else if (lastCatalog != null) {
    data = VisitMaterialsData.fromJson(lastCatalog).withoutRequired();
    fromOther = true;
  } else {
    return null;
  }

  final dead = {...deadUuids, ...queueEntries.where((e) => e.state == 'dead').map((e) => e.clientUuid)};
  final cachedOps = <(String?, MaterialOperation, bool)>[];
  if (outletEntry?['ops'] is List) {
    for (final o in outletEntry!['ops'] as List) {
      if (o is Map && o['op'] is Map) {
        final op = MaterialOperation.fromJson(Map<String, dynamic>.from(o['op'] as Map));
        if (!dead.contains(op.clientUuid)) cachedOps.add((o['visit']?.toString(), op, o['ok'] == true));
      }
    }
  }

  for (final (visit, op, ok) in cachedOps) {
    if (visit != visitClientUuid) data = applyMaterialOperation(data, op, trusted: ok);
  }
  // Cả nhánh "điểm bán khác / cache chưa có data": vẫn reset để cờ "đã kiểm" của op lượt TRƯỚC không lọt sang lượt này
  // (an toàn vì withoutRequired() đã bỏ loại bắt buộc).
  if (!sameVisit) data = data.resetForNewVisit();
  final seen = <String>{};
  for (final (visit, op, ok) in cachedOps) {
    if (visit == visitClientUuid) {
      data = applyMaterialOperation(data, op, trusted: ok);
      seen.add(op.clientUuid);
    }
  }
  for (final e in queueEntries) {
    if (e.state == 'dead' || seen.contains(e.clientUuid)) continue;
    final op = materialOperationFromQueuePayload(e.payload);
    if (op != null) data = applyMaterialOperation(data, op);
  }
  return CachedMaterials(data, requiredFromOtherOutlet: fromOther);
}

/// Kết quả nạp mục Vật tư.
class MaterialsLoadResult {
  final VisitMaterialsData? data;

  /// 403 — tài khoản không có quyền vật tư ⇒ ẩn mục.
  final bool forbidden;

  /// Đang dùng bản lưu trên máy (ngoại tuyến / lượt chưa lên server).
  final bool fromCache;

  /// Điểm bán chưa có cache riêng ⇒ loại bắt buộc lấy theo lần tải gần nhất ở điểm bán KHÁC (có thể lệch luật).
  final bool requiredFromOtherOutlet;
  final String? error;

  const MaterialsLoadResult({
    this.data,
    this.forbidden = false,
    this.fromCache = false,
    this.requiredFromOtherOutlet = false,
    this.error,
  });
}

/// Kết quả nạp mục Vật tư ở màn chi tiết điểm bán (#24707).
class OutletMaterialsLoadResult {
  final OutletMaterialsSnapshot? snapshot;

  /// Thời điểm lấy [snapshot] từ server (bản lưu trên máy: lúc lưu).
  final DateTime? fetchedAt;
  final bool fromCache;

  /// 403 — tài khoản không có quyền xem vật tư điểm bán ⇒ ẩn mục.
  final bool forbidden;

  /// Loại có thao tác khai trong lượt còn chờ gửi.
  final Set<int> pendingTypeIds;

  /// Loại trong danh mục đã lưu (mang `schema` chi tiết ⇒ nhãn lựa chọn đúng) theo id.
  final Map<int, OutletMaterialType> catalogTypes;
  final String? error;

  const OutletMaterialsLoadResult({
    this.snapshot,
    this.fetchedAt,
    this.fromCache = false,
    this.forbidden = false,
    this.pendingTypeIds = const {},
    this.catalogTypes = const {},
    this.error,
  });
}

/// Kết quả nạp một trang lịch sử vật tư của điểm bán.
class OutletMaterialHistoryLoadResult {
  final OutletMaterialHistoryPage? page;
  final DateTime? fetchedAt;
  final bool fromCache;
  final bool forbidden;

  /// Trang sau trang 1 khi đang ngoại tuyến (bản lưu chỉ có trang 1).
  final bool offline;
  final String? error;

  const OutletMaterialHistoryLoadResult({
    this.page,
    this.fetchedAt,
    this.fromCache = false,
    this.forbidden = false,
    this.offline = false,
    this.error,
  });
}

/// Kết quả gửi một thao tác.
class MaterialSubmitOutcome {
  final bool ok;

  /// Đã xếp hàng đợi ngoại tuyến (chưa có kết quả server).
  final bool queued;
  final String? error;
  final int? outletMaterialId;
  final VisitRequirementsEntity? requirements;

  const MaterialSubmitOutcome({
    required this.ok,
    this.queued = false,
    this.error,
    this.outletMaterialId,
    this.requirements,
  });
}

/// Đổi mọi ảnh còn nằm trên máy (ở `photos` và ở ô ẢNH [MaterialOperation.detailPhotoFields] của `details`) ra token qua [upload]
/// (`POST /dms/form-photos` — cùng luồng ô ảnh biểu mẫu thị trường). Lỗi tải ảnh ĐƯỢC ném ra để hàng đợi thử lại —
/// không gửi thao tác thiếu ảnh. Tệp không còn trên máy thì bỏ (server sẽ báo nếu thiếu ảnh bắt buộc).
Future<MaterialOperation> resolveOperationPhotos(
  MaterialOperation op,
  Future<String?> Function(File file) upload,
) async {
  if (!op.hasLocalPhotos) return op;

  Future<List<String>> resolveList(List<String> list) async {
    final out = <String>[];
    for (final raw in list) {
      if (isPhotoToken(raw)) {
        out.add(raw);
        continue;
      }
      // iOS đổi thư mục app sau cập nhật ⇒ dựng lại đường dẫn theo Documents hiện tại (#24698 vòng 3).
      final file = await OfflinePhotoStore.existingFile(raw);
      if (file == null) {
        debugPrint('[VisitMaterial] Ảnh không còn trên máy, bỏ qua: $raw');
        continue;
      }
      final token = await upload(file);
      if (token != null) out.add(token);
    }
    return out;
  }

  final photos = await resolveList(op.photos);
  Map<String, dynamic>? details;
  if (op.details != null) {
    details = <String, dynamic>{};
    for (final e in op.details!.entries) {
      final v = e.value;
      // CHỈ ô ảnh của schema — ô chọn nhiều cũng là danh sách chuỗi, đụng vào là xoá trắng giá trị.
      details[e.key] = (op.detailPhotoFields.contains(e.key) && v is List)
          ? await resolveList(v.map((x) => x.toString()).toList())
          : v;
    }
  }
  return op.withPhotos(photos, details: details);
}

/// Lỗi tạm (mất mạng / máy chủ 5xx / không rõ) ⇒ xếp hàng đợi; lỗi 4xx ⇒ báo thẳng câu của server.
bool isRetryableMaterialError(Object e) {
  if (e is SocketException || e is NetworkException) return true;
  if (e is AppException) return e.statusCode == null || e.statusCode! >= 500;
  return true;
}

class VisitMaterialRepository {
  final Ref _ref;

  /// Đã thử tải danh mục "Tạo điểm bán" cho mục Vật tư ở chi tiết điểm bán trong phiên này — không lặp lại mỗi lần nạp
  /// (403 / danh mục rỗng thì không có gì để lưu, gọi lại chỉ thêm độ trễ).
  bool _createCatalogTried = false;

  VisitMaterialRepository(this._ref);

  VisitMaterialApiService get _api => _ref.read(visitMaterialApiServiceProvider);
  AppDatabase get _db => _ref.read(appDatabaseProvider);

  Future<String> _uploadPhoto(File file) async =>
      (await _ref.read(formsApiServiceProvider).uploadPhoto(file)).token;

  /// Nạp mục Vật tư. Lượt đã lên server + có mạng ⇒ gọi API (lưu cache theo điểm bán + danh mục/loại bắt buộc gần nhất);
  /// còn lại ⇒ cache ([materialsFromCache]). Thao tác còn nằm hàng đợi của lượt này được áp đè lên để hiện "đã kiểm".
  Future<MaterialsLoadResult> load({
    required int visitId,
    required int customerId,
    required String visitClientUuid,
  }) async {
    final isOnline = _ref.read(connectivityProvider).isOnline;
    String? error;
    if (visitId > 0 && isOnline) {
      try {
        final (raw, data) = await _api.getMaterials(visitId);
        final queue = await _queueEntries(visitClientUuid);
        await _writeCache(
          customerId,
          visitClientUuid,
          raw,
          keepOpUuids: queue.where((e) => e.state == 'pending' || e.state == 'sending').map((e) => e.clientUuid).toSet(),
        );
        return MaterialsLoadResult(data: overlayPendingQueue(data, queue));
      } catch (e) {
        if (e is AppException && e.statusCode == 403) {
          return const MaterialsLoadResult(forbidden: true);
        }
        if (!isRetryableMaterialError(e)) {
          error = e is AppException ? e.message : e.toString();
        }
      }
    }

    final prefs = await _prefs();
    Set<String> deadUuids = const {};
    try {
      deadUuids = await _db.getDeadVisitMaterialUuids();
    } catch (_) {}
    final cached = materialsFromCache(
      outletEntry: _decode(prefs?.getString(_outletKey(customerId))),
      lastCatalog: _decode(prefs?.getString(visitMaterialsLastCatalogKey)),
      visitClientUuid: visitClientUuid,
      queueEntries: await _queueEntries(visitClientUuid),
      deadUuids: deadUuids,
    );
    if (cached == null) {
      return MaterialsLoadResult(error: error);
    }
    return MaterialsLoadResult(
      data: cached.data,
      fromCache: true,
      requiredFromOtherOutlet: cached.requiredFromOtherOutlet,
      error: error,
    );
  }

  /// Hiện trạng vật tư của điểm bán, ngoài lượt (#24707): có mạng ⇒ GET + lưu bản trên máy; mất mạng / lỗi tạm ⇒ bản
  /// lưu gần nhất. Kèm loại có thao tác khai trong lượt còn chờ gửi (nhãn "chờ đồng bộ").
  Future<OutletMaterialsLoadResult> loadOutletView(int customerId) async {
    final prefs = await _prefs();
    Set<int> pending = const {};
    try {
      pending = pendingMaterialTypeIds(
        _decode(prefs?.getString(_outletKey(customerId))),
        await _db.getOpenVisitMaterialUuids(),
      );
    } catch (_) {}
    var catalogTypes = _cachedCatalogTypes(prefs);

    String? error;
    if (_ref.read(connectivityProvider).isOnline) {
      try {
        final (raw, snapshot) = await _api.getOutletMaterials(customerId);
        final now = DateTime.now();
        await prefs?.setString(
          _outletViewKey(customerId),
          jsonEncode({'fetched_at': now.millisecondsSinceEpoch, 'data': raw}),
        );
        await _pruneOutletCache(prefs, visitMaterialsOutletViewPrefix, outletViewCacheMax);
        await prefs?.remove(_outletForbiddenKey);
        // Có loại mang chi tiết mà danh mục trên máy thiếu schema của nó ⇒ tải danh mục "Tạo điểm bán" (một lần/phiên)
        // để đọc nhãn lựa chọn.
        final missing = snapshot.items
            .any((i) => (i.details?.isNotEmpty ?? false) && catalogTypes[i.type.id]?.schema == null);
        if (missing && !_createCatalogTried) {
          _createCatalogTried = true;
          catalogTypes = {...catalogTypes, ...await _fetchCreateCatalogTypes()};
        }
        return OutletMaterialsLoadResult(
          snapshot: snapshot,
          fetchedAt: now,
          pendingTypeIds: pending,
          catalogTypes: catalogTypes,
        );
      } catch (e) {
        if (_isNoLongerViewable(e)) {
          // 403 mất quyền · 404/410 ngoài phạm vi xem / điểm bán đã xoá: KHÔNG hiện bản lưu cũ (kể cả khi mất mạng sau
          // đó) ⇒ bỏ bản lưu của điểm bán.
          // 403 chỉ là quyền XEM hiện trạng (lịch sử gác quyền riêng); 404/410 ⇒ bỏ cả lịch sử.
          final forbidden = (e as AppException).statusCode == 403;
          await _forgetOutletCache(prefs, customerId, history: !forbidden);
          if (forbidden) {
            // Nhớ "không có quyền xem" để mở lại khi mất mạng vẫn ẩn mục (không mời "kết nối mạng rồi thử lại").
            await prefs?.setBool(_outletForbiddenKey, true);
            return const OutletMaterialsLoadResult(forbidden: true);
          }
          return OutletMaterialsLoadResult(error: e.message);
        }
        if (!isRetryableMaterialError(e)) error = e is AppException ? e.message : e.toString();
      }
    }
    if (prefs?.getBool(_outletForbiddenKey) == true) return const OutletMaterialsLoadResult(forbidden: true);
    final cached = _decode(prefs?.getString(_outletViewKey(customerId)));
    if (cached == null || cached['data'] is! Map) {
      return OutletMaterialsLoadResult(error: error, pendingTypeIds: pending, catalogTypes: catalogTypes);
    }
    return OutletMaterialsLoadResult(
      snapshot: OutletMaterialsSnapshot.fromJson(Map<String, dynamic>.from(cached['data'] as Map)),
      fetchedAt: _msToDate(cached['fetched_at']),
      fromCache: true,
      pendingTypeIds: pending,
      catalogTypes: catalogTypes,
      error: error,
    );
  }

  /// Một trang lịch sử vật tư của MỘT loại tại điểm bán (#24707). Trang 1 được lưu trên máy để xem khi mất mạng; trang
  /// sau chỉ tải khi có mạng.
  Future<OutletMaterialHistoryLoadResult> loadOutletHistory(
    int customerId,
    int materialTypeId, {
    int page = 1,
  }) async {
    final prefs = await _prefs();
    final key = _outletHistoryKey(customerId, materialTypeId);
    String? error;
    if (_ref.read(connectivityProvider).isOnline) {
      try {
        final (raw, result) =
            await _api.getOutletMaterialHistory(customerId, materialTypeId: materialTypeId, page: page);
        final now = DateTime.now();
        if (page == 1) {
          await prefs?.setString(key, jsonEncode({'fetched_at': now.millisecondsSinceEpoch, 'body': raw}));
          await _pruneOutletCache(prefs, visitMaterialsOutletHistoryPrefix, outletHistoryCacheMax);
        }
        return OutletMaterialHistoryLoadResult(page: result, fetchedAt: now);
      } catch (e) {
        if (_isNoLongerViewable(e)) {
          // 403 chỉ là quyền XEM lịch sử ⇒ giữ bản lưu hiện trạng; 404/410 ⇒ bỏ hết của điểm bán.
          final forbidden = (e as AppException).statusCode == 403;
          await _forgetOutletCache(prefs, customerId, view: !forbidden);
          if (forbidden) return const OutletMaterialHistoryLoadResult(forbidden: true);
          return OutletMaterialHistoryLoadResult(error: e.message);
        }
        // Cùng cách mục hiện trạng: lỗi tạm (mạng / 5xx) im lặng dùng bản lưu, chỉ báo lỗi 4xx.
        if (!isRetryableMaterialError(e)) error = e is AppException ? e.message : e.toString();
        // Trang sau không có bản lưu ⇒ báo để người dùng bấm thử lại.
        if (page > 1) return OutletMaterialHistoryLoadResult(error: error, offline: error == null);
      }
    } else if (page > 1) {
      return const OutletMaterialHistoryLoadResult(offline: true);
    }
    final cached = page == 1 ? _decode(prefs?.getString(key)) : null;
    if (cached == null || cached['body'] is! Map) return OutletMaterialHistoryLoadResult(error: error);
    final body = OutletMaterialHistoryPage.fromJson(Map<String, dynamic>.from(cached['body'] as Map));
    return OutletMaterialHistoryLoadResult(
      // Bản lưu chỉ có trang 1 ⇒ không mời "tải thêm" khi đang ngoại tuyến.
      page: OutletMaterialHistoryPage(items: body.items),
      fetchedAt: _msToDate(cached['fetched_at']),
      fromCache: true,
      error: error,
    );
  }

  /// Danh mục + luật "Tạo điểm bán": có mạng ⇒ GET và lưu cache; không có / lỗi tạm ⇒ cache. 403 ⇒ ẩn bước vật tư.
  Future<CreateCatalogLoadResult> loadCreateCatalog() async {
    if (_ref.read(connectivityProvider).isOnline) {
      try {
        final (raw, catalog) = await _api.getCreateCatalog();
        final prefs = await _prefs();
        await prefs?.setString(visitMaterialsCreateCatalogKey, jsonEncode(raw));
        return CreateCatalogLoadResult(catalog: catalog);
      } catch (e) {
        if (e is AppException && e.statusCode == 403) return const CreateCatalogLoadResult(forbidden: true);
      }
    }
    final cached = _decode((await _prefs())?.getString(visitMaterialsCreateCatalogKey));
    if (cached == null) return const CreateCatalogLoadResult();
    return CreateCatalogLoadResult(catalog: MaterialCreateCatalog.fromJson(cached), fromCache: true);
  }

  /// Gửi MỘT thao tác: trực tuyến gửi ngay (đọc `results[0].ok`); mất mạng / lượt chưa lên server ⇒ xếp hàng đợi với
  /// CHÍNH `client_uuid` của thao tác (server khử trùng nếu lượt trực tuyến đã kịp ghi). Thao tác được nhận (gửi xong
  /// hoặc xếp hàng) ghi thêm vào cache điểm bán — mất mạng sau đó cổng ④ vẫn thấy "đã kiểm".
  Future<MaterialSubmitOutcome> submit({
    required int visitId,
    required int customerId,
    required String visitClientUuid,
    required String dealerName,
    required MaterialOperation op,
  }) async {
    var current = op;
    if (visitId > 0 && _ref.read(connectivityProvider).isOnline) {
      try {
        current = await resolveOperationPhotos(op, _uploadPhoto);
        final body = buildMaterialsRequest([current.toItemJson()], isOfflineSync: false);
        final res = await _api.saveMaterials(visitId, body);
        final r = res.resultFor(current.clientUuid, 0);
        if (r == null) {
          return const MaterialSubmitOutcome(ok: false, error: 'Phản hồi lưu vật tư không hợp lệ từ máy chủ.');
        }
        if (r.ok) await _appendCachedOp(customerId, visitClientUuid, current, serverOk: true);
        return MaterialSubmitOutcome(
          ok: r.ok,
          error: r.ok ? null : (r.error ?? 'Không lưu được thao tác vật tư.'),
          outletMaterialId: r.outletMaterialId,
          requirements: res.requirements,
        );
      } catch (e) {
        if (!isRetryableMaterialError(e)) {
          return MaterialSubmitOutcome(ok: false, error: e is AppException ? e.message : e.toString());
        }
        debugPrint('[VisitMaterial] Gửi trực tuyến lỗi tạm, chuyển hàng đợi: $e');
      }
    }

    await enqueue(visitId: visitId, visitClientUuid: visitClientUuid, dealerName: dealerName, op: current);
    await _appendCachedOp(customerId, visitClientUuid, current);
    return const MaterialSubmitOutcome(ok: true, queued: true);
  }

  /// Xếp thao tác vào hàng đợi ngoại tuyến — con của lượt viếng thăm ([visitClientUuid]) như ảnh / check-out.
  Future<void> enqueue({
    required int visitId,
    required String visitClientUuid,
    required String dealerName,
    required MaterialOperation op,
  }) async {
    await _db.enqueue(
      SyncQueueEntriesCompanion(
        entity: const drift.Value('visit_material'),
        op: const drift.Value('save'),
        clientUuid: drift.Value(op.clientUuid),
        parentUuid: drift.Value(visitClientUuid),
        payload: drift.Value(jsonEncode({
          'visit_id': visitId,
          'dealer_name': dealerName,
          'op': op.toJson(),
        })),
        state: const drift.Value('pending'),
        createdAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
        createdElapsed: drift.Value(SystemClock.nowMonotonicMs),
        bootId: drift.Value(SystemClock.bootId),
        attempts: const drift.Value(0),
      ),
    );
  }

  Future<List<SyncQueueEntry>> _queueEntries(String visitClientUuid) async {
    try {
      return await _db.getVisitMaterialEntries(visitClientUuid);
    } catch (_) {
      return const [];
    }
  }

  Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  static String _outletKey(int customerId) => '$visitMaterialsCachePrefix$customerId';

  /// Server từ chối HẲN việc xem vật tư điểm bán: 403 (mất quyền) · 404/410 (ngoài phạm vi xem / điểm bán đã xoá).
  /// 4xx khác (408/429/409/401 lúc làm mới phiên…) là tạm — giữ bản lưu.
  static bool _isNoLongerViewable(Object e) =>
      e is AppException && (e.statusCode == 403 || e.statusCode == 404 || e.statusCode == 410);

  /// Bỏ bản lưu hiện trạng ([view]) và/hoặc lịch sử mọi loại ([history]) của một điểm bán.
  static Future<void> _forgetOutletCache(
    SharedPreferences? prefs,
    int customerId, {
    bool view = true,
    bool history = true,
  }) async {
    if (prefs == null) return;
    try {
      if (view) await prefs.remove(_outletViewKey(customerId));
      if (!history) return;
      final hp = '$visitMaterialsOutletHistoryPrefix${customerId}_';
      for (final k in prefs.getKeys().where((k) => k.startsWith(hp)).toList()) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }

  /// Loại vật tư mang schema (nhãn lựa chọn, ô ảnh) cho mục Vật tư ở chi tiết điểm bán, từ danh mục ĐÃ LƯU: danh mục
  /// của lượt gần nhất đè danh mục "Tạo điểm bán".
  static Map<int, OutletMaterialType> _cachedCatalogTypes(SharedPreferences? prefs) {
    final out = <int, OutletMaterialType>{};
    try {
      final create = _decode(prefs?.getString(visitMaterialsCreateCatalogKey));
      if (create != null) {
        for (final t in MaterialCreateCatalog.fromJson(create).types) {
          out[t.id] = t;
        }
      }
      final last = _decode(prefs?.getString(visitMaterialsLastCatalogKey));
      if (last != null) {
        for (final t in VisitMaterialsData.fromJson(last).types) {
          out[t.id] = t;
        }
      }
    } catch (_) {}
    return out;
  }

  /// Tải danh mục "Tạo điểm bán" (cùng quyền người dùng app, được lưu lại) — khi máy chưa có danh mục nào.
  Future<Map<int, OutletMaterialType>> _fetchCreateCatalogTypes() async {
    try {
      return {for (final t in (await loadCreateCatalog()).catalog?.types ?? const <OutletMaterialType>[]) t.id: t};
    } catch (_) {
      return const {};
    }
  }

  /// Bản lưu mục Vật tư ở chi tiết điểm bán — cùng tiền tố [visitMaterialsCachePrefix] nên bị xoá khi đăng xuất.
  /// Lần GET hiện trạng gần nhất bị 403 (mọi điểm bán — quyền theo vai, không theo điểm bán).
  static const String _outletForbiddenKey = '${visitMaterialsOutletViewPrefix}forbidden';

  static String _outletViewKey(int customerId) => '$visitMaterialsOutletViewPrefix$customerId';

  static String _outletHistoryKey(int customerId, int typeId) =>
      '$visitMaterialsOutletHistoryPrefix${customerId}_$typeId';

  /// Giữ tối đa [max] bản lưu mang tiền tố [prefix] (dọn khi vượt ~10%) — bỏ bản `fetched_at` cũ nhất (bản hỏng coi như cũ nhất).
  static Future<void> _pruneOutletCache(SharedPreferences? prefs, String prefix, int max) async {
    if (prefs == null) return;
    try {
      final keys = prefs.getKeys().where((k) => k.startsWith(prefix) && k != _outletForbiddenKey).toList();
      // Dọn theo đợt (vượt trần ~10%) — mỗi lần dọn phải giải mã mọi bản lưu để đọc `fetched_at`.
      if (keys.length <= max + max ~/ 10) return;
      int at(String k) {
        final v = _decode(prefs.getString(k))?['fetched_at'];
        return v is num ? v.toInt() : 0;
      }

      final stamps = {for (final k in keys) k: at(k)};
      keys.sort((a, b) => stamps[a]!.compareTo(stamps[b]!));
      for (final k in keys.take(keys.length - max)) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }

  static DateTime? _msToDate(dynamic v) => v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;

  static Map<String, dynamic>? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final d = jsonDecode(raw);
      return d is Map ? Map<String, dynamic>.from(d) : null;
    } catch (_) {
      return null;
    }
  }

  /// GET mới ⇒ thay cache điểm bán (bỏ thao tác đã ghi thêm — GET đã gồm chúng, TRỪ [keepOpUuids] còn nằm hàng đợi chưa
  /// lên server) + lưu danh mục và loại bắt buộc gần nhất.
  Future<void> _writeCache(
    int customerId,
    String visitClientUuid,
    Map<String, dynamic> raw, {
    Set<String> keepOpUuids = const {},
  }) async {
    final prefs = await _prefs();
    if (prefs == null) return;
    try {
      if (customerId > 0) {
        final old = _decode(prefs.getString(_outletKey(customerId)));
        final kept = old?['ops'] is List
            ? (old!['ops'] as List)
                .where((o) => o is Map && o['op'] is Map && keepOpUuids.contains((o['op'] as Map)['client_uuid']))
                .toList()
            : const [];
        await prefs.setString(
          _outletKey(customerId),
          jsonEncode({'visit_client_uuid': visitClientUuid, 'data': raw, 'ops': kept}),
        );
      }
      await prefs.setString(
        visitMaterialsLastCatalogKey,
        jsonEncode({'catalog': raw['catalog'], 'required_type_ids': raw['required_type_ids']}),
      );
    } catch (_) {}
  }

  Future<void> _appendCachedOp(
    int customerId,
    String visitClientUuid,
    MaterialOperation op, {
    bool serverOk = false,
  }) async {
    if (customerId <= 0) return;
    final prefs = await _prefs();
    if (prefs == null) return;
    try {
      final next = appendOpToCacheEntry(
        _decode(prefs.getString(_outletKey(customerId))),
        visitClientUuid,
        op,
        serverOk: serverOk,
      );
      await prefs.setString(_outletKey(customerId), jsonEncode(next));
    } catch (_) {}
  }
}
