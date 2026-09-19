import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../network/api_client.dart';
import '../network/connectivity_provider.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.read(appDatabaseProvider);
  final apiClient = ref.read(apiClientProvider);
  final service = SyncService(db, apiClient, ref);
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// Tiến trình đồng bộ ngoại tuyến (§3, §4, §8 SPEC-DONG-BO-OFFLINE-2026-09-15.md)
class SyncService {
  final AppDatabase _db;
  final ApiClient _apiClient;
  final Ref _ref;

  bool _isSyncing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _pollingTimer;
  final Random _random = Random();

  SyncService(this._db, this._apiClient, this._ref) {
    _init();
  }

  Future<void> _init() async {
    // 1. Hồi phục các mục 'sending' mồ côi về 'pending' khi khởi động (§3.3 Luật 5)
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
  Future<void> syncQueue() async {
    if (_isSyncing) {
      debugPrint('[SyncService] syncQueue đang chạy, bỏ qua lời gọi trùng lặp.');
      return;
    }

    // Kiểm tra kết nối mạng
    final isOnline = _ref.read(connectivityProvider).isOnline;
    if (!isOnline) {
      debugPrint('[SyncService] Không có kết nối mạng, tạm dừng đồng bộ.');
      return;
    }

    _isSyncing = true;
    try {
      // Lấy danh sách pending theo FIFO, tối đa 50 mục (§3.3 Luật 6)
      final entries = await _db.getPendingQueueEntries(limit: 50);
      if (entries.isEmpty) {
        return;
      }

      debugPrint('[SyncService] Bắt đầu đồng bộ ${entries.length} mục trong hàng đợi...');

      for (final entry in entries) {
        // Kiểm tra lại kết nối trước mỗi mục
        if (!_ref.read(connectivityProvider).isOnline) {
          debugPrint('[SyncService] Mất mạng giữa chừng, dừng lô đồng bộ.');
          break;
        }

        await _processEntry(entry);
      }
    } catch (e) {
      debugPrint('[SyncService] Lỗi trong vòng lặp syncQueue: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Xử lý một mục trong hàng đợi
  Future<void> _processEntry(SyncQueueEntry entry) async {
    // Đánh dấu sang 'sending'
    await _db.markSending(entry.id);

    try {
      if (entry.entity == 'customer' && entry.op == 'create') {
        await _syncCreateCustomer(entry);
      } else {
        // Các loại entity khác nếu có
        await _db.markDone(entry.id);
      }
    } on DioException catch (dioErr) {
      _handleDioError(entry, dioErr);
    } catch (e) {
      _handleGenericError(entry, e.toString());
    }
  }

  /// Đồng bộ tạo mới khách hàng lên server
  Future<void> _syncCreateCustomer(SyncQueueEntry entry) async {
    final payloadMap = jsonDecode(entry.payload) as Map<String, dynamic>;

    // Gửi lên API /crm/customers kèm client_uuid (BB-2, BB-3)
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

    // Đánh dấu hoàn thành trong hàng đợi (§3.2, §4.3)
    await _db.markDone(entry.id, serverId: serverId);

    // Cập nhật trạng thái 'synced' trong bảng khách hàng cục bộ
    if (serverId != null) {
      await _db.markCustomerSynced(entry.clientUuid, serverId, code: serverCode, type: serverType);
    }

    debugPrint('[SyncService] Đồng bộ khách hàng thành công! UUID: ${entry.clientUuid}, Server ID: $serverId');
  }

  /// Xử lý lỗi từ Dio theo phân loại của đặc tả (§8.2)
  void _handleDioError(SyncQueueEntry entry, DioException dioErr) {
    final statusCode = dioErr.response?.statusCode;

    // 1. Lỗi vĩnh viễn (403 Forbidden, 422 Unprocessable / INVALID) -> Chuyển 'dead' (§3.2, §3.3 Luật 1)
    if (statusCode == 403 || statusCode == 422) {
      final errorMsg = dioErr.response?.data?.toString() ?? dioErr.message ?? 'Lỗi dữ liệu không hợp lệ';
      debugPrint('[SyncService] Mục #${entry.id} gặp lỗi vĩnh viễn ($statusCode), chuyển dead: $errorMsg');
      _db.markDead(entry.id, errorMsg);
      return;
    }

    // 2. Ca đặc biệt: Server trả 409 hoặc đã tồn tại (ALREADY_EXISTS) (§4.3)
    // Coi là THÀNH CÔNG để đảm bảo idempotency!
    if (statusCode == 409) {
      debugPrint('[SyncService] Mục #${entry.id} đã tồn tại trên server (ALREADY_EXISTS), đánh dấu done.');
      _db.markDone(entry.id);
      return;
    }

    // 3. Lỗi mạng / timeout / 5xx -> Exponential backoff kèm jitter ±20% (§8.2)
    _applyBackoff(entry, dioErr.message ?? 'Lỗi kết nối mạng');
  }

  void _handleGenericError(SyncQueueEntry entry, String errorMessage) {
    _applyBackoff(entry, errorMessage);
  }

  /// Tính toán lịch thử lại theo Exponential Backoff với Jitter ±20% (§8.2)
  void _applyBackoff(SyncQueueEntry entry, String error) {
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

    _db.reschedule(
      entry.id,
      nextAttemptAt: nextAttemptAt,
      attempts: nextAttemptCount,
      error: error,
    );
  }
}
