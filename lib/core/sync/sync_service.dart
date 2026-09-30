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
import '../utils/system_clock.dart';
import '../../features/customer/presentation/viewmodels/customer_view_model.dart';
import '../../features/customer/data/utils/customer_payload_helper.dart';

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
      if (force) {
        debugPrint('[SyncService] Force syncQueue: reset cờ _isSyncing bị treo.');
        _isSyncing = false;
      } else {
        debugPrint('[SyncService] syncQueue đang chạy, bỏ qua lời gọi trùng lặp.');
        return const SyncResult();
      }
    }

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

    _isSyncing = true;
    int successCount = 0;
    int retryableCount = 0;
    final List<SyncDeadError> currentDeadErrors = [];

    try {
      // Lấy danh sách pending theo FIFO, tối đa 50 mục (§3.3 Luật 6)
      // Không bao giờ lấy các mục 'dead' (lỗi 4xx vĩnh viễn không retry)
      final entries = await _db.getPendingQueueEntries(limit: 50, force: force);
      if (entries.isEmpty) {
        debugPrint('[SyncService] Không có mục nào cần gửi trong hàng đợi.');
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
      } else if (entry.entity == 'form_submission' && entry.op == 'create') {
        await _syncSubmitForm(entry);
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
    try {
      final file = File(trimmed);
      if (await file.exists()) {
        final fileName = file.path.split(Platform.pathSeparator).last.split('/').last;
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(file.path, filename: fileName),
        });
        final res = await _apiClient.postMultipart('/crm/customer-photos', formData: formData);
        if (res is Map && res['data'] is Map && res['data']['token'] != null) {
          return res['data']['token'].toString();
        }
      }
    } catch (e) {
      debugPrint('[SyncService] Lỗi khi upload ảnh điểm bán: $e');
    }
    return null;
  }

  /// Đồng bộ tạo mới khách hàng lên server theo hợp đồng 30/09/2026
  Future<void> _syncCreateCustomer(SyncQueueEntry entry) async {
    final rawSource = jsonDecode(entry.payload) as Map<String, dynamic>;

    // 1. Phân giải toàn bộ ảnh (tải ảnh cục bộ lên /crm/customer-photos nếu chưa có token 32-hex)
    final resolvedTokens = <String>[];
    final rawTokens = rawSource['photo_tokens'] ?? rawSource['photo_token'] ?? rawSource['photo_file_id'] ?? rawSource['photo'];
    if (rawTokens is List) {
      for (final item in rawTokens) {
        final itemStr = item.toString().trim();
        if (itemStr.isEmpty) continue;
        final token = await _resolvePhotoToken(itemStr);
        if (token != null && token.isNotEmpty) {
          resolvedTokens.add(token);
        }
      }
    } else if (rawTokens != null) {
      final itemStr = rawTokens.toString().trim();
      if (itemStr.isNotEmpty) {
        final token = await _resolvePhotoToken(itemStr);
        if (token != null && token.isNotEmpty) {
          resolvedTokens.add(token);
        }
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
      await _db.markCustomerSynced(entry.clientUuid, serverId, code: serverCode, type: serverType);
      try {
        _ref.read(customerViewModelProvider.notifier).loadCustomers(isRefresh: true);
      } catch (_) {}
    }

    debugPrint('[SyncService] Đồng bộ khách hàng thành công! UUID: ${entry.clientUuid}, Server ID: $serverId');
  }

  /// Đồng bộ phiếu biểu mẫu thị trường (survey / collect) lên server
  Future<void> _syncSubmitForm(SyncQueueEntry entry) async {
    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
    payload['is_offline_sync'] = true;
    payload['client_uuid'] = entry.clientUuid;

    // §9.1: Bổ sung queued_seconds và client_boot_id cho phiếu offline
    final queuedSec = SystemClock.calculateQueuedSeconds(
      createdElapsedMs: entry.createdElapsed,
      entryBootId: entry.bootId,
    );
    if (queuedSec != null) {
      payload['queued_seconds'] = queuedSec;
    }
    payload['client_boot_id'] = entry.bootId;

    final response = await _apiClient.post(
      '/dms/form-submissions',
      data: payload,
    );

    int? serverId;
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is Map<String, dynamic> && data['id'] is num) {
        serverId = (data['id'] as num).toInt();
      }
    }

    await _db.markDone(entry.id, serverId: serverId);
    debugPrint('[SyncService] Đồng bộ phiếu biểu mẫu thành công! UUID: ${entry.clientUuid}, Server ID: $serverId');
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
