import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'goong_config.dart';

/// Bản đồ động Goong Vector Map (dựa trên MapLibre Mapbox GL v8 style).
///
/// Độ sắc nét cao, hiển thị chi tiết từng số nhà, tên đường, toà nhà.
/// Cho phép vuốt, kéo, phóng to/thu nhỏ, xoay và có nút bấm định vị vị trí hiện tại.
class GoongMapView extends StatefulWidget {
  /// Tâm bản đồ.
  final LatLng center;

  /// Các điểm đánh dấu thêm.
  final List<LatLng> markers;

  /// Bán kính Geofence (mét) quanh [center].
  final double? geofenceRadiusMeters;

  /// Mức zoom (mặc định 16.0 cho độ chi tiết mặt đường/số nhà rõ nét).
  final double zoom;

  /// Hiện chấm GPS vị trí người dùng.
  final bool showMyLocation;

  /// Hiện nút bấm bay về vị trí GPS hiện tại.
  final bool showMyLocationButton;

  /// Hiện nút bấm phóng to / thu nhỏ (+ / -).
  final bool showZoomControls;

  /// Cho phép thao tác kéo, vuốt, phóng to.
  final bool interactive;

  /// Kiểu bản đồ Goong (Đường phố, Vệ tinh, Giao thông, Ban đêm)
  final GoongMapStyle mapStyle;

  /// Callback khi bấm nút vị trí của tôi.
  final VoidCallback? onMyLocationTap;

  /// Callback khi chạm vào bản đồ.
  final void Function(LatLng point)? onTap;

  const GoongMapView({
    super.key,
    required this.center,
    this.markers = const [],
    this.geofenceRadiusMeters,
    this.zoom = GoongConfig.defaultZoom,
    this.showMyLocation = true,
    this.showMyLocationButton = true,
    this.showZoomControls = false,
    this.interactive = true,
    this.mapStyle = GoongMapStyle.standard,
    this.onMyLocationTap,
    this.onTap,
  });

  @override
  State<GoongMapView> createState() => _GoongMapViewState();
}

class _GoongMapViewState extends State<GoongMapView> {
  MapLibreMapController? _controller;
  bool _styleLoaded = false;

  @override
  void didUpdateWidget(covariant GoongMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final latDiff = (oldWidget.center.latitude - widget.center.latitude).abs();
    final lngDiff = (oldWidget.center.longitude - widget.center.longitude).abs();
    final hasMovedSignificantly = latDiff > 0.0001 || lngDiff > 0.0001;

    // Chỉ cập nhật lại vòng tròn/marker khi toạ độ thay đổi thật sự.
    // TUYỆT ĐỐI không gọi animateCamera ở đây để không làm giật/reset mức zoom người dùng đang thao tác.
    if (hasMovedSignificantly && _styleLoaded) {
      _drawOverlays();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!GoongConfig.hasMapTilesKey) {
      return _placeholder('Chưa cấu hình khoá bản đồ Goong Maptiles.');
    }

    return Stack(
      children: [
        MapLibreMap(
          key: ValueKey('maplibre_${widget.mapStyle.styleName}'),
          styleString: widget.mapStyle.url,
          initialCameraPosition: CameraPosition(
            target: widget.center,
            zoom: widget.zoom,
          ),
          onMapCreated: (controller) => _controller = controller,
          onStyleLoadedCallback: () {
            _styleLoaded = true;
            _drawOverlays();
          },
          onMapClick: widget.onTap == null
              ? null
              : (_, latLng) => widget.onTap!.call(latLng),
          gestureRecognizers: widget.interactive
              ? const <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                    EagerGestureRecognizer.new,
                  ),
                }
              : null,
          myLocationEnabled: widget.showMyLocation,
          myLocationTrackingMode: MyLocationTrackingMode.none,
          compassEnabled: widget.interactive,
          rotateGesturesEnabled: widget.interactive,
          scrollGesturesEnabled: widget.interactive,
          zoomGesturesEnabled: widget.interactive,
          tiltGesturesEnabled: false,
          dragEnabled: widget.interactive,
          trackCameraPosition: true,
          attributionButtonPosition: AttributionButtonPosition.bottomLeft,
          attributionButtonMargins: const math.Point(-1000, -1000),
          logoViewMargins: const math.Point(-1000, -1000),
        ),

        // Nút lấy GPS / Bay về vị trí hiện tại
        if (widget.showMyLocationButton)
          Positioned(
            right: 12,
            bottom: 12,
            child: Material(
              color: Colors.white,
              elevation: 3,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _handleMyLocationTap,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.my_location,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),

        // Nút phóng to / thu nhỏ (+ / -) nếu bật
        if (widget.showZoomControls)
          Positioned(
            right: 12,
            top: 12,
            child: Column(
              children: [
                _mapControlButton(
                  icon: Icons.add,
                  onTap: () => _controller?.animateCamera(CameraUpdate.zoomIn()),
                ),
                const SizedBox(height: 6),
                _mapControlButton(
                  icon: Icons.remove,
                  onTap: () => _controller?.animateCamera(CameraUpdate.zoomOut()),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _mapControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: AppRadius.roundedSm,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: AppColors.onSurface, size: 20),
        ),
      ),
    );
  }

  void _handleMyLocationTap() {
    if (widget.onMyLocationTap != null) {
      widget.onMyLocationTap!();
    }
    _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(widget.center, 16.5),
    );
  }

  Future<void> _drawOverlays() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    try {
      await controller.clearCircles();

      final radius = widget.geofenceRadiusMeters;
      if (radius != null && radius > 0) {
        await controller.addCircle(
          CircleOptions(
            geometry: widget.center,
            circleRadius: _pixelsForMeters(radius, widget.center.latitude),
            circleColor: '#2E7D32',
            circleOpacity: 0.15,
            circleStrokeWidth: 1.5,
            circleStrokeColor: '#2E7D32',
            circleStrokeOpacity: 0.7,
          ),
        );
      }

      // Marker tâm chính (Vị trí hiện tại / Điểm check-in)
      await controller.addCircle(
        CircleOptions(
          geometry: widget.center,
          circleRadius: 8,
          circleColor: '#1A73E8',
          circleOpacity: 1,
          circleStrokeWidth: 3,
          circleStrokeColor: '#FFFFFF',
        ),
      );

      for (final point in widget.markers) {
        await controller.addCircle(
          CircleOptions(
            geometry: point,
            circleRadius: 7,
            circleColor: '#D32F2F',
            circleOpacity: 1,
            circleStrokeWidth: 2.5,
            circleStrokeColor: '#FFFFFF',
          ),
        );
      }
    } catch (_) {}
  }

  double _pixelsForMeters(double meters, double latitude) {
    final metersPerPixel = 156543.03392 *
        math.cos(latitude * math.pi / 180.0) /
        math.pow(2, widget.zoom);

    return metersPerPixel <= 0 ? 0 : meters / metersPerPixel;
  }

  Widget _placeholder(String message) => Container(
        color: AppColors.surfaceContainerHigh,
        alignment: Alignment.center,
        child: Text(message),
      );
}
