import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'goong_api_service.dart';
import 'goong_config.dart';
import 'goong_map_view.dart';

/// Card Bản đồ chuẩn chung dùng trên toàn bộ ứng dụng:
/// - Màn hình tạo mới / sửa khách hàng
/// - Màn hình biểu mẫu động (Dynamic Form)
/// - Màn hình chấm công / Check-in đi tuyến
class AppMapLocationCard extends StatefulWidget {
  /// Tiêu đề thẻ (mặc định: 'Vị trí điểm bán trên bản đồ')
  final String title;

  /// Vĩ độ (Lat)
  final num? lat;

  /// Kinh độ (Lng)
  final num? lng;

  /// Địa chỉ khởi tạo (nếu đã có sẵn, tránh gọi lại geocode)
  final String? initialAddress;

  /// Chiều cao khung bản đồ
  final double mapHeight;

  /// Mức phóng mặc định
  final double zoom;

  /// Cho phép chỉnh sửa / lấy vị trí
  final bool isReadOnly;

  /// Bắt buộc có tọa độ
  final bool isRequired;

  /// Thông báo lỗi xác thực
  final String? errorText;

  /// Danh sách các điểm đánh dấu phụ thêm trên bản đồ
  final List<LatLng> markers;

  /// Bán kính Geofence (nếu dùng cho chấm công / check-in)
  final double? geofenceRadiusMeters;

  /// Hiển thị bộ chuyển đổi chế độ bản đồ (Đường phố / Vệ tinh / Giao thông)
  final bool showStyleSwitcher;

  /// Text nút lấy vị trí ban đầu
  final String locateButtonText;

  /// Text nút cập nhật vị trí
  final String updateButtonText;

  /// Callback khi lấy hoặc cập nhật thành công tọa độ & địa chỉ
  final void Function(double lat, double lng, String? address)? onLocationChanged;

  /// Callback khi xóa tọa độ
  final VoidCallback? onCleared;

  const AppMapLocationCard({
    super.key,
    this.title = 'Vị trí điểm bán trên bản đồ',
    required this.lat,
    required this.lng,
    this.initialAddress,
    this.mapHeight = 220,
    this.zoom = 17.0,
    this.isReadOnly = false,
    this.isRequired = false,
    this.errorText,
    this.markers = const [],
    this.geofenceRadiusMeters,
    this.showStyleSwitcher = true,
    this.locateButtonText = 'LẤY VỊ TRÍ HIỆN TẠI',
    this.updateButtonText = 'CẬP NHẬT LẠI VỊ TRÍ HIỆN TẠI',
    this.onLocationChanged,
    this.onCleared,
  });

  @override
  State<AppMapLocationCard> createState() => _AppMapLocationCardState();
}

class _AppMapLocationCardState extends State<AppMapLocationCard> {
  bool _isLocating = false;
  String? _resolvedAddress;
  bool _isLoadingAddress = false;
  GoongMapStyle _currentMapStyle = GoongMapStyle.standard;

  @override
  void initState() {
    super.initState();
    _resolvedAddress = widget.initialAddress;
    if (widget.lat != null && widget.lng != null && (_resolvedAddress == null || _resolvedAddress!.isEmpty)) {
      _fetchAddress(widget.lat!.toDouble(), widget.lng!.toDouble());
    }
  }

