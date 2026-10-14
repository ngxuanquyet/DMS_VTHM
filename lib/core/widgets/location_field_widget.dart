import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../map/goong_config.dart';
import '../map/goong_map_view.dart';
import '../map/goong_models.dart';
import '../map/goong_providers.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/voice_input_mic_button.dart';

/// Widget nhập và hiển thị ô Địa chỉ + Tọa độ GPS (`input_type = "location"`)
/// Tích hợp đầy đủ bản đồ Goong Map tương tác, 3 chế độ xem (Đường phố / Vệ tinh / Giao thông),
/// nút phóng to thu nhỏ, vuốt xem bản đồ và tra cứu địa chỉ tự động.
/// Đặc tả kỹ thuật theo tài liệu API-O-VI-TRI-BIEU-MAU-2026-10-13.md
class LocationFieldWidget extends ConsumerStatefulWidget {
  final String label;
  final bool isRequired;
  final bool isReadOnly;
  final String? description;
  final int maxLength;
  final String? errorText;
  final Map<String, dynamic>? value;
  final ValueChanged<Map<String, dynamic>?> onChanged;

  const LocationFieldWidget({
    super.key,
    required this.label,
    this.isRequired = false,
    this.isReadOnly = false,
    this.description,
    this.maxLength = 500,
    this.errorText,
    required this.value,
    required this.onChanged,
  });

  @override
  ConsumerState<LocationFieldWidget> createState() => _LocationFieldWidgetState();
}

class _LocationFieldWidgetState extends ConsumerState<LocationFieldWidget> {
  late final TextEditingController _addressController;
  final FocusNode _addressFocusNode = FocusNode();
  bool _isLocating = false;
  String? _locationError;
  String? _resolvedAddress;
  bool _isLoadingAddress = false;
  GoongMapStyle _currentMapStyle = GoongMapStyle.standard;

  Timer? _debounceTimer;
  List<GoongPrediction> _suggestions = [];
  bool _isSearchingSuggestions = false;

  @override
  void initState() {
    super.initState();
    final initialAddress = widget.value?['address']?.toString() ?? '';
    _addressController = TextEditingController(text: initialAddress);
    _resolvedAddress = initialAddress.isNotEmpty ? initialAddress : null;

    if (_lat != null && _lng != null && (_resolvedAddress == null || _resolvedAddress!.isEmpty)) {
      _reverseGeocodeAndUpdate(_lat!, _lng!);
    }
  }

