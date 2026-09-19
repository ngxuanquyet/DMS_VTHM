import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../location/location_provider.dart';
import '../localization/language_provider.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/location_dialog.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService(ref);
});

class LocationService {
  final Ref _ref;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  static Position? _cachedPosition;

  static Position? get currentCachedPosition => _cachedPosition;

  static void updateCachedPosition(Position pos) {
    _cachedPosition = pos;
  }

  LocationService(this._ref);

  void dispose() {
    _serviceStatusSubscription?.cancel();
  }

  /// Bắt đầu lắng nghe stream trạng thái GPS của máy khi app ĐÃ CÓ QUYỀN VỊ TRÍ
  void _startListeningToServiceStatus() {
    if (kIsWeb) return;
    _serviceStatusSubscription?.cancel();

    try {
      _serviceStatusSubscription =
          Geolocator.getServiceStatusStream().listen((status) {
        final isEnabled = status == ServiceStatus.enabled;
        if (isEnabled) {
          // Khi người dùng vừa bật lại GPS -> Tự động đóng dialog nhắc bật GPS
          if (LocationPermissionDialog.isShowing &&
              LocationPermissionDialog.currentDialogType ==
                  LocationDialogType.serviceDisabled) {
            LocationPermissionDialog.dismiss();
            showLocationRestoredToast();
          }
        }
      });
    } catch (_) {}
  }

  /// Hàm kiểm tra toàn diện và lấy tọa độ người dùng:
  /// - Bước 1: Kiểm tra & Yêu cầu quyền vị trí (requestPermission / openAppSettings)
  /// - Bước 2: Kiểm tra GPS máy (isLocationServiceEnabled / openLocationSettings)
  /// - Bước 3: Lấy tọa độ thực tế Position và trả về
  Future<Position?> checkAndGetLocation(
    BuildContext context, {
    bool showDialog = true,
  }) async {
    final strings = _ref.read(stringsProvider);

    if (kIsWeb) {
      return Position(
        longitude: 105.6049,
        latitude: 21.3089,
        timestamp: DateTime.now(),
        accuracy: 10,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }

    try {
      // =======================================================================
      // BƯỚC 1: KIỂM TRA QUYỀN VỊ TRÍ (Location Permission)
      // =======================================================================
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        // Chưa có quyền -> Gọi popup xin quyền của hệ thống (requestPermission)
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          if (showDialog && context.mounted) {
            LocationPermissionDialog.show(
              context,
              type: LocationDialogType.permissionDenied,
              strings: strings,
              onPrimaryAction: () async {
                final newPerm = await Geolocator.requestPermission();
                if (newPerm == LocationPermission.deniedForever && context.mounted) {
                  LocationPermissionDialog.show(
                    context,
                    type: LocationDialogType.permissionDeniedForever,
                    strings: strings,
                    onPrimaryAction: () => Geolocator.openAppSettings(),
                  );
                }
              },
            );
          }
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Người dùng đã từ chối vĩnh viễn -> Gợi ý mở App Settings
        if (showDialog && context.mounted) {
          LocationPermissionDialog.show(
            context,
            type: LocationDialogType.permissionDeniedForever,
            strings: strings,
            onPrimaryAction: () => Geolocator.openAppSettings(),
          );
        }
        return null;
      }

      // =======================================================================
      // BƯỚC 2: KIỂM TRA TRẠNG THÁI GPS MÁY (Location Service Enabled)
      // Chỉ kiểm tra khi quyền vị trí ĐÃ ĐƯỢC CẤP
      // =======================================================================
      // Bắt đầu lắng nghe stream trạng thái GPS
      _startListeningToServiceStatus();

      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        if (showDialog && context.mounted) {
          LocationPermissionDialog.show(
            context,
            type: LocationDialogType.serviceDisabled,
            strings: strings,
            onPrimaryAction: () => Geolocator.openLocationSettings(),
          );
        }
        return null;
      }

      // =======================================================================
      // BƯỚC 3: CẢ 2 ĐIỀU KIỆN ĐỀU THỎA MÃN -> TIẾN HÀNH LẤY TỌA ĐỘ
      // =======================================================================
      // 1. Kiểm tra cache trong bộ nhớ trước (<0.1ms) để phản hồi tức thì
      if (_cachedPosition != null) {
        _ref.read(locationProvider.notifier).checkLocationStatus(showDialogIfDisabled: false);
        _refreshPositionInBackground();
        return _cachedPosition;
      }

      // 2. Thử lấy vị trí đã biết gần nhất từ hệ thống (<5ms)
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _cachedPosition = lastKnown;
        _ref.read(locationProvider.notifier).checkLocationStatus(showDialogIfDisabled: false);
        _refreshPositionInBackground();
        return lastKnown;
      }

      // 3. Fallback lấy vị trí mới với timeout nhanh 2 giây
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 2),
        ),
      );

      _cachedPosition = position;
      _ref.read(locationProvider.notifier).checkLocationStatus(showDialogIfDisabled: false);
      return position;
    } catch (_) {
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          _cachedPosition = lastKnown;
          _ref.read(locationProvider.notifier).checkLocationStatus(showDialogIfDisabled: false);
          return lastKnown;
        }
        return _cachedPosition;
      } catch (_) {
        return _cachedPosition;
      }
    }
  }

  void _refreshPositionInBackground() {
    unawaited(
      Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 3),
        ),
      ).then((freshPos) {
        _cachedPosition = freshPos;
        _ref.read(locationProvider.notifier).checkLocationStatus(showDialogIfDisabled: false);
      }).catchError((_) {}),
    );
  }

  /// Hiển thị toast thông báo màu xanh khi GPS đã được bật lại thành công
  void showLocationRestoredToast() {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    final strings = _ref.read(stringsProvider);

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

  /// Mô phỏng kiểm tra vị trí cho mục demo / testing trên màn Cá nhân
  void simulateLocationOff(BuildContext context) {
    final strings = _ref.read(stringsProvider);
    LocationPermissionDialog.show(
      context,
      type: LocationDialogType.serviceDisabled,
      strings: strings,
      onPrimaryAction: () => Geolocator.openLocationSettings(),
    );

    Future.delayed(const Duration(seconds: 3), () {
      LocationPermissionDialog.dismiss();
      showLocationRestoredToast();
    });
  }
}
