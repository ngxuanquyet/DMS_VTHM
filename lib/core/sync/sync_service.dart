import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../errors/app_exceptions.dart';
import '../network/api_client.dart';
import '../network/connectivity_provider.dart';
import '../services/app_notification_service.dart';
import '../utils/image_upload_helper.dart';
import '../utils/system_clock.dart';
import '../../features/notifications/presentation/viewmodels/notifications_view_model.dart';
import '../../features/customer/presentation/viewmodels/customer_view_model.dart';
import '../../features/customer/data/utils/customer_payload_helper.dart';
import '../../features/position_declaration/data/repositories/position_declaration_repository_impl.dart';
import '../../features/route/presentation/viewmodels/route_view_model.dart';
import '../../features/visit/data/repositories/visit_repository_impl.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.read(appDatabaseProvider);
  final apiClient = ref.read(apiClientProvider);
  final service = SyncService(db, apiClient, ref);
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

class SyncDeadError {
  final int entryId;
  final String entity;
  final String clientUuid;
  final int? statusCode;
  final String message;

  const SyncDeadError({
    required this.entryId,
    required this.entity,
    required this.clientUuid,
    this.statusCode,
    required this.message,
  });

  @override
  String toString() => 'SyncDeadError(id: $entryId, entity: $entity, code: $statusCode, msg: $message)';
}

class SyncResult {
  final int totalEntries;
  final int successCount;
  final List<SyncDeadError> deadErrors;
  final int retryableCount;

  const SyncResult({
    this.totalEntries = 0,
    this.successCount = 0,
    this.deadErrors = const [],
    this.retryableCount = 0,
  });

  bool get hasDeadErrors => deadErrors.isNotEmpty;
  bool get hasErrors => deadErrors.isNotEmpty || retryableCount > 0;
  bool get isSuccess => totalEntries > 0 && deadErrors.isEmpty && retryableCount == 0;
}

enum _SyncItemStatus { success, dead, retryable }

/// Tiến trình đồng bộ ngoại tuyến (§3, §4, §8 SPEC-DONG-BO-OFFLINE-2026-09-15.md)
class SyncService {
  final AppDatabase _db;
  final ApiClient _apiClient;
  final Ref _ref;

  bool _isSyncing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _pollingTimer;
  final Random _random = Random();
  final List<SyncDeadError> _recentDeadErrors = [];

  List<SyncDeadError> get recentDeadErrors => List.unmodifiable(_recentDeadErrors);

  void clearRecentDeadErrors() {
    _recentDeadErrors.clear();
  }

  SyncService(this._db, this._apiClient, this._ref) {
    _init();
  }

