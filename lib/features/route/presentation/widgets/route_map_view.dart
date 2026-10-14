import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/location/location_provider.dart';
import '../../../../core/map/goong_config.dart';
import '../../../../core/map/goong_models.dart';
import '../../../../core/map/goong_providers.dart';
import '../../../../core/rules/mobile_rules_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../customer/domain/entities/customer_entity.dart';
import '../../../visit/data/repositories/visit_repository_impl.dart';
import '../../../visit/domain/entities/visit_entity.dart';
import '../../domain/entities/route_entity.dart';
import '../viewmodels/route_view_model.dart';
import 'active_visit_blocking_dialog.dart';
import 'checkin_distance_warning_dialog.dart';

/// Chế độ xem bản đồ tuyến bán hàng Goong Maps v2.
///
/// Hiển thị toàn bộ điểm bán theo ghim màu trạng thái:
/// - Chưa ghé: Vàng cam (#F59E0B)
/// - Đang ghé: Xanh dương (#0284C7)
/// - Đã xong: Xanh lá cây (#10B981)
///
/// Vị trí nhân viên hiển thị dạng chấm phát sóng (pulsing radar beacon).
/// Chạm ghim để xem tóm tắt thông tin điểm bán & mở ứng dụng chỉ đường.
/// Tự động gọi Goong Trip v2 API (/v2/trip) để vẽ lộ trình vòng lặp tối ưu tránh quay đầu xe.
class RouteMapView extends ConsumerStatefulWidget {
  final List<DealerEntity> dealers;
  final ValueChanged<DealerEntity?>? onSelectedDealerChanged;

  const RouteMapView({
    super.key,
    required this.dealers,
    this.onSelectedDealerChanged,
  });

