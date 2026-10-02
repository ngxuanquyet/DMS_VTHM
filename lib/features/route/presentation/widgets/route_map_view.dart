import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/location/location_provider.dart';
import '../../../../core/rules/mobile_rules_service.dart';
import '../../../../core/map/goong_config.dart';
import '../../../../core/map/goong_map_view.dart';
import '../../../../core/map/goong_providers.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../customer/domain/entities/customer_entity.dart';
import '../../../visit/domain/entities/visit_entity.dart';
import '../../../visit/data/repositories/visit_repository_impl.dart';
import '../../domain/entities/route_entity.dart';
import '../viewmodels/route_view_model.dart';
import 'active_visit_blocking_dialog.dart';
import 'checkin_distance_warning_dialog.dart';

class RouteMapView extends ConsumerStatefulWidget {
  final List<DealerEntity> dealers;

  const RouteMapView({super.key, required this.dealers});

  @override
  ConsumerState<RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends ConsumerState<RouteMapView> {
  GoongMapStyle _currentStyle = GoongMapStyle.standard;
  int _selectedDealerIndex = 0;

  @override
  void didUpdateWidget(covariant RouteMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedDealerIndex >= widget.dealers.length) {
      _selectedDealerIndex = 0;
    }
  }

  Future<void> _openDirections(BuildContext context, DealerEntity dealer) async {
    final hasGps = dealer.lat != null && dealer.lng != null;
    final hasAddress = dealer.address.trim().isNotEmpty;

    if (!hasGps && !hasAddress) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Điểm bán chưa cập nhật toạ độ GPS hoặc địa chỉ để chỉ đường'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final destination = hasGps
        ? '${dealer.lat},${dealer.lng}'
        : Uri.encodeComponent(dealer.address.trim());

    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destination&travelmode=driving',
    );

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  String _formatDistance(double? distanceMeters) {
    if (distanceMeters == null) return '_';
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final livePoint = ref.watch(currentPointProvider).value;

    final dealersWithCoords = widget.dealers.where((d) => d.lat != null && d.lng != null).toList();

    // Map Center
    LatLng center;
    if (widget.dealers.isNotEmpty &&
        _selectedDealerIndex < widget.dealers.length &&
        widget.dealers[_selectedDealerIndex].lat != null &&
        widget.dealers[_selectedDealerIndex].lng != null) {
      final cur = widget.dealers[_selectedDealerIndex];
      center = LatLng(cur.lat!, cur.lng!);
    } else if (livePoint != null) {
      center = LatLng(livePoint.lat, livePoint.lng);
    } else if (dealersWithCoords.isNotEmpty) {
      center = LatLng(dealersWithCoords.first.lat!, dealersWithCoords.first.lng!);
    } else {
      center = const LatLng(21.3120, 105.6010);
    }

    final markers = dealersWithCoords.map((d) => LatLng(d.lat!, d.lng!)).toList();

    DealerEntity? selectedDealer;
    if (widget.dealers.isNotEmpty && _selectedDealerIndex < widget.dealers.length) {
      selectedDealer = widget.dealers[_selectedDealerIndex];
    }

    double? selectedDistance;
    if (livePoint != null && selectedDealer?.lat != null && selectedDealer?.lng != null) {
      selectedDistance = Geolocator.distanceBetween(
        livePoint.lat,
        livePoint.lng,
        selectedDealer!.lat!,
        selectedDealer.lng!,
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Map Container
          SizedBox(
            height: 380,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.md),
                topRight: Radius.circular(AppRadius.md),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GoongMapView(
                    center: center,
                    markers: markers,
                    zoom: 14.5,
                    mapStyle: _currentStyle,
                    interactive: true,
                    showZoomControls: true,
                    showMyLocation: true,
                    showMyLocationButton: true,
                  ),

                  // Layer switch buttons
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: AppRadius.roundedFull,
                        boxShadow: AppShadows.level2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _layerButton(
                            title: 'Chuẩn',
                            isSelected: _currentStyle == GoongMapStyle.standard,
                            onTap: () => setState(() => _currentStyle = GoongMapStyle.standard),
                          ),
                          _layerButton(
                            title: 'Vệ tinh',
                            isSelected: _currentStyle == GoongMapStyle.satellite,
                            onTap: () => setState(() => _currentStyle = GoongMapStyle.satellite),
                          ),
                          _layerButton(
                            title: 'Điều hướng',
                            isSelected: _currentStyle == GoongMapStyle.navigation,
                            onTap: () => setState(() => _currentStyle = GoongMapStyle.navigation),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Route Stops Pill
                  Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceContainer : Colors.white.withValues(alpha: 0.95),
                        borderRadius: AppRadius.roundedMd,
                        boxShadow: AppShadows.level2,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: AppColors.primaryContainer, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${dealersWithCoords.length}/${widget.dealers.length} điểm bán có toạ độ GPS',
                              style: AppTypography.labelSmall(
                                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Selected Dealer Card under the Map
          if (selectedDealer != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: AppRadius.roundedSm,
                              ),
                              child: Text(
                                '${selectedDealer.order} - ${selectedDealer.code ?? "KH"}',
                                style: AppTypography.labelSmall(
                                  color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                                ).copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedDealer.name,
                                style: AppTypography.titleMedium(
                                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                ).copyWith(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(
                        label: selectedDealer.statusLabel,
                        type: selectedDealer.status == DealerVisitStatus.completed
                            ? StatusBadgeType.success
                            : (selectedDealer.status == DealerVisitStatus.inProgress
                                ? StatusBadgeType.warning
                                : StatusBadgeType.neutral),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.place_outlined, size: 14, color: AppColors.outline),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          selectedDealer.address,
                          style: AppTypography.bodySmall(
                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.near_me_rounded, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Cách bạn ${_formatDistance(selectedDistance)}',
                        style: AppTypography.labelSmall(
                          color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Prev button
                      IconButton(
                        onPressed: _selectedDealerIndex > 0
                            ? () => setState(() => _selectedDealerIndex--)
                            : null,
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      Text(
                        '${_selectedDealerIndex + 1}/${widget.dealers.length}',
                        style: AppTypography.labelSmall(
                          color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      // Next button
                      IconButton(
                        onPressed: _selectedDealerIndex < widget.dealers.length - 1
                            ? () => setState(() => _selectedDealerIndex++)
                            : null,
                        icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      const Spacer(),
                      AppButton(
                        text: 'Chỉ đường',
                        height: 36,
                        icon: Icons.directions_outlined,
                        onPressed: () => _openDirections(context, selectedDealer!),
                      ),
                      const SizedBox(width: 8),
                      AppButton(
                        text: 'Check-in',
                        height: 36,
                        icon: Icons.login_rounded,
                        onPressed: () => _handleCheckin(context, selectedDealer!),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleCheckin(BuildContext context, DealerEntity dealer) async {
    // 0. Nếu điểm bán đã hoàn thành viếng thăm hôm nay (§3 Luật 2)
    if (dealer.status == DealerVisitStatus.completed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hôm nay bạn đã hoàn thành viếng thăm điểm bán này rồi.'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Nếu điểm bán đang có phiên viếng thăm mở (§3 Luật 3) -> Vào tiếp tục ngay
    if (dealer.status == DealerVisitStatus.inProgress) {
      ref.read(checkInViewModelProvider.notifier).initCheckinWithDealer(dealer);
      if (context.mounted) {
        context.push('/check-in', extra: dealer);
      }
      return;
    }

    // 0.1. Chặn mở lượt mới nếu ĐANG CÓ một lượt viếng thăm tại điểm bán khác chưa đóng (§3 Luật 3)
    // Hoạt động cả khi Online lẫn Offline
    final checkInState = ref.read(checkInViewModelProvider);
    final routeState = ref.read(routeViewModelProvider);
    VisitEntity? activeVisit = checkInState.visitId > 0 && checkInState.visitEntity?.isOpen == true
        ? checkInState.visitEntity
        : (routeState.activeVisit?.isOpen == true ? routeState.activeVisit : null);

    if (activeVisit == null) {
      try {
        final saved = await ref.read(visitRepositoryProvider).getActiveVisit();
        if (saved != null && saved.isOpen) {
          activeVisit = saved;
        }
      } catch (_) {}
    }

    final targetCustomerId = dealer.customer is CustomerEntity
        ? (dealer.customer as CustomerEntity).id
        : int.tryParse(dealer.id.replaceAll(RegExp(r'[^\d]'), ''));

    if (activeVisit != null && targetCustomerId != null && activeVisit.customerId != targetCustomerId) {
      final activeDealerName = activeVisit.customerName.isNotEmpty
          ? activeVisit.customerName
          : (checkInState.checkinData?.dealer.name ?? 'Điểm bán khác');
      if (context.mounted) {
        await showActiveVisitBlockingDialog(
          context: context,
          ref: ref,
          activeVisit: activeVisit,
          activeDealerName: activeDealerName,
          targetDealerName: dealer.name,
        );
      }
      return;
    }

    // 1. Kiểm tra nhanh quyền vị trí & trạng thái GPS từ RAM (0ms)
    final locState = ref.read(locationProvider);
    if (!locState.isReady) {
      // Chưa cấp quyền hoặc chưa bật GPS -> Mở dialog yêu cầu cấp quyền ngay
      await ref.read(locationServiceProvider).checkAndGetLocation(context);
      return;
    }

    // 2. Tính khoảng cách ngay lập tức (< 1ms) từ dữ liệu sẵn có
    // ⚠️ Theo đặc tả 01/10/2026: Điểm bán chưa có toạ độ (lat/lng = null) -> Server luôn cho qua, app cũng cho qua, đừng chặn!
    if (dealer.lat != null && dealer.lng != null) {
      double actualDistance;
      final livePoint = ref.read(currentPointProvider).value;
      if (livePoint != null) {
        actualDistance = Geolocator.distanceBetween(
          livePoint.lat,
          livePoint.lng,
          dealer.lat!,
          dealer.lng!,
        );
      } else {
        final cachedPos = LocationService.currentCachedPosition;
        if (cachedPos != null) {
          actualDistance = Geolocator.distanceBetween(
            cachedPos.latitude,
            cachedPos.longitude,
            dealer.lat!,
            dealer.lng!,
          );
        } else {
          final lastKnown = await Geolocator.getLastKnownPosition();
          if (lastKnown != null) {
            actualDistance = Geolocator.distanceBetween(
              lastKnown.latitude,
              lastKnown.longitude,
              dealer.lat!,
              dealer.lng!,
            );
          } else {
            actualDistance = 0;
          }
        }
      }

      final mobileRules = ref.read(mobileRulesProvider);
      final allowedRadius = dealer.geofenceRadiusM ??
          (dealer.customer is CustomerEntity
              ? (dealer.customer as CustomerEntity).geofenceRadiusM
              : null) ??
          mobileRules.visit.defaultRadiusM;

      // 3. Nếu yêu cầu geofence và khoảng cách > bán kính cho phép -> Hiển thị popup cảnh báo
      if (mobileRules.visit.requireGeofence && actualDistance > allowedRadius) {
        if (context.mounted) {
          showCheckinDistanceWarningDialog(
            context,
            dealerName: dealer.name,
            distanceMeters: actualDistance,
            allowedRadiusMeters: allowedRadius,
            lat: dealer.lat,
            lng: dealer.lng,
            address: dealer.address,
          );
        }
        return;
      }
    }

    // 4. Hợp lệ -> Khởi tạo sẵn dữ liệu điểm bán và vào màn check-in tức thì (<5ms, không giật lag)
    ref.read(checkInViewModelProvider.notifier).initCheckinWithDealer(dealer);
    if (context.mounted) {
      context.push('/check-in', extra: dealer);
    }
  }

  Widget _layerButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.onSurface,
          ),
        ),
      ),
    );
  }
}
