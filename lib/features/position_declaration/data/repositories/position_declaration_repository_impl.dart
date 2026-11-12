// ignore_for_file: prefer_initializing_formals
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/utils/account_key.dart';
import '../../../../core/utils/offline_photo_store.dart';
import '../../../../core/utils/system_clock.dart';
import '../../domain/entities/position_declaration_entity.dart';
import '../../domain/entities/position_reason_entity.dart';
import '../../domain/repositories/position_declaration_repository.dart';
import '../models/position_declaration_request_model.dart';
import '../services/position_declaration_api_service.dart';

final positionDeclarationApiServiceProvider =
    Provider<PositionDeclarationApiService>((ref) {
  return PositionDeclarationApiService(ref.read(apiClientProvider));
});

final positionDeclarationRepositoryProvider =
    Provider<PositionDeclarationRepository>((ref) {
  return PositionDeclarationRepositoryImpl(
    apiService: ref.read(positionDeclarationApiServiceProvider),
    database: ref.read(appDatabaseProvider),
    ref: ref,
  );
});

class PositionDeclarationRepositoryImpl implements PositionDeclarationRepository {
  final PositionDeclarationApiService _apiService;
  final AppDatabase _database;
  final Ref _ref;

  static const String _reasonsCacheKey = 'pos_reasons_active_cache';

  PositionDeclarationRepositoryImpl({
    required PositionDeclarationApiService apiService,
    required AppDatabase database,
    required Ref ref,
  })  : _apiService = apiService,
        _database = database,
        _ref = ref;

  bool get _isOnline => _ref.read(connectivityProvider).isOnline;

  @override
  Future<List<PositionReasonEntity>> getActiveReasons({
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final cachedJson = prefs.getString(_reasonsCacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final list = jsonDecode(cachedJson) as List<dynamic>;
          final cachedReasons = list
              .whereType<Map<String, dynamic>>()
              .map((e) => PositionReasonEntity.fromJson(e))
              .toList();
          if (cachedReasons.isNotEmpty) {
            // Nếu có kết nối mạng, tải ngầm làm mới cache
            if (_isOnline) {
              _fetchAndCacheReasons(prefs);
            }
            return cachedReasons;
          }
        } catch (_) {}
      }
    }

