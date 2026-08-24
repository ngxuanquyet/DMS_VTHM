import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/offline_dialog.dart';

class ConnectivityState {
  final bool isOnline;
  final bool isDialogVisible;

  const ConnectivityState({
    this.isOnline = true,
    this.isDialogVisible = false,
  });

  ConnectivityState copyWith({
    bool? isOnline,
    bool? isDialogVisible,
  }) {
    return ConnectivityState(
      isOnline: isOnline ?? this.isOnline,
      isDialogVisible: isDialogVisible ?? this.isDialogVisible,
    );
  }
}

final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
  return ConnectivityNotifier();
});

class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _heartbeatTimer;
  bool _isChecking = false;

  ConnectivityNotifier() : super(const ConnectivityState()) {
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    // 1. Initial immediate check
    checkConnectivity();

    // 2. Real-time native OS broadcast stream (0ms latency on Android/iOS)
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _processConnectivityResults(results);
    });

    // 3. Fallback active ping every 5 seconds
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    if (!bindingName.contains('TestWidgetsFlutterBinding') &&
        !bindingName.contains('AutomatedTestWidgetsFlutterBinding')) {
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted) {
          checkConnectivity();
        }
      });
    }
  }

  Future<void> _processConnectivityResults(List<ConnectivityResult> results) async {
    if (!mounted) return;

    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      // Hardware is completely disconnected
      _handleStatusChange(false);
    } else {
      // Connected to WiFi/Mobile network - verify internet reachability
      final hasRealInternet = await _pingInternet();
      _handleStatusChange(hasRealInternet);
    }
  }

  Future<bool> checkConnectivity() async {
    if (!mounted || _isChecking) return mounted ? state.isOnline : true;
    _isChecking = true;

    try {
      if (kIsWeb) {
        _handleStatusChange(true);
        return true;
      }

      final results = await _connectivity.checkConnectivity();
      if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
        _handleStatusChange(false);
        return false;
      }

      final hasInternet = await _pingInternet();
      _handleStatusChange(hasInternet);
      return hasInternet;
    } catch (_) {
      _handleStatusChange(false);
      return false;
    } finally {
      _isChecking = false;
    }
  }

  Future<bool> _pingInternet() async {
    try {
      final result = await InternetAddress.lookup('8.8.8.8')
          .timeout(const Duration(milliseconds: 2000));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _handleStatusChange(bool hasConnection) {
    if (!mounted) return;

    final wasOnline = state.isOnline;

    if (wasOnline != hasConnection) {
      state = state.copyWith(isOnline: hasConnection);

      if (!hasConnection) {
        // MẤT MẠNG -> Tự động hiện popup modal mất mạng
        showOfflineDialog();
      } else {
        // CÓ MẠNG LẠI -> Tự động ẩn popup (nếu đang mở) và hiện thanh thông báo màu xanh trong 3s
        hideOfflineDialog();
        showReconnectedToast();
      }
    }
  }

  /// Triggered automatically on network loss or from ApiClient on Dio network errors
  void handleNetworkDisconnection() {
    if (!mounted) return;
    state = state.copyWith(isOnline: false);
    showOfflineDialog();
  }

  /// Manually or automatically open the offline disconnect dialog
  void showOfflineDialog() {
    if (!mounted) return;

    try {
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        state = state.copyWith(isDialogVisible: true);
        OfflineDisconnectDialog.show(
          context,
          onDismiss: () {
            if (mounted) {
              state = state.copyWith(isDialogVisible: false);
            }
          },
        );
      }
    } catch (_) {
      // In non-UI unit tests, ignore widget tree binding lookup
    }
  }

  /// Automatically hide/dismiss the offline disconnect dialog when connection is restored
  void hideOfflineDialog() {
    if (!mounted) return;
    OfflineDisconnectDialog.dismiss();
    state = state.copyWith(isDialogVisible: false);
  }

  /// Show sleek green bottom banner notification sliding up from bottom for 3 seconds
  void showReconnectedToast() {
    try {
      final messenger = rootScaffoldMessengerKey.currentState;
      if (messenger != null) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            padding: EdgeInsets.zero,
            content: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: AppRadius.roundedLg,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.wifi_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Đã khôi phục kết nối mạng',
                          style: AppTypography.labelLarge(color: Colors.white).copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Hệ thống đang tự động đồng bộ dữ liệu...',
                          style: AppTypography.bodySmall(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primaryFixed,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (_) {}
  }

  /// Simulate disconnection for testing
  void simulateOffline() {
    if (!mounted) return;
    _handleStatusChange(false);
  }

  /// Restore online status for testing
  void simulateOnline() {
    if (!mounted) return;
    _handleStatusChange(true);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}
