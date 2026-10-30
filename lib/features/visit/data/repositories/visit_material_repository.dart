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
import '../../../../core/utils/system_clock.dart';
import '../../../forms/presentation/viewmodels/forms_view_model.dart';
import '../../domain/entities/visit_requirements_entity.dart';
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

/// Lối thoát cho thao tác vật tư lỗi máy chủ (5xx / phản hồi sai — mất mạng KHÔNG tính) trong hàng đợi: bỏ cuộc (dead)
/// chỉ khi ĐỦ [visitMaterialMaxServerFailures] lần lỗi liên tiếp VÀ chuỗi lỗi đã kéo dài ≥ [visitMaterialGiveUpAfter].
/// Check-out của lượt phải chờ thao tác vật tư ([AppDatabase.isCheckoutHeldByMaterials]); không có lối thoát thì lỗi tất
/// định giữ check-out mãi ⇒ lượt treo trên server, check-in lượt sau và đăng xuất bị chặn. Cần CẢ HAI điều kiện vì
/// "Đồng bộ ngay" / kéo làm mới / đẩy trước check-out bỏ qua lịch thử lại: chỉ đếm số lần thì vài phút API 502 lúc
/// triển khai + NV kéo làm mới 10 lần là thao tác chết oan. 30 phút đủ qua một lần máy chủ khởi động lại / triển khai,
/// đủ ngắn để NV còn ở gần điểm bán khi thấy "Lỗi đồng bộ". Luật chống kẹt của hàng đợi trên máy, không phải nghiệp vụ.
const int visitMaterialMaxServerFailures = 10;
const Duration visitMaterialGiveUpAfter = Duration(minutes: 30);

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
      ..remove('_server_failure_first_ms');
    return (jsonEncode(p), false);
  }
  final failures = (p['_server_failures'] is num ? (p['_server_failures'] as num).toInt() : 0) + 1;
  final first = p['_server_failure_first_ms'] is num ? (p['_server_failure_first_ms'] as num).toInt() : nowMs;
  p['_server_failures'] = failures;
  p['_server_failure_first_ms'] = first;
  final giveUp =
      failures >= visitMaterialMaxServerFailures && nowMs - first >= visitMaterialGiveUpAfter.inMilliseconds;
  return (jsonEncode(p), giveUp);
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
      if (key == visitMaterialsLastCatalogKey) continue;
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
  Future<String> Function(File file) upload,
) async {
  if (!op.hasLocalPhotos) return op;

  Future<List<String>> resolveList(List<String> list) async {
    final out = <String>[];
    for (final raw in list) {
      if (isPhotoToken(raw)) {
        out.add(raw);
        continue;
      }
      var path = raw;
      if (path.startsWith('file://')) path = Uri.parse(path).toFilePath();
      final file = File(path);
      if (!await file.exists()) {
        debugPrint('[VisitMaterial] Ảnh không còn trên máy, bỏ qua: $path');
        continue;
      }
      out.add(await upload(file));
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
