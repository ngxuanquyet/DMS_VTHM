import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../localization/language_provider.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/location_dialog.dart';

class LocationState {
  final bool isServiceEnabled;
  final LocationPermission permission;
  final bool isChecking;
  final bool isDialogVisible;

  const LocationState({
    this.isServiceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.isChecking = false,
    this.isDialogVisible = false,
  });

  bool get hasPermission =>
      permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;

  bool get isReady => isServiceEnabled && hasPermission;

  LocationState copyWith({
    bool? isServiceEnabled,
    LocationPermission? permission,
    bool? isChecking,
    bool? isDialogVisible,
  }) {
    return LocationState(
      isServiceEnabled: isServiceEnabled ?? this.isServiceEnabled,
      permission: permission ?? this.permission,
      isChecking: isChecking ?? this.isChecking,
      isDialogVisible: isDialogVisible ?? this.isDialogVisible,
    );
  }
}

final locationProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
  return LocationNotifier(ref);
});

class LocationNotifier extends StateNotifier<LocationState>
    with WidgetsBindingObserver {
  final Ref ref;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  Timer? _pollingTimer;

  LocationNotifier(this.ref) : super(const LocationState()) {
    WidgetsBinding.instance.addObserver(this);
    _initLocationListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _serviceStatusSubscription?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When returning from quick settings shade / settings screen, check immediately
    if (state == AppLifecycleState.resumed) {
      checkLocationStatus(showDialogIfDisabled: true);
    }
  }

  void _initLocationListener() {
    // Initial check on app startup
    checkLocationStatus(showDialogIfDisabled: false);

    // Stream for GPS hardware on/off toggle in realtime (Android & iOS)
    if (!kIsWeb) {
      try {
        _serviceStatusSubscription =
            Geolocator.getServiceStatusStream().listen((status) async {
          final isEnabled = status == ServiceStatus.enabled;
          final wasEnabled = state.isServiceEnabled;

          state = state.copyWith(isServiceEnabled: isEnabled);

          if (!isEnabled) {
            // GPS TẮT -> Hiển thị popup cảnh báo Chưa bật GPS
            showLocationDisabledDialog();
          } else {
            // GPS ĐÃ ĐƯỢC BẬT LẠI:
            // 1. Tự động ẩn popup Chưa bật vị trí nếu đang hiển thị
            if (LocationPermissionDialog.currentDialogType ==
                LocationDialogType.serviceDisabled) {
              LocationPermissionDialog.dismiss();
              state = state.copyWith(isDialogVisible: false);
            }

            final permission = await Geolocator.checkPermission();
            final hasPerm = permission == LocationPermission.whileInUse ||
                permission == LocationPermission.always;

            state = state.copyWith(permission: permission);

            if (hasPerm) {
              // Đã có cả GPS và Quyền -> Thông báo toast xanh
              if (!wasEnabled) {
                showLocationRestoredToast();
              }
            } else {
              // Nếu chưa có quyền -> Chuyển sang hiện popup xin quyền
              if (permission == LocationPermission.deniedForever) {
                showPermissionDeniedForeverDialog();
              } else {
                showPermissionDeniedDialog();
              }
            }
          }
        });
      } catch (_) {}

      // Fast active polling (1s interval) to guarantee instantaneous response on all Android devices
      final bindingName = WidgetsBinding.instance.runtimeType.toString();
      if (!bindingName.contains('TestWidgetsFlutterBinding') &&
          !bindingName.contains('AutomatedTestWidgetsFlutterBinding')) {
        _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) {
            _checkLocationFast();
          }
        });
      }
    }
  }

  /// Fast background polling check
  Future<void> _checkLocationFast() async {
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      final wasEnabled = state.isServiceEnabled;

      state = state.copyWith(isServiceEnabled: isServiceEnabled);

      if (isServiceEnabled) {
        // If GPS is now turned ON and the "Chưa bật vị trí" popup is still showing -> AUTO DISMISS IT!
        if (LocationPermissionDialog.currentDialogType ==
            LocationDialogType.serviceDisabled) {
          LocationPermissionDialog.dismiss();
          state = state.copyWith(isDialogVisible: false);

          final permission = await Geolocator.checkPermission();
          final hasPerm = permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always;

          state = state.copyWith(permission: permission);

          if (hasPerm && !wasEnabled) {
            showLocationRestoredToast();
          } else if (!hasPerm) {
            if (permission == LocationPermission.deniedForever) {
              showPermissionDeniedForeverDialog();
            } else {
              showPermissionDeniedDialog();
            }
          }
        }
      }
    } catch (_) {}
  }

  /// Full check GPS & permission status
  Future<bool> checkLocationStatus({bool showDialogIfDisabled = true}) async {
    if (kIsWeb) {
      state = state.copyWith(
        isServiceEnabled: true,
        permission: LocationPermission.always,
      );
      return true;
    }

    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();
      final wasEnabled = state.isServiceEnabled;
      final hasPerm = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

      state = state.copyWith(
        isServiceEnabled: isServiceEnabled,
        permission: permission,
      );

      if (isServiceEnabled) {
        if (LocationPermissionDialog.currentDialogType ==
            LocationDialogType.serviceDisabled) {
          LocationPermissionDialog.dismiss();
          state = state.copyWith(isDialogVisible: false);
          if (!wasEnabled && hasPerm) {
            showLocationRestoredToast();
          }
        }
      }

      if (!isServiceEnabled) {
        if (showDialogIfDisabled) {
          showLocationDisabledDialog();
        }
        return false;
      }

      if (permission == LocationPermission.denied) {
        if (showDialogIfDisabled) {
          showPermissionDeniedDialog();
        }
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        if (showDialogIfDisabled) {
          showPermissionDeniedForeverDialog();
        }
        return false;
      }

      return true;
    } catch (_) {
      return true;
    }
  }

  /// Request permission or prompt dialog to open settings
  Future<bool> requestLocationAccess() async {
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        showLocationDisabledDialog();
        return false;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        state = state.copyWith(permission: permission);

        if (permission == LocationPermission.denied) {
          showPermissionDeniedDialog();
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        showPermissionDeniedForeverDialog();
        return false;
      }

      state = state.copyWith(
        isServiceEnabled: true,
        permission: permission,
      );
      return true;
    } catch (_) {
      return true;
    }
  }

  void showLocationDisabledDialog() {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    final strings = ref.read(stringsProvider);

    state = state.copyWith(isDialogVisible: true);
    LocationPermissionDialog.show(
      context,
      type: LocationDialogType.serviceDisabled,
      strings: strings,
      onPrimaryAction: () async {
        await Geolocator.openLocationSettings();
      },
      onDismiss: () {
        state = state.copyWith(isDialogVisible: false);
      },
    );
  }

  void showPermissionDeniedDialog() {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    final strings = ref.read(stringsProvider);

    state = state.copyWith(isDialogVisible: true);
    LocationPermissionDialog.show(
      context,
      type: LocationDialogType.permissionDenied,
      strings: strings,
      onPrimaryAction: () async {
        final perm = await Geolocator.requestPermission();
        final hasPerm = perm == LocationPermission.whileInUse ||
            perm == LocationPermission.always;

        state = state.copyWith(permission: perm);

        if (hasPerm) {
          LocationPermissionDialog.dismiss();
          state = state.copyWith(isDialogVisible: false);
          showLocationRestoredToast();
        } else if (perm == LocationPermission.deniedForever) {
          showPermissionDeniedForeverDialog();
        } else {
          showPermissionDeniedDialog();
        }
      },
      onDismiss: () {
        state = state.copyWith(isDialogVisible: false);
      },
    );
  }

  void showPermissionDeniedForeverDialog() {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    final strings = ref.read(stringsProvider);

    state = state.copyWith(isDialogVisible: true);
    LocationPermissionDialog.show(
      context,
      type: LocationDialogType.permissionDeniedForever,
      strings: strings,
      onPrimaryAction: () async {
        await Geolocator.openAppSettings();
      },
      onDismiss: () {
        state = state.copyWith(isDialogVisible: false);
      },
    );
  }

  void showLocationRestoredToast() {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    final strings = ref.read(stringsProvider);

    rootScaffoldMessengerKey.currentState?.removeCurrentSnackBar();
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
        content: Row(
          children: [
            const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                strings.locationEnabledToast,
                style: AppTypography.bodyMedium(color: Colors.white).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Simulate GPS turned off for 3 seconds (Testing & Demo)
  void simulateLocationOff() {
    state = state.copyWith(isServiceEnabled: false);
    showLocationDisabledDialog();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        state = state.copyWith(isServiceEnabled: true);
        LocationPermissionDialog.dismiss();
        state = state.copyWith(isDialogVisible: false);
        showLocationRestoredToast();
      }
    });
  }
}
