import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../customer/presentation/widgets/customer_card.dart';

Future<void> showCheckinDistanceWarningDialog(
  BuildContext context, {
  required String dealerName,
  required double distanceMeters,
  required int allowedRadiusMeters,
  double? lat,
  double? lng,
  String? address,
  bool isCheckout = false,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => CheckinDistanceWarningDialog(
      dealerName: dealerName,
      distanceMeters: distanceMeters,
      allowedRadiusMeters: allowedRadiusMeters,
      lat: lat,
      lng: lng,
      address: address,
      isCheckout: isCheckout,
    ),
  );
}

/// Hộp thoại cảnh báo khoảng cách khi Check-out (§1 & §3 SPEC-2026-10-13)
/// Hiển thị cảnh báo nếu vị trí vượt quá bán kính quy định.
/// Không chặn người dùng: người dùng có thể chọn "Ở lại / Kiểm tra lại" (trả về false)
/// hoặc "Tiếp tục Check-out" (trả về true để gửi API kèm cờ gắn vi phạm ngoài vùng).
Future<bool> showCheckoutDistanceWarningDialog(
  BuildContext context, {
  required String dealerName,
  required double distanceMeters,
  required int allowedRadiusMeters,
  double? lat,
  double? lng,
  String? address,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => CheckoutDistanceWarningDialog(
      dealerName: dealerName,
      distanceMeters: distanceMeters,
      allowedRadiusMeters: allowedRadiusMeters,
      lat: lat,
      lng: lng,
      address: address,
    ),
  );
  return result ?? false;
}

class CheckinDistanceWarningDialog extends StatelessWidget {
  final String dealerName;
  final double distanceMeters;
  final int allowedRadiusMeters;
  final double? lat;
  final double? lng;
  final String? address;
  final bool isCheckout;

  const CheckinDistanceWarningDialog({
    super.key,
    required this.dealerName,
    required this.distanceMeters,
    required this.allowedRadiusMeters,
    this.lat,
    this.lng,
    this.address,
    this.isCheckout = false,
  });

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _openDirections(BuildContext context) async {
    await CustomerCard.defaultOpenDirections(
      context,
      lat: lat,
      lng: lng,
      address: address ?? '',
    );
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
              isCheckout ? 'Không thể Check-out' : 'Không thể Check-in',
              textAlign: TextAlign.center,
              style: AppTypography.headlineSmallMobile(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),

            // Description
            Text(
              isCheckout
                  ? 'Khoảng cách hiện tại vượt quá phạm vi cho phép (tối đa ${allowedRadiusMeters}m). Vui lòng di chuyển đến gần điểm bán để thực hiện check-out.'
                  : 'Khoảng cách hiện tại vượt quá phạm vi cho phép (tối đa ${allowedRadiusMeters}m). Vui lòng di chuyển đến gần điểm bán để thực hiện check-in.',
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_rounded,
                          size: 12,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Không hợp lệ (> ${allowedRadiusMeters}m)',
                          style: const TextStyle(
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

class CheckoutDistanceWarningDialog extends StatelessWidget {
  final String dealerName;
  final double distanceMeters;
  final int allowedRadiusMeters;
  final double? lat;
  final double? lng;
  final String? address;

  const CheckoutDistanceWarningDialog({
    super.key,
    required this.dealerName,
    required this.distanceMeters,
    required this.allowedRadiusMeters,
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
    await CustomerCard.defaultOpenDirections(
      context,
      lat: lat,
      lng: lng,
      address: address ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedDist = _formatDistance(distanceMeters);
    final excessDist = distanceMeters > allowedRadiusMeters
        ? _formatDistance(distanceMeters - allowedRadiusMeters)
        : '0 m';

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
            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
            width: 1.2,
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
                color: const Color(0xFFFEF3C7).withValues(alpha: isDark ? 0.25 : 0.8),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 32,
                  color: Color(0xFFD97706),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              'Cảnh báo khoảng cách Check-out',
              textAlign: TextAlign.center,
              style: AppTypography.headlineSmallMobile(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),

            // Tag: Vượt bán kính
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7).withValues(alpha: isDark ? 0.2 : 0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFDE68A).withValues(alpha: isDark ? 0.3 : 1),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.flag_rounded,
                    size: 13,
                    color: Color(0xFFD97706),
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Có thể bị gắn cờ vi phạm (ngoài vùng)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Description
            Text(
              'Bạn đang cách điểm bán $formattedDist, vượt quá phạm vi cho phép (tối đa ${allowedRadiusMeters}m).\n\nNếu tiếp tục, lượt viếng thăm vẫn sẽ được đóng thành công, nhưng hệ thống sẽ đánh dấu ngoài vùng để quản lý đối soát.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                height: 1.45,
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
                            color: Color(0xFFD97706),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedDist,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    height: 28,
                    width: 1,
                    color: (isDark
                            ? AppColors.darkOutlineVariant
                            : AppColors.outlineVariant)
                        .withValues(alpha: 0.5),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Bán kính cho phép',
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
                          Text(
                            '${allowedRadiusMeters}m',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.darkOnSurface
                                  : AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(+$excessDist)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Map Distance Route Illustration
            Container(
              height: 120,
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
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.straighten_rounded,
                              size: 12,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formattedDist,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // User Marker (Left bottom)
                    Positioned(
                      left: 18,
                      bottom: 10,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFD97706).withValues(alpha: 0.3),
                            ),
                            child: Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFD97706),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: (isDark
                                      ? AppColors.darkSurface
                                      : Colors.white)
                                  .withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Vị trí của bạn',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Dealer Marker (Right top)
                    Positioned(
                      right: 18,
                      top: 8,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.storefront_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            constraints: const BoxConstraints(maxWidth: 120),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: (isDark
                                      ? AppColors.darkSurface
                                      : Colors.white)
                                  .withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              dealerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
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

            // Action Buttons: 2 buttons (Kiểm tra lại / Vẫn Check-out)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
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
                        'Kiểm tra lại',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkOnSurface
                              : AppColors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Vẫn Check-out',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Directions Link (optional)
            TextButton.icon(
              onPressed: () => _openDirections(context),
              icon: const Icon(
                Icons.directions_rounded,
                size: 15,
                color: AppColors.primary,
              ),
              label: const Text(
                'Chỉ đường đến điểm bán',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
