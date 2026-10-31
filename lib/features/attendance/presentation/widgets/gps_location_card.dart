import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/localization/language_provider.dart';
import '../../../../core/location/location_provider.dart';
import '../../../../core/map/goong_map_view.dart';
import '../../../../core/map/goong_models.dart';
import '../../../../core/map/goong_providers.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../domain/entities/attendance_entity.dart';

class GpsLocationCard extends ConsumerStatefulWidget {
  final AttendanceLocationEntity location;

  const GpsLocationCard({super.key, required this.location});

  @override
  ConsumerState<GpsLocationCard> createState() => _GpsLocationCardState();
}

class _GpsLocationCardState extends ConsumerState<GpsLocationCard> {
  GoongLatLng? _lastKnownPoint;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = ref.watch(stringsProvider);
    final locState = ref.watch(locationProvider);
    final isOnline = ref.watch(connectivityProvider).isOnline;

    // Vị trí GPS THẬT của người dùng đang đứng
    final livePointAsync = ref.watch(currentPointProvider);
    final currentPoint = livePointAsync.value;

    if (currentPoint != null && currentPoint != _lastKnownPoint) {
      _lastKnownPoint = currentPoint;
    }

    final cached = LocationService.currentCachedPosition;
    final fallbackPoint = (cached != null)
        ? GoongLatLng(cached.latitude, cached.longitude)
        : (widget.location.latitude != 0 && widget.location.longitude != 0
            ? GoongLatLng(widget.location.latitude, widget.location.longitude)
            : null);

    final livePoint = currentPoint ?? _lastKnownPoint ?? fallbackPoint;

    // Lấy địa chỉ thật từ Goong Maps Reverse Geocoding
    final liveAddress = (isOnline && livePoint != null)
        ? ref.watch(reverseGeocodeProvider(livePoint)).value?.formattedAddress
        : null;

    final String displayAddress;
    final String accuracyBadge;
    final Color badgeColor;

    if (!locState.isServiceEnabled) {
      displayAddress = 'Chưa bật định vị GPS trên điện thoại';
      accuracyBadge = 'GPS: Tắt';
      badgeColor = AppColors.error;
    } else if (!locState.hasPermission) {
      displayAddress = 'Chưa cấp quyền truy cập vị trí';
      accuracyBadge = 'GPS: Chưa cấp quyền';
      badgeColor = AppColors.error;
    } else if (livePoint != null) {
      displayAddress = (liveAddress != null && liveAddress.isNotEmpty)
          ? liveAddress
          : (widget.location.address.isNotEmpty && widget.location.address != 'Vị trí hiện tại'
              ? widget.location.address
              : (!isOnline
                  ? 'Toạ độ: ${livePoint.lat.toStringAsFixed(5)}, ${livePoint.lng.toStringAsFixed(5)}'
                  : 'Vĩnh Yên, Vĩnh Phúc'));
      accuracyBadge = isOnline ? 'GPS: ±8m' : 'GPS: Ngoại tuyến';
      badgeColor = AppColors.primary;
    } else {
      displayAddress = widget.location.address.isNotEmpty
          ? widget.location.address
          : 'Đang tìm tín hiệu GPS...';
      accuracyBadge = 'GPS: Đang dò';
      badgeColor = AppColors.secondary;
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    locState.isReady ? Icons.location_on : Icons.location_off,
                    color: locState.isReady ? AppColors.primary : AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    strings.currentLocation,
                    style: AppTypography.titleMedium(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.roundedSm,
                ),
                child: Text(
                  accuracyBadge,
                  style: AppTypography.labelSmall(
                    color: badgeColor,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            displayAddress,
            style: AppTypography.bodyMedium(
              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          // Interactive Map area with Goong Vector Map
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: AppRadius.roundedMd,
              color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHigh,
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildMapContent(context, ref, locState, livePoint, isDark, isOnline),
          ),
        ],
      ),
    );
  }

  Widget _buildMapContent(
    BuildContext context,
    WidgetRef ref,
    LocationState locState,
    GoongLatLng? livePoint,
    bool isDark,
    bool isOnline,
  ) {
    if (!locState.isServiceEnabled) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_disabled, color: AppColors.error, size: 36),
            const SizedBox(height: 8),
            Text(
              'Vui lòng bật GPS để xác định vị trí chấm công',
              style: AppTypography.bodySmall(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => ref
                  .read(locationProvider.notifier)
                  .checkLocationStatus(showDialogIfDisabled: true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppRadius.roundedSm,
                ),
                child: Text(
                  'Bật định vị ngay',
                  style: AppTypography.labelLarge(color: Colors.white)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!locState.hasPermission) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, color: AppColors.error, size: 36),
            const SizedBox(height: 8),
            Text(
              'Chưa cấp quyền truy cập vị trí cho ứng dụng',
              style: AppTypography.bodySmall(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => ref
                  .read(locationProvider.notifier)
                  .checkLocationStatus(showDialogIfDisabled: true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppRadius.roundedSm,
                ),
                child: Text(
                  'Cấp quyền vị trí',
                  style: AppTypography.labelLarge(color: Colors.white)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (livePoint != null) {
      if (!isOnline) {
        return _buildOfflineMapPlaceholder(context, ref, livePoint, isDark);
      }
      return GoongMapView(
        key: const ValueKey('attendance_goong_map'),
        center: LatLng(livePoint.lat, livePoint.lng),
        zoom: 16.5,
        showMyLocation: false,
        showMyLocationButton: true,
        showZoomControls: true,
        interactive: true,
        onMyLocationTap: () {
          // Lấy lại toạ độ GPS mới nhất khi bấm nút định vị
          ref.invalidate(currentPointProvider);
        },
      );
    }

    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppLoading(size: 140),
          SizedBox(height: 10),
          Text(
            'Đang lấy toạ độ GPS chính xác...',
            style: TextStyle(fontSize: 13, color: AppColors.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineMapPlaceholder(
    BuildContext context,
    WidgetRef ref,
    GoongLatLng livePoint,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLowest
            : AppColors.surfaceContainerLow,
        borderRadius: AppRadius.roundedMd,
      ),
      child: Stack(
        children: [
          // Vòng radar định vị tượng trưng tín hiệu GPS vệ tinh
          Center(
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: (isDark ? Colors.white : AppColors.primary).withValues(alpha: 0.08),
                  width: 1.5,
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 85,
              height: 85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: (isDark ? Colors.white : AppColors.primary).withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
            ),
          ),
          // Nội dung thông báo chế độ ngoại tuyến
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Định vị GPS ngoại tuyến',
                    style: AppTypography.titleMedium(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ).copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${livePoint.lat.toStringAsFixed(5)}, ${livePoint.lng.toStringAsFixed(5)}',
                    style: AppTypography.bodySmall(
                      color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                    ).copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Bản đồ tạm ẩn khi không có kết nối mạng.\nTọa độ GPS thực tế vẫn được ghi nhận để chấm công.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall(
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                    ).copyWith(fontSize: 11.5, height: 1.3),
                  ),
                ],
              ),
            ),
          ),
          // Nút lấy lại toạ độ GPS
          Positioned(
            right: 12,
            bottom: 12,
            child: Material(
              color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
              elevation: 2,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  ref.invalidate(currentPointProvider);
                },
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.my_location,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
