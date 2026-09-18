import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/map/goong_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../customer/domain/entities/customer_entity.dart';
import '../../../customer/presentation/widgets/edit_customer_dialog.dart';
import '../../domain/entities/route_entity.dart';

class RouteDealerTimeline extends ConsumerWidget {
  final List<DealerEntity> dealers;

  const RouteDealerTimeline({super.key, required this.dealers});

  Future<void> _makePhoneCall(BuildContext context, String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Điểm bán chưa có số điện thoại')),
      );
      return;
    }
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
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
    if (distanceMeters == null) return '';
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final livePoint = ref.watch(currentPointProvider).value;

    if (dealers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_search_outlined,
                size: 48,
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
              ),
              const SizedBox(height: 12),
              Text(
                'Không có điểm bán nào trên tuyến này',
                style: AppTypography.titleMedium(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: dealers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final dealer = dealers[index];

        double? distance;
        if (livePoint != null && dealer.lat != null && dealer.lng != null) {
          distance = Geolocator.distanceBetween(
            livePoint.lat,
            livePoint.lng,
            dealer.lat!,
            dealer.lng!,
          );
        }

        return _buildDealerCard(context, dealer, distance, isDark);
      },
    );
  }

  Widget _buildDealerCard(
    BuildContext context,
    DealerEntity dealer,
    double? distance,
    bool isDark,
  ) {
    final isCompleted = dealer.status == DealerVisitStatus.completed;
    final isInProgress = dealer.status == DealerVisitStatus.inProgress;
    final codeText = dealer.code?.isNotEmpty == true ? dealer.code! : 'KH${dealer.order}';
    final distanceText = _formatDistance(distance);
    final isValidDistance = distance != null && distance <= 200;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isInProgress
              ? const Color(0xFF47B347)
              : (isDark ? AppColors.darkOutlineVariant : const Color(0xFFE0E3E0)),
          width: isInProgress ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isInProgress
                ? const Color(0xFF006E15).withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: isInProgress ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Left accent bar
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 5,
            child: Container(
              color: (isCompleted || isInProgress)
                  ? const Color(0xFF47B347)
                  : (isDark ? AppColors.darkOutline : const Color(0xFFBECAB7)),
            ),
          ),

          // Main Card Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Mã KH + Status tag & Distance + Directions button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: Code + Status Badge
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCompleted || isInProgress
                                ? const Color(0xFFEFF6E8)
                                : (isDark ? AppColors.darkSurfaceContainer : const Color(0xFFE4EADD)),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isDark ? AppColors.darkOutlineVariant : const Color(0xFFBECAB7),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            codeText,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isCompleted || isInProgress
                                  ? (isDark ? AppColors.primaryFixedDim : const Color(0xFF006E15))
                                  : (isDark ? AppColors.darkOnSurfaceVariant : const Color(0xFF3F4A3B)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.primaryContainer.withValues(alpha: 0.2) : const Color(0xFFEFF6E8),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 13,
                                  color: Color(0xFF006E15),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Đã ghé',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? AppColors.primaryFixedDim : const Color(0xFF006E15),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (!isInProgress)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceContainer : const Color(0xFFE4EADD),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Chưa ghé',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.darkOnSurfaceVariant : const Color(0xFF3F4A3B),
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Right: Distance Chip & Directions Button
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (distanceText.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isInProgress && isValidDistance
                                  ? const Color(0xFFEFF6E8)
                                  : (isDark ? AppColors.darkSurfaceContainer : const Color(0xFFE4EADD)),
                              borderRadius: BorderRadius.circular(8),
                              border: isInProgress && isValidDistance
                                  ? Border.all(
                                      color: isDark ? AppColors.primaryFixedDim : const Color(0xFFBECAB7),
                                      width: 1,
                                    )
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.near_me,
                                  size: 13,
                                  color: isInProgress && isValidDistance
                                      ? const Color(0xFF006E15)
                                      : (isDark ? AppColors.darkOnSurfaceVariant : const Color(0xFF3F4A3B)),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  isInProgress && isValidDistance
                                      ? '$distanceText (Hợp lệ)'
                                      : distanceText,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isInProgress && isValidDistance
                                        ? const Color(0xFF006E15)
                                        : (isDark ? AppColors.darkOnSurfaceVariant : const Color(0xFF3F4A3B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        // Directions Button
                        InkWell(
                          onTap: () => _openDirections(context, dealer),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceContainer : const Color(0xFFEFF6E8),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? AppColors.darkOutlineVariant : const Color(0xFFBECAB7),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.directions,
                                  size: 14,
                                  color: isDark ? AppColors.primaryFixedDim : const Color(0xFF006E15),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Chỉ đường',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.primaryFixedDim : const Color(0xFF006E15),
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
                const SizedBox(height: 8),

                // Customer / Store Name
                InkWell(
                  onTap: () {
                    if (dealer.customer is CustomerEntity) {
                      _showCustomerDetail(context, dealer.customer as CustomerEntity);
                    }
                  },
                  child: Text(
                    dealer.name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: isInProgress ? 17 : 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkOnSurface : const Color(0xFF181C1B),
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Address Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: Color(0xFF006E15),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        dealer.address,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: isDark ? AppColors.darkOnSurfaceVariant : const Color(0xFF3F4A3B),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Contact & Time / Phone & Check-in Row
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: isDark ? AppColors.darkOutlineVariant : const Color(0xFFE0E3E0),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left column: Contact Person + Phone Link
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Contact person
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 15,
                                  color: isDark ? AppColors.darkOnSurfaceVariant : const Color(0xFF3F4A3B),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    dealer.contactPerson?.isNotEmpty == true
                                        ? dealer.contactPerson!
                                        : 'Chưa cập nhật',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? AppColors.darkOnSurface : const Color(0xFF181C1B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),

                            // Phone link (if available)
                            if (!isCompleted && dealer.phone != null && dealer.phone!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              InkWell(
                                onTap: () => _makePhoneCall(context, dealer.phone),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.call,
                                      size: 13,
                                      color: isDark ? AppColors.primaryFixedDim : const Color(0xFF006E15),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      dealer.phone!,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.primaryFixedDim : const Color(0xFF006E15),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Right column: Time chip (if visited) OR Check-in Button (if in progress/pending)
                      if (isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceContainer : const Color(0xFFEFF6E8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 13,
                                color: isDark ? AppColors.primaryFixedDim : const Color(0xFF006E15),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dealer.visitedTime ?? '08:30 AM',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppColors.primaryFixedDim : const Color(0xFF006E15),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Material(
                          color: const Color(0xFF47B347),
                          borderRadius: BorderRadius.circular(8),
                          elevation: 1,
                          shadowColor: const Color(0xFF006E15).withValues(alpha: 0.2),
                          child: InkWell(
                            onTap: () => context.push('/check-in'),
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.how_to_reg,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Check-in',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomerDetail(BuildContext context, CustomerEntity customer) {
    EditCustomerDialog.show(
      context,
      customer: customer,
      onSave: (changes) async {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật thông tin điểm bán')),
        );
      },
    );
  }
}

