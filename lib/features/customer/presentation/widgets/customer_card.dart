import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../route/domain/entities/route_entity.dart';
import '../../domain/entities/customer_entity.dart';
import '../viewmodels/customer_view_model.dart';

/// Template card hiển thị thông tin khách hàng dùng chung cho cả màn Tuyến và màn Khách hàng.
///
/// Template chuẩn hóa toàn bộ bố cục từ màn tuyến, có 1 tham số [actionButton] ở góc phải dưới:
/// - Ở màn Tuyến: [actionButton] là nút **Check-in** (hoặc chip hiển thị giờ nếu đã hoàn thành ghé)
/// - Ở màn Khách hàng: [actionButton] là nút **Sửa**
class CustomerCard extends StatelessWidget {
  final CustomerWithDistance? item;
  final String code;
  final String name;
  final String address;
  final String? phone;
  final String? contactPerson;
  final String? contactTitle;
  final String? type;
  final double? lat;
  final double? lng;
  final double? distance;
  final String? distanceText;
  final bool isCompleted;
  final bool isInProgress;
  final String? visitedTime;
  final String? syncStatus;

  /// Tham số button duy nhất của template:
  /// - Màn tuyến: nút Check-in
  /// - Màn khách hàng: nút Sửa
  final Widget? actionButton;

  final VoidCallback? onTap;
  final VoidCallback? onDirections;
  final VoidCallback? onCallPhone;

  // Cached static styling
  static const _codeBgCompleted = Color(0xFFEFF6E8);
  static const _codeBgNormal = Color(0xFFE4EADD);
  static const _codeBorder = Color(0xFFBECAB7);
  static const _pendingBgLight = Color(0xFFFEF3C7);
  static const _pendingBgDark = Color(0x4D78350F);
  static const _pendingBorder = Color(0xFFF59E0B);
  static const _pendingIcon = Color(0xFFD97706);
  static const _pendingTextLight = Color(0xFFB45309);
  static const _pendingTextDark = Color(0xFFFBBF24);

  CustomerCard({
    super.key,
    this.item,
    String? code,
    String? name,
    String? address,
    this.phone,
    this.contactPerson,
    this.contactTitle,
    this.type,
    this.lat,
    this.lng,
    this.distance,
    this.distanceText,
    this.isCompleted = false,
    this.isInProgress = false,
    this.visitedTime,
    this.syncStatus,
    this.actionButton,
    this.onTap,
    this.onDirections,
    this.onCallPhone,
  })  : code = code ?? (item != null ? item.customer.code : ''),
        name = name ?? (item != null ? item.customer.name : ''),
        address = address ?? (item != null ? item.customer.address : '');

  /// Factory khởi tạo từ DealerEntity (Màn Tuyến: tham số button mặc định là Check-in)
  factory CustomerCard.fromDealer({
    Key? key,
    required DealerEntity dealer,
    double? distance,
    String? distanceText,
    Widget? actionButton,
    VoidCallback? onCheckIn,
    VoidCallback? onTap,
    VoidCallback? onDirections,
    VoidCallback? onCallPhone,
  }) {
    final isCompleted = dealer.status == DealerVisitStatus.completed;
    final resolvedButton = actionButton ??
        (isCompleted
            ? CustomerCard.buildVisitedTimeChip(visitedTime: dealer.visitedTime)
            : (onCheckIn != null
                ? CustomerCard.buildCheckInButton(onTap: onCheckIn)
                : null));

    final resolvedType = dealer.type?.isNotEmpty == true
        ? dealer.type
        : (dealer.customer is CustomerEntity
            ? (dealer.customer as CustomerEntity).type
            : null);

    return CustomerCard(
      key: key,
      code: dealer.code?.isNotEmpty == true ? dealer.code! : 'KH${dealer.order}',
      name: dealer.name,
      address: dealer.address,
      phone: dealer.phone,
      contactPerson: dealer.contactPerson,
      type: resolvedType,
      lat: dealer.lat,
      lng: dealer.lng,
      distance: distance,
      distanceText: distanceText,
      isCompleted: isCompleted,
      isInProgress: dealer.status == DealerVisitStatus.inProgress,
      visitedTime: dealer.visitedTime,
      actionButton: resolvedButton,
      onTap: onTap,
      onDirections: onDirections,
      onCallPhone: onCallPhone,
    );
  }