  @override
  void didUpdateWidget(covariant AppMapLocationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lat != oldWidget.lat || widget.lng != oldWidget.lng) {
      if (widget.lat != null && widget.lng != null) {
        _fetchAddress(widget.lat!.toDouble(), widget.lng!.toDouble());
      } else {
        setState(() => _resolvedAddress = null);
      }
    }
  }

  Future<void> _fetchAddress(double lat, double lng) async {
    setState(() => _isLoadingAddress = true);
    try {
      final place = await GoongApiService().reverseGeocode(lat, lng);
      if (mounted) {
        setState(() {
          _resolvedAddress = place?.formattedAddress;
          _isLoadingAddress = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingAddress = false);
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    if (widget.isReadOnly) return;

    setState(() => _isLocating = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chưa được cấp quyền GPS. Vui lòng cấp quyền định vị trong Cài đặt.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quyền GPS bị từ chối vĩnh viễn. Vui lòng mở Cài đặt ứng dụng để cấp quyền.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        setState(() => _isLocating = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final lat = double.parse(position.latitude.toStringAsFixed(6));
      final lng = double.parse(position.longitude.toStringAsFixed(6));

      widget.onLocationChanged?.call(lat, lng, _resolvedAddress);
      setState(() => _isLocating = false);

      _fetchAddress(lat, lng);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Đã xác định vị trí trên bản đồ!'),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLocating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lấy vị trí GPS: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasCoords = widget.lat != null && widget.lng != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Text(
                widget.title,
                style: AppTypography.labelLarge(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              if (widget.isRequired)
                const Text(
                  ' *',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const Spacer(),
              if (hasCoords)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: AppRadius.roundedFull,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Đã ghim vị trí',
                        style: AppTypography.labelSmall(color: AppColors.primary).copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceContainer
                        : AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
                    borderRadius: AppRadius.roundedFull,
                  ),
                  child: Text(
                    'Chưa định vị',
                    style: AppTypography.labelSmall(
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
                    ).copyWith(fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Main Map Card
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceContainerLowest
                  : AppColors.surfaceContainerLowest,
              borderRadius: AppRadius.roundedLg,
              border: Border.all(
                color: widget.errorText != null
                    ? AppColors.error
                    : (hasCoords
                        ? AppColors.primary.withValues(alpha: 0.35)
                        : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant)),
                width: hasCoords ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: hasCoords
                      ? AppColors.primary.withValues(alpha: 0.06)
                      : const Color(0x06000000),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Interactive Map View
                if (hasCoords) ...[
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: widget.mapHeight,
                        width: double.infinity,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          child: GoongMapView(
                            key: ValueKey('app_map_loc_${widget.lat}_${widget.lng}_${_currentMapStyle.styleName}'),
                            center: LatLng(
                              widget.lat!.toDouble(),
                              widget.lng!.toDouble(),
                            ),
                            zoom: widget.zoom,
                            mapStyle: _currentMapStyle,
                            markers: widget.markers,
                            geofenceRadiusMeters: widget.geofenceRadiusMeters,
                            showMyLocation: true,
                            showMyLocationButton: true,
                            showZoomControls: true,
                            interactive: true,
                            onMyLocationTap: _isLocating ? null : _getCurrentLocation,
                          ),
                        ),
                      ),
                      // Map Style Switcher Chips
                      if (widget.showStyleSwitcher)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: AppRadius.roundedFull,
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x26000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildStyleOption(GoongMapStyle.standard, 'Đường phố', Icons.map_rounded),
                                const SizedBox(width: 2),
                                _buildStyleOption(GoongMapStyle.satellite, 'Vệ tinh', Icons.satellite_alt_rounded),
                                const SizedBox(width: 2),
                                _buildStyleOption(GoongMapStyle.navigation, 'Giao thông', Icons.traffic_rounded),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Address info preview below map
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.my_location_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isLoadingAddress
                                    ? 'Đang nhận diện địa chỉ vị trí...'
                                    : (_resolvedAddress ?? 'Vị trí đã được xác thực trên bản đồ'),
                                style: AppTypography.bodySmall(
                                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                ).copyWith(fontWeight: FontWeight.w600, height: 1.3),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Bạn có thể vuốt, kéo, phóng to / thu nhỏ bản đồ để kiểm tra vị trí',
                                style: AppTypography.bodySmall(
                                  color: isDark
                                      ? AppColors.darkOnSurfaceVariant
                                      : AppColors.onSurfaceVariant,
                                ).copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Empty State Preview
                  Container(
                    height: 130,
                    width: double.infinity,
                    color: isDark
                        ? AppColors.darkSurfaceContainer
                        : AppColors.surfaceContainerHigh.withValues(alpha: 0.35),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.map_rounded,
                            size: 28,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Chưa có vị trí trên bản đồ',
                          style: AppTypography.bodyMedium(
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Bấm nút bên dưới để lấy tọa độ thực tế tại điểm bán',
                          style: AppTypography.bodySmall(
                            color: isDark
                                ? AppColors.darkOnSurfaceVariant
                                : AppColors.outline,
                          ).copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],

                // Action Button
                if (!widget.isReadOnly)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton.icon(
                        onPressed: _isLocating ? null : _getCurrentLocation,
                        icon: _isLocating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                hasCoords ? Icons.refresh_rounded : Icons.my_location_rounded,
                                size: 18,
                              ),
                        label: Text(
                          _isLocating
                              ? 'Đang lấy vị trí GPS...'
                              : (hasCoords ? widget.updateButtonText : widget.locateButtonText),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasCoords
                              ? (isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHighest)
                              : AppColors.primary,
                          foregroundColor: hasCoords
                              ? (isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                              : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Error Text (if any)
          if (widget.errorText != null && widget.errorText!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 13, color: AppColors.error),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.errorText!,
                    style: AppTypography.bodySmall(color: AppColors.error).copyWith(fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStyleOption(GoongMapStyle style, String label, IconData icon) {
    final isSelected = _currentMapStyle == style;

    return InkWell(
      onTap: () {
        setState(() => _currentMapStyle = style);
      },
      borderRadius: AppRadius.roundedFull,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: AppRadius.roundedFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