  @override
  void didUpdateWidget(covariant LocationFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newAddress = widget.value?['address']?.toString() ?? '';
    // Không ghi đè controller khi đang focus gõ phím để không làm mất dấu cách (space)
    if (!_addressFocusNode.hasFocus && !_isLocating && newAddress != _addressController.text) {
      _addressController.text = newAddress;
      if (newAddress.isNotEmpty) {
        _resolvedAddress = newAddress;
      }
    }

    final oldLat = (oldWidget.value?['lat'] as num?)?.toDouble() ??
        double.tryParse(oldWidget.value?['lat']?.toString() ?? '');
    final oldLng = (oldWidget.value?['lng'] as num?)?.toDouble() ??
        double.tryParse(oldWidget.value?['lng']?.toString() ?? '');

    if (_lat != oldLat || _lng != oldLng) {
      if (_lat != null && _lng != null) {
        _reverseGeocodeAndUpdate(_lat!, _lng!);
      } else {
        setState(() => _resolvedAddress = null);
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _addressFocusNode.dispose();
    _addressController.dispose();
    super.dispose();
  }

  double? get _lat {
    final v = widget.value?['lat'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  double? get _lng {
    final v = widget.value?['lng'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  double? get _accuracy {
    final v = widget.value?['accuracy'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  bool get _isMock => widget.value?['mock'] == true;

  bool get _hasCoords => _lat != null && _lng != null;

  GoongLatLng _getNearAnchor() {
    if (_lat != null && _lng != null) {
      return GoongLatLng(_lat!, _lng!);
    }
    final cached = LocationService.currentCachedPosition;
    if (cached != null) {
      return GoongLatLng(cached.latitude, cached.longitude);
    }
    return const GoongLatLng(GoongConfig.fallbackLat, GoongConfig.fallbackLng);
  }

  void _notifyChange({
    String? address,
    double? lat,
    double? lng,
    double? accuracy,
    bool? mock,
  }) {
    // Không dùng trim() trực tiếp ở đây để tránh xoá mất khoảng trắng vừa gõ
    final rawAddress = address ?? _addressController.text;
    final finalLat = lat ?? _lat;
    final finalLng = lng ?? _lng;
    final finalAccuracy = accuracy ?? _accuracy;
    final finalMock = mock ?? _isMock;

    if (finalLat == null && finalLng == null && rawAddress.trim().isEmpty) {
      widget.onChanged(null);
      return;
    }

    final map = <String, dynamic>{
      'address': rawAddress.isNotEmpty ? rawAddress : null,
      'lat': finalLat != null ? double.parse(finalLat.toStringAsFixed(7)) : null,
      'lng': finalLng != null ? double.parse(finalLng.toStringAsFixed(7)) : null,
      'accuracy': finalAccuracy != null ? double.parse(finalAccuracy.toStringAsFixed(1)) : null,
      'mock': finalMock,
    };

    widget.onChanged(map);
  }

  void _onAddressChanged(String text) {
    _notifyChange(address: text);

    _debounceTimer?.cancel();
    final trimmed = text.trim();
    if (trimmed.length < 2) {
      if (_suggestions.isNotEmpty || _isSearchingSuggestions) {
        setState(() {
          _suggestions = [];
          _isSearchingSuggestions = false;
        });
      }
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() {
        _isSearchingSuggestions = true;
      });

      try {
        final goong = ref.read(goongApiServiceProvider);
        final anchor = _getNearAnchor();
        final results = await goong.autocomplete(trimmed, near: anchor, limit: 6);
        if (!mounted) return;
        setState(() {
          _suggestions = results;
          _isSearchingSuggestions = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _suggestions = [];
          _isSearchingSuggestions = false;
        });
      }
    });
  }

  Future<void> _selectSuggestion(GoongPrediction prediction) async {
    _debounceTimer?.cancel();
    final chosenText = prediction.description;
    setState(() {
      _addressController.text = chosenText;
      _suggestions = [];
      _isSearchingSuggestions = false;
    });
    _notifyChange(address: chosenText);

    // Lấy toạ độ chi tiết từ Goong place detail
    try {
      final goong = ref.read(goongApiServiceProvider);
      final place = await goong.placeDetail(prediction.placeId);
      if (place != null && place.location != null && mounted) {
        final finalAddr = place.formattedAddress.isNotEmpty ? place.formattedAddress : chosenText;
        if (finalAddr != _addressController.text) {
          _addressController.text = finalAddr;
        }
        final pLat = double.parse(place.location!.lat.toStringAsFixed(7));
        final pLng = double.parse(place.location!.lng.toStringAsFixed(7));
        setState(() {
          _resolvedAddress = finalAddr;
        });
        _notifyChange(
          address: finalAddr,
          lat: pLat,
          lng: pLng,
        );
      }
    } catch (_) {}
  }

  Future<void> _reverseGeocodeAndUpdate(double lat, double lng) async {
    setState(() => _isLoadingAddress = true);
    try {
      final goongService = ref.read(goongApiServiceProvider);
      final place = await goongService.reverseGeocode(lat, lng);
      if (place != null && place.formattedAddress.isNotEmpty && mounted) {
        final addr = place.formattedAddress;
        setState(() {
          _resolvedAddress = addr;
          if (_addressController.text.trim().isEmpty) {
            _addressController.text = addr;
          }
          _isLoadingAddress = false;
        });
        _notifyChange(
          address: _addressController.text.isNotEmpty ? _addressController.text : addr,
          lat: lat,
          lng: lng,
        );
      } else {
        if (mounted) setState(() => _isLoadingAddress = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAddress = false);
    }
  }

  Future<void> _fetchFreshLocation() async {
    if (widget.isReadOnly || _isLocating) return;

    setState(() {
      _isLocating = true;
      _locationError = null;
    });

    try {
      // 1. Kiểm tra dịch vụ định vị GPS
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Dịch vụ định vị GPS đang tắt. Vui lòng bật GPS trên thiết bị.');
      }

      // 2. Kiểm tra và xin quyền truy cập vị trí
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Quyền truy cập vị trí bị từ chối.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Quyền truy cập vị trí bị từ chối vĩnh viễn. Vui lòng bật trong Cài đặt.');
      }

      // 1. Thử lấy vị trí đã biết gần nhất từ hệ thống (< 5ms) để phản hồi tức thì
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        final lat = double.parse(lastKnown.latitude.toStringAsFixed(7));
        final lng = double.parse(lastKnown.longitude.toStringAsFixed(7));
        final accuracy = double.parse(lastKnown.accuracy.toStringAsFixed(1));
        final isMock = lastKnown.isMocked;

        _notifyChange(
          lat: lat,
          lng: lng,
          accuracy: accuracy,
          mock: isMock,
        );
        _reverseGeocodeAndUpdate(lat, lng);
        LocationService.updateCachedPosition(lastKnown);
        setState(() => _isLocating = false);
      }

      // 2. Lấy vị trí mới với accuracy medium (nhanh < 1s, timeout 4s)
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );

        final lat = double.parse(position.latitude.toStringAsFixed(7));
        final lng = double.parse(position.longitude.toStringAsFixed(7));
        final accuracy = double.parse(position.accuracy.toStringAsFixed(1));
        final isMock = position.isMocked;

        _notifyChange(
          lat: lat,
          lng: lng,
          accuracy: accuracy,
          mock: isMock,
        );
        _reverseGeocodeAndUpdate(lat, lng);
        LocationService.updateCachedPosition(position);
        if (mounted) {
          setState(() => _isLocating = false);
        }
      } catch (_) {
        if (lastKnown == null) rethrow;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLocating = false;
          _locationError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _clearCoordinates() {
    _notifyChange(
      lat: null,
      lng: null,
      accuracy: null,
      mock: false,
    );
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildStyleOption(GoongMapStyle style, String label, IconData icon) {
    final isSelected = _currentMapStyle == style;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (!isSelected) {
            setState(() {
              _currentMapStyle = style;
            });
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 12,
                color: isSelected ? Colors.white : Colors.white70,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasCoords = _hasCoords;
    final lat = _lat;
    final lng = _lng;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLowest
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.errorText != null
              ? AppColors.error
              : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
          width: widget.errorText != null ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề trường + Badge Trạng thái
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    text: widget.label,
                    style: AppTypography.labelLarge(
                      color: isDark
                          ? AppColors.darkOnSurface
                          : AppColors.onSurface,
                    ).copyWith(fontWeight: FontWeight.w600),
                    children: [
                      if (widget.isRequired)
                        const TextSpan(
                          text: ' *',
                          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: AppColors.primary),
                    const SizedBox(width: 3),
                    Text(
                      'Vị trí & GPS',
                      style: AppTypography.labelSmall(
                        color: AppColors.primary,
                      ).copyWith(fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (widget.description != null && widget.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.description!,
              style: AppTypography.bodySmall(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
          ],

          const SizedBox(height: 10),

          // 1. Ô gõ địa chỉ (tuỳ chọn, ≤ 500 ký tự) (§2)
          if (!widget.isReadOnly) ...[
            TextField(
              focusNode: _addressFocusNode,
              controller: _addressController,
              maxLength: widget.maxLength,
              decoration: InputDecoration(
                hintText: 'Nhập địa chỉ (số nhà, tên đường, khu vực...)',
                hintStyle: AppTypography.bodySmall(
                  color: isDark ? AppColors.darkOutline : AppColors.outline,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                prefixIcon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VoiceInputMicButton(
                      fieldName: widget.label,
                      size: 20,
                      onTextRecognized: (text) {
                        _addressController.text = text;
                        _onAddressChanged(text);
                      },
                    ),
                    if (_addressController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _debounceTimer?.cancel();
                          _addressController.clear();
                          setState(() {
                            _suggestions = [];
                            _isSearchingSuggestions = false;
                          });
                          _notifyChange(address: '');
                        },
                      ),
                  ],
                ),
                counterText: '', // Ẩn counter để giao diện gọn gàng
                filled: true,
                fillColor: isDark ? AppColors.darkSurfaceContainer : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              onChanged: _onAddressChanged,
            ),
            if (_isSearchingSuggestions)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Đang tìm gợi ý địa điểm gần bạn (Goong Maps)...',
                      style: AppTypography.bodySmall(
                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                      ).copyWith(fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            if (_suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 6, 4),
                      child: Row(
                        children: [
                          const Icon(Icons.near_me_outlined, size: 13, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Gợi ý địa điểm gần bạn (Goong Maps v2)',
                              style: AppTypography.labelSmall(
                                color: AppColors.primary,
                              ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _suggestions = [];
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: const Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Icon(Icons.close_rounded, size: 14, color: AppColors.outline),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ..._suggestions.map((p) => InkWell(
                      onTap: () => _selectSuggestion(p),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.location_on_outlined, size: 15, color: AppColors.primary),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.mainText.isNotEmpty ? p.mainText : p.description,
                                    style: AppTypography.bodySmall(
                                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                    ).copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                  if (p.secondaryText.isNotEmpty)
                                    Text(
                                      p.secondaryText,
                                      style: AppTypography.bodySmall(
                                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                                      ).copyWith(fontSize: 11),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                  ],
                ),
              ),
            const SizedBox(height: 10),
          ] else if (_addressController.text.isNotEmpty) ...[
            // Hiển thị địa chỉ ở chế độ ReadOnly (§5)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.place_outlined, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _addressController.text,
                      style: AppTypography.bodyMedium(
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // 2. Khung Bản Đồ Tương Tác Goong Map (Đủ 3 chế độ xem, phóng to thu nhỏ, vuốt xem bản đồ)
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceContainerLowest
                  : AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasCoords
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
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
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 230,
                      width: double.infinity,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: GoongMapView(
                          key: ValueKey('loc_field_map_${lat ?? 0}_${lng ?? 0}_${_currentMapStyle.styleName}'),
                          center: hasCoords
                              ? LatLng(lat!, lng!)
                              : LatLng(
                                  _getNearAnchor().lat,
                                  _getNearAnchor().lng,
                                ),
                          zoom: hasCoords ? 16.5 : 14.5,
                          mapStyle: _currentMapStyle,
                          showMyLocation: false,
                          showMyLocationButton: !widget.isReadOnly,
                          showZoomControls: true, // Nút phóng to / thu nhỏ (+ / -)
                          interactive: true, // Cho phép vuốt, kéo, cuộn, xoay bản đồ
                          onMyLocationTap: _isLocating ? null : _fetchFreshLocation,
                          onTap: widget.isReadOnly
                              ? null
                              : (point) {
                                  final newLat = double.parse(point.latitude.toStringAsFixed(7));
                                  final newLng = double.parse(point.longitude.toStringAsFixed(7));
                                  _notifyChange(lat: newLat, lng: newLng);
                                  _reverseGeocodeAndUpdate(newLat, newLng);
                                },
                        ),
                      ),
                    ),

                    // Chip Switcher: Đủ 3 chế độ xem (Đường phố, Vệ tinh, Giao thông)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
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

                    // Nhãn chỉ dẫn khi chưa ghim vị trí
                    if (!hasCoords)
                      Positioned(
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.touch_app_rounded, size: 14, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                widget.isReadOnly
                                    ? 'Chưa có vị trí ghim trên bản đồ'
                                    : 'Chạm bản đồ hoặc bấm nút để ghim vị trí',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                // Thông tin địa chỉ giải mã bên dưới bản đồ
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isLoadingAddress
                                  ? 'Đang nhận diện địa chỉ vị trí...'
                                  : (_resolvedAddress != null &&
                                          _resolvedAddress!.isNotEmpty &&
                                          _resolvedAddress != _addressController.text
                                      ? _resolvedAddress!
                                      : (hasCoords
                                          ? 'Vị trí đã được xác thực trên bản đồ'
                                          : 'Chưa xác định toạ độ trên bản đồ')),
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
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 3. Nút Lấy vị trí + Hiển thị Tọa độ GPS đã lấy (§2)
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (!widget.isReadOnly)
                ElevatedButton.icon(
                  onPressed: _isLocating ? null : _fetchFreshLocation,
                  icon: _isLocating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          hasCoords ? Icons.refresh_rounded : Icons.my_location_rounded,
                          size: 18,
                        ),
                  label: Text(
                    _isLocating
                        ? 'Đang lấy GPS...'
                        : (hasCoords ? 'Lấy lại vị trí' : 'Lấy vị trí'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasCoords ? AppColors.secondary : AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),

              // Hiển thị tọa độ dạng pill
              if (hasCoords)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Đã định vị vị trí',
                        style: AppTypography.bodySmall(
                          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (_isMock) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA580C).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'GPS giả',
                            style: TextStyle(
                              color: Color(0xFFEA580C),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      // Nút mở Google Maps (§5)
                      InkWell(
                        onTap: () => _openGoogleMaps(lat!, lng!),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Icon(
                            Icons.map_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      if (!widget.isReadOnly) ...[
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: _clearCoordinates,
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.all(2.0),
                            child: Icon(Icons.close_rounded, size: 16, color: AppColors.outline),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),

          // Lỗi lấy GPS
          if (_locationError != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.error),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _locationError!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],

          // Lỗi validate form
          if (widget.errorText != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.errorText!,
              style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }
}
