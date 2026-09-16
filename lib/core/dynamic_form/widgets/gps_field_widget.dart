import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/dynamic_form_field.dart';
import 'dynamic_form_field_wrapper.dart';

class DynamicGpsFieldWidget extends StatefulWidget {
  final DynamicFormField field;
  final Map<String, dynamic>? value;
  final ValueChanged<Map<String, dynamic>?> onChanged;
  final String? errorText;

  const DynamicGpsFieldWidget({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  @override
  State<DynamicGpsFieldWidget> createState() => _DynamicGpsFieldWidgetState();
}

class _DynamicGpsFieldWidgetState extends State<DynamicGpsFieldWidget> {
  bool _isLocating = false;

  Future<void> _getCurrentLocation() async {
    if (widget.field.isReadOnly) return;
    setState(() => _isLocating = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Chưa được cấp quyền truy cập vị trí GPS.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          setState(() => _isLocating = false);
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final lat = double.parse(position.latitude.toStringAsFixed(6));
      final lng = double.parse(position.longitude.toStringAsFixed(6));

      widget.onChanged({'lat': lat, 'lng': lng});
      setState(() => _isLocating = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật tọa độ GPS thành công!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLocating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi lấy GPS: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lat = widget.value?['lat'];
    final lng = widget.value?['lng'];
    final hasCoords = lat != null && lng != null;

    return DynamicFormFieldWrapper(
      field: widget.field,
      errorText: widget.errorText,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.field.isReadOnly
              ? (isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHigh)
              : (isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest),
          borderRadius: AppRadius.roundedMd,
          border: Border.all(
            color: widget.errorText != null
                ? AppColors.error
                : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.my_location_rounded,
                        size: 18,
                        color: hasCoords ? AppColors.primary : AppColors.outline,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hasCoords
                              ? '$lat, $lng'
                              : (widget.field.placeholder ?? 'Chưa có tọa độ GPS'),
                          style: AppTypography.bodySmall(
                            color: hasCoords
                                ? (isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                                : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline),
                          ).copyWith(
                            fontWeight: hasCoords ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasCoords && !widget.field.isReadOnly)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16, color: AppColors.error),
                    onPressed: () => widget.onChanged(null),
                    tooltip: 'Xóa tọa độ',
                  ),
              ],
            ),
            if (!widget.field.isReadOnly) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLocating ? null : _getCurrentLocation,
                  icon: _isLocating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.gps_fixed_rounded, size: 16),
                  label: Text(
                    _isLocating ? 'Đang lấy vị trí...' : 'LẤY TỌA ĐỘ GPS HIỆN TẠI',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
