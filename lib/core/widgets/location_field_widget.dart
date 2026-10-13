import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../map/goong_config.dart';
import '../map/goong_models.dart';
import '../map/goong_providers.dart';
import '../services/location_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Widget nhập và hiển thị ô Địa chỉ + Tọa độ GPS (`input_type = "location"`)
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

  Timer? _debounceTimer;
  List<GoongPrediction> _suggestions = [];
  bool _isSearchingSuggestions = false;

  @override
  void initState() {
    super.initState();
    final initialAddress = widget.value?['address']?.toString() ?? '';
    _addressController = TextEditingController(text: initialAddress);
  }

  @override
  void didUpdateWidget(covariant LocationFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newAddress = widget.value?['address']?.toString() ?? '';
    // Không ghi đè controller khi đang focus gõ phím để không làm mất dấu cách (space)
    if (!_addressFocusNode.hasFocus && !_isLocating && newAddress != _addressController.text) {
      _addressController.text = newAddress;
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
        _notifyChange(
          address: finalAddr,
          lat: place.location!.lat,
          lng: place.location!.lng,
        );
      }
    } catch (_) {}
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

      // 3. Lấy vị trí độ chính xác cao, MỚI (không dùng cache cũ) (§2)
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final lat = double.parse(position.latitude.toStringAsFixed(7));
      final lng = double.parse(position.longitude.toStringAsFixed(7));
      final accuracy = double.parse(position.accuracy.toStringAsFixed(1));
      final isMock = position.isMocked;

      // 4. Tự động gợi ý địa chỉ qua reverse-geocoding nếu ô địa chỉ đang trống (§2)
      String currentAddr = _addressController.text.trim();
      if (currentAddr.isEmpty) {
        try {
          final goongService = ref.read(goongApiServiceProvider);
          final place = await goongService.reverseGeocode(lat, lng);
          if (place != null && place.formattedAddress.isNotEmpty) {
            currentAddr = place.formattedAddress;
            _addressController.text = currentAddr;
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }

      _notifyChange(
        address: currentAddr,
        lat: lat,
        lng: lng,
        accuracy: accuracy,
        mock: isMock,
      );
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasCoords = _hasCoords;
    final lat = _lat;
    final lng = _lng;
    final accuracy = _accuracy;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLowest
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
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
          // Tiêu đề trường + Badge
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                suffixIcon: _addressController.text.isNotEmpty
                    ? IconButton(
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
                      )
                    : null,
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

          // 2. Nút Lấy vị trí + Hiển thị Tọa độ GPS đã lấy (§2)
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
                        '${lat!.toStringAsFixed(6)}, ${lng!.toStringAsFixed(6)}',
                        style: AppTypography.bodySmall(
                          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (accuracy != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(±${accuracy.toStringAsFixed(1)} m)',
                          style: AppTypography.bodySmall(
                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                          ).copyWith(fontSize: 11),
                        ),
                      ],
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
                        onTap: () => _openGoogleMaps(lat, lng),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
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
