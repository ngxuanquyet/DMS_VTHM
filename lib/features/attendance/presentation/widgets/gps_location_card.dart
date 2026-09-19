import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/localization/language_provider.dart';
import '../../../../core/location/location_provider.dart';
import '../../../../core/map/goong_map_view.dart';
import '../../../../core/map/goong_models.dart';
import '../../../../core/map/goong_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
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

    // Vị trí GPS THẬT của người dùng đang đứng
    final livePointAsync = ref.watch(currentPointProvider);
    final currentPoint = livePointAsync.value;

    if (currentPoint != null && currentPoint != _lastKnownPoint) {
      _lastKnownPoint = currentPoint;
    }

    final livePoint = currentPoint ?? _lastKnownPoint;

    // Lấy địa chỉ thật từ Goong Maps Reverse Geocoding
    final liveAddress = livePoint != null
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
          : (widget.location.address.isNotEmpty
              ? widget.location.address
              : 'Vĩnh Yên, Vĩnh Phúc');
      accuracyBadge = 'GPS: ±8m';
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
            child: _buildMapContent(context, ref, locState, livePoint, isDark),
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
      return GoongMapView(
        key: const ValueKey('attendance_goong_map'),
        center: LatLng(livePoint.lat, livePoint.lng),
        zoom: 16.5,
        showMyLocation: true,
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
}