  @override
  ConsumerState<RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends ConsumerState<RouteMapView> {
  MapLibreMapController? _controller;
  GoongMapStyle _currentStyle = GoongMapStyle.standard;
  bool _styleLoaded = false;
  bool _isLoadingTrip = false;

  DealerEntity? _selectedDealer;
  GoongTrip? _currentTrip;
  List<LatLng> _tripPoints = [];
  List<DealerEntity> _orderedDealers = [];

  List<DealerEntity> get _dealersWithCoords =>
      widget.dealers.where((d) => d.lat != null && d.lng != null).toList();

  List<DealerEntity> get _displayDealers =>
      _orderedDealers.isNotEmpty ? _orderedDealers : _dealersWithCoords;

  @override
  void initState() {
    super.initState();
    if (_dealersWithCoords.isNotEmpty) {
      _selectedDealer = _dealersWithCoords.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onSelectedDealerChanged?.call(_selectedDealer);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller?.onCircleTapped.remove(_handleCircleTapped);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RouteMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedDealer != null &&
        !widget.dealers.any((d) => d.id == _selectedDealer!.id)) {
      _selectedDealer = _displayDealers.isNotEmpty ? _displayDealers.first : null;
      widget.onSelectedDealerChanged?.call(_selectedDealer);
    }

    final oldCoordsCount = oldWidget.dealers.where((d) => d.lat != null && d.lng != null).length;
    final newCoordsCount = _dealersWithCoords.length;
    if (oldCoordsCount != newCoordsCount && _styleLoaded) {
      _drawOverlays();
      _fetchAndDrawTrip();
    }
  }

  Future<void> _fetchAndDrawTrip() async {
    final dealersWithCoords = _dealersWithCoords;
    if (dealersWithCoords.isEmpty) return;

    final goongApi = ref.read(goongApiServiceProvider);
    final livePoint = ref.read(currentPointProvider).value;

    final origin = livePoint != null
        ? GoongLatLng(livePoint.lat, livePoint.lng)
        : GoongLatLng(dealersWithCoords.first.lat!, dealersWithCoords.first.lng!);

    final waypoints = dealersWithCoords
        .map((d) => GoongLatLng(d.lat!, d.lng!))
        .toList();

    setState(() => _isLoadingTrip = true);
    try {
      final trip = await goongApi.getTripRoute(
        origin: origin,
        waypoints: waypoints,
        vehicle: 'bike',
        roundtrip: true,
      );

      if (!mounted) return;
      if (trip != null) {
        _currentTrip = trip;
        if (trip.polyline.isNotEmpty) {
          _tripPoints = _decodePolyline(trip.polyline);
          await _drawTripPolyline();
        }
        if (trip.waypointOrder.isNotEmpty) {
          _orderedDealers = _buildSortedDealers(dealersWithCoords, trip.waypointOrder);
          if (_selectedDealer != null) {
            final found = _orderedDealers.where((d) => d.id == _selectedDealer!.id).firstOrNull;
            if (found != null) {
              _selectedDealer = found;
            }
          }
          await _drawOverlays();
        }
      }
    } catch (_) {
      // Bỏ qua lỗi mạng, bản đồ vẫn vẽ ghim bình thường
    } finally {
      if (mounted) {
        setState(() => _isLoadingTrip = false);
      }
    }
  }

  List<DealerEntity> _buildSortedDealers(List<DealerEntity> original, List<int> order) {
    if (order.isEmpty || original.isEmpty) return original;

    final hasOriginShift = order.contains(original.length) ||
        (order.length == original.length + 1 && order.first == 0);

    final List<DealerEntity> sorted = [];
    final used = <int>{};

    for (final rawIdx in order) {
      final idx = hasOriginShift ? rawIdx - 1 : rawIdx;
      if (idx >= 0 && idx < original.length && !used.contains(idx)) {
        sorted.add(original[idx]);
        used.add(idx);
      }
    }

    for (int i = 0; i < original.length; i++) {
      if (!used.contains(i)) {
        sorted.add(original[i]);
      }
    }

    return sorted;
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    final int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        if (index >= len) break;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        if (index >= len) break;
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  Future<void> _drawTripPolyline() async {
    final controller = _controller;
    if (controller == null || _tripPoints.isEmpty) return;

    try {
      await controller.clearLines();
      await controller.addLine(
        LineOptions(
          geometry: _tripPoints,
          lineColor: '#0284C7',
          lineWidth: 4.5,
          lineOpacity: 0.85,
          lineJoin: 'round',
        ),
      );
    } catch (_) {}
  }

  Future<void> _drawOverlays() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      await controller.clearCircles();

      // 1. Chấm phát sóng vị trí nhân viên (Broadcasting Beacon)
      final livePoint = ref.read(currentPointProvider).value;
      if (livePoint != null) {
        final empLatLng = LatLng(livePoint.lat, livePoint.lng);

        // Vòng sóng radar mở rộng ngoài cùng
        await controller.addCircle(
          CircleOptions(
            geometry: empLatLng,
            circleRadius: 26,
            circleColor: '#0284C7',
            circleOpacity: 0.16,
            circleStrokeWidth: 1.5,
            circleStrokeColor: '#0284C7',
            circleStrokeOpacity: 0.45,
          ),
        );

        // Vòng sóng giữa
        await controller.addCircle(
          CircleOptions(
            geometry: empLatLng,
            circleRadius: 15,
            circleColor: '#0284C7',
            circleOpacity: 0.30,
            circleStrokeWidth: 1.0,
            circleStrokeColor: '#FFFFFF',
            circleStrokeOpacity: 0.7,
          ),
        );

        // Chấm beacon chính
        await controller.addCircle(
          CircleOptions(
            geometry: empLatLng,
            circleRadius: 8.5,
            circleColor: '#0284C7',
            circleOpacity: 1.0,
            circleStrokeWidth: 2.5,
            circleStrokeColor: '#FFFFFF',
          ),
        );

        // Điểm sáng trắng trung tâm
        await controller.addCircle(
          CircleOptions(
            geometry: empLatLng,
            circleRadius: 3.5,
            circleColor: '#FFFFFF',
            circleOpacity: 1.0,
          ),
        );
      }

      // 2. Toàn bộ điểm bán theo màu sắc trạng thái
      for (final dealer in _displayDealers) {
        final dealerLatLng = LatLng(dealer.lat!, dealer.lng!);
        final isSelected = _selectedDealer?.id == dealer.id;
        final circleData = <String, dynamic>{'dealerId': dealer.id};

        final String pinColorHex;
        switch (dealer.status) {
          case DealerVisitStatus.completed:
            pinColorHex = '#10B981'; // Đã xong (Xanh lá)
            break;
          case DealerVisitStatus.inProgress:
            pinColorHex = '#0284C7'; // Đang ghé (Xanh dương)
            break;
          case DealerVisitStatus.pending:
            pinColorHex = '#F59E0B'; // Chưa ghé (Cam hổ phách)
            break;
        }

        // Vòng highlight nếu đang chọn
        if (isSelected) {
          await controller.addCircle(
            CircleOptions(
              geometry: dealerLatLng,
              circleRadius: 17,
              circleColor: pinColorHex,
              circleOpacity: 0.32,
              circleStrokeWidth: 2.0,
              circleStrokeColor: pinColorHex,
              circleStrokeOpacity: 0.9,
            ),
            circleData,
          );
        }

        // Ghim điểm bán
        await controller.addCircle(
          CircleOptions(
            geometry: dealerLatLng,
            circleRadius: isSelected ? 11 : 9,
            circleColor: pinColorHex,
            circleOpacity: 1.0,
            circleStrokeWidth: 2.2,
            circleStrokeColor: '#FFFFFF',
            circleStrokeOpacity: 1.0,
          ),
          circleData,
        );

        // Tâm ghim
        await controller.addCircle(
          CircleOptions(
            geometry: dealerLatLng,
            circleRadius: isSelected ? 4.5 : 3.5,
            circleColor: '#FFFFFF',
            circleOpacity: 1.0,
          ),
          circleData,
        );
      }
    } catch (_) {}
  }

