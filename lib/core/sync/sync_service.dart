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
import '../network/refresh_outcome.dart';
import '../services/app_notification_service.dart';
import '../utils/image_upload_helper.dart';
import '../utils/offline_photo_store.dart';
import '../utils/system_clock.dart';
import 'sync_entity_group.dart';
import '../../features/notifications/presentation/viewmodels/notifications_view_model.dart';
import '../../features/customer/presentation/viewmodels/customer_view_model.dart';
import '../../features/customer/data/utils/customer_payload_helper.dart';
import '../../features/position_declaration/data/repositories/position_declaration_repository_impl.dart';
import '../../features/route/presentation/viewmodels/route_view_model.dart';
import '../../features/travel/presentation/viewmodels/travel_view_model.dart';
import '../../features/visit/data/repositories/visit_repository_impl.dart';
import '../../features/visit/data/models/visit_material_model.dart';
import '../../features/visit/domain/entities/visit_entity.dart';
import '../../features/visit/data/repositories/visit_material_repository.dart';
import '../../features/forms/presentation/viewmodels/forms_view_model.dart';
import '../../features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.read(appDatabaseProvider);
  final apiClient = ref.read(apiClientProvider);
  final service = SyncService(db, apiClient, ref);
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// Mục bị chặn vì phiên đăng nhập (401 / thu quyền app) chờ bao lâu mới thử lại — đăng nhập lại thì "Đồng bộ ngay"
/// hoặc lượt đổi mạng gửi ngay, không phải chờ hết khoảng này.
const Duration authBlockedRetryDelay = Duration(minutes: 1);

/// Mã lỗi server khi mở lượt mới mà còn lượt cũ chưa check-out (`OpenVisitException::CODE`).
const String openVisitErrorCode = 'DMS_VISIT_STILL_OPEN';

/// Trần số lần check-in bị server trả [openVisitErrorCode] (mỗi lần cách tối đa 5 phút ⇒ ≈ 2 giờ CÓ MẠNG). Trần kỹ thuật
/// chống vòng lặp vĩnh viễn (mục chờ gửi chặn đăng xuất): lượt trước không được đóng trong chừng ấy thì báo lỗi ở "Lỗi
/// đồng bộ" thay vì thử mãi. Màn tuyến đưa lượt treo lên để nhân viên check-out / huỷ trước khi tới trần. Đếm RIÊNG
/// trong payload ([openVisitCountKey]) — không dùng `attempts`: "Đồng bộ ngay" đặt lại `attempts`, và `attempts` còn
/// đếm cả lỗi mạng/5xx.
const int openVisitMaxAttempts = 24;

/// Khoá nội bộ trong payload dòng tạo lượt: số lần server trả [openVisitErrorCode]. KHÔNG gửi lên server.
const String openVisitCountKey = '_still_open_count';

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

/// [authBlocked]: máy chủ không nhận phiên đăng nhập (401 / chưa được cấp quyền app DMS) — lỗi của PHIÊN, không phải
/// của mục: mục giữ nguyên chờ gửi và cả lô dừng (các mục sau cũng sẽ nhận đúng lỗi đó).
enum _SyncItemStatus { success, dead, retryable, authBlocked, skipped }

/// Mục con chưa gửi được vì lượt cha chưa có serverId — chờ cha, KHÔNG tính là một lần gửi hỏng (không đếm vào chuỗi lỗi
/// thả check-out, [SyncService.releasesCheckout]).
class _ParentPendingException extends AppException {
  const _ParentPendingException(super.message);
}

/// Tiến trình đồng bộ ngoại tuyến (§3, §4, §8 SPEC-DONG-BO-OFFLINE-2026-09-15.md)
class SyncService {
  final AppDatabase _db;
  final ApiClient _apiClient;
  final Ref _ref;

  bool _isSyncing = false;

  /// Mục vừa bị chặn vì phiên là do bị thu quyền app (DMS_APP_FORBIDDEN), không phải 401.
  bool _lastAuthBlockForbidden = false;

