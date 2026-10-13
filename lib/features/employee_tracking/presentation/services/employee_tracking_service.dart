import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/app_notification_service.dart';
import '../../../../core/services/location_service.dart';
import '../../data/datasources/employee_tracking_api_service.dart';
import '../../data/datasources/employee_tracking_local_storage.dart';
import '../../data/models/location_pending_request_model.dart';
import '../../data/models/location_ping_point_model.dart';
import '../../domain/entities/employee_tracking_state.dart';

final employeeTrackingLocalStorageProvider = Provider<EmployeeTrackingLocalStorage>((ref) {
  return EmployeeTrackingLocalStorage();
});

final employeeTrackingProvider =
    StateNotifierProvider<EmployeeTrackingNotifier, EmployeeTrackingState>((ref) {
  final apiService = ref.watch(employeeTrackingApiServiceProvider);
  final storage = ref.watch(employeeTrackingLocalStorageProvider);
  final notifService = ref.watch(appNotificationServiceProvider);

  final notifier = EmployeeTrackingNotifier(
    apiService: apiService,
    storage: storage,
    notifService: notifService,
  );
  return notifier;
});

class EmployeeTrackingNotifier extends StateNotifier<EmployeeTrackingState>
    with WidgetsBindingObserver {
  final EmployeeTrackingApiService _apiService;
  final EmployeeTrackingLocalStorage _storage;
  final AppNotificationService _notifService;

  Timer? _periodicTimer;
  bool _isDisposed = false;
  int _lastHandledRequestId = -1;
  Position? _lastKnownPosition;

  EmployeeTrackingNotifier({
    required EmployeeTrackingApiService apiService,
    required EmployeeTrackingLocalStorage storage,
    required AppNotificationService notifService,
  })  : _apiService = apiService,
        _storage = storage,
        _notifService = notifService,
        super(const EmployeeTrackingState()) {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Khởi động dịch vụ theo dõi vị trí khi người dùng đăng nhập / mở app
  Future<void> startService() async {
    if (_isDisposed) return;

    // 1. Kiểm tra quyền vị trí (§0: Không có quyền thì tắt tính năng, không chặn app)
    await _checkPermissionStatus();

    // 2. Tải số lượng điểm chờ trong hàng đợi offline
    final pendingCount = await _storage.getPendingCount();
    state = state.copyWith(pendingPointsCount: pendingCount);

    // 3. Hỏi trạng thái từ server & kiểm tra lệnh chờ (§3: GET /dms/locations/pending)
    await refreshPendingRequest();

    // 4. Nếu app đang ở foreground và có quyền -> Bắt đầu hẹn giờ gửi (§0 & §2)
    _startOrRestartPeriodicTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (_isDisposed) return;

    switch (lifecycleState) {
      case AppLifecycleState.resumed:
        // App mở lại foreground -> khôi phục timer & kiểm tra lệnh chờ
        _startOrRestartPeriodicTimer();
        refreshPendingRequest();
        break;

      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // App chuyển nền hoặc thoát:
        // 1. DỪNG timer (§0: Tuyệt đối KHÔNG chạy nền ngầm cả ngày)
        _stopPeriodicTimer();
        // 2. Gửi MỘT điểm cuối source=app_exit (§0 & §2)
        _sendAppExitPoint();
        break;
      case AppLifecycleState.hidden:
        _stopPeriodicTimer();
        break;
    }
  }

  /// Bắt đầu hoặc khởi động lại Timer gửi định kỳ theo nhịp next_interval_sec của server
  void _startOrRestartPeriodicTimer() {
    _stopPeriodicTimer();

    if (!state.isSharing) {
      return;
    }

    final intervalSec = state.nextIntervalSec > 0 ? state.nextIntervalSec : 180;
    debugPrint('[EmployeeTracking] Hẹn giờ gửi vị trí định kỳ mỗi $intervalSec giây');

    _periodicTimer = Timer.periodic(Duration(seconds: intervalSec), (timer) {
      _onPeriodicTick();
    });
  }

  void _stopPeriodicTimer() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Xử lý mỗi nhịp hẹn giờ foreground (source: 'auto')
  Future<void> _onPeriodicTick() async {
    if (!state.isSharing || state.isPinging) return;

    try {
      final pos = await _getCurrentPosition();
      if (pos == null) return;
      _lastKnownPosition = pos;

      final point = LocationPingPointModel.create(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracyM: pos.accuracy,
        isMockLocation: pos.isMocked,
        source: 'auto',
        appVersion: AppConstants.appVersion,
      );

      // Đưa vào hàng đợi và gửi bù (kèm các điểm offline trước đó nếu có)
      await _storage.enqueuePoint(point);
      await _flushQueue();
    } catch (e) {
      debugPrint('[EmployeeTracking] Lỗi tick định kỳ: $e');
    }
  }

  /// Gửi MỘT điểm cuối khi app chuyển nền hoặc thoát (source: 'app_exit')
  Future<void> _sendAppExitPoint() async {
    if (state.isPermissionForbidden || state.isFeatureBlockedByRule) return;

    try {
      Position? pos;
      try {
        // Cố gắng đo nhanh với timeout 2.5s, nếu không kịp dùng tọa độ gần nhất
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(milliseconds: 2500),
        );
      } catch (_) {
        pos = _lastKnownPosition ?? LocationService.currentCachedPosition;
      }

      if (pos == null) return;

      final point = LocationPingPointModel.create(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracyM: pos.accuracy,
        isMockLocation: pos.isMocked,
        source: 'app_exit',
        appVersion: AppConstants.appVersion,
      );

      // Đưa vào hàng đợi
      await _storage.enqueuePoint(point);

      // Cố gắng gửi ngay trong vòng đời còn lại
      final batch = await _storage.getPendingBatch(limit: 200);
      if (batch.isNotEmpty) {
        final res = await _apiService.pingLocations(batch);
        if (res.success) {
          await _storage.removeByClientUuids(batch.map((p) => p.clientUuid));
        }
      }
    } catch (e) {
      debugPrint('[EmployeeTracking] Lỗi gửi điểm app_exit: $e');
      // Điểm đã lưu trong storage, sẽ tự động gửi bù ở lần mở app kế tiếp
    }
  }

  /// Gửi toàn bộ điểm trong hàng đợi (tối đa 200 điểm/lượt)
  Future<void> _flushQueue() async {
    if (state.isPinging) return;

    final batch = await _storage.getPendingBatch(limit: 200);
    if (batch.isEmpty) return;

    state = state.copyWith(isPinging: true);

    try {
      final res = await _apiService.pingLocations(batch);

      // Cập nhật số điểm đã dọn khỏi hàng đợi
      final sentUuids = batch.map((p) => p.clientUuid).toList();
      await _storage.removeByClientUuids(sentUuids);

      final remainingCount = await _storage.getPendingCount();

      // Cập nhật nhịp gửi kế tiếp từ server nếu thay đổi
      final hasIntervalChanged = res.nextIntervalSec != state.nextIntervalSec;

      state = state.copyWith(
        isPinging: false,
        lastPingTime: DateTime.now(),
        lastPingSuccess: true,
        pendingPointsCount: remainingCount,
        nextIntervalSec: res.nextIntervalSec,
      );

      // Nếu admin đổi nhịp gửi (ví dụ 180 -> 300) -> cập nhật lại Timer ngay
      if (hasIntervalChanged) {
        _startOrRestartPeriodicTimer();
      }

      // Kiểm tra có lệnh xin vị trí đang chờ trong phản hồi ping không (§2 & §3)
      if (res.pendingRequest != null) {
        await handlePendingRequest(res.pendingRequest!);
      }
    } on LocationTrackingDisabledException catch (e) {
      // 422 LOCATION_RULE: Server tắt tính năng -> Ngừng gửi, không retry
      debugPrint('[EmployeeTracking] Server tắt tính năng vị trí: $e');
      _stopPeriodicTimer();
      state = state.copyWith(
        isPinging: false,
        isFeatureBlockedByRule: true,
        lastError: e.toString(),
      );
    } on LocationPermissionDeniedException catch (e) {
      // 403: Thiếu quyền -> Tắt hẳn tính năng trên máy đó
      debugPrint('[EmployeeTracking] Thiếu quyền 403: $e');
      _stopPeriodicTimer();
      state = state.copyWith(
        isPinging: false,
        isPermissionForbidden: true,
        lastError: e.toString(),
      );
    } on LocationValidationException catch (e) {
      // 422 VALIDATION_ERROR: Lỗi dữ liệu lập trình -> Xoá các điểm lỗi khỏi queue để không kẹt vòng lặp
      debugPrint('[EmployeeTracking] Lỗi validation 422: $e');
      await _storage.removeByClientUuids(batch.map((p) => p.clientUuid));
      final remainingCount = await _storage.getPendingCount();
      state = state.copyWith(
        isPinging: false,
        pendingPointsCount: remainingCount,
        lastError: e.toString(),
      );
    } catch (e) {
      debugPrint('[EmployeeTracking] Lỗi gửi vị trí (ngoại tuyến / mạng): $e');
      state = state.copyWith(
        isPinging: false,
        lastPingSuccess: false,
        lastError: e.toString(),
      );
    }
  }

  /// Hỏi trạng thái server & kiểm tra lệnh "Xin vị trí ngay" (§3: GET /dms/locations/pending)
  Future<void> refreshPendingRequest() async {
    try {
      final res = await _apiService.getPendingRequest();

      final hasIntervalChanged = res.nextIntervalSec != state.nextIntervalSec;

      state = state.copyWith(
        isEnabledByServer: res.enabled,
        nextIntervalSec: res.nextIntervalSec,
        activePendingRequest: res.pendingRequest,
        isFeatureBlockedByRule: !res.enabled,
      );

      if (hasIntervalChanged) {
        _startOrRestartPeriodicTimer();
      }

      if (res.pendingRequest != null) {
        await handlePendingRequest(res.pendingRequest!);
      }
    } on LocationPermissionDeniedException {
      state = state.copyWith(isPermissionForbidden: true);
      _stopPeriodicTimer();
    } catch (e) {
      debugPrint('[EmployeeTracking] Lỗi kiểm tra pending: $e');
    }
  }

  /// Xử lý lệnh "Xin vị trí ngay" theo đúng 3 bước bắt buộc trong §3
  Future<void> handlePendingRequest(LocationPendingRequestModel request) async {
    // Tránh xử lý trùng lặp cùng 1 request_id
    if (_lastHandledRequestId == request.id && !request.isOpen) {
      return;
    }

    // 🔴 Quá expires_at thì ĐỪNG gửi nữa (§3)
    if (request.isExpired()) {
      debugPrint('[EmployeeTracking] Lệnh #${request.id} đã quá hạn (${request.expiresAt}), bỏ qua.');
      state = state.copyWith(clearActivePendingRequest: true);
      return;
    }

    _lastHandledRequestId = request.id;
    state = state.copyWith(activePendingRequest: request);

    // =========================================================================
    // BƯỚC 1: Hiện thông báo cho nhân viên (§3)
    // "{requested_by} đã yêu cầu vị trí của bạn" + reason nếu có
    // =========================================================================
    final reasonText = (request.reason != null && request.reason!.isNotEmpty)
        ? '\nLý do: ${request.reason}'
        : '';
    final message = '${request.requestedBy} đã yêu cầu vị trí của bạn.$reasonText';

    try {
      await _notifService.sendNotification(
        id: request.id,
        title: 'Yêu cầu vị trí từ quản lý',
        message: message,
        type: 'location_request',
        category: 'work',
        showSystemTray: true,
      );
    } catch (e) {
      debugPrint('[EmployeeTracking] Lỗi hiện thông báo: $e');
    }

    // =========================================================================
    // BƯỚC 2: Lấy GPS một lần
    // =========================================================================
    Position? pos = await _getCurrentPosition();
    if (pos == null) {
      debugPrint('[EmployeeTracking] Không thể lấy GPS để trả lời lệnh #${request.id}');
      return;
    }
    _lastKnownPosition = pos;

    // =========================================================================
    // BƯỚC 3: POST /dms/locations/ping với source: "requested" và request_id
    // =========================================================================
    final point = LocationPingPointModel.create(
      lat: pos.latitude,
      lng: pos.longitude,
      accuracyM: pos.accuracy,
      isMockLocation: pos.isMocked,
      source: 'requested',
      requestId: request.id,
      appVersion: AppConstants.appVersion,
    );

    try {
      final res = await _apiService.pingLocations([point]);
      if (res.success) {
        debugPrint('[EmployeeTracking] Đã trả lời lệnh #${request.id} thành công');
        state = state.copyWith(
          clearActivePendingRequest: true,
          lastPingTime: DateTime.now(),
          lastPingSuccess: true,
        );
      }
    } catch (e) {
      debugPrint('[EmployeeTracking] Lỗi gửi trả lời requested ping: $e');
      // Nếu mất mạng, lưu vào queue kèm request_id
      await _storage.enqueuePoint(point);
    }
  }

  /// Tiếp nhận sự kiện Realtime từ Centrifugo: `dms.location.request` (§3.1)
  /// payload: `{request_id, expires_at, requested_by, reason}`
  Future<void> handleCentrifugoEvent(Map<String, dynamic> payload) async {
    try {
      final req = LocationPendingRequestModel(
        id: payload['request_id'] as int? ?? payload['id'] as int? ?? 0,
        requestedBy: payload['requested_by'] as String? ?? 'Quản lý',
        requestedAt: payload['requested_at'] as String? ?? DateTime.now().toIso8601String(),
        expiresAt: payload['expires_at'] as String? ?? '',
        status: 'delivered',
        statusLabel: 'Yêu cầu trực tiếp',
        isOpen: true,
        reason: payload['reason'] as String?,
      );
      await handlePendingRequest(req);
    } catch (e) {
      debugPrint('[EmployeeTracking] Lỗi xử lý Centrifugo event: $e');
    }
  }

  /// Kiểm tra trạng thái quyền vị trí
  Future<void> _checkPermissionStatus() async {
    try {
      final perm = await Geolocator.checkPermission();
      final isGranted = perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse;
      state = state.copyWith(isPermissionGranted: isGranted);
    } catch (_) {}
  }

  /// Yêu cầu người dùng cấp quyền vị trí tường minh (§0 & §7)
  Future<bool> requestPermission() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      final isGranted = perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse;
      state = state.copyWith(isPermissionGranted: isGranted);

      if (isGranted) {
        _startOrRestartPeriodicTimer();
      }
      return isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Đo GPS hiện tại an toàn, không ném ngoại lệ làm crash app
  Future<Position?> _getCurrentPosition() async {
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) return null;

      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('[EmployeeTracking] Đo GPS thất bại: $e');
      return _lastKnownPosition ?? LocationService.currentCachedPosition;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopPeriodicTimer();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