  void _selectDealer(DealerEntity dealer) {
    setState(() => _selectedDealer = dealer);
    widget.onSelectedDealerChanged?.call(dealer);
    _drawOverlays();
    _controller?.animateCamera(
      CameraUpdate.newLatLng(LatLng(dealer.lat!, dealer.lng!)),
    );
  }

  void _handleCircleTapped(Circle circle) {
    final dealerId = circle.data?['dealerId'] as String?;
    if (dealerId != null) {
      final found = _displayDealers.where((d) => d.id == dealerId).firstOrNull;
      if (found != null) {
        _selectDealer(found);
        return;
      }
    }
    final geom = circle.options.geometry;
    if (geom != null) {
      _handleMapClick(geom);
    }
  }

  void _handleMapClick(LatLng tappedPoint) {
    DealerEntity? closest;
    double minDistance = 500; // ngưỡng chạm trong bán kính 500 mét

    for (final dealer in _displayDealers) {
      final dist = Geolocator.distanceBetween(
        tappedPoint.latitude,
        tappedPoint.longitude,
        dealer.lat!,
        dealer.lng!,
      );
      if (dist < minDistance) {
        minDistance = dist;
        closest = dealer;
      }
    }

    if (closest != null) {
      _selectDealer(closest);
    }
  }

