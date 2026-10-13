import '../../data/models/location_pending_request_model.dart';

class EmployeeTrackingState {
  final bool isEnabledByServer;
  final bool isPermissionGranted;
  final int nextIntervalSec;
  final bool isPinging;
  final DateTime? lastPingTime;
  final bool? lastPingSuccess;
  final String? lastError;
  final int pendingPointsCount;
  final LocationPendingRequestModel? activePendingRequest;
  final bool isFeatureBlockedByRule; // 422 LOCATION_RULE: Tắt tính năng
  final bool isPermissionForbidden; // 403: Thiếu quyền

  const EmployeeTrackingState({
    this.isEnabledByServer = true,
    this.isPermissionGranted = false,
    this.nextIntervalSec = 180,
    this.isPinging = false,
    this.lastPingTime,
    this.lastPingSuccess,
    this.lastError,
    this.pendingPointsCount = 0,
    this.activePendingRequest,
    this.isFeatureBlockedByRule = false,
    this.isPermissionForbidden = false,
  });

  /// Kiểm tra xem tính năng có đang thực sự chia sẻ vị trí hay không
  bool get isSharing =>
      isEnabledByServer &&
      isPermissionGranted &&
      !isFeatureBlockedByRule &&
      !isPermissionForbidden;

  EmployeeTrackingState copyWith({
    bool? isEnabledByServer,
    bool? isPermissionGranted,
    int? nextIntervalSec,
    bool? isPinging,
    DateTime? lastPingTime,
    bool? lastPingSuccess,
    String? lastError,
    int? pendingPointsCount,
    LocationPendingRequestModel? activePendingRequest,
    bool clearActivePendingRequest = false,
    bool? isFeatureBlockedByRule,
    bool? isPermissionForbidden,
  }) {
    return EmployeeTrackingState(
      isEnabledByServer: isEnabledByServer ?? this.isEnabledByServer,
      isPermissionGranted: isPermissionGranted ?? this.isPermissionGranted,
      nextIntervalSec: nextIntervalSec ?? this.nextIntervalSec,
      isPinging: isPinging ?? this.isPinging,
      lastPingTime: lastPingTime ?? this.lastPingTime,
      lastPingSuccess: lastPingSuccess ?? this.lastPingSuccess,
      lastError: lastError,
      pendingPointsCount: pendingPointsCount ?? this.pendingPointsCount,
      activePendingRequest: clearActivePendingRequest
          ? null
          : (activePendingRequest ?? this.activePendingRequest),
      isFeatureBlockedByRule: isFeatureBlockedByRule ?? this.isFeatureBlockedByRule,
      isPermissionForbidden: isPermissionForbidden ?? this.isPermissionForbidden,
    );
  }
}
