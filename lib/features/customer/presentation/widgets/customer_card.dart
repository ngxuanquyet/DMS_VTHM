import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/customer_entity.dart';
import '../viewmodels/customer_view_model.dart';

class CustomerCard extends StatelessWidget {
  final CustomerWithDistance item;
  final VoidCallback? onEdit;
  final VoidCallback? onTap;

  const CustomerCard({
    super.key,
    required this.item,
    this.onEdit,
    this.onTap,
  });

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Điểm bán chưa có số điện thoại')),
      );
      return;
    }
    final uri = Uri.parse('tel:$cleanNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openMapDirections(
    BuildContext context, {
    required CustomerEntity customer,
  }) async {
    final hasGps = customer.lat != null && customer.lng != null;
    final hasAddress = customer.address.trim().isNotEmpty;

    if (!hasGps && !hasAddress) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Điểm bán chưa cập nhật tọa độ GPS hoặc địa chỉ để chỉ đường'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final destination = hasGps
        ? '${customer.lat},${customer.lng}'
        : Uri.encodeComponent(customer.address.trim());

    // Official Google Maps Directions API URL
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destination&travelmode=driving',
    );

    try {
      final launched = await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        final fallbackLaunched = await launchUrl(
          googleMapsUrl,
          mode: LaunchMode.platformDefault,
        );

        if (!fallbackLaunched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể mở ứng dụng Google Maps trên thiết bị'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi mở chỉ đường: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = item.customer;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLowest
            : AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.roundedLg,
        border: Border.all(
          color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
          width: 1,
        ),
        boxShadow: AppShadows.level1,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Left Accent Indicator Bar
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: Container(
              color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
            ),
          ),
          // Main Card Content
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Code + Type & Distance/GPS status + Directions Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: AppRadius.roundedSm,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            customer.code,
                            style: AppTypography.labelSmall(
                              color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceContainer
                                : AppColors.surfaceContainerHigh,
                            borderRadius: AppRadius.roundedSm,
                          ),
                          child: Text(
                            customer.type,
                            style: AppTypography.labelSmall(
                              color: isDark
                                  ? AppColors.darkOnSurfaceVariant
                                  : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (customer.hasCoordinates)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceContainer
                                  : AppColors.surfaceContainerHigh,
                              borderRadius: AppRadius.roundedSm,
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkOutlineVariant
                                    : AppColors.outlineVariant,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.near_me_rounded,
                                  size: 11,
                                  color: isDark
                                      ? AppColors.primaryFixedDim
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  item.formattedDistance,
                                  style: AppTypography.labelSmall(
                                    color: isDark
                                        ? AppColors.primaryFixedDim
                                        : AppColors.primary,
                                  ).copyWith(fontWeight: FontWeight.w700, fontSize: 11),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceContainer
                                  : AppColors.surfaceContainerLow,
                              borderRadius: AppRadius.roundedSm,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_off_outlined,
                                  size: 11,
                                  color: isDark
                                      ? AppColors.darkOnSurfaceVariant
                                      : AppColors.outline,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Chưa có GPS',
                                  style: AppTypography.labelSmall(
                                    color: isDark
                                        ? AppColors.darkOnSurfaceVariant
                                        : AppColors.outline,
                                  ).copyWith(fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(width: 6),
                        // Directions Button on Top-Right
                        InkWell(
                          onTap: () => _openMapDirections(
                            context,
                            customer: customer,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceContainer
                                  : const Color(0xFFEFF6E8),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkOutlineVariant
                                    : const Color(0xFFBECAB7),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.directions,
                                  size: 13,
                                  color: isDark
                                      ? AppColors.primaryFixedDim
                                      : const Color(0xFF006E15),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Chỉ đường',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.primaryFixedDim
                                        : const Color(0xFF006E15),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Customer Name
                Text(
                  customer.name,
                  style: AppTypography.titleMedium(
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700, height: 1.2),
                ),
                const SizedBox(height: 4),

                // Address
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 14,
                      color: isDark
                          ? AppColors.darkOnSurfaceVariant
                          : AppColors.outline,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        customer.address,
                        style: AppTypography.bodySmall(
                          color: isDark
                              ? AppColors.darkOnSurfaceVariant
                              : AppColors.onSurfaceVariant,
                        ).copyWith(height: 1.25),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Contact & Action Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 14,
                            color: isDark
                                ? AppColors.darkOnSurfaceVariant
                                : AppColors.outline,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              customer.contactTitle != null && customer.contactTitle!.isNotEmpty
                                  ? '${customer.contactPerson} (${customer.contactTitle})'
                                  : customer.contactPerson,
                              style: AppTypography.bodySmall(
                                color: isDark
                                    ? AppColors.darkOnSurface
                                    : AppColors.onSurface,
                              ).copyWith(fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Phone Call Button
                        if (customer.phone.isNotEmpty) ...[
                          InkWell(
                            onTap: () => _makePhoneCall(context, customer.phone),
                            borderRadius: AppRadius.roundedSm,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: AppRadius.roundedSm,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.phone_in_talk_rounded,
                                    size: 12,
                                    color: isDark
                                        ? AppColors.primaryFixedDim
                                        : AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    customer.phone,
                                    style: AppTypography.labelSmall(
                                      color: isDark
                                          ? AppColors.primaryFixedDim
                                          : AppColors.primary,
                                    ).copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        // Edit Customer Button on Bottom-Right
                        if (onEdit != null)
                          InkWell(
                            onTap: onEdit,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkSurfaceContainer
                                    : const Color(0xFFEFF6E8),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.darkOutlineVariant
                                      : const Color(0xFFBECAB7),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_note_rounded,
                                    size: 15,
                                    color: isDark
                                        ? AppColors.primaryFixedDim
                                        : const Color(0xFF006E15),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Sửa',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.primaryFixedDim
                                          : const Color(0xFF006E15),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
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
}