    if (_isOnline) {
      return await _fetchAndCacheReasons(prefs);
    } else {
      // Khi offline, đọc từ cache
      final cachedJson = prefs.getString(_reasonsCacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final list = jsonDecode(cachedJson) as List<dynamic>;
          return list
              .whereType<Map<String, dynamic>>()
              .map((e) => PositionReasonEntity.fromJson(e))
              .toList();
        } catch (_) {}
      }
      return const [];
    }
  }

  Future<List<PositionReasonEntity>> _fetchAndCacheReasons(
    SharedPreferences prefs,
  ) async {
    try {
      final reasons = await _apiService.getActiveReasons();
      if (reasons.isNotEmpty) {
        final jsonStr = jsonEncode(reasons.map((e) => e.toJson()).toList());
        await prefs.setString(_reasonsCacheKey, jsonStr);
      }
      return reasons;
    } catch (e) {
      debugPrint('[PositionDeclarationRepo] Lỗi tải danh mục lý do: $e');
      // Trả lại cache nếu có
      final cachedJson = prefs.getString(_reasonsCacheKey);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final list = jsonDecode(cachedJson) as List<dynamic>;
        return list
            .whereType<Map<String, dynamic>>()
            .map((e) => PositionReasonEntity.fromJson(e))
            .toList();
      }
      rethrow;
    }
  }

  @override
  Future<String> uploadPhoto(File file) async {
    final res = await _apiService.uploadPhoto(file);
    return res.token;
  }

  @override
  Future<PositionDeclarationEntity> submitDeclaration(
    PositionDeclarationEntity declaration,
  ) async {
    // 0. Ảnh chụp nằm ở thư mục tạm của camera (image_picker) — hệ điều hành dọn trước khi có mạng là khai báo chết vì
    // "mất ảnh". Chép vào chỗ lưu lâu dài TRƯỚC khi lưu / xếp hàng, cùng luật ảnh viếng thăm / chấm công / điểm bán.
    if (declaration.localPhotoPaths.isNotEmpty) {
      declaration = declaration.copyWith(
        localPhotoPaths: await OfflinePhotoStore.persist(
          declaration.localPhotoPaths,
          dirName: 'offline_declaration_photos',
          prefix: declaration.clientUuid,
        ),
      );
    }

    // 1. Lưu bản ghi cục bộ ở trạng thái pending trước
    await saveLocalDeclaration(declaration);

    // 2. Nếu đang online -> Cố gắng tải ảnh & gửi trực tiếp
    if (_isOnline) {
      try {
        final tokens = List<String>.from(declaration.photoTokens);

        // Upload các ảnh cục bộ chưa có token
        for (final path in declaration.localPhotoPaths) {
          final file = File(path);
          if (await file.exists()) {
            final token = await uploadPhoto(file);
            if (!tokens.contains(token)) {
              tokens.add(token);
            }
          }
        }

        final request = PositionDeclarationRequestModel(
          reasonId: declaration.reasonId,
          lat: declaration.lat,
          lng: declaration.lng,
          photoTokens: tokens,
          title: declaration.title,
          address: declaration.address,
          accuracyM: declaration.accuracyM,
          note: declaration.note,
          isMockLocation: declaration.isMockLocation,
          clientUuid: declaration.clientUuid,
          clientTime: declaration.clientTime,
          isOfflineSync: false,
          clientBootId: SystemClock.bootId,
        );

        final res = await _apiService.createDeclaration(request);

        final serverId = res['id'] is int ? res['id'] as int : int.tryParse(res['id']?.toString() ?? '');
        final declaredAt = res['declared_at']?.toString();
        final declaredDate = res['declared_date']?.toString();

        final syncedEntity = declaration.copyWith(
          id: serverId,
          photoTokens: tokens,
          declaredAt: declaredAt,
          declaredDate: declaredDate,
          syncStatus: 'synced',
          syncError: null,
        );

        await saveLocalDeclaration(syncedEntity);
        // Khai báo gửi trực tuyến cũng vào nhật ký đã gửi (màn Báo cáo gửi dữ liệu).
        await _database.logDirectSend(
          entity: 'declaration',
          op: 'create',
          clientUuid: declaration.clientUuid,
          payload: {'reason_name': declaration.reasonName, 'address': declaration.address},
          serverId: serverId,
        );
        return syncedEntity;
      } catch (e) {
        // CÙNG luật phân loại với hàng đợi ([isPermanentRejection]): 401 / 403 `DMS_APP_FORBIDDEN` / 408 / 429 KHÔNG phải
        // bị từ chối — đánh 'error' là khai báo nằm chết, không dòng hàng đợi nào gửi lại (server khử trùng theo
        // client_uuid nên xếp hàng an toàn).
        if (isPermanentRejection(e)) {
          await updateLocalDeclarationStatus(
            declaration.clientUuid,
            syncStatus: 'error',
            error: (e as AppException).message,
          );
          rethrow;
        }
        debugPrint('[PositionDeclarationRepo] Lỗi tạm khi gửi -> Đưa vào hàng đợi offline: $e');
      }
    }

    // 3. Đưa vào hàng đợi SyncQueueEntries để đồng bộ ngoại tuyến
    await _enqueueOfflineDeclaration(declaration);
    return declaration.copyWith(syncStatus: 'pending');
  }

  Future<void> _enqueueOfflineDeclaration(
    PositionDeclarationEntity declaration,
  ) async {
    final payloadMap = {
      'reason_id': declaration.reasonId,
      'lat': declaration.lat,
      'lng': declaration.lng,
      'photo_tokens': declaration.photoTokens,
      'local_photo_paths': declaration.localPhotoPaths,
      'title': declaration.title,
      'address': declaration.address,
      'accuracy_m': declaration.accuracyM,
      'note': declaration.note,
      'is_mock_location': declaration.isMockLocation,
      'client_uuid': declaration.clientUuid,
      'client_time': declaration.clientTime,
      'reason_code': declaration.reasonCode,
      'reason_name': declaration.reasonName,
      'reason_color': declaration.reasonColor,
    };

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _database.enqueue(
      SyncQueueEntriesCompanion.insert(
        entity: 'declaration',
        op: 'create',
        clientUuid: declaration.clientUuid,
        payload: jsonEncode(payloadMap),
        createdAt: declaration.createdAtMs > 0 ? declaration.createdAtMs : nowMs,
        // Mốc LÚC BẤM — tải ảnh + lần gửi trực tuyến vừa hỏng có thể đã chờ khá lâu.
        createdElapsed: SystemClock.monotonicMsAt(
            declaration.createdAtMs > 0 ? DateTime.fromMillisecondsSinceEpoch(declaration.createdAtMs) : null),
        bootId: SystemClock.bootId,
      ),
    );
  }

  @override
  Future<List<PositionDeclarationEntity>> getLocalDeclarations() async {
    final prefs = await SharedPreferences.getInstance();
    final key = declarationsListKey(prefs);
    if (key == null) return const [];
    final jsonStr = prefs.getString(key);
    if (jsonStr == null || jsonStr.isEmpty) return const [];

    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      final declarations = list
          .whereType<Map<String, dynamic>>()
          .map((e) => PositionDeclarationEntity.fromJson(e))
          .toList();

      // Sắp xếp bản ghi mới nhất lên đầu
      declarations.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
      return declarations;
    } catch (e) {
      debugPrint('[PositionDeclarationRepo] Lỗi đọc danh sách lịch sử: $e');
      return const [];
    }
  }

  @override
  Future<void> saveLocalDeclaration(
    PositionDeclarationEntity declaration,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = declarationsListKey(prefs);
    if (key == null) return;
    final currentList = await getLocalDeclarations();

    final updated = List<PositionDeclarationEntity>.from(currentList);
    final existingIdx = updated.indexWhere(
      (e) => e.clientUuid == declaration.clientUuid,
    );

    if (existingIdx >= 0) {
      updated[existingIdx] = declaration;
    } else {
      updated.insert(0, declaration);
    }

    final jsonStr = jsonEncode(updated.map((e) => e.toJson()).toList());
    await prefs.setString(key, jsonStr);
  }

  @override
  Future<void> updateLocalDeclarationStatus(
    String clientUuid, {
    required String syncStatus,
    int? serverId,
    String? declaredAt,
    String? declaredDate,
    String? error,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = declarationsListKey(prefs);
    if (key == null) return;
    final currentList = await getLocalDeclarations();

    final updated = List<PositionDeclarationEntity>.from(currentList);
    final existingIdx = updated.indexWhere((e) => e.clientUuid == clientUuid);

    if (existingIdx >= 0) {
      final current = updated[existingIdx];
      updated[existingIdx] = current.copyWith(
        syncStatus: syncStatus,
        id: serverId ?? current.id,
        declaredAt: declaredAt ?? current.declaredAt,
        declaredDate: declaredDate ?? current.declaredDate,
        syncError: error,
      );

      final jsonStr = jsonEncode(updated.map((e) => e.toJson()).toList());
      await prefs.setString(key, jsonStr);
    }
  }
}
