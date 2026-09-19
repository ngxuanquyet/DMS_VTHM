import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

Future<void> showCheckinDistanceWarningDialog(
  BuildContext context, {
  required String dealerName,
  required double distanceMeters,
  double? lat,
  double? lng,
  String? address,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => CheckinDistanceWarningDialog(
      dealerName: dealerName,
      distanceMeters: distanceMeters,
      lat: lat,
      lng: lng,
      address: address,
    ),
  );
}

class CheckinDistanceWarningDialog extends StatelessWidget {
  final String dealerName;
  final double distanceMeters;
  final double? lat;
  final double? lng;
  final String? address;

  const CheckinDistanceWarningDialog({
    super.key,
    required this.dealerName,
    required this.distanceMeters,
    this.lat,
    this.lng,
    this.address,
  });

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _openDirections(BuildContext context) async {
    final hasGps = lat != null && lng != null;
    final hasAddress = address != null && address!.trim().isNotEmpty;

    if (!hasGps && !hasAddress) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Điểm bán chưa có tọa độ hoặc địa chỉ để chỉ đường'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final destination = hasGps
        ? '$lat,$lng'
        : Uri.encodeComponent(address!.trim());

    // 1. Android Google Maps navigation intent
    final androidNavUri = Uri.parse('google.navigation:q=$destination&mode=d');

    // 2. iOS Google Maps app scheme
    final iosGmapsUri = Uri.parse('comgooglemaps://?daddr=$destination&directionsmode=driving');

    // 3. Official Google Maps universal URL
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destination&travelmode=driving',
    );

    // 4. Apple Maps fallback
    final appleMapsUri = Uri.parse('maps://?daddr=$destination&dirflg=d');

    try {
      if (await canLaunchUrl(androidNavUri)) {
        await launchUrl(androidNavUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      if (await canLaunchUrl(iosGmapsUri)) {
        await launchUrl(iosGmapsUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      final launched = await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (_) {}

    try {
      if (await canLaunchUrl(appleMapsUri)) {
        await launchUrl(appleMapsUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      await launchUrl(googleMapsUrl, mode: LaunchMode.platformDefault);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể mở ứng dụng bản đồ Google Maps'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedDist = _formatDistance(distanceMeters);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceContainerLowest
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: (isDark
                    ? AppColors.darkOutlineVariant
                    : AppColors.outlineVariant)
                .withValues(alpha: 0.6),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              offset: Offset(0, 10),
              blurRadius: 25,
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.errorContainer.withValues(alpha: 0.4),
              ),
              child: const Center(
                child: Icon(
                  Icons.location_off_rounded,
                  size: 30,
                  color: AppColors.error,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              'Không thể Check-in',
              textAlign: TextAlign.center,
              style: AppTypography.headlineSmallMobile(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),

            // Description
            Text(
              'Khoảng cách hiện tại vượt quá phạm vi cho phép (tối đa 100m). Vui lòng di chuyển đến gần điểm bán để thực hiện check-in.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                height: 1.4,
                color: isDark
                    ? AppColors.darkOnSurfaceVariant
                    : AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),

            // Distance Info Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceContainerLowest
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (isDark
                          ? AppColors.darkOutlineVariant
                          : AppColors.outlineVariant)
                      .withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Khoảng cách hiện tại',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.darkOnSurfaceVariant
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.near_me_rounded,
                            size: 16,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedDist,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_rounded,
                          size: 12,
                          color: AppColors.error,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Không hợp lệ (> 100m)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Map Distance Route Illustration
            Container(
              height: 135,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (isDark
                          ? AppColors.darkOutlineVariant
                          : AppColors.outlineVariant)
                      .withValues(alpha: 0.7),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _MiniMapPainter(isDark: isDark),
                    ),
                    // Distance Tag Top-Left
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: (isDark
                                  ? AppColors.darkSurface
                                  : Colors.white)
                              .withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.outlineVariant.withValues(alpha: 0.5),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.straighten_rounded,
                              size: 12,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formattedDist,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // User Marker (Left bottom)
                    Positioned(
                      left: 18,
                      bottom: 12,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.secondary.withValues(alpha: 0.3),
                            ),
                            child: Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.secondary,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x29000000),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: (isDark
                                      ? AppColors.darkSurface
                                      : Colors.white)
                                  .withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.outlineVariant.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Text(
                              'Vị trí của bạn',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Dealer Marker (Right top)
                    Positioned(
                      right: 18,
                      top: 10,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.storefront_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            constraints: const BoxConstraints(maxWidth: 130),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: (isDark
                                      ? AppColors.darkSurface
                                      : Colors.white)
                                  .withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.outlineVariant.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              dealerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.darkOnSurface
                                    : AppColors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openDirections(context);
                },
                icon: const Icon(
                  Icons.directions_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: const Text(
                  'CHỈ ĐƯỜNG NGAY',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isDark
                        ? AppColors.darkOutlineVariant
                        : AppColors.outlineVariant,
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'ĐÓNG',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkOnSurfaceVariant
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  final bool isDark;

  _MiniMapPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF1E241D) : const Color(0xFFE9F0E5);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final roadPaint = Paint()
      ..color = isDark ? const Color(0xFF2C352B) : const Color(0xFFDEE5D8)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Road 1 (horizontal curve)
    final path1 = Path();
    path1.moveTo(-20, size.height * 0.3);
    path1.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.7,
      size.width * 0.6,
      size.height * 0.4,
    );
    path1.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.2,
      size.width + 20,
      size.height * 0.6,
    );
    canvas.drawPath(path1, roadPaint);

    // Road 2 (vertical cross)
    final path2 = Path();
    path2.moveTo(size.width * 0.25, -10);
    path2.lineTo(size.width * 0.35, size.height + 10);
    canvas.drawPath(path2, roadPaint);

    // Road 3 (vertical cross right)
    final path3 = Path();
    path3.moveTo(size.width * 0.75, -10);
    path3.lineTo(size.width * 0.65, size.height + 10);
    canvas.drawPath(path3, roadPaint);

    // Dashed Route Curve
    final dashPaint = Paint()
      ..color = AppColors.secondary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final routePath = Path();
    final start = Offset(size.width * 0.18, size.height * 0.72);
    final end = Offset(size.width * 0.82, size.height * 0.28);
    final control = Offset(size.width * 0.42, size.height * 0.25);

    routePath.moveTo(start.dx, start.dy);
    routePath.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

    // Draw dashed path
    final pathMetrics = routePath.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0.0;
      const dashWidth = 6.0;
      const dashSpace = 4.0;
      while (distance < metric.length) {
        final extractPath = metric.extractPath(
          distance,
          (distance + dashWidth).clamp(0.0, metric.length),
        );
        canvas.drawPath(extractPath, dashPaint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