  /// Factory khởi tạo từ CustomerWithDistance (Màn Khách hàng: tham số button mặc định là Sửa)
  factory CustomerCard.fromCustomerWithDistance({
    Key? key,
    required CustomerWithDistance item,
    Widget? actionButton,
    VoidCallback? onEdit,
    VoidCallback? onTap,
    VoidCallback? onDirections,
    VoidCallback? onCallPhone,
  }) {
    final resolvedButton = actionButton ??
        (onEdit != null
            ? CustomerCard.buildEditButton(onTap: onEdit)
            : null);

    return CustomerCard(
      key: key,
      item: item,
      code: item.customer.code.isNotEmpty ? item.customer.code : 'KH${item.customer.id}',
      name: item.customer.name,
      address: item.customer.address,
      phone: item.customer.phone,
      contactPerson: item.customer.contactTitle != null && item.customer.contactTitle!.isNotEmpty
          ? '${item.customer.contactPerson} (${item.customer.contactTitle})'
          : item.customer.contactPerson,
      type: item.customer.type,
      lat: item.customer.lat,
      lng: item.customer.lng,
      distance: item.distanceMeters,
      distanceText: item.formattedDistance != '—' ? item.formattedDistance : null,
      isCompleted: item.customer.visitStatus == CustomerVisitStatus.visited,
      isInProgress: false,
      syncStatus: item.customer.syncStatus,
      actionButton: resolvedButton,
      onTap: onTap,
      onDirections: onDirections,
      onCallPhone: onCallPhone,
    );
  }

  /// Factory khởi tạo từ CustomerEntity
  factory CustomerCard.fromCustomer({
    Key? key,
    required CustomerEntity customer,
    double? distance,
    String? distanceText,
    Widget? actionButton,
    VoidCallback? onEdit,
    VoidCallback? onCheckIn,
    VoidCallback? onTap,
    VoidCallback? onDirections,
    VoidCallback? onCallPhone,
  }) {
    final isCompleted = customer.visitStatus == CustomerVisitStatus.visited;
    final resolvedButton = actionButton ??
        (onEdit != null
            ? CustomerCard.buildEditButton(onTap: onEdit)
            : (onCheckIn != null
                ? (isCompleted
                    ? CustomerCard.buildVisitedTimeChip()
                    : CustomerCard.buildCheckInButton(onTap: onCheckIn))
                : null));

    return CustomerCard(
      key: key,
      code: customer.code.isNotEmpty ? customer.code : 'KH${customer.id}',
      name: customer.name,
      address: customer.address,
      phone: customer.phone,
      contactPerson: customer.contactTitle != null && customer.contactTitle!.isNotEmpty
          ? '${customer.contactPerson} (${customer.contactTitle})'
          : customer.contactPerson,
      type: customer.type,
      lat: customer.lat,
      lng: customer.lng,
      distance: distance,
      distanceText: distanceText,
      isCompleted: isCompleted,
      isInProgress: false,
      syncStatus: customer.syncStatus,
      actionButton: resolvedButton,
      onTap: onTap,
      onDirections: onDirections,
      onCallPhone: onCallPhone,
    );
  }

  /// Nút Check-in chuẩn của template (dùng cho màn Tuyến)
  static Widget buildCheckInButton({
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF47B347),
      borderRadius: BorderRadius.circular(8),
      elevation: 1,
      shadowColor: const Color(0x33006E15),
      child: InkWell(
        onTap: onTap,
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
    );
  }

  /// Nút Sửa chuẩn của template (dùng cho màn Khách hàng)
  static Widget buildEditButton({
    required VoidCallback onTap,
    bool isDark = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
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
              Icons.edit_note_rounded,
              size: 16,
              color: isDark ? AppColors.primaryFixedDim : const Color(0xFF006E15),
            ),
            const SizedBox(width: 3),
            Text(
              'Sửa',
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
    );
  }