  /// Phiên đã bị xoá khỏi máy (AuthInterceptor xoá khi máy chủ từ chối làm mới) — không còn refresh token.
  static Future<bool> _sessionCleared() async {
    try {
      final token = (await SharedPreferences.getInstance()).getString(AppConstants.keyRefreshToken);
      return token == null || token.isEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Hoàn tất khi lượt gửi ĐANG chạy xong (null khi rảnh) — để nơi gọi CHỜ thay vì nhận kết quả rỗng của lời gọi trùng.
  Completer<void>? _runDone;

  bool get isSyncing => _isSyncing;

  /// Mục con chưa lấy được serverId của mục cha. Mặc định là lỗi tạm (thử lại sau). Chỉ ném 4xx (đi đường dead chuẩn
  /// — người dùng thấy ở "Lỗi đồng bộ", xoá được) khi KHÔNG BAO GIỜ có serverId nữa — kẻo thử lại mãi và chặn đăng
  /// xuất vĩnh viễn (đăng xuất chờ hết mục chờ gửi):
  /// - cha không còn trong máy (dọn mục lỗi / huỷ lượt; dòng done chỉ bị dọn sau AppDatabase.doneRetention và khi không
  ///   còn mục con chưa xong);
  /// - cha bị từ chối (dead) mà KHÔNG phải điểm bán — chỉ điểm bán được sửa rồi gửi lại (hồi dead → pending ở
  ///   customer_local_data_source), nên con của điểm bán bị từ chối vẫn phải chờ.
  /// Không ghi parentUuid (ảnh chấm công chờ "lượt chấm gần nhất", dòng cũ) hay cha done mà thiếu serverId (409) KHÔNG
  /// tính là hết hy vọng — giữ như cũ (thử lại); 409 cần lấy lại id từ máy chủ (#24401).
  Never _throwParentUnresolved(SyncQueueEntry entry, SyncQueueEntry? parent, String message, {String? parentUuid}) {
    final effectiveParentUuid = parentUuid ?? entry.parentUuid;
    final hopeless = effectiveParentUuid != null &&
        (parent == null || (parent.state == 'dead' && parent.entity != 'customer'));
    if (hopeless) throw AppException('$message — mục cha không còn hoặc không thể đồng bộ', 410);
    throw _ParentPendingException(message);
  }
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
      final pendingEntries = await _db.getPendingQueueEntries(limit: 50);
      final grouped = SyncEntityGroupHelper.groupEntries(pendingEntries);
      if (grouped.length >= 3) {
        final summary = SyncEntityGroupHelper.buildSummaryText(pendingEntries);
        _ref.read(appNotificationServiceProvider).notifyOfflineQueuePending(
              pendingCount: grouped.length,
              summaryText: summary,
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
  ///
  /// Không tính vào kết quả "kéo xuống làm mới" ([RefreshOutcome.untracked]): đẩy hàng đợi không phải tải dữ liệu mới.
  Future<SyncResult> syncQueue({bool force = false}) =>
      RefreshOutcome.untracked(() => _syncQueue(force: force));

  /// Chờ lượt gửi đang chạy (nếu có) xong.
  Future<void> waitUntilIdle() async {
    while (_runDone != null) {
      await _runDone!.future;
    }
  }

  /// Đẩy CHỈ các mục con chặn check-out (ảnh / phiếu / thao tác vật tư) của lượt [visitClientUuid] lên server TRƯỚC
  /// check-out trực tuyến: server từ chối thao tác vật tư sau giờ ra, đếm ảnh/phiếu ở cổng check-out (#24522, #24698
  /// vòng 2). Không reset lịch thử lại / không xử lý phần còn lại của hàng đợi. Lượt gửi đang chạy thì CHỜ nó xong. Có
  /// trần [timeout] để nút check-out không quay mãi. Trả `false` nếu vẫn còn mục chưa gửi được.
  Future<bool> flushVisitCheckoutChildren(
    String visitClientUuid, {
    Duration timeout = visitMaterialFlushTimeout,
  }) async {
    try {
      return await _flushVisitCheckoutChildren(visitClientUuid).timeout(timeout);
    } on TimeoutException {
      debugPrint('[SyncService] Hết ${timeout.inSeconds}s chờ đẩy ảnh/phiếu/vật tư của lượt $visitClientUuid.');
      return false;
    }
  }

  Future<bool> _flushVisitCheckoutChildren(String visitClientUuid) async {
    await waitUntilIdle();
    if (!await _hasBlockingCheckoutChildren(visitClientUuid)) return true;
    await RefreshOutcome.untracked(() => _syncQueue(force: false, onlyCheckoutChildrenOf: visitClientUuid));
    await waitUntilIdle();
    return !await _hasBlockingCheckoutChildren(visitClientUuid);
  }

  /// Còn mục con chưa gửi mà VẪN giữ check-out (cùng luật hàng đợi: mục đã hỏng quá trần thì thôi giữ — [releasesCheckout]).
  Future<bool> _hasBlockingCheckoutChildren(String visitClientUuid) async =>
      (await _db.getOpenCheckoutChildren(visitClientUuid)).any((c) => !releasesCheckout(c));

  /// Đẩy lệnh của các lượt viếng thăm còn chờ (check-in / check-out / huỷ + ảnh / phiếu / vật tư của chúng) TRƯỚC
  /// check-in trực tuyến lượt mới (#24698 vòng 2). Cùng cách [flushVisitCheckoutChildren]. Trả `false` nếu còn lệnh lượt
  /// chưa lên server ⇒ check-in mới phải đi hàng đợi (đứng sau lượt trước — [AppDatabase.isVisitCreateHeld]).
  Future<bool> flushVisitLifecycle({Duration timeout = visitMaterialFlushTimeout}) async {
    // Đường nhanh: không còn lệnh lượt nào ⇒ check-in KHÔNG phải chờ lượt đồng bộ đang chạy (ảnh, điểm bán…).
    if (!await _db.hasOpenVisitLifecycleEntries()) return true;
    try {
      return await _flushVisitLifecycle().timeout(timeout);
    } on TimeoutException {
      debugPrint('[SyncService] Hết ${timeout.inSeconds}s chờ đẩy lệnh lượt viếng thăm còn chờ.');
      return false;
    }
  }

  Future<bool> _flushVisitLifecycle() async {
    await waitUntilIdle();
    if (!await _db.hasOpenVisitLifecycleEntries()) return true;
    await RefreshOutcome.untracked(() => _syncQueue(force: false, onlyVisitLifecycle: true));
    await waitUntilIdle();
    return !await _db.hasOpenVisitLifecycleEntries();
  }

  Future<SyncResult> _syncQueue({
    required bool force,
    String? onlyCheckoutChildrenOf,
    bool onlyVisitLifecycle = false,
  }) async {
    if (_isSyncing) {
      debugPrint('[SyncService] syncQueue đang chạy, bỏ qua lời gọi trùng lặp.');
      return const SyncResult();
    }
    _isSyncing = true;
    final runDone = Completer<void>();
    _runDone = runDone;

    int successCount = 0;
    int retryableCount = 0;
    final List<SyncDeadError> currentDeadErrors = [];

    try {
      if (force) {
        // Hồi phục sending mồ côi và reset hoãn retry của pending. TUYỆT ĐỐI không đụng đến dead (4xx vĩnh viễn)
        await _db.recoverOrphanedSendingEntries(resetPendingBackoff: true);
      }

      // Neo lại đồng hồ máy trước khi tính `queued_seconds`: máy có thể đã ngủ từ lần neo trước.
      await SystemClock.refresh();

      // Kiểm tra kết nối mạng
      final isOnline = _ref.read(connectivityProvider).isOnline;
      if (!isOnline && !force) {
        debugPrint('[SyncService] Không có kết nối mạng, tạm dừng đồng bộ.');
        return const SyncResult();
      }

      // Lấy danh sách pending theo FIFO, tối đa 50 mục (§3.3 Luật 6)
      // Không bao giờ lấy các mục 'dead' (lỗi 4xx vĩnh viễn không retry)
      // Chế độ đẩy mục con chặn check-out của MỘT lượt (trước check-out trực tuyến): chỉ mục pending của lượt đó, bỏ qua
      // lịch thử lại của riêng chúng (người dùng đang chờ ở nút check-out), không đụng mục khác.
      final entries = onlyCheckoutChildrenOf != null
          ? await _db.getPendingCheckoutChildren(onlyCheckoutChildrenOf)
          : onlyVisitLifecycle
              ? await _db.getPendingVisitLifecycleEntries()
          : await _db.getPendingQueueEntries(limit: 50, force: force);
      if (entries.isEmpty) {
        // Hàng đợi rỗng ⇒ KHÔNG tải lại gì: lượt định kỳ 60s / đổi mạng / màn gọi đồng bộ mà ép tải lại toàn bộ điểm
        // bán (1.000+ điểm ≈ 11 lượt API + ghi SQLite + các màn nạp lại) mỗi phút là nguồn giật + tốn dữ liệu. Danh sách
        // vẫn được làm mới: tải ngầm khi mở/chuyển màn (sau 5 phút), kéo làm mới, và sau khi đẩy được mục (dưới).
        debugPrint('[SyncService] Không có mục nào cần gửi trong hàng đợi.');
        return const SyncResult();
      }

      debugPrint('[SyncService] Bắt đầu đồng bộ ${entries.length} mục trong hàng đợi (force: $force)...');

      final List<SyncQueueEntry> succeededEntries = [];
      var sessionRejected = false;
      var forbidden = false;

      for (final entry in entries) {
        // Kiểm tra lại kết nối trước mỗi mục (trừ khi force)
        if (!_ref.read(connectivityProvider).isOnline && !force) {
          debugPrint('[SyncService] Mất mạng giữa chừng, dừng lô đồng bộ.');
          break;
        }

        // Lô nạp sẵn trong RAM: đã đổi người đăng nhập giữa chừng (đăng xuất → người khác vào) thì KHÔNG gửi tiếp mục
        // của người trước bằng token người sau (#24400) — để nguyên, chờ đúng chủ.
        if (entry.ownerUserId != _db.ownerUserId) {
          debugPrint('[SyncService] Đã đổi người đăng nhập, dừng lô đồng bộ.');
          break;
        }

        // Check-out nhường ảnh / phiếu / thao tác vật tư chưa gửi của cùng lượt — để nguyên pending, vòng sau xét lại.
        if (await _db.isCheckoutHeld(entry, released: releasesCheckout)) {
          debugPrint('[SyncService] Hoãn check-out #${entry.id}: còn ảnh/phiếu/vật tư của lượt chưa gửi.');
          // Tính là "chưa xong" — kết quả/thông báo đồng bộ không được báo thành công khi lượt còn chưa check-out.
          retryableCount++;
          continue;
        }

        // Check-in lượt sau nhường check-out còn chờ của lượt trước (server không mở lượt mới khi lượt cũ còn mở).
        if (await _db.isVisitCreateHeld(entry)) {
          debugPrint('[SyncService] Hoãn check-in #${entry.id}: check-out của lượt trước chưa gửi.');
          retryableCount++;
          continue;
        }

        final status = await _processEntry(entry, currentDeadErrors);
        if (status == _SyncItemStatus.authBlocked) forbidden = _lastAuthBlockForbidden;
        if (status == _SyncItemStatus.success) {
          successCount++;
          succeededEntries.add(entry);
        } else if (status == _SyncItemStatus.dead) {
          // currentDeadErrors already populated
        } else if (status == _SyncItemStatus.retryable) {
          retryableCount++;
        } else if (status == _SyncItemStatus.authBlocked) {
          retryableCount++;
          debugPrint('[SyncService] Phiên đăng nhập không còn hiệu lực, dừng lô — các mục giữ nguyên chờ đăng nhập lại.');
          sessionRejected = true;
          break;
        }
      }

      // Phiên chết thật (làm mới bị từ chối / không có refresh token / bị thu quyền app): đăng xuất CƯỠNG BỨC — giữ
      // nguyên hàng đợi, đúng người đăng nhập lại là gửi tiếp. Không làm thì người dùng kẹt: mục chờ gửi chặn nút đăng
      // xuất, mà gửi thì mãi 401.
      // CHỈ khi phiên đã bị xoá thật (làm mới bị từ chối ⇒ không còn refresh token) hoặc bị thu quyền app — 401 của
      // lần gửi lại sau khi làm mới THÀNH CÔNG thì phiên vẫn sống: chỉ dừng lô, đăng xuất là thu hồi oan token mới.
      if (sessionRejected && (forbidden || await _sessionCleared())) {
        try {
          await _ref.read(authViewModelProvider.notifier).forceLogoutSessionRejected();
        } catch (e) {
          debugPrint('[SyncService] Không đăng xuất cưỡng bức được: $e');
        }
      }

      if (successCount > 0) {
        try {
          final summary = SyncEntityGroupHelper.buildSummaryText(succeededEntries);
          _ref.read(appNotificationServiceProvider).notifyOfflineSyncSuccess(
                successCount: successCount,
                summaryText: summary,
              );
          _ref.invalidate(unreadNotificationCountProvider);
        } catch (_) {}
      }

      // Lượt đẩy có chủ đích (trước check-in / check-out) không báo "còn mục chờ" — chạy mỗi lần bấm.
      if (retryableCount > 0 && onlyCheckoutChildrenOf == null && !onlyVisitLifecycle) {
        try {
          final remainingEntries = await _db.getPendingQueueEntries(limit: 50);
          final grouped = SyncEntityGroupHelper.groupEntries(remainingEntries);
          if (grouped.isNotEmpty) {
            final summary = SyncEntityGroupHelper.buildSummaryText(remainingEntries);
            _ref.read(appNotificationServiceProvider).notifyOfflineQueuePending(
                  pendingCount: grouped.length,
                  summaryText: summary,
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
      _runDone = null;
      runDone.complete();
      // Gửi xong thì không giữ mãi trong máy: mọi lượt (kể cả hàng đợi rỗng) dọn mục done quá hạn giữ (+ tệp ảnh).
      unawaited(_db.purgeDoneEntries().catchError((Object e) {
        debugPrint('[SyncService] Lỗi dọn mục đã gửi: $e');
        return 0;
      }));
      // Chỉ làm mới khi CÓ mục vừa đẩy lên thành công (dữ liệu server vừa đổi: điểm bán mới có id, lượt viếng thăm…).
      // Các lượt tải đủ danh sách chạy cùng lúc đi chung một lượt (CustomerRepositoryImpl._sharedFullFetch).
      // Lượt đẩy CÓ CHỦ ĐÍCH ngay trước check-in / check-out trực tuyến KHÔNG tải lại: tải tuyến chạy song song với lệnh
      // check-in là đối soát chụp danh sách cũ ⇒ coi lượt vừa mở là "đã huỷ trên server" rồi huỷ nó (#24698 vòng 2).
      // Lượt định kỳ kế tiếp / màn gọi sau thao tác lo phần làm mới.
      final targeted = onlyCheckoutChildrenOf != null || onlyVisitLifecycle;
      if (successCount > 0 && !targeted && _ref.read(connectivityProvider).isOnline) {
        try {
          _ref.read(customerViewModelProvider.notifier).loadCustomers(isRefresh: true);
        } catch (_) {}
        try {
          _ref.read(routeApiServiceProvider).getMyRoutes(forceRefresh: true);
        } catch (_) {}
        try {
          _ref.read(routeViewModelProvider.notifier).loadRouteDetail(isRefresh: true);
        } catch (_) {}
        try {
          _ref.read(travelViewModelProvider.notifier).loadMyTravel(refresh: true);
        } catch (_) {}
      }
    }
  }

  /// Ảnh / phiếu của lượt gửi hỏng lặp quá trần thì thôi giữ check-out — mục vẫn thử lại. Bộ đếm nằm trong payload (không
  /// bị "Đồng bộ ngay" đặt lại như `attempts`); chờ lượt cha không tính; chuỗi đã nguội (lần hỏng cuối quá lâu) không tính.
  static bool releasesCheckout(SyncQueueEntry child) =>
      child.entity != 'visit_material' &&
      serverFailureChainExhausted(child.payload, nowMs: DateTime.now().millisecondsSinceEpoch);

  /// Xử lý một mục trong hàng đợi
  Future<_SyncItemStatus> _processEntry(
    SyncQueueEntry batchEntry,
    List<SyncDeadError> currentDeadErrors,
  ) async {
    // Đánh dấu sang 'sending' — dòng đã bị xoá / đổi trạng thái sau lúc nạp lô (huỷ lượt chưa gửi…) thì KHÔNG gửi.
    if (!await _db.markSending(batchEntry.id)) return _SyncItemStatus.skipped;
    // Đọc LẠI dòng sau khi giành: lô nạp sẵn tới 50 mục, người dùng có thể đã gộp phần sửa vào payload (sửa điểm bán)
    // trong lúc chờ tới lượt — gửi bản trong RAM là gửi payload cũ rồi markDone, phần sửa mất (rà soát #24698 lỗi 8).
    final entry = await _db.getEntryById(batchEntry.id) ?? batchEntry;

    try {
      if (entry.entity == 'customer' && entry.op == 'create') {
        await _syncCreateCustomer(entry);
      } else if (entry.entity == 'customer' && entry.op == 'update') {
        await _syncUpdateCustomer(entry);
      } else if (entry.entity == 'visit' && entry.op == 'create') {
        await _syncCreateVisit(entry);
      } else if (entry.entity == 'visit_photo' && entry.op == 'upload') {
        await _syncVisitPhoto(entry);
      } else if (entry.entity == 'form_submission' && entry.op == 'create') {
        await _syncSubmitForm(entry);
      } else if (entry.entity == 'visit_material' && entry.op == 'save') {
        await _syncVisitMaterial(entry);
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
        // Loại mục bản app này không biết gửi: báo lỗi (dead, thấy ở "Lỗi đồng bộ"), KHÔNG đánh dấu "đã gửi" rồi mất.
        throw AppException('Bản app này không gửi được loại dữ liệu ${entry.entity}/${entry.op}.', 422);
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

    var file = File(cleanPath);
    if (!await file.exists()) {
      // iOS đổi UUID thư mục app sau cập nhật/khôi phục: tệp vẫn còn, chỉ đường dẫn tuyệt đối lưu từ trước đã cũ ⇒ dựng
      // lại theo thư mục Documents hiện tại trước khi kết luận là mất.
      final rebased = await _rebaseToCurrentDocuments(cleanPath);
      if (rebased != null) file = rebased;
    }
    if (!await file.exists()) {
      // Đường dẫn tệp trong máy mà tệp đã mất ⇒ báo lỗi (dead, hiện ở "Lỗi đồng bộ") — bỏ qua là điểm bán lên server
      // thiếu ảnh mà không ai biết (cùng luật ảnh viếng thăm / phiếu / khai báo vị trí). Chuỗi KHÔNG phải đường dẫn
      // (giá trị ô chọn trong `data`, URL) thì trả null để nơi gọi giữ nguyên.
      if (trimmed.startsWith('file://') || await _isAppLocalPath(cleanPath)) {
        throw const AppException('Ảnh điểm bán không còn trên máy, không gửi được.', 410);
      }
      debugPrint('[SyncService] Không phải tệp ảnh trong máy, bỏ qua: $cleanPath');
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
    // Đã tải lên mà không đọc được token ⇒ lỗi máy chủ (thử lại), không lặng lẽ gửi điểm bán thiếu ảnh.
    if (token == null || token.isEmpty) {
      throw const AppException('Phản hồi tải ảnh điểm bán không hợp lệ từ máy chủ.', 502);
    }
    return token;
  }

  /// Dấu đường dẫn tệp của app trên máy — nhận cả đường dẫn CŨ: iOS đổi UUID thư mục app sau cập nhật/khôi phục, nên
  /// đường dẫn lưu trong hàng đợi từ trước không còn nằm trong thư mục hiện tại; Android có cả bộ nhớ ngoài của app.
  static const _appPathMarkers = [
    '/Containers/Data/Application/',
    '/data/user/',
    '/data/data/',
    '/Android/data/',
    '/offline_customer_photos/',
  ];

  /// [path] là tệp ảnh app tự chụp/chép (vùng lưu riêng của app, hiện tại hoặc theo dấu đường dẫn) — KHÔNG phải chuỗi
  /// khác tình cờ bắt đầu bằng '/' (đường dẫn trên máy chủ kiểu `/media/...`, giá trị ô chọn).
  static Future<bool> _isAppLocalPath(String path) async {
    if (!path.startsWith('/')) return false;
    if (_appPathMarkers.any(path.contains)) return true;
    return (await _appDirs()).any((d) => p.isWithin(d, path));
  }

  /// Thư mục tài liệu / hỗ trợ / tạm của app — tra một lần (mỗi lần tra là một lời gọi kênh nền tảng).
  static List<String>? _appDirsCache;

  static Future<List<String>> _appDirs() async {
    final cached = _appDirsCache;
    if (cached != null) return cached;
    final dirs = <String>[];
    for (final dir in [getApplicationDocumentsDirectory, getApplicationSupportDirectory, getTemporaryDirectory]) {
      try {
        dirs.add((await dir()).path);
      } catch (_) {}
    }
    return _appDirsCache = dirs;
  }

  /// Tệp ảnh của mục hàng đợi còn trên máy không: đường dẫn đã lưu, hoặc — iOS đổi UUID thư mục app sau cập nhật/khôi phục —
  /// dựng lại theo thư mục Documents hiện tại. null = mất thật (#24698: trước đây chỉ ảnh điểm bán dựng lại, ảnh viếng
  /// thăm / phiếu / chấm công thành "mất tệp" dù tệp vẫn còn).
  static Future<File?> _existingLocalFile(String? path) async {
    if (path == null || path.isEmpty) return null;
    final clean = OfflinePhotoStore.toFilePath(path);
    final file = File(clean);
    if (await file.exists()) return file;
    return _rebaseToCurrentDocuments(clean);
  }

  /// Đường dẫn cũ `…/Documents/<phần sau>` dựng lại theo thư mục Documents HIỆN TẠI (null nếu không áp dụng / không có).
  static Future<File?> _rebaseToCurrentDocuments(String path) async {
    const marker = '/Documents/';
    final i = path.indexOf(marker);
    if (i < 0) return null;
    try {
      final docs = (await getApplicationDocumentsDirectory()).path;
      final candidate = File(p.join(docs, path.substring(i + marker.length)));
      return candidate.path != path && await candidate.exists() ? candidate : null;
    } catch (_) {
      return null;
    }
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

    // Vật tư khai lúc tạo (#24526): đổi ảnh trên máy ra token NGAY lúc đồng bộ, như thao tác vật tư của lượt. Lỗi tải
    // ảnh ném ra ⇒ mục thử lại, không gửi điểm bán thiếu ảnh vật tư (bản ngoại tuyến server BỎ thao tác sai).
    if (rawSource['materials'] is List) {
      rawSource['materials'] = await resolveCreateMaterials(
        rawSource['materials'],
        skipRejectedMaterialPhotos((file) async => (await _ref.read(formsApiServiceProvider).uploadPhoto(file)).token),
      );
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

    // Nghiệp vụ 21/10/2026: tạo điểm bán = server tự ghi một lượt viếng thăm (visit_kind = new_outlet).
    // Gửi kèm đồng hồ hàng đợi (§9.1, cùng cách check-in/check-out) để lượt rơi ĐÚNG giờ/ngày bấm tạo,
    // kể cả khi hôm sau mới có mạng. Ba khoá này KHÔNG lấy từ dữ liệu nguồn (helper chặn), chỉ gắn ở đây.
    final queuedSec = SystemClock.calculateQueuedSeconds(
      createdElapsedMs: entry.createdElapsed,
      entryBootId: entry.bootId,
    );
    if (queuedSec != null) {
      payloadMap['queued_seconds'] = queuedSec;
    }
    payloadMap['client_boot_id'] = entry.bootId;
    payloadMap['client_time'] = DateTime.fromMillisecondsSinceEpoch(entry.createdAt).toIso8601String();

    // 3. Gửi lên API /crm/customers kèm client_uuid
    final response = await _apiClient.post(
      '/crm/customers',
      data: payloadMap,
    );

    int? serverId;
    String? serverCode;
    String? serverType;
    int? newOutletVisitId;

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
      newOutletVisitId = int.tryParse(data['new_outlet_visit_id']?.toString() ?? '');
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

      // KHÔNG dựng cache vật tư ở đây: lượt ngoại tuyến server BỎ thao tác sai mà vẫn trả 200 ⇒ không biết thao tác nào
      // thật sự được ghi; lượt viếng thăm đầu có mạng sẽ GET hiện trạng thật.

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
      // Server vừa ghi lượt "Tạo điểm bán" ⇒ tải lại tuyến để điểm bán hiện "Đã ghé" (tiến độ tuyến)
      if (newOutletVisitId != null) {
        try {
          _ref.read(routeViewModelProvider.notifier).loadRouteDetail(isRefresh: true);
        } catch (_) {}
      }
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

  /// Đồng bộ Cập nhật điểm bán lên server (§7 PATCH /crm/customers/{id})
  Future<void> _syncUpdateCustomer(SyncQueueEntry entry) async {
    int? serverId = entry.serverId;
    if (serverId == null || serverId <= 0) {
      if (entry.clientUuid.startsWith('server_')) {
        serverId = int.tryParse(entry.clientUuid.replaceFirst('server_', ''));
      }
    }

    SyncQueueEntry? createEntry;
    if (serverId == null || serverId <= 0) {
      // Lệnh sửa xếp khi dòng TẠO điểm bán còn đang gửi (customer_local_data_source.updateCustomerOffline): lấy mã server
      // từ dòng tạo / bảng điểm bán trong máy. Bản cũ đánh dấu "đã gửi" luôn ⇒ mất phần sửa không báo.
      createEntry = await _db.getEntryByClientUuid(entry.clientUuid);
      if (createEntry != null && createEntry.id != entry.id && (createEntry.serverId ?? 0) > 0) {
        serverId = createEntry.serverId;
      } else {
        final localCust = await (_db.select(_db.localCustomers)
              ..where((tbl) => tbl.clientUuid.equals(entry.clientUuid))
              ..limit(1))
            .getSingleOrNull();
        if (localCust?.id != null && localCust!.id! > 0) serverId = localCust.id;
      }
    }

    if (serverId == null || serverId <= 0) {
      debugPrint('[SyncService] Chưa có serverId để cập nhật khách hàng: ${entry.clientUuid}');
      final parent = (createEntry != null && createEntry.id != entry.id && createEntry.op == 'create') ? createEntry : null;
      _throwParentUnresolved(entry, parent, 'Chưa có mã điểm bán trên máy chủ để gửi phần sửa',
          parentUuid: entry.clientUuid);
    }

    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;

    // Xử lý photo_tokens nếu có đường dẫn cục bộ cần upload
    if (payload['photo_tokens'] is List) {
      final rawTokens = payload['photo_tokens'] as List;
      final resolved = <String>[];
      for (final t in rawTokens) {
        final res = await _resolvePhotoToken(t.toString());
        if (res != null) resolved.add(res);
      }
      payload['photo_tokens'] = resolved;
    }

    // Lượt sửa từ HÀNG ĐỢI ngoại tuyến (#24331): server nới phép kiểm (bỏ mục `erp_link_changes` sai thay vì 4xx — 4xx làm hàng
    // đợi bỏ hẳn lần sửa, mất cả các ô khác đã sửa). Cờ RIÊNG của request — `is_offline_sync` là CỘT của điểm bán, gửi là ghi đè.
    payload['offline_queue'] = true;
    await _apiClient.patch('/crm/customers/$serverId', data: payload);
    await _db.markDone(entry.id, serverId: serverId);
    debugPrint('[SyncService] Đồng bộ CẬP NHẬT khách hàng thành công! ID: $serverId, UUID: ${entry.clientUuid}');
  }

  /// Giờ máy LÚC BẤM (ms) của check-in/check-out — `client_time` trong payload; thiếu thì lúc xếp hàng. Lúc xếp hàng có thể
  /// muộn ~30s (dòng được xếp SAU lượt gửi trực tuyến vừa hỏng), nên ưu tiên `client_time`.
  static int _tapWallMs(Map<String, dynamic> payload, SyncQueueEntry entry) =>
      DateTime.tryParse(payload['client_time']?.toString() ?? '')?.millisecondsSinceEpoch ?? entry.createdAt;

  /// Đồng bộ Check-in viếng thăm lên server (§3 & §9)
  Future<void> _syncCreateVisit(SyncQueueEntry entry) async {
    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
    final markedMaybeOnServer = payload[visitMaybeOnServerKey] == true;
    payload.remove(openVisitCountKey);
    payload.remove(visitMaybeOnServerKey);
    payload['is_offline_sync'] = true;
    payload['client_uuid'] = entry.clientUuid;

    // Nếu customer_id là ID âm hoặc chưa có, tìm theo customer_client_uuid hoặc parentUuid (§5.3)
    int? customerId;
    if (payload['customer_id'] != null) {
      customerId = int.tryParse(payload['customer_id'].toString());
    }
    final customerUuid = payload['customer_client_uuid']?.toString() ?? entry.parentUuid;
    if (customerId == null || customerId <= 0) {
      if (customerUuid != null && customerUuid.isNotEmpty) {
        final parentCustomer = await _db.getEntryByClientUuid(customerUuid);
        if (parentCustomer != null && parentCustomer.serverId != null && parentCustomer.serverId! > 0) {
          payload['customer_id'] = parentCustomer.serverId;
        } else {
          // Dự phòng kiểm tra bảng LocalCustomers nếu hàng đợi đồng bộ đã được dọn
          final localCust = await (_db.select(_db.localCustomers)
                ..where((tbl) => tbl.clientUuid.equals(customerUuid))
                ..limit(1))
              .getSingleOrNull();
          if (localCust != null && localCust.id != null && localCust.id! > 0) {
            payload['customer_id'] = localCust.id;
          } else {
            _throwParentUnresolved(entry, parentCustomer, 'Chưa có serverId của điểm bán cha cho lượt viếng thăm', parentUuid: customerUuid);
          }
        }
      } else {
        throw const AppException('Lượt viếng thăm thiếu mã điểm bán hợp lệ để mở lượt', 422);
      }
    }

    // Tính queued_seconds từ hardware clock (§9.1)
    final queuedSec = SystemClock.calculateQueuedSeconds(
      createdElapsedMs: entry.createdElapsed,
      entryBootId: entry.bootId,
      wallFallbackCreatedAtMs: _tapWallMs(payload, entry), // máy khởi động lại ⇒ theo giờ máy (#24698 lỗi 4)
    );
    if (queuedSec != null) {
      payload['queued_seconds'] = queuedSec;
    }
    payload['client_boot_id'] = entry.bootId;

    // Đánh dấu "có thể đã tới server" NGAY TRƯỚC khi gửi (sau mọi bước có thể dừng mà chưa gửi, vd chờ điểm bán cha): hỏng
    // giữa chừng (quá giờ, mất phản hồi) thì huỷ lượt không được xoá thẳng dòng này nữa (#24698 lỗi 6).
    if (!markedMaybeOnServer) {
      final stored = jsonDecode(entry.payload) as Map<String, dynamic>;
      await _db.updatePayload(entry.id, jsonEncode({...stored, visitMaybeOnServerKey: true}));
    }

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

    // Cập nhật serverId cho lượt viếng thăm trong cache cục bộ — CHỈ theo clientUuid: khớp thêm "id < 0" là gán mã
    // của lượt A cho lượt offline B đang mở (nhiều lượt offline cùng chờ mạng), ảnh/check-out của B đổ vào A.
    // Lượt ở điểm bán tạo ngoại tuyến (customerId 0) nhận luôn id server của điểm bán vừa tra được (#24698 vòng 2).
    final resolvedCustomerId = int.tryParse(payload['customer_id']?.toString() ?? '') ?? 0;
    VisitEntity withServerIds(VisitEntity v) => v.copyWith(
          id: serverId,
          customerId: v.customerId <= 0 && resolvedCustomerId > 0 ? resolvedCustomerId : null,
        );
    if (serverId != null) {
      try {
        final visitRepo = _ref.read(visitRepositoryProvider);
        final all = await visitRepo.getAllLocalVisits();
        final idx = all.indexWhere((v) => v.clientUuid == entry.clientUuid);
        if (idx >= 0) {
          final updated = withServerIds(all[idx]);
          await visitRepo.saveLocalVisit(updated);
        }
        final active = await visitRepo.getActiveVisit();
        if (active != null && active.clientUuid == entry.clientUuid) {
          final updatedActive = withServerIds(active);
          await visitRepo.saveActiveVisit(updatedActive);

          try {
            _ref.read(routeViewModelProvider.notifier).setActiveVisit(updatedActive);
          } catch (_) {}
          try {
            _ref
                .read(checkInViewModelProvider.notifier)
                .syncServerVisitId(serverId, clientUuid: entry.clientUuid, customerId: resolvedCustomerId);
          } catch (_) {}
          try {
            // §1.3 SPEC-2026-10-18: Tải lại biểu mẫu khảo sát ngay khi đồng bộ xong check-in ngoại tuyến
            _ref
                .read(checkInViewModelProvider.notifier)
                .loadSurveyForms(updatedActive.customerId);
          } catch (_) {}
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
    SyncQueueEntry? parent;
    if ((visitId == null || visitId <= 0) && entry.parentUuid != null) {
      parent = await _db.getEntryByClientUuid(entry.parentUuid!);
      if (parent != null && parent.serverId != null && parent.serverId! > 0) {
        visitId = parent.serverId;
      }
    }

    if (visitId == null || visitId <= 0) {
      _throwParentUnresolved(entry, parent, 'Chưa có serverId của lượt viếng thăm cha');
    }

    // Mất tệp ảnh ⇒ báo lỗi (dead, hiện ở "Lỗi đồng bộ"), KHÔNG đánh dấu "đã gửi" — lượt sẽ thiếu ảnh mà không ai biết.
    final file = await _existingLocalFile(entry.localPath);
    if (file == null) {
      throw const AppException('Tệp ảnh viếng thăm không còn trên máy, không gửi được.', 410);
    }

    final preparedFile = await ImageUploadHelper.prepareImageForUpload(file);
    final fileName = ImageUploadHelper.getValidFileName(preparedFile.path);

    final formMap = <String, dynamic>{
      // fromFile: đọc theo luồng khi gửi, không giữ cả tệp ảnh trong RAM (như các chỗ gửi ảnh khác).
      'file': await MultipartFile.fromFile(preparedFile.path, filename: fileName),
      'photo_type': payload['photo_type'] ?? 'other',
    };
    if (payload['lat'] != null) formMap['lat'] = payload['lat'];
    if (payload['lng'] != null) formMap['lng'] = payload['lng'];
    if (payload['taken_at'] != null) formMap['taken_at'] = payload['taken_at'];

    final formData = FormData.fromMap(formMap);
    await _apiClient.postMultipart('/dms/visits/$visitId/photos', formData: formData);

    await _db.markDone(entry.id);

    if (file.path.contains('offline_visit_photos')) {
      try {
        if (await file.exists()) await file.delete();
      } catch (err) {
        debugPrint('[SyncService] Xoá file lỗi: $err');
      }
    }

    debugPrint('[SyncService] Tải ảnh viếng thăm lên thành công cho lượt #$visitId');
  }

  /// Gửi một thao tác vật tư (#24522) nằm hàng đợi: `is_offline_sync=true` + `queued_seconds` (đồng hồ phần cứng)
  /// ở cả lô lẫn phần tử, CÙNG `client_uuid` sinh lúc bấm. Phản hồi 200 vẫn có thể `ok:false` ⇒ ném 422 (dead, hiện
  /// câu lỗi của server ở "Lỗi đồng bộ") — không thử lại mãi một thao tác server đã nói không.
  Future<void> _syncVisitMaterial(SyncQueueEntry entry) async {
    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
    final op = materialOperationFromQueuePayload(entry.payload);
    if (op == null) throw AppException('Thao tác vật tư trên máy bị hỏng, không gửi được.', 422);

    int? visitId = int.tryParse(payload['visit_id']?.toString() ?? '');
    SyncQueueEntry? parent;
    if ((visitId == null || visitId <= 0) && entry.parentUuid != null) {
      parent = await _db.getEntryByClientUuid(entry.parentUuid!);
      if (parent != null && parent.serverId != null && parent.serverId! > 0) {
        visitId = parent.serverId;
      }
    }
    if (visitId == null || visitId <= 0) {
      _throwParentUnresolved(entry, parent, 'Chưa có serverId của lượt viếng thăm cha cho thao tác vật tư');
    }

    final resolved = await resolveOperationPhotos(
      op,
      (file) async => (await _ref.read(formsApiServiceProvider).uploadPhoto(file)).token,
    );
    final queuedSec = SystemClock.calculateQueuedSeconds(
      createdElapsedMs: entry.createdElapsed,
      entryBootId: entry.bootId,
    );
    final body = buildMaterialsRequest(
      [resolved.toItemJson(isOfflineSync: true, queuedSeconds: queuedSec)],
      isOfflineSync: true,
      queuedSeconds: queuedSec,
    );
    final res = await _ref.read(visitMaterialApiServiceProvider).saveMaterials(visitId, body);
    final r = res.resultFor(resolved.clientUuid, 0);
    // Phản hồi 200 mà thiếu kết quả = máy chủ trả sai — tính như lỗi máy chủ (đếm vào trần bỏ cuộc), không phải lỗi mạng.
    if (r == null) throw AppException('Phản hồi lưu vật tư không hợp lệ từ máy chủ.', 502);
    if (!r.ok) throw AppException(r.error ?? 'Máy chủ từ chối thao tác vật tư.', 422);

    await _db.markDone(entry.id, serverId: r.logId);
    debugPrint('[SyncService] Đồng bộ thao tác vật tư thành công cho lượt #$visitId (uuid ${entry.clientUuid})');
  }

  /// Đồng bộ Check-out viếng thăm lên server (§7 & §9)
  Future<void> _syncCheckoutVisit(SyncQueueEntry entry) async {
    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
    int? visitId;
    if (payload['visit_id'] != null) {
      visitId = int.tryParse(payload['visit_id'].toString());
    }

    // Nếu visitId là ID âm hoặc chưa có, tìm theo parentUuid
    SyncQueueEntry? parent;
    if ((visitId == null || visitId <= 0) && entry.parentUuid != null) {
      parent = await _db.getEntryByClientUuid(entry.parentUuid!);
      if (parent != null && parent.serverId != null && parent.serverId! > 0) {
        visitId = parent.serverId;
      }
    }

    if (visitId == null || visitId <= 0) {
      _throwParentUnresolved(entry, parent, 'Chưa có serverId của lượt viếng thăm cha để check-out');
    }

    payload['is_offline_sync'] = true;

    // Tính queued_seconds từ hardware clock (§9.1)
    final queuedSec = SystemClock.calculateQueuedSeconds(
      createdElapsedMs: entry.createdElapsed,
      entryBootId: entry.bootId,
      wallFallbackCreatedAtMs: _tapWallMs(payload, entry), // máy khởi động lại ⇒ theo giờ máy (#24698 lỗi 4)
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
      try {
        _ref.read(travelViewModelProvider.notifier).loadMyTravel(refresh: true);
      } catch (_) {}
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
      } else if (parent != null && (parent.state == 'pending' || parent.state == 'sending')) {
        // Huỷ lúc check-in còn đang gửi dở: CHỜ check-in có mã server rồi mới huỷ — đánh dấu xong ở đây là để lượt
        // treo trên server khi check-in lên tới nơi.
        throw const _ParentPendingException('Chờ check-in của lượt lên server rồi mới huỷ');
      } else if (parent != null && parent.state == 'done') {
        // Check-in ĐÃ lên server mà máy không giữ được mã lượt: không huỷ được — báo lỗi (hiện ở "Lỗi đồng bộ") thay vì
        // đánh dấu xong để lượt mở treo trên server mà không ai biết.
        throw const AppException('Không xác định được lượt viếng thăm trên máy chủ để huỷ — báo quản lý đóng lượt.', 410);
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
        await _clearActiveVisitIf(visitId, entry.parentUuid);
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
          await _clearActiveVisitIf(visitId, entry.parentUuid);
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

  /// Bỏ bản lưu "lượt đang mở" CHỈ khi nó là lượt vừa huỷ ([visitId] / [visitClientUuid]). Lệnh huỷ lượt A thường tới
  /// server SAU khi nhân viên đã check-in lượt B — xoá vô điều kiện là mất lượt B trên máy (#24698 vòng 2).
  Future<void> _clearActiveVisitIf(int visitId, String? visitClientUuid) async {
    final visitRepo = _ref.read(visitRepositoryProvider);
    final active = await visitRepo.getActiveVisit();
    if (active == null) return;
    if (active.id == visitId || (visitClientUuid != null && active.clientUuid == visitClientUuid)) {
      await visitRepo.clearActiveVisit();
    }
  }

  /// Tải một ảnh lên [path] (kho ảnh tạm của biểu mẫu / khai báo vị trí), trả token. KHÔNG nuốt lỗi: lỗi mạng/5xx ném
  /// ra để cả mục thử lại — nuốt thì phiếu đi lên thiếu ảnh (hoặc mang đường dẫn trên máy ⇒ 422 ⇒ mất phiếu).
  Future<String> _uploadTempPhoto(String path, File file) async {
    final preparedFile = await ImageUploadHelper.prepareImageForUpload(file);
    final fileName = ImageUploadHelper.getValidFileName(preparedFile.path);

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(preparedFile.path, filename: fileName),
    });
    final res = await _apiClient.postMultipart(path, formData: formData);
    if (res is Map && res['data'] is Map && res['data']['token'] != null) {
      return res['data']['token'].toString();
    }
    throw const AppException('Phản hồi tải ảnh không hợp lệ từ máy chủ.', 502);
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
          _throwParentUnresolved(entry, parent, 'Chưa có serverId của lượt viếng thăm cha cho biểu mẫu');
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
            final file = await _existingLocalFile(p.toString());
            // Mất tệp ⇒ báo lỗi (dead), không nộp phiếu thiếu ảnh mà không ai biết.
            if (file == null) {
              throw const AppException('Ảnh của phiếu không còn trên máy, không gửi được.', 410);
            }
            newTokens.add(await _uploadTempPhoto('/dms/form-photos', file));
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
    // Bộ đếm lỗi máy chủ của hàng đợi ([recordVisitMaterialFailure]) là khoá nội bộ.
    sendPayload.removeWhere((k, _) => k.startsWith('_server_failure'));

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
          // Mất tệp ⇒ báo lỗi (dead), không gửi khai báo thiếu ảnh mà không ai biết — cùng luật ảnh phiếu/viếng thăm.
          if (!await file.exists()) {
            throw const AppException('Ảnh khai báo vị trí không còn trên máy, không gửi được.', 410);
          }
          final token = await _uploadTempPhoto('/dms/position-photos', file);
          if (!resolvedTokens.contains(token)) {
            resolvedTokens.add(token);
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
    // Giờ công = giờ server lúc nhận − khoảng nằm chờ (#24618, chủ hệ thống chốt 02/11/2026): gửi khoảng chờ đo bằng
    // đồng hồ máy (cùng cách check-in). Máy đã khởi động lại ⇒ null ⇒ KHÔNG gửi (server ghi giờ nhận, không đoán).
    payload['is_offline_sync'] = '1';
    final queuedSec = SystemClock.calculateQueuedSeconds(
      createdElapsedMs: entry.createdElapsed,
      entryBootId: entry.bootId,
    );
    if (queuedSec != null) {
      payload['queued_seconds'] = queuedSec;
    }
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
    SyncQueueEntry? parent;
    if ((punchId == null || punchId <= 0)) {
      if (entry.parentUuid != null) {
        parent = await _db.getEntryByClientUuid(entry.parentUuid!);
        if (parent != null && parent.serverId != null && parent.serverId! > 0) {
          punchId = parent.serverId;
        }
      }
      // Dự phòng CHỈ cho dòng cũ không ghi lượt cha: lấy lượt chấm gần nhất đã đồng bộ. Có cha mà cha chưa lên
      // server (đang chờ thử lại) thì CHỜ cha — lấy "lượt gần nhất" lúc đó là gắn ảnh ra ca vào lượt vào ca.
      if ((punchId == null || punchId <= 0) && entry.parentUuid == null) {
        final lastPunch = await _db.findLastSyncedPunchEntry();
        if (lastPunch != null && lastPunch.serverId != null && lastPunch.serverId! > 0) {
          punchId = lastPunch.serverId;
        }
      }
    }

    if (punchId == null || punchId <= 0) {
      debugPrint('[SyncService] Chưa tìm thấy serverId của lượt chấm cho ảnh, giữ lại để retry sau');
      _throwParentUnresolved(entry, parent, 'Lượt chấm công chưa được đồng bộ lên máy chủ');
    }

    final file = await _existingLocalFile(entry.localPath ?? payload['local_path']?.toString());
    if (file == null) {
      throw const AppException('Tệp ảnh chấm công không còn trên máy, không gửi được.', 410);
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
    final data = dioErr.response?.data;
    return await _handleErrorByStatus(entry, statusCode, errorMsg, currentDeadErrors,
        errorCode: data is Map ? data['code']?.toString() : null);
  }

  /// Xử lý lỗi từ AppException
  Future<_SyncItemStatus> _handleAppException(
    SyncQueueEntry entry,
    AppException appErr,
    List<SyncDeadError> currentDeadErrors,
  ) async {
    return await _handleErrorByStatus(entry, appErr.statusCode, appErr.message, currentDeadErrors,
        parentPending: appErr is _ParentPendingException, errorCode: appErr.code);
  }

  /// Xử lý lỗi chung (ngoại lệ mạng hoặc không xác định)
  Future<_SyncItemStatus> _handleGenericError(SyncQueueEntry entry, String errorMessage) async {
    return await _handleErrorByStatus(entry, null, errorMessage, []);
  }

  /// Xử lý lỗi tập trung theo status code:
  /// - 401 / DMS_APP_FORBIDDEN: lỗi của PHIÊN đăng nhập -> giữ pending, dừng lô ([_SyncItemStatus.authBlocked])
  /// - 4xx khác (trừ 408/429): Lỗi hỏng vĩnh viễn -> KHÔNG RETRY, chuyển 'dead', báo cho người dùng
  /// - 408 / 429 / 5xx / Network (statusCode == null): Lỗi tạm thời -> RETRY với Exponential Backoff
  Future<_SyncItemStatus> _handleErrorByStatus(
    SyncQueueEntry entry,
    int? statusCode,
    String errorMsg,
    List<SyncDeadError> currentDeadErrors, {
    bool parentPending = false,
    String? errorCode,
  }) async {
    // 0. Phiên hết hạn / tài khoản bị thu quyền app: dữ liệu của mục KHÔNG sai — đăng nhập lại là gửi được. Chuyển
    // dead ở đây (bản cũ) là mất trắng: mục dead chỉ xoá được, và cả lô phía sau cũng nhận đúng lỗi này.
    if (statusCode == 401 || errorCode == 'DMS_APP_FORBIDDEN') {
      _lastAuthBlockForbidden = errorCode == 'DMS_APP_FORBIDDEN';
      await _db.reschedule(
        entry.id,
        nextAttemptAt: DateTime.now().millisecondsSinceEpoch + authBlockedRetryDelay.inMilliseconds,
        attempts: entry.attempts,
        error: errorMsg,
      );
      return _SyncItemStatus.authBlocked;
    }

    // 1. §9: Nếu nhận 422 "đã check-out rồi" hoặc "đã đóng" -> Coi là THÀNH CÔNG để dọn hàng đợi
    // CHỈ cho check-out / huỷ lượt (đóng lượt hai lần là cùng kết quả). Mục khác (điểm bán, phiếu, ảnh, vật tư…) mà câu
    // lỗi lỡ chứa cụm này ("Tuyến đã đóng", nhãn tự do…) thì bị nuốt thành "đã gửi" — mất dữ liệu không báo.
    if (statusCode == 422 &&
        entry.entity == 'visit' &&
        (entry.op == 'checkout' || entry.op == 'cancel') &&
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
    // Lối thoát cho thao tác vật tư: lỗi máy chủ (5xx / trả sai) lặp lại tới trần thì bỏ cuộc (dead) — nếu không,
    // check-out của lượt bị giữ mãi sau nó ([AppDatabase.isCheckoutHeld]) và lượt treo trên server.
    // Ảnh / phiếu của lượt cũng ghi chuỗi lỗi (chỉ để thôi giữ check-out — [releasesCheckout]), không bỏ cuộc. Với
    // chúng MỌI lần gửi hỏng đều đếm (5xx, quá giờ, lỗi nén ảnh/tệp…) — chỉ "đang chờ lượt cha" không đếm; vật tư giữ luật
    // cũ (chỉ lỗi máy chủ đếm, lỗi mạng cắt chuỗi).
    var giveUp = false;
    if (AppDatabase.checkoutGatedEntities.contains(entry.entity) &&
        !parentPending &&
        (statusCode == null || statusCode >= 500)) {
      final (payload, stop) = recordVisitMaterialFailure(
        entry.payload,
        serverError: statusCode != null || entry.entity != 'visit_material',
        nowMs: DateTime.now().millisecondsSinceEpoch,
      );
      if (payload != entry.payload) await _db.updatePayload(entry.id, payload);
      if (stop && entry.entity == 'visit_material') {
        giveUp = true;
        errorMsg = 'Máy chủ lỗi ${visitMaterialServerFailures(payload)} lần liên tiếp trong hơn '
            '${visitMaterialGiveUpAfter.inMinutes} phút khi lưu vật tư — đã dừng gửi: $errorMsg';
      }
    }

    // 408 (quá giờ) / 429 (quá tải — proxy/LB trả) là lỗi TẠM, cùng luật đường trực tuyến (CustomerRepositoryImpl).
    // Check-in bị từ chối vì còn lượt trước chưa check-out (DMS_VISIT_STILL_OPEN): CHỜ — lượt trước được check-out /
    // huỷ là gửi được; coi là lỗi vĩnh viễn thì lượt mới (cùng ảnh, phiếu, check-out của nó) bị bỏ trắng.
    var stillOpen = errorCode == openVisitErrorCode && entry.entity == 'visit' && entry.op == 'create';
    // Lượt trước có check-out / huỷ bị từ chối hẳn ⇒ chờ nhân viên đóng lại nó (hoặc cron đầu ngày), KHÔNG đếm vào trần.
    if (stillOpen && !await _db.hasDeadVisitCloseBefore(entry)) {
      Map<String, dynamic> p = {};
      try {
        p = jsonDecode(entry.payload) as Map<String, dynamic>;
      } catch (_) {}
      final count = ((p[openVisitCountKey] as num?)?.toInt() ?? 0) + 1;
      p[openVisitCountKey] = count;
      await _db.updatePayload(entry.id, jsonEncode(p));
      if (count >= openVisitMaxAttempts) {
        stillOpen = false;
        errorMsg = 'Lượt trước vẫn chưa được check-out / huỷ sau $count lần thử — vào lượt đang mở để đóng nó: $errorMsg';
      }
    }
    final permanentClientError = !stillOpen &&
        statusCode != null && statusCode >= 400 && statusCode < 500 && statusCode != 408 && statusCode != 429;
    if (giveUp || permanentClientError) {
      debugPrint('[SyncService] [4xx - LỖI HỎNG VĨNH VIỄN] Mục #${entry.id} ($statusCode): $errorMsg -> Chuyển "dead", KHÔNG RETRY.');
      await _db.markDead(entry.id, errorMsg);

      // Khách hàng -> đánh dấu lỗi đồng bộ (KHÔNG phải "bị từ chối duyệt" — xem markCustomerSyncError)
      if (entry.entity == 'customer') {
        await _db.markCustomerSyncError(entry.clientUuid, errorMsg);
        try {
          _ref.read(customerViewModelProvider.notifier).loadCustomers(isRefresh: true);
        } catch (_) {}
      } else if (entry.entity == 'visit_material') {
        // Op bị từ chối không được sống lại thành "đã kiểm" từ cache khi NV xoá dòng lỗi.
        await forgetCachedMaterialOp(entry.clientUuid);
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

    // 4. Phân loại lỗi 408 / 429 / 5xx hoặc Lỗi mạng (statusCode == null):
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
