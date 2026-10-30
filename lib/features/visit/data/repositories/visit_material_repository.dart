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

/// Kết quả nạp mục Vật tư.
class MaterialsLoadResult {
  final VisitMaterialsData? data;

  /// 403 — tài khoản không có quyền vật tư ⇒ ẩn mục.
  final bool forbidden;

  /// Đang dùng bản lưu trên máy (ngoại tuyến / lượt chưa lên server).
  final bool fromCache;
  final String? error;

  const MaterialsLoadResult({this.data, this.forbidden = false, this.fromCache = false, this.error});
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

/// Đổi mọi ảnh còn nằm trên máy (ở `photos` và ở ô ảnh trong `details`) ra token qua [upload]
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
      details[e.key] = (v is List && v.every((x) => x is String)) ? await resolveList(v.cast<String>()) : v;
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

  /// Nạp mục Vật tư. Lượt đã lên server + có mạng ⇒ gọi API (và lưu cache theo điểm bán); còn lại ⇒ cache.
  /// Thao tác còn nằm hàng đợi của lượt này được áp đè lên để hiện "đã kiểm".
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
        await _writeCache(customerId, visitClientUuid, raw);
        final overlaid = await _overlayQueued(data, visitClientUuid, includeSent: false);
        return MaterialsLoadResult(data: overlaid);
      } catch (e) {
        if (e is AppException && e.statusCode == 403) {
          return const MaterialsLoadResult(forbidden: true);
        }
        if (!isRetryableMaterialError(e)) {
          error = e is AppException ? e.message : e.toString();
        }
      }
    }

    final cached = await _readCache(customerId, visitClientUuid);
    if (cached == null) {
      return MaterialsLoadResult(error: error);
    }
    final overlaid = await _overlayQueued(cached, visitClientUuid, includeSent: true);
    return MaterialsLoadResult(data: overlaid, fromCache: true, error: error);
  }

  /// Gửi MỘT thao tác: trực tuyến gửi ngay (đọc `results[0].ok`); mất mạng / lượt chưa lên server ⇒ xếp hàng đợi với
  /// CHÍNH `client_uuid` của thao tác (server khử trùng nếu lượt trực tuyến đã kịp ghi).
  Future<MaterialSubmitOutcome> submit({
    required int visitId,
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

  Future<VisitMaterialsData> _overlayQueued(
    VisitMaterialsData data,
    String visitClientUuid, {
    required bool includeSent,
  }) async {
    List<SyncQueueEntry> entries;
    try {
      entries = await _db.getVisitMaterialEntries(visitClientUuid);
    } catch (_) {
      return data;
    }
    var out = data;
    for (final e in entries) {
      final keep = e.state == 'pending' || e.state == 'sending' || (includeSent && e.state == 'done');
      if (!keep) continue;
      final op = materialOperationFromQueuePayload(e.payload);
      if (op != null) out = applyMaterialOperation(out, op);
    }
    return out;
  }

  Future<void> _writeCache(int customerId, String visitClientUuid, Map<String, dynamic> raw) async {
    if (customerId <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$visitMaterialsCachePrefix$customerId',
        jsonEncode({'visit_client_uuid': visitClientUuid, 'data': raw}),
      );
    } catch (_) {}
  }

  /// Bản cache của lượt KHÁC thì "đã kiểm trong lượt" không còn đúng ⇒ [VisitMaterialsData.resetForNewVisit].
  Future<VisitMaterialsData?> _readCache(int customerId, String visitClientUuid) async {
    if (customerId <= 0) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$visitMaterialsCachePrefix$customerId');
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['data'] is! Map) return null;
      final data = VisitMaterialsData.fromJson(Map<String, dynamic>.from(decoded['data'] as Map));
      if (decoded['visit_client_uuid'] == visitClientUuid) return data;
      return data.resetForNewVisit();
    } catch (_) {
      return null;
    }
  }
}