  /// Chip hiển thị giờ ghé thăm (khi đã hoàn thành ghé trên tuyến)
  static Widget buildVisitedTimeChip({
    String? visitedTime,
    bool isDark = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            visitedTime ?? '08:30 AM',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.primaryFixedDim : const Color(0xFF006E15),
            ),
          ),
        ],
      ),
    );
  }

  static String formatDistance(double? distanceMeters) {
    if (distanceMeters == null) return '—';
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  static Future<void> defaultMakePhoneCall(BuildContext context, String? phoneNumber) async {
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

  static Future<void> defaultOpenDirections(
    BuildContext context, {
    double? lat,
    double? lng,
    required String address,
  }) async {
    final hasGps = lat != null && lng != null;
    final hasAddress = address.trim().isNotEmpty;

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
        ? '$lat,$lng'
        : Uri.encodeComponent(address.trim());

    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destination&travelmode=driving',
    );

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveCustomer = item?.customer;
    final effectiveCode = code.isNotEmpty ? code : (effectiveCustomer?.code ?? '');
    final effectiveName = name.isNotEmpty ? name : (effectiveCustomer?.name ?? '');
    final effectiveAddress = address.isNotEmpty ? address : (effectiveCustomer?.address ?? '');
    final effectivePhone = phone ?? effectiveCustomer?.phone;
    final effectiveContact = contactPerson ??
        (effectiveCustomer != null
            ? (effectiveCustomer.contactTitle != null && effectiveCustomer.contactTitle!.isNotEmpty
                ? '${effectiveCustomer.contactPerson} (${effectiveCustomer.contactTitle})'
                : effectiveCustomer.contactPerson)
            : null);
    final effectiveLat = lat ?? effectiveCustomer?.lat;
    final effectiveLng = lng ?? effectiveCustomer?.lng;
    final effectiveDistance = distance ?? item?.distanceMeters;
    final effectiveSyncStatus = syncStatus ?? effectiveCustomer?.syncStatus;
    final effectiveIsCompleted = isCompleted || effectiveCustomer?.visitStatus == CustomerVisitStatus.visited;
    final effectiveType = (type?.trim().isNotEmpty == true)
        ? type!.trim()
        : (effectiveCustomer?.type.trim().isNotEmpty == true
            ? effectiveCustomer!.type.trim()
            : null);

    final hasCoordinates = effectiveLat != null && effectiveLng != null;
    final isValidDistance = effectiveDistance != null && effectiveDistance <= 100;
    final distText = distanceText ?? (item != null ? item!.formattedDistance : formatDistance(effectiveDistance));

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
                ? const Color(0x1F006E15)
                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: isInProgress ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                            color: effectiveIsCompleted || isInProgress
                                ? _codeBgCompleted
                                : (isDark ? AppColors.darkSurfaceContainer : _codeBgNormal),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isDark ? AppColors.darkOutlineVariant : _codeBorder,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            effectiveCode,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: effectiveIsCompleted || isInProgress
                                  ? (isDark ? AppColors.primaryFixedDim : const Color(0xFF006E15))
                                  : (isDark ? AppColors.darkOnSurfaceVariant : const Color(0xFF3F4A3B)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Offline sync status or visit status tag
                        if (effectiveSyncStatus == 'pending') ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? _pendingBgDark : _pendingBgLight,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _pendingBorder,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 11,
                                  color: _pendingIcon,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Chờ đồng bộ',
                                  style: AppTypography.labelSmall(
                                    color: isDark ? _pendingTextDark : _pendingTextLight,
                                  ).copyWith(fontWeight: FontWeight.w600, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ] else if (effectiveIsCompleted) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0x33006E15) : const Color(0xFFEFF6E8),
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
                          ),
                        ] else if (!isInProgress) ...[
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
                      ],
                    ),

                    // Right: Distance Chip & Directions Button
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                                hasCoordinates ? Icons.near_me : Icons.location_off_outlined,
                                size: 13,
                                color: isInProgress && isValidDistance
                                    ? const Color(0xFF006E15)
                                    : (isDark ? AppColors.darkOnSurfaceVariant : const Color(0xFF3F4A3B)),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                !hasCoordinates
                                    ? 'Chưa có GPS'
                                    : (isInProgress && isValidDistance
                                        ? '$distText (Hợp lệ)'
                                        : distText),
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

                        // Directions Button
                        InkWell(
                          onTap: onDirections ??
                              () => defaultOpenDirections(
                                    context,
                                    lat: effectiveLat,
                                    lng: effectiveLng,
                                    address: effectiveAddress,
                                  ),
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

                // Customer / Store Name & Type Chip
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onTap,
                        child: Text(
                          effectiveName,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: isInProgress ? 17 : 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkOnSurface : const Color(0xFF181C1B),
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),
                    if (effectiveType != null && effectiveType.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceContainer : const Color(0xFFF1F5EB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? AppColors.darkOutlineVariant : const Color(0xFFCDD7C7),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.storefront_outlined,
                              size: 12,
                              color: isDark ? AppColors.primaryFixedDim : const Color(0xFF006E15),
                            ),
                            const SizedBox(width: 3.5),
                            Text(
                              effectiveType,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.primaryFixedDim : const Color(0xFF006E15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
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
                        effectiveAddress.isNotEmpty ? effectiveAddress : 'Chưa cập nhật địa chỉ',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: isDark ? AppColors.darkOnSurfaceVariant : const Color(0xFF3F4A3B),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Contact & Action Row (Phone, Action Button parameter)
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
                                    effectiveContact?.isNotEmpty == true
                                        ? effectiveContact!
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
                            if (effectivePhone != null && effectivePhone.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              InkWell(
                                onTap: onCallPhone ?? () => defaultMakePhoneCall(context, effectivePhone),
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
                                      effectivePhone,
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

                      // Right column: Tham số button duy nhất của template (Check-in ở màn tuyến, Sửa ở màn khách hàng)
                      if (actionButton != null)
                        actionButton!,
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
}