  void _fitAllStops() {
    final controller = _controller;
    if (controller == null) return;

    final points = <LatLng>[];
    final livePoint = ref.read(currentPointProvider).value;
    if (livePoint != null) {
      points.add(LatLng(livePoint.lat, livePoint.lng));
    }
    for (final d in _dealersWithCoords) {
      points.add(LatLng(d.lat!, d.lng!));
    }

    if (points.isEmpty) return;
    if (points.length == 1) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15.5));
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        left: 40,
        top: 60,
        right: 40,
        bottom: 220,
      ),
    );
  }

  void _flyToMyLocation() {
    final livePoint = ref.read(currentPointProvider).value;
    if (livePoint != null) {
      _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(livePoint.lat, livePoint.lng),
          16.0,
        ),
      );
    } else {
      ref.read(locationServiceProvider).checkAndGetLocation(context);
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

    final dealersWithCoords = _dealersWithCoords;

    // Tính tâm bản đồ
    LatLng center;
    if (_selectedDealer?.lat != null && _selectedDealer?.lng != null) {
      center = LatLng(_selectedDealer!.lat!, _selectedDealer!.lng!);
    } else if (livePoint != null) {
      center = LatLng(livePoint.lat, livePoint.lng);
    } else if (dealersWithCoords.isNotEmpty) {
      center = LatLng(dealersWithCoords.first.lat!, dealersWithCoords.first.lng!);
    } else {
      center = const LatLng(21.028511, 105.804817);
    }

    // Khoảng cách tới điểm bán đang chọn
    double? selectedDistance;
    if (livePoint != null && _selectedDealer?.lat != null && _selectedDealer?.lng != null) {
      selectedDistance = Geolocator.distanceBetween(
        livePoint.lat,
        livePoint.lng,
        _selectedDealer!.lat!,
        _selectedDealer!.lng!,
      );
    }

    final pendingCount = widget.dealers.where((d) => d.status == DealerVisitStatus.pending).length;
    final inProgressCount = widget.dealers.where((d) => d.status == DealerVisitStatus.inProgress).length;
    final completedCount = widget.dealers.where((d) => d.status == DealerVisitStatus.completed).length;

    return Stack(
      children: [
        // 1. Bản đồ Goong Vector MapLibre
        MapLibreMap(
          key: ValueKey('maplibre_route_${_currentStyle.styleName}'),
          styleString: _currentStyle.url,
          initialCameraPosition: CameraPosition(
            target: center,
            zoom: 14.5,
          ),
          onMapCreated: (controller) {
            _controller?.onCircleTapped.remove(_handleCircleTapped);
            _controller = controller;
            controller.onCircleTapped.add(_handleCircleTapped);
          },
          onStyleLoadedCallback: () {
            _styleLoaded = true;
            _drawOverlays();
            _fetchAndDrawTrip();
          },
          onMapClick: (_, latLng) => _handleMapClick(latLng),
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(
              EagerGestureRecognizer.new,
            ),
          },
          myLocationEnabled: false,
          trackCameraPosition: true,
          compassEnabled: true,
          rotateGesturesEnabled: true,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          attributionButtonMargins: const math.Point(-1000, -1000),
          logoViewMargins: const math.Point(-1000, -1000),
        ),

        // 2. Thanh điều khiển lớp bản đồ & thông tin lộ trình ở trên cùng
        Positioned(
          top: 10,
          left: 12,
          right: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Nút chuyển lớp bản đồ (Chuẩn / Vệ tinh / Giao thông)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurface.withValues(alpha: 0.95)
                          : Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppShadows.level2,
                      border: Border.all(
                        color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                      ),
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
                          title: 'Giao thông',
                          isSelected: _currentStyle == GoongMapStyle.navigation,
                          onTap: () => setState(() => _currentStyle = GoongMapStyle.navigation),
                        ),
                      ],
                    ),
                  ),

                  // Nút tiện ích: Xem toàn cảnh & Bay về vị trí GPS
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _actionCircleButton(
                        icon: Icons.fullscreen_rounded,
                        tooltip: 'Toàn cảnh lộ trình',
                        onTap: _fitAllStops,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _actionCircleButton(
                        icon: Icons.my_location_rounded,
                        tooltip: 'Vị trí của tôi',
                        onTap: _flyToMyLocation,
                        isDark: isDark,
                        iconColor: const Color(0xFF0284C7),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Chip hiển thị Lộ trình tối ưu Goong Trip v2
              if (_currentTrip != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface.withValues(alpha: 0.92)
                        : Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppShadows.level2,
                    border: Border.all(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.alt_route_rounded, size: 15, color: Color(0xFF0284C7)),
                      const SizedBox(width: 6),
                      Text(
                        _orderedDealers.isNotEmpty
                            ? 'Lộ trình tối ưu Goong: ${(_currentTrip!.distanceMeters / 1000).toStringAsFixed(1)} km • ${(_currentTrip!.durationSeconds / 60).round()}p (Đã xếp theo đường ngắn nhất)'
                            : 'Lộ trình tối ưu Goong: ${(_currentTrip!.distanceMeters / 1000).toStringAsFixed(1)} km • ${(_currentTrip!.durationSeconds / 60).round()}p',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: _fetchAndDrawTrip,
                        child: _isLoadingTrip
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF0284C7)),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 6),

              // Chip chú thích màu sắc ghim (Status Legend)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface.withValues(alpha: 0.90)
                      : Colors.white.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppShadows.level1,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _legendItem(color: const Color(0xFFF59E0B), label: 'Chưa ghé ($pendingCount)'),
                    const SizedBox(width: 8),
                    _legendItem(color: const Color(0xFF0284C7), label: 'Đang ghé ($inProgressCount)'),
                    const SizedBox(width: 8),
                    _legendItem(color: const Color(0xFF10B981), label: 'Đã xong ($completedCount)'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 3. Card tóm tắt điểm bán được chọn ở dưới cùng
        if (_selectedDealer != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _buildDealerSummaryCard(
              context,
              _selectedDealer!,
              selectedDistance,
              _displayDealers,
              isDark,
            ),
          )
        else
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppShadows.level2,
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chạm vào một ghim để xem tóm tắt điểm bán & mở chỉ đường',
                      style: AppTypography.bodySmall(
                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDealerSummaryCard(
    BuildContext context,
    DealerEntity dealer,
    double? selectedDistance,
    List<DealerEntity> dealersWithCoords,
    bool isDark,
  ) {
    final currentIndex = dealersWithCoords.indexWhere((d) => d.id == dealer.id);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Số thứ tự + Mã KH + Trạng thái + Nút đóng
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#${currentIndex >= 0 ? (currentIndex + 1).toString().padLeft(2, '0') : dealer.order} • ${dealer.code ?? "KH"}',
                      style: AppTypography.labelSmall(
                        color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(
                    label: dealer.statusLabel,
                    type: dealer.status == DealerVisitStatus.completed
                        ? StatusBadgeType.success
                        : (dealer.status == DealerVisitStatus.inProgress
                            ? StatusBadgeType.warning
                            : StatusBadgeType.neutral),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  setState(() => _selectedDealer = null);
                  widget.onSelectedDealerChanged?.call(null);
                  _drawOverlays();
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Tên điểm bán
          Text(
            dealer.name,
            style: AppTypography.titleMedium(
              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
            ).copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),

          // Địa chỉ
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place_outlined, size: 14, color: AppColors.outline),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  dealer.address,
                  style: AppTypography.bodySmall(
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Khoảng cách từ vị trí nhân viên
          Row(
            children: [
              const Icon(Icons.near_me_rounded, size: 13, color: Color(0xFF0284C7)),
              const SizedBox(width: 4),
              Text(
                'Cách bạn ${_formatDistance(selectedDistance)}',
                style: AppTypography.labelSmall(
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              if (dealer.phone != null && dealer.phone!.isNotEmpty) ...[
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => launchUrl(Uri.parse('tel:${dealer.phone}')),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_rounded, size: 12, color: AppColors.primary),
                      const SizedBox(width: 3),
                      Text(
                        dealer.phone!,
                        style: AppTypography.labelSmall(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // Action buttons: Điều hướng vòng lặp (Next/Prev) + Chỉ đường + Check-in
          Row(
            children: [
              // Nút lùi điểm bán
              IconButton(
                onPressed: currentIndex > 0
                    ? () => _selectDealer(dealersWithCoords[currentIndex - 1])
                    : null,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 15),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              Text(
                '${currentIndex >= 0 ? currentIndex + 1 : 1}/${dealersWithCoords.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                ),
              ),
              // Nút tiến điểm bán
              IconButton(
                onPressed: currentIndex >= 0 && currentIndex < dealersWithCoords.length - 1
                    ? () => _selectDealer(dealersWithCoords[currentIndex + 1])
                    : null,
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 15),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),

              const Spacer(),

              // Nút Mở Chỉ đường
              OutlinedButton.icon(
                onPressed: () => _openDirections(context, dealer),
                icon: const Icon(Icons.directions_rounded, size: 16),
                label: const Text('Chỉ đường'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0284C7),
                  side: const BorderSide(color: Color(0xFF0284C7)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              const SizedBox(width: 8),

              // Nút Vào viếng thăm / Check-in
              ElevatedButton.icon(
                onPressed: () => _handleCheckin(context, dealer),
                icon: const Icon(Icons.login_rounded, size: 16),
                label: Text(dealer.status == DealerVisitStatus.inProgress ? 'Tiếp tục' : 'Check-in'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleCheckin(BuildContext context, DealerEntity dealer) async {
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

    final checkInState = ref.read(checkInViewModelProvider);
    final routeState = ref.read(routeViewModelProvider);
    VisitEntity? activeVisit = checkInState.visitId != 0 && checkInState.visitEntity?.isOpen == true
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

    if (activeVisit != null && targetCustomerId != null && activeVisit.customerId == targetCustomerId) {
      final dealerWithVisit = dealer.visit != null
          ? dealer
          : dealer.copyWith(visit: activeVisit, status: DealerVisitStatus.inProgress);
      ref.read(checkInViewModelProvider.notifier).initCheckinWithDealer(dealerWithVisit);
      if (context.mounted) {
        await context.push('/check-in', extra: dealerWithVisit);
        if (context.mounted) {
          ref.read(routeViewModelProvider.notifier).loadRouteDetail();
        }
      }
      return;
    }

    if (dealer.status == DealerVisitStatus.inProgress) {
      final dealerWithVisit = dealer.visit != null
          ? dealer
          : (activeVisit != null ? dealer.copyWith(visit: activeVisit) : dealer);
      ref.read(checkInViewModelProvider.notifier).initCheckinWithDealer(dealerWithVisit);
      if (context.mounted) {
        await context.push('/check-in', extra: dealerWithVisit);
        if (context.mounted) {
          ref.read(routeViewModelProvider.notifier).loadRouteDetail();
        }
      }
      return;
    }

    if (activeVisit != null && targetCustomerId != null && activeVisit.customerId != targetCustomerId) {
      final activeDealerName = activeVisit.customerName.isNotEmpty
          ? activeVisit.customerName
          : (checkInState.checkinData?.dealer.name ?? 'Điểm bán khác');
      if (context.mounted) {
        final chosenDealer = await showActiveVisitBlockingDialog(
          context: context,
          ref: ref,
          activeVisit: activeVisit,
          activeDealerName: activeDealerName,
          targetDealerName: dealer.name,
        );
        if (chosenDealer != null && context.mounted) {
          ref.read(checkInViewModelProvider.notifier).initCheckinWithDealer(chosenDealer);
          await context.push('/check-in', extra: chosenDealer);
          if (context.mounted) {
            ref.read(routeViewModelProvider.notifier).loadRouteDetail();
          }
        }
      }
      return;
    }

    final locState = ref.read(locationProvider);
    if (!locState.isReady) {
      if (!context.mounted) return;
      await ref.read(locationServiceProvider).checkAndGetLocation(context);
      return;
    }

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
          actualDistance = lastKnown != null
              ? Geolocator.distanceBetween(
                  lastKnown.latitude,
                  lastKnown.longitude,
                  dealer.lat!,
                  dealer.lng!,
                )
              : 0;
        }
      }

      final mobileRules = ref.read(mobileRulesProvider);
      final allowedRadius = dealer.geofenceRadiusM ??
          (dealer.customer is CustomerEntity
              ? (dealer.customer as CustomerEntity).geofenceRadiusM
              : null) ??
          mobileRules.visit.defaultRadiusM;

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

    ref.read(checkInViewModelProvider.notifier).initCheckinWithDealer(dealer);
    if (context.mounted) {
      await context.push('/check-in', extra: dealer);
      if (context.mounted) {
        ref.read(routeViewModelProvider.notifier).loadRouteDetail();
      }
    }
  }

  Widget _layerButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
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

  Widget _actionCircleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isDark,
    Color? iconColor,
  }) {
    return Material(
      color: isDark ? AppColors.darkSurface.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      elevation: 2,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 20,
              color: iconColor ?? (isDark ? AppColors.darkOnSurface : AppColors.onSurface),
            ),
          ),
        ),
      ),
    );
  }

  Widget _legendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