  Future<void> _init() async {
    // 1. Hồi phục các mục 'sending' mồ côi về 'pending' khi khởi động (§3.3 Luật 5)
    // TUYỆT ĐỐI không hồi phục các mục 'dead' (lỗi 4xx)
    try {
      final recovered = await _db.recoverOrphanedSendingEntries();
      if (recovered > 0) {
        debugPrint('[SyncService] Đã hồi phục $recovered mục kẹt ở state "sending" về "pending"');
      }
    } catch (e) {
      debugPrint('[SyncService] Lỗi khi hồi phục sending entries: $e');
    }

    // 2. Lắng nghe thay đổi kết nối mạng (§3.3)
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        debugPrint('[SyncService] Phát hiện có mạng -> Tự động kích hoạt syncQueue()');
        syncQueue();
      }
    });

    // 3. Chu kỳ kiểm tra định kỳ (polling nhẹ mỗi 60s cho các mục đến hạn retry)
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      syncQueue();
    });

    // 4. Cảnh báo tồn đọng hàng đợi ngoại tuyến khi khởi động
    try {
      final pendingCount = await _db.countPendingSync();
      if (pendingCount >= 3) {
        _ref.read(appNotificationServiceProvider).notifyOfflineQueuePending(
              pendingCount: pendingCount,
            );
        _ref.invalidate(unreadNotificationCountProvider);
      }
    } catch (_) {}
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _pollingTimer?.cancel();
  }

  /// Kích hoạt xử lý hàng đợi đồng bộ.
  /// Tuân thủ Bất biến §3.3 Luật 4: Duy nhất MỘT tiến trình gửi chạy tại một thời điểm.
  /// Nếu [force] = true: cưỡng chế reset trạng thái stuck, bỏ qua kiểm tra nextAttemptAt (người dùng bấm đồng bộ).
  Future<SyncResult> syncQueue({bool force = false}) async {
    if (_isSyncing) {
      debugPrint('[SyncService] syncQueue đang chạy, bỏ qua lời gọi trùng lặp.');
      return const SyncResult();
    }
    _isSyncing = true;

    int successCount = 0;
    int retryableCount = 0;
    final List<SyncDeadError> currentDeadErrors = [];

    try {
      if (force) {
        // Hồi phục sending mồ côi và reset hoãn retry của pending. TUYỆT ĐỐI không đụng đến dead (4xx vĩnh viễn)
        await _db.recoverOrphanedSendingEntries(resetPendingBackoff: true);
      }

      // Kiểm tra kết nối mạng
      final isOnline = _ref.read(connectivityProvider).isOnline;
      if (!isOnline && !force) {
        debugPrint('[SyncService] Không có kết nối mạng, tạm dừng đồng bộ.');
        return const SyncResult();
      }

      // Lấy danh sách pending theo FIFO, tối đa 50 mục (§3.3 Luật 6)
      // Không bao giờ lấy các mục 'dead' (lỗi 4xx vĩnh viễn không retry)
      final entries = await _db.getPendingQueueEntries(limit: 50, force: force);
      if (entries.isEmpty) {
        debugPrint('[SyncService] Không có mục nào cần gửi trong hàng đợi.');
        if (_ref.read(connectivityProvider).isOnline) {
          try {
            _ref.read(customerViewModelProvider.notifier).loadCustomers(isRefresh: true);
          } catch (_) {}
          try {
            _ref.read(routeApiServiceProvider).getMyRoutes(forceRefresh: true);
          } catch (_) {}
        }
        return const SyncResult();
      }

      debugPrint('[SyncService] Bắt đầu đồng bộ ${entries.length} mục trong hàng đợi (force: $force)...');

      for (final entry in entries) {
        // Kiểm tra lại kết nối trước mỗi mục (trừ khi force)
        if (!_ref.read(connectivityProvider).isOnline && !force) {
          debugPrint('[SyncService] Mất mạng giữa chừng, dừng lô đồng bộ.');
          break;
        }

        final status = await _processEntry(entry, currentDeadErrors);
        if (status == _SyncItemStatus.success) {
          successCount++;
        } else if (status == _SyncItemStatus.dead) {
          // currentDeadErrors already populated
        } else if (status == _SyncItemStatus.retryable) {
          retryableCount++;
        }
      }

      if (successCount > 0) {
        try {
          _ref.read(appNotificationServiceProvider).notifyOfflineSyncSuccess(
                successCount: successCount,
              );
          _ref.invalidate(unreadNotificationCountProvider);
        } catch (_) {}
      }

      if (retryableCount > 0) {
        try {
          final pending = await _db.countPendingSync();
          if (pending > 0) {
            _ref.read(appNotificationServiceProvider).notifyOfflineQueuePending(
                  pendingCount: pending,
                );
            _ref.invalidate(unreadNotificationCountProvider);
          }
        } catch (_) {}
      }

      return SyncResult(
        totalEntries: entries.length,
        successCount: successCount,
        deadErrors: currentDeadErrors,
        retryableCount: retryableCount,
      );
    } catch (e) {
      debugPrint('[SyncService] Lỗi trong vòng lặp syncQueue: $e');
      return SyncResult(
        totalEntries: 0,
        successCount: successCount,
        deadErrors: currentDeadErrors,
        retryableCount: retryableCount + 1,
      );
    } finally {
      _isSyncing = false;
      if (_ref.read(connectivityProvider).isOnline) {
        try {
          _ref.read(customerViewModelProvider.notifier).loadCustomers(isRefresh: true);
        } catch (_) {}
        try {
          _ref.read(routeApiServiceProvider).getMyRoutes(forceRefresh: true);
        } catch (_) {}
        try {
          _ref.read(routeViewModelProvider.notifier).loadRouteDetail(isRefresh: true);
        } catch (_) {}
      }
    }
  }

  /// Xử lý một mục trong hàng đợi
  Future<_SyncItemStatus> _processEntry(
    SyncQueueEntry entry,
    List<SyncDeadError> currentDeadErrors,
  ) async {
    // Đánh dấu sang 'sending'
    await _db.markSending(entry.id);

    try {
      if (entry.entity == 'customer' && entry.op == 'create') {
        await _syncCreateCustomer(entry);
      } else if (entry.entity == 'visit' && entry.op == 'create') {
        await _syncCreateVisit(entry);
      } else if (entry.entity == 'visit_photo' && entry.op == 'upload') {
        await _syncVisitPhoto(entry);
      } else if (entry.entity == 'form_submission' && entry.op == 'create') {
        await _syncSubmitForm(entry);
      } else if (entry.entity == 'visit' && entry.op == 'checkout') {
        await _syncCheckoutVisit(entry);
      } else if (entry.entity == 'visit' && entry.op == 'cancel') {
        await _syncCancelVisit(entry);
      } else if (entry.entity == 'declaration' && entry.op == 'create') {
        await _syncPositionDeclaration(entry);
      } else if (entry.entity == 'attendance_punch' && entry.op == 'create') {
        await _syncAttendancePunch(entry);
      } else if (entry.entity == 'attendance_photo' && entry.op == 'upload') {
        await _syncAttendancePhoto(entry);
      } else {
        // Các loại entity khác nếu có
        await _db.markDone(entry.id);
      }
      return _SyncItemStatus.success;
    } on DioException catch (dioErr) {
      return await _handleDioError(entry, dioErr, currentDeadErrors);
    } catch (e) {
      if (e is AppException) {
        return await _handleAppException(entry, e, currentDeadErrors);
      } else {
        return await _handleGenericError(entry, e.toString());
      }
    }
  }

  /// Đồng bộ tạo mới khách hàng lên server
  Future<String?> _resolvePhotoToken(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    // Nếu đã là 32-hex token từ trước
    if (trimmed.length == 32 && !trimmed.contains('/') && !trimmed.contains(r'\')) {
      return trimmed;
    }

    // Nếu là tệp cục bộ cần tải lên
    String cleanPath = trimmed;
    if (cleanPath.startsWith('file://')) {
      try {
        cleanPath = Uri.parse(cleanPath).toFilePath();
      } catch (_) {
        cleanPath = cleanPath.replaceFirst('file://', '');
      }
    }

    final file = File(cleanPath);
    if (!await file.exists()) {
      debugPrint('[SyncService] Tệp ảnh không tồn tại: $cleanPath');
      return null;
    }

    final preparedFile = await ImageUploadHelper.prepareImageForUpload(file);
    final fileName = ImageUploadHelper.getValidFileName(preparedFile.path);
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(preparedFile.path, filename: fileName),
    });

    // Tuyệt đối không nuốt ngoại lệ mạng (SocketException, DioException) tại đây để SyncService
    // có thể retry khi mạng ổn định, không gửi payload thiếu ảnh lên server gây lỗi 422!
    final res = await _apiClient.postMultipart('/crm/customer-photos', formData: formData);

    String? token;
    if (res is Map) {
      final d = res['data'];
      if (d is Map) {
        token = d['token']?.toString() ?? d['file_token']?.toString() ?? d['photo_token']?.toString();
      } else if (d is String && d.length == 32) {
        token = d;
      }
      token ??= res['token']?.toString() ?? res['file_token']?.toString() ?? res['photo_token']?.toString();
    }
    return token;
  }

  /// Đồng bộ tạo mới khách hàng lên server theo hợp đồng 30/09/2026
  Future<void> _syncCreateCustomer(SyncQueueEntry entry) async {
    final rawSource = jsonDecode(entry.payload) as Map<String, dynamic>;

    // 1. Phân giải toàn bộ ảnh (tải ảnh cục bộ lên /crm/customer-photos nếu chưa có token 32-hex)
    final resolvedTokens = <String>[];
    final candidatePhotos = <String>[];

    void collectCandidate(dynamic val) {
      if (val == null) return;
      if (val is List) {
        for (final item in val) {
          collectCandidate(item);
        }
      } else if (val is String) {
        final s = val.trim();
        if (s.isNotEmpty && !candidatePhotos.contains(s)) {
          candidatePhotos.add(s);
        }
      }
    }

    collectCandidate(rawSource['photo_tokens']);
    collectCandidate(rawSource['photo_token']);
    collectCandidate(rawSource['photo_file_id']);
    collectCandidate(rawSource['photo']);
    collectCandidate(rawSource['photos']);
    collectCandidate(rawSource['local_photo_paths']);

    for (final candidate in candidatePhotos) {
      final token = await _resolvePhotoToken(candidate);
      if (token != null && token.isNotEmpty && !resolvedTokens.contains(token)) {
        resolvedTokens.add(token);
      }
    }

    // Phân giải ảnh trong map 'data' nếu có
    if (rawSource['data'] is Map<String, dynamic>) {
      final dataMap = Map<String, dynamic>.from(rawSource['data'] as Map<String, dynamic>);
      for (final key in dataMap.keys.toList()) {
        final val = dataMap[key];
        if (val is List) {
          final resolvedList = <String>[];
          for (final item in val) {
            final strItem = item.toString().trim();
            final token = await _resolvePhotoToken(strItem);
            resolvedList.add(token ?? strItem);
          }
          dataMap[key] = resolvedList;
        } else if (val is String && (val.endsWith('.jpg') || val.endsWith('.png') || val.endsWith('.jpeg') || val.contains('/') || val.contains(r'\'))) {
          final token = await _resolvePhotoToken(val);
          if (token != null) {
            dataMap[key] = token;
          }
        }
      }
      rawSource['data'] = dataMap;
    }

    // Dọn sạch các trường nội bộ của app khỏi rawSource để tránh lọt vào payload gửi lên server
    rawSource.remove('local_photo_paths');
    rawSource.remove('localPhotoPaths');

    // 2. Sử dụng CustomerPayloadHelper để xây dựng payload chuẩn 25 khoá gốc
    final payloadMap = CustomerPayloadHelper.buildCustomerApiPayload(
      sourceData: rawSource,
      resolvedPhotoTokens: resolvedTokens.isNotEmpty ? resolvedTokens : null,
      clientUuid: entry.clientUuid,
      isOfflineSync: true,
    );

    // 3. Gửi lên API /crm/customers kèm client_uuid
    final response = await _apiClient.post(
      '/crm/customers',
      data: payloadMap,
    );

    int? serverId;
    String? serverCode;
    String? serverType;

    if (response is Map<String, dynamic>) {
      final data = response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;

      if (data['id'] != null) {
        serverId = int.tryParse(data['id'].toString());
      }
      if (data['code'] != null) {
        serverCode = data['code'].toString();
      }
      serverType = data['customer_type_name']?.toString() ??
          data['customer_type_code']?.toString() ??
          data['customer_type']?.toString() ??
          data['type']?.toString();
    }

    // 4. Đánh dấu hoàn thành trong hàng đợi (§3.2, §4.3, §7)
    // Server trả về 200 kèm created: false (trùng client_uuid) cũng là thành công
    await _db.markDone(entry.id, serverId: serverId);

    // 5. Cập nhật trạng thái 'synced' trong bảng khách hàng cục bộ
    if (serverId != null) {
      String? updatedDynamicFieldsJson;
      try {
        final existingRows = await (_db.select(_db.localCustomers)..where((tbl) => tbl.clientUuid.equals(entry.clientUuid))).get();
        if (existingRows.isNotEmpty) {
          final row = existingRows.first;
          Map<String, dynamic> dyn = {};
          if (row.dynamicFieldsJson.isNotEmpty) {
            dyn = jsonDecode(row.dynamicFieldsJson) as Map<String, dynamic>;
          }
          if (resolvedTokens.isNotEmpty) {
            dyn['photo_tokens'] = resolvedTokens;
            dyn['photo_urls'] = resolvedTokens;
            dyn['photo_url'] = resolvedTokens.first;
            dyn['photo_token'] = resolvedTokens.first;
          }
          updatedDynamicFieldsJson = jsonEncode(dyn);
        }
      } catch (_) {}

      await _db.markCustomerSynced(
        entry.clientUuid,
        serverId,
        code: serverCode,
        type: serverType,
        dynamicFieldsJson: updatedDynamicFieldsJson,
      );
      try {
        _ref.read(customerViewModelProvider.notifier).loadCustomers(isRefresh: true);
      } catch (_) {}
    }

    // 6. Dọn dẹp tệp ảnh offline tạm sau khi đã đồng bộ thành công lên server
    if (candidatePhotos.isNotEmpty) {
      for (final p in candidatePhotos) {
        if (p.contains('offline_customer_photos')) {
          try {
            final f = File(p);
            if (await f.exists()) {
              await f.delete();
            }
          } catch (_) {}
        }
      }
    }

    debugPrint('[SyncService] Đồng bộ khách hàng thành công! UUID: ${entry.clientUuid}, Server ID: $serverId');
  }

  /// Đồng bộ Check-in viếng thăm lên server (§3 & §9)
  Future<void> _syncCreateVisit(SyncQueueEntry entry) async {
    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
    payload['is_offline_sync'] = true;
    payload['client_uuid'] = entry.clientUuid;

    // Nếu customer_id là ID âm hoặc chưa có, tìm theo parentUuid (§5.3)
    int? customerId;
    if (payload['customer_id'] != null) {
      customerId = int.tryParse(payload['customer_id'].toString());
    }
    if ((customerId == null || customerId <= 0) && entry.parentUuid != null) {
      final parentCustomer = await _db.getEntryByClientUuid(entry.parentUuid!);
      if (parentCustomer != null && parentCustomer.serverId != null && parentCustomer.serverId! > 0) {
        payload['customer_id'] = parentCustomer.serverId;
      } else {
        throw AppException('Chưa có serverId của khách hàng cha cho lượt viếng thăm');
      }
    }

    // Tính queued_seconds từ hardware clock (§9.1)
    final queuedSec = SystemClock.calculateQueuedSeconds(
      createdElapsedMs: entry.createdElapsed,
      entryBootId: entry.bootId,
    );
    if (queuedSec != null) {
      payload['queued_seconds'] = queuedSec;
    }
    payload['client_boot_id'] = entry.bootId;

    final response = await _apiClient.post(
      '/dms/visits',
      data: payload,
    );

    int? serverId;
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic> && data['id'] != null) {
        serverId = int.tryParse(data['id'].toString());
      }
    }

    await _db.markDone(entry.id, serverId: serverId);

    // Cập nhật serverId cho lượt viếng thăm trong cache cục bộ
    if (serverId != null) {
      try {
        final visitRepo = _ref.read(visitRepositoryProvider);
        final all = await visitRepo.getAllLocalVisits();
        final idx = all.indexWhere((v) => v.clientUuid == entry.clientUuid || v.id < 0);
        if (idx >= 0) {
          final updated = all[idx].copyWith(id: serverId);
          await visitRepo.saveLocalVisit(updated);
        }
        final active = await visitRepo.getActiveVisit();
        if (active != null && (active.clientUuid == entry.clientUuid || active.id < 0)) {
          await visitRepo.saveActiveVisit(active.copyWith(id: serverId));
        }
      } catch (err) {
        debugPrint('[SyncService] Cập nhật local visit serverId lỗi: $err');
      }
    }

    debugPrint('[SyncService] Đồng bộ Check-in thành công! UUID: ${entry.clientUuid}, Server ID: $serverId');
  }

  /// Tải ảnh viếng thăm ngoại tuyến lên server (§4.1 & §9)
  Future<void> _syncVisitPhoto(SyncQueueEntry entry) async {
    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
    int? visitId;
    if (payload['visit_id'] != null) {
      visitId = int.tryParse(payload['visit_id'].toString());
    }

    // Nếu visitId là ID âm hoặc chưa có, tìm theo parentUuid
    if ((visitId == null || visitId <= 0) && entry.parentUuid != null) {
      final parent = await _db.getEntryByClientUuid(entry.parentUuid!);
      if (parent != null && parent.serverId != null && parent.serverId! > 0) {
        visitId = parent.serverId;
      }
    }

    if (visitId == null || visitId <= 0) {
      throw AppException('Chưa có serverId của lượt viếng thăm cha');
    }

    final localPath = entry.localPath;
    if (localPath == null || localPath.isEmpty) {
      await _db.markDone(entry.id);
      return;
    }

    final file = File(localPath);
    if (!await file.exists()) {
      await _db.markDone(entry.id);
      return;
    }

    final preparedFile = await ImageUploadHelper.prepareImageForUpload(file);
    final fileName = ImageUploadHelper.getValidFileName(preparedFile.path);
    final bytes = await preparedFile.readAsBytes();

    final formMap = <String, dynamic>{
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      'photo_type': payload['photo_type'] ?? 'other',
    };
    if (payload['lat'] != null) formMap['lat'] = payload['lat'];
    if (payload['lng'] != null) formMap['lng'] = payload['lng'];
    if (payload['taken_at'] != null) formMap['taken_at'] = payload['taken_at'];

    final formData = FormData.fromMap(formMap);
    await _apiClient.postMultipart('/dms/visits/$visitId/photos', formData: formData);

    await _db.markDone(entry.id);

    if (localPath.contains('offline_visit_photos')) {
      try {
        if (await file.exists()) await file.delete();
      } catch (err) {
        debugPrint('[SyncService] Xoá file lỗi: $err');
      }
    }

    debugPrint('[SyncService] Tải ảnh viếng thăm lên thành công cho lượt #$visitId');
  }

  /// Đồng bộ Check-out viếng thăm lên server (§7 & §9)
  Future<void> _syncCheckoutVisit(SyncQueueEntry entry) async {
    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
    int? visitId;
    if (payload['visit_id'] != null) {
      visitId = int.tryParse(payload['visit_id'].toString());
    }

    // Nếu visitId là ID âm hoặc chưa có, tìm theo parentUuid
    if ((visitId == null || visitId <= 0) && entry.parentUuid != null) {
      final parent = await _db.getEntryByClientUuid(entry.parentUuid!);
      if (parent != null && parent.serverId != null && parent.serverId! > 0) {
        visitId = parent.serverId;
      }
    }

    if (visitId == null || visitId <= 0) {
      throw AppException('Chưa có serverId của lượt viếng thăm cha để check-out');
    }

    payload['is_offline_sync'] = true;

    // Tính queued_seconds từ hardware clock (§9.1)
    final queuedSec = SystemClock.calculateQueuedSeconds(
      createdElapsedMs: entry.createdElapsed,
      entryBootId: entry.bootId,
    );
    if (queuedSec != null) {
      payload['queued_seconds'] = queuedSec;
    }
    payload['client_boot_id'] = entry.bootId;

    try {
      await _apiClient.post(
        '/dms/visits/$visitId/checkout',
        data: payload,
      );
      await _db.markDone(entry.id);
      debugPrint('[SyncService] Đồng bộ Check-out thành công cho lượt #$visitId');
    } catch (e) {
      final raw = e.toString();
      // Nếu server trả về 422 "đã check-out rồi" / "đã đóng", coi là thành công theo §9
      if (raw.contains('đã check-out rồi') || raw.contains('đã đóng')) {
        await _db.markDone(entry.id);
        debugPrint('[SyncService] Lượt #$visitId đã được đóng trước đó, đánh dấu hoàn tất.');
        return;
      }
      rethrow;
    }
  }

  /// Đồng bộ Huỷ lượt viếng thăm ngoại tuyến lên server (§3.4 HUY-LUOT-VIENG-THAM-2026-09-30)
  Future<void> _syncCancelVisit(SyncQueueEntry entry) async {
    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
    int? visitId;
    if (payload['visit_id'] != null) {
      visitId = int.tryParse(payload['visit_id'].toString());
    }

    // Nếu visitId là ID âm hoặc chưa có, tìm theo parentUuid
    if ((visitId == null || visitId <= 0) && entry.parentUuid != null) {
      final parent = await _db.findVisitQueueEntry(entry.parentUuid!);
      if (parent != null && parent.serverId != null && parent.serverId! > 0) {
        visitId = parent.serverId;
      }
    }

    if (visitId == null || visitId <= 0) {
      debugPrint('[SyncService] Hủy lượt không có serverId hợp lệ: $visitId, đánh dấu hoàn tất.');
      await _db.markDone(entry.id);
      return;
    }

    try {
      await _apiClient.post('/dms/visits/$visitId/cancel');
      await _db.markDone(entry.id);

      // Cập nhật trạng thái đã huỷ trong cache cục bộ
      try {
        final visitRepo = _ref.read(visitRepositoryProvider);
        await visitRepo.clearActiveVisit();
        final all = await visitRepo.getAllLocalVisits();
        final idx = all.indexWhere((v) =>
            v.id == visitId || (entry.parentUuid != null && v.clientUuid == entry.parentUuid));
        if (idx >= 0) {
          final updated = all[idx].copyWith(
            cancelledAt: DateTime.now(),
            cancelledAtRaw: DateTime.now().toIso8601String(),
          );
          await visitRepo.saveLocalVisit(updated);
        }
      } catch (err) {
        debugPrint('[SyncService] Lỗi cập nhật local visit sau khi huỷ: $err');
      }

      try {
        _ref.read(routeViewModelProvider.notifier).markVisitCancelledLocally(visitId, clientUuid: entry.parentUuid);
      } catch (_) {}

      debugPrint('[SyncService] Đồng bộ Huỷ lượt thành công cho lượt #$visitId');
    } catch (e) {
      final raw = e.toString().toLowerCase();
      // Server idempotent (§3.4): Nếu server báo "đã bị huỷ" / "đã huỷ" hoặc "đã check out rồi", coi là thành công
      if (raw.contains('đã bị huỷ') ||
          raw.contains('đã huỷ') ||
          raw.contains('đã bị hủy') ||
          raw.contains('đã hủy') ||
          raw.contains('already cancelled') ||
          raw.contains('404') ||
          raw.contains('đã check out') ||
          raw.contains('đã checkout') ||
          raw.contains('đã check-out') ||
          raw.contains('không hủy được nữa') ||
          raw.contains('không huỷ được nữa') ||
          raw.contains('không hủy được') ||
          raw.contains('không huỷ được') ||
          raw.contains('already checked out') ||
          raw.contains('already closed')) {
        await _db.markDone(entry.id);
        try {
          final visitRepo = _ref.read(visitRepositoryProvider);
          await visitRepo.clearActiveVisit();
        } catch (_) {}
        try {
          _ref.read(routeViewModelProvider.notifier).markVisitCancelledLocally(visitId, clientUuid: entry.parentUuid);
        } catch (_) {}
        debugPrint('[SyncService] Lượt #$visitId đã được đóng/huỷ trước đó trên server, đánh dấu hoàn tất.');
        return;
      }
      rethrow;
    }
  }

  /// Tải ảnh biểu mẫu thị trường lên /dms/form-photos (§2)
  Future<String?> _uploadFormPhoto(File file) async {
    try {
      final preparedFile = await ImageUploadHelper.prepareImageForUpload(file);
      final fileName = ImageUploadHelper.getValidFileName(preparedFile.path);

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(preparedFile.path, filename: fileName),
      });
      final res = await _apiClient.postMultipart('/dms/form-photos', formData: formData);
      if (res is Map && res['data'] is Map && res['data']['token'] != null) {
        return res['data']['token'].toString();
      }
    } catch (e) {
      debugPrint('[SyncService] Lỗi khi upload ảnh biểu mẫu: $e');
    }
    return null;
  }

  /// Đồng bộ phiếu biểu mẫu thị trường (survey / collect) lên server
  Future<void> _syncSubmitForm(SyncQueueEntry entry) async {
    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
    payload['is_offline_sync'] = true;
    payload['client_uuid'] = entry.clientUuid;

    // Nếu phiếu gắn với một lượt viếng thăm offline, giải quyết visit_id từ parent
    if (payload['visit_id'] != null) {
      final vId = int.tryParse(payload['visit_id'].toString()) ?? 0;
      if (vId <= 0 && entry.parentUuid != null) {
        final parent = await _db.getEntryByClientUuid(entry.parentUuid!);
        if (parent != null && parent.serverId != null && parent.serverId! > 0) {
          payload['visit_id'] = parent.serverId;
        } else {
          throw AppException('Chưa có serverId của lượt viếng thăm cha cho biểu mẫu');
        }
      }
    }

    // §9.1: Bổ sung queued_seconds và client_boot_id cho phiếu offline
    final queuedSec = SystemClock.calculateQueuedSeconds(
      createdElapsedMs: entry.createdElapsed,
      entryBootId: entry.bootId,
    );
    if (queuedSec != null) {
      payload['queued_seconds'] = queuedSec;
    }
    payload['client_boot_id'] = entry.bootId;

    // §5: Trích xuất _local_photo_paths phục vụ tải ảnh lên hoặc tải lại khi bị dọn rác
    final localPhotoPaths = payload['_local_photo_paths'] as Map<String, dynamic>?;
    final answers = payload['answers'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(payload['answers'] as Map)
        : <String, dynamic>{};

    Future<void> uploadAllLocalPhotos() async {
      if (localPhotoPaths == null || localPhotoPaths.isEmpty) return;
      for (final kv in localPhotoPaths.entries) {
        final fieldCode = kv.key;
        final paths = kv.value;
        if (paths is List) {
          final newTokens = <String>[];
          for (final p in paths) {
            final file = File(p.toString());
            if (await file.exists()) {
              final token = await _uploadFormPhoto(file);
              if (token != null && token.isNotEmpty) {
                newTokens.add(token);
              }
            }
          }
          if (newTokens.isNotEmpty) {
            answers[fieldCode] = newTokens;
          }
        }
      }
      payload['answers'] = answers;
    }

    // Kiểm tra xem trong answers có trường ảnh nào còn đang giữ đường dẫn file cục bộ không
    bool hasLocalPathsInAnswers = false;
    answers.forEach((k, v) {
      if (v is List) {
        for (final item in v) {
          final str = item.toString();
          if (str.contains('/') || str.contains(r'\') || str.length != 32) {
            hasLocalPathsInAnswers = true;
          }
        }
      }
    });

    if (hasLocalPathsInAnswers && localPhotoPaths != null) {
      await uploadAllLocalPhotos();
    }

    // Payload gửi lên server loại bỏ các khoá nội bộ
    final sendPayload = Map<String, dynamic>.from(payload);
    sendPayload.remove('_local_photo_paths');

    dynamic response;
    try {
      response = await _apiClient.post(
        '/dms/form-submissions',
        data: sendPayload,
      );
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      // §5 & §6: Nếu server báo "không tìm thấy ảnh vừa tải lên. Vui lòng tải lại."
      // do cron dọn rác sau 1 ngày, app tự động tải lại ảnh gốc từ máy và nộp lại với CÙNG client_uuid
      if ((errStr.contains('không tìm thấy ảnh') || errStr.contains('không tìm thấy ảnh vừa tải lên')) &&
          localPhotoPaths != null &&
          localPhotoPaths.isNotEmpty) {
        debugPrint('[SyncService] Phát hiện ảnh bị dọn rác, tự động tải lại ảnh gốc từ máy...');
        await uploadAllLocalPhotos();
        sendPayload['answers'] = payload['answers'];
        // Gửi lại cùng client_uuid (§3 & §5)
        response = await _apiClient.post(
          '/dms/form-submissions',
          data: sendPayload,
        );
      } else {
        rethrow;
      }
    }

    int? serverId;
    bool isDuplicate = false;
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        if (data['id'] is num) {
          serverId = (data['id'] as num).toInt();
        }
        isDuplicate = data['duplicate'] == true;
      }
    }

    // §3 & §9: duplicate: true coi như thành công, xoá khỏi hàng đợi
    await _db.markDone(entry.id, serverId: serverId);
    debugPrint('[SyncService] Đồng bộ phiếu biểu mẫu thành công! UUID: ${entry.clientUuid}, Server ID: $serverId, Duplicate: $isDuplicate');
  }

  /// Tải ảnh khai báo vị trí lên /dms/position-photos
  Future<String?> _uploadPositionPhoto(File file) async {
    try {
      final preparedFile = await ImageUploadHelper.prepareImageForUpload(file);
      final fileName = ImageUploadHelper.getValidFileName(preparedFile.path);

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(preparedFile.path, filename: fileName),
      });
      final res = await _apiClient.postMultipart('/dms/position-photos', formData: formData);
      if (res is Map && res['data'] is Map && res['data']['token'] != null) {
        return res['data']['token'].toString();
      }
    } catch (e) {
      debugPrint('[SyncService] Lỗi khi upload ảnh khai báo vị trí: $e');
    }
    return null;
  }

  /// Đồng bộ bản ghi khai báo vị trí lên máy chủ (§4 & §5)
  Future<void> _syncPositionDeclaration(SyncQueueEntry entry) async {
    final rawSource = jsonDecode(entry.payload) as Map<String, dynamic>;

    // 1. Phân giải & upload các ảnh cục bộ
    final resolvedTokens = <String>[];
    final existingTokens = rawSource['photo_tokens'];
    if (existingTokens is List) {
      for (final t in existingTokens) {
        final str = t.toString().trim();
        if (str.length == 32 && !str.contains('/') && !str.contains(r'\')) {
          resolvedTokens.add(str);
        }
      }
    }

    final localPaths = rawSource['local_photo_paths'];
    if (localPaths is List) {
      for (final p in localPaths) {
        final path = p.toString().trim();
        if (path.isNotEmpty) {
          final file = File(path);
          if (await file.exists()) {
            final token = await _uploadPositionPhoto(file);
            if (token != null && !resolvedTokens.contains(token)) {
              resolvedTokens.add(token);
            }
          }
        }
      }
    }

    // 2. Tính toán queued_seconds (§5.1) dùng đồng hồ đơn điệu
    final queuedSeconds = SystemClock.calculateQueuedSeconds(
      createdElapsedMs: entry.createdElapsed,
      entryBootId: entry.bootId,
    );

    // 3. Gửi lên POST /dms/position-declarations
    final payloadMap = <String, dynamic>{
      'reason_id': rawSource['reason_id'],
      'lat': rawSource['lat'],
      'lng': rawSource['lng'],
      'photo_tokens': resolvedTokens,
      'is_offline_sync': true,
      'client_uuid': entry.clientUuid,
      'client_boot_id': entry.bootId,
    };

    if (queuedSeconds != null) {
      payloadMap['queued_seconds'] = queuedSeconds;
    }
    if (rawSource['accuracy_m'] != null) {
      payloadMap['accuracy_m'] = rawSource['accuracy_m'];
    }
    if (rawSource['title'] != null && rawSource['title'].toString().trim().isNotEmpty) {
      payloadMap['title'] = rawSource['title'].toString().trim();
    }
    if (rawSource['address'] != null && rawSource['address'].toString().trim().isNotEmpty) {
      payloadMap['address'] = rawSource['address'].toString().trim();
    }
    if (rawSource['note'] != null && rawSource['note'].toString().trim().isNotEmpty) {
      payloadMap['note'] = rawSource['note'].toString().trim();
    }
    if (rawSource['is_mock_location'] != null) {
      payloadMap['is_mock_location'] = rawSource['is_mock_location'];
    }
    if (rawSource['client_time'] != null && rawSource['client_time'].toString().isNotEmpty) {
      payloadMap['client_time'] = rawSource['client_time'];
    }
    if (rawSource['device_info'] != null) {
      payloadMap['device_info'] = rawSource['device_info'];
    }

    final response = await _apiClient.post(
      '/dms/position-declarations',
      data: payloadMap,
    );

    int? serverId;
    String? declaredAt;
    String? declaredDate;

    if (response is Map<String, dynamic>) {
      final data = response['data'] is Map<String, dynamic>
          ? response['data'] as Map<String, dynamic>
          : response;
      if (data['id'] != null) {
        serverId = int.tryParse(data['id'].toString());
      }
      declaredAt = data['declared_at']?.toString();
      declaredDate = data['declared_date']?.toString();
    }

    await _db.markDone(entry.id, serverId: serverId);
    debugPrint('[SyncService] Đồng bộ khai báo vị trí thành công! UUID: ${entry.clientUuid}, Server ID: $serverId, mốc: $declaredAt');

    // Cập nhật trạng thái 'synced' trong danh sách lịch sử cục bộ
    try {
      await _ref.read(positionDeclarationRepositoryProvider).updateLocalDeclarationStatus(
        entry.clientUuid,
        syncStatus: 'synced',
        serverId: serverId,
        declaredAt: declaredAt,
        declaredDate: declaredDate,
      );
    } catch (_) {}
  }

  /// Đồng bộ lượt chấm công lên máy chủ (§3 API-CHAM-CONG-MOBILE-2026-10-05.md)
  Future<void> _syncAttendancePunch(SyncQueueEntry entry) async {
    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
    final res = await _apiClient.post(
      '/attendance/mobile/punch',
      data: payload,
    );

    int? serverId;
    if (res is Map<String, dynamic>) {
      final data = res['data'] is Map<String, dynamic>
          ? res['data'] as Map<String, dynamic>
          : res;
      if (data['id'] != null) {
        serverId = int.tryParse(data['id'].toString());
      }
    }
    await _db.markDone(entry.id, serverId: serverId);
    debugPrint('[SyncService] Đồng bộ lượt chấm công thành công! UUID: ${entry.clientUuid}, Server ID: $serverId');
  }

  /// Đồng bộ ảnh của lượt chấm công lên máy chủ (§4 API-CHAM-CONG-MOBILE-2026-10-05.md)
  Future<void> _syncAttendancePhoto(SyncQueueEntry entry) async {
    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
    int? punchId = payload['punch_id'] as int?;

    // Nếu punchId âm (tạo offline), cố gắng tìm serverId của lượt chấm cha qua parentUuid
    if ((punchId == null || punchId <= 0)) {
      if (entry.parentUuid != null) {
        final parentRows = await (_db.select(_db.syncQueueEntries)
              ..where((tbl) => tbl.clientUuid.equals(entry.parentUuid!)))
            .get();
        if (parentRows.isNotEmpty && parentRows.first.serverId != null && parentRows.first.serverId! > 0) {
          punchId = parentRows.first.serverId;
        }
      }
      // Dự phòng: Tìm lượt attendance_punch gần nhất đã sync thành công
      if (punchId == null || punchId <= 0) {
        final lastPunch = await _db.findLastSyncedPunchEntry();
        if (lastPunch != null && lastPunch.serverId != null && lastPunch.serverId! > 0) {
          punchId = lastPunch.serverId;
        }
      }
    }

    if (punchId == null || punchId <= 0) {
      debugPrint('[SyncService] Chưa tìm thấy serverId của lượt chấm cho ảnh, giữ lại để retry sau');
      throw AppException('Lượt chấm công chưa được đồng bộ lên máy chủ');
    }

    final localPath = entry.localPath ?? payload['local_path']?.toString();
    if (localPath == null) {
      await _db.markDead(entry.id, 'Tệp ảnh không tồn tại');
      return;
    }

    final file = File(localPath);
    if (!await file.exists()) {
      await _db.markDead(entry.id, 'Tệp ảnh cục bộ không tồn tại: $localPath');
      return;
    }

    final preparedFile = await ImageUploadHelper.prepareImageForUpload(file);
    final fileName = ImageUploadHelper.getValidFileName(preparedFile.path);

    final formMap = <String, dynamic>{
      'file': await MultipartFile.fromFile(preparedFile.path, filename: fileName),
      'photo_type': payload['photo_type'] ?? 'front',
    };
    if (payload['taken_at'] != null) formMap['taken_at'] = payload['taken_at'];
    if (payload['lat'] != null) formMap['lat'] = payload['lat'];
    if (payload['lng'] != null) formMap['lng'] = payload['lng'];

    final formData = FormData.fromMap(formMap);
    await _apiClient.postMultipart('/attendance/mobile/punches/$punchId/photos', formData: formData);
    await _db.markDone(entry.id);
    debugPrint('[SyncService] Đồng bộ ảnh chấm công thành công cho lượt #$punchId!');
  }



  String _extractDioErrorMessage(DioException dioErr) {
    final data = dioErr.response?.data;
    if (data is Map) {
      if (data['message'] != null && data['message'].toString().trim().isNotEmpty) {
        return data['message'].toString().trim();
      }
      if (data['error'] != null && data['error'].toString().trim().isNotEmpty) {
        return data['error'].toString().trim();
      }
    } else if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    return dioErr.message ?? 'Lỗi không xác định từ máy chủ';
  }

  /// Xử lý lỗi từ Dio theo phân loại của đặc tả (§8.2 & §9)
  Future<_SyncItemStatus> _handleDioError(
    SyncQueueEntry entry,
    DioException dioErr,
    List<SyncDeadError> currentDeadErrors,
  ) async {
    final statusCode = dioErr.response?.statusCode;
    final errorMsg = _extractDioErrorMessage(dioErr);
    return await _handleErrorByStatus(entry, statusCode, errorMsg, currentDeadErrors);
  }

  /// Xử lý lỗi từ AppException
  Future<_SyncItemStatus> _handleAppException(
    SyncQueueEntry entry,
    AppException appErr,
    List<SyncDeadError> currentDeadErrors,
  ) async {
    return await _handleErrorByStatus(entry, appErr.statusCode, appErr.message, currentDeadErrors);
  }

  /// Xử lý lỗi chung (ngoại lệ mạng hoặc không xác định)
  Future<_SyncItemStatus> _handleGenericError(SyncQueueEntry entry, String errorMessage) async {
    return await _handleErrorByStatus(entry, null, errorMessage, []);
  }

  /// Xử lý lỗi tập trung theo status code:
  /// - 4xx (400 <= statusCode < 500): Lỗi hỏng vĩnh viễn -> KHÔNG RETRY, chuyển 'dead', báo cho người dùng
  /// - 500 / 5xx / Network (statusCode == null hoặc >= 500): Lỗi mạng / server tạm thời -> RETRY với Exponential Backoff
  Future<_SyncItemStatus> _handleErrorByStatus(
    SyncQueueEntry entry,
    int? statusCode,
    String errorMsg,
    List<SyncDeadError> currentDeadErrors,
  ) async {
    // 1. §9: Nếu nhận 422 "đã check-out rồi" hoặc "đã đóng" -> Coi là THÀNH CÔNG để dọn hàng đợi
    if (statusCode == 422 &&
        (errorMsg.contains('đã check-out rồi') || errorMsg.contains('đã đóng'))) {
      debugPrint('[SyncService] Mục #${entry.id} nhận 422 (đã check-out rồi) -> Coi là thành công (§9).');
      await _db.markDone(entry.id);
      return _SyncItemStatus.success;
    }

    // 2. Ca đặc biệt: Server trả 409 hoặc đã tồn tại (ALREADY_EXISTS) (§4.3)
    // Coi là THÀNH CÔNG để đảm bảo idempotency!
    if (statusCode == 409) {
      debugPrint('[SyncService] Mục #${entry.id} đã tồn tại trên server (409 ALREADY_EXISTS), đánh dấu done.');
      await _db.markDone(entry.id);
      return _SyncItemStatus.success;
    }

    // 3. Phân loại lỗi 4xx (400 <= statusCode < 500):
    // -> LỖI HỎNG VĨNH VIỄN (Permanent Client Error)
    // -> KHÔNG RETRY, chuyển sang 'dead', báo cho người dùng biết
    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      debugPrint('[SyncService] [4xx - LỖI HỎNG VĨNH VIỄN] Mục #${entry.id} ($statusCode): $errorMsg -> Chuyển "dead", KHÔNG RETRY.');
      await _db.markDead(entry.id, errorMsg);

      // Nếu là khách hàng -> cập nhật syncStatus = 'error' và approvalStatus = 'rejected'
      if (entry.entity == 'customer') {
        await _db.markCustomerSyncError(entry.clientUuid, errorMsg);
        try {
          _ref.read(customerViewModelProvider.notifier).loadCustomers(isRefresh: true);
        } catch (_) {}
      } else if (entry.entity == 'declaration') {
        try {
          await _ref.read(positionDeclarationRepositoryProvider).updateLocalDeclarationStatus(
            entry.clientUuid,
            syncStatus: 'error',
            error: errorMsg,
          );
        } catch (_) {}
      }

      final deadError = SyncDeadError(
        entryId: entry.id,
        entity: entry.entity,
        clientUuid: entry.clientUuid,
        statusCode: statusCode,
        message: errorMsg,
      );
      currentDeadErrors.add(deadError);
      _recentDeadErrors.removeWhere((e) => e.entryId == entry.id);
      _recentDeadErrors.add(deadError);

      return _SyncItemStatus.dead;
    }

    // 4. Phân loại lỗi 500 / 5xx hoặc Lỗi mạng (statusCode == null hoặc statusCode >= 500):
    // -> LỖI MẠNG / LỖI SERVER TẠM THỜI (Transient / Network Error)
    // -> RETRY: Exponential Backoff kèm Jitter ±20%
    debugPrint('[SyncService] [5xx / MẠNG - LỖI TẠM THỜI] Mục #${entry.id} (Status: $statusCode): $errorMsg -> Sẽ RETRY theo Backoff.');
    await _applyBackoff(entry, errorMsg);
    return _SyncItemStatus.retryable;
  }

  /// Tính toán lịch thử lại theo Exponential Backoff với Jitter ±20% (§8.2)
  Future<void> _applyBackoff(SyncQueueEntry entry, String error) async {
    final nextAttemptCount = entry.attempts + 1;

    // Các mốc: lần 1: +2s, lần 2: +4s, lần 3: +8s, lần 4: +16s, lần 5+: +300s (5 phút trần)
    int baseDelaySeconds;
    if (nextAttemptCount <= 1) {
      baseDelaySeconds = 2;
    } else if (nextAttemptCount == 2) {
      baseDelaySeconds = 4;
    } else if (nextAttemptCount == 3) {
      baseDelaySeconds = 8;
    } else if (nextAttemptCount == 4) {
      baseDelaySeconds = 16;
    } else {
      baseDelaySeconds = 300; // 5 phút tối đa
    }

    // Thêm nhiễu ngẫu nhiên (jitter) ±20% (§8.2)
    final jitterFactor = 0.8 + (_random.nextDouble() * 0.4); // 0.8 -> 1.2
    final delaySeconds = (baseDelaySeconds * jitterFactor).round();
    final nextAttemptAt = DateTime.now().millisecondsSinceEpoch + (delaySeconds * 1000);

    debugPrint('[SyncService] Mục #${entry.id} thử lại lần $nextAttemptCount sau ${delaySeconds}s do lỗi: $error');

    await _db.reschedule(
      entry.id,
      nextAttemptAt: nextAttemptAt,
      attempts: nextAttemptCount,
      error: error,
    );
  }
}
