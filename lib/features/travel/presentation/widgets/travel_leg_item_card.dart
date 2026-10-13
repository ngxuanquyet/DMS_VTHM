import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/travel_leg_entity.dart';

/// Card hiển thị từng chặng di chuyển trong ngày
/// Tuân thủ quy tắc §3 & §4.2 API-QUANG-DUONG-MOBILE-2026-10-08.md (Cập nhật 13/10/2026)
class TravelLegItemCard extends StatelessWidget {
  final TravelLegEntity leg;
  final bool isLast;

  const TravelLegItemCard({
    super.key,
    required this.leg,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isStart = leg.legKind == 'start';
    final hasEndpoints = leg.from != null || leg.to != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hàng 1: Thứ tự chặng, loại chặng, và badge trạng thái từ server
            Row(
              children: [
                // Thứ tự chặng (#1, #2...)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isStart
                        ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF))
                        : (isDark ? const Color(0xFF14532D) : const Color(0xFFF0FDF4)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isStart
                          ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE))
                          : (isDark ? const Color(0xFF22C55E) : const Color(0xFFBBF7D0)),
                      width: 0.8,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '#${leg.seq}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isStart
                            ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))
                            : (isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Nhãn loại chặng từ server (leg_kind_label)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        leg.legKindLabel.isNotEmpty
                            ? leg.legKindLabel
                            : (isStart ? 'Chấm công vào → Điểm bán đầu tiên' : 'Giữa hai điểm bán'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isStart ? 'Chặng khởi đầu ngày' : 'Chặng di chuyển bán hàng',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Badge trạng thái dùng status_label và status_color của server (§4.2)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: leg.statusBackgroundColorValue,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: leg.statusColorValue.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    leg.statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: leg.statusColorValue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 0.6),
            const SizedBox(height: 12),

            // Hiển thị Lộ trình từ đâu đến đâu (§4.2 Cập nhật 13/10/2026)
            if (hasEndpoints)
              _buildTimelineSection(context, isDark)
            else
              _buildLegacyDistanceRow(isDark),

            // Chú ý: Tuyệt đối KHÔNG hiển thị leg.errorNote cho nhân viên theo §4.2
          ],
        ),
      ),
    );
  }

  /// Khối Timeline thể hiện chặng từ đâu đến đâu
  Widget _buildTimelineSection(BuildContext context, bool isDark) {
    return Column(
      children: [
        // 1. Điểm xuất phát (TỪ)
        if (leg.from != null)
          _buildEndpointItem(
            endpoint: leg.from!,
            isFrom: true,
            isDark: isDark,
          ),

        // 2. Đoạn đường nối giữa 2 mốc kèm số km
        _buildConnectorAndDistance(isDark),

        // 3. Điểm đến (ĐẾN)
        if (leg.to != null)
          _buildEndpointItem(
            endpoint: leg.to!,
            isFrom: false,
            isDark: isDark,
          ),
      ],
    );
  }

  /// Vẽ 1 mốc đầu hoặc mốc cuối của chặng
  Widget _buildEndpointItem({
    required TravelEndpointEntity endpoint,
    required bool isFrom,
    required bool isDark,
  }) {
    Color iconColor;
    Color iconBg;
    IconData iconData;

    if (endpoint.isPunch) {
      iconColor = const Color(0xFF2563EB); // Blue
      iconBg = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF);
      iconData = Icons.fingerprint_rounded;
    } else if (endpoint.isVisit) {
      if (isFrom) {
        iconColor = const Color(0xFF0D9488); // Teal
        iconBg = isDark ? const Color(0xFF134E4A) : const Color(0xFFF0FDFA);
      } else {
        iconColor = const Color(0xFFEA580C); // Orange
        iconBg = isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFF7ED);
      }
      iconData = Icons.storefront_rounded;
    } else if (endpoint.isMissing) {
      iconColor = const Color(0xFFDC2626); // Red
      iconBg = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2);
      iconData = Icons.location_off_rounded;
    } else {
      iconColor = const Color(0xFF64748B);
      iconBg = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
      iconData = Icons.place_rounded;
    }

    final formattedTime = endpoint.formattedTime;
    String? timePrefix;
    if (formattedTime != null) {
      if (isFrom) {
        timePrefix = endpoint.isVisit ? 'Rời' : 'Chấm';
      } else {
        timePrefix = 'Đến';
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon đại diện cho mốc
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
            border: Border.all(
              color: iconColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(
            iconData,
            size: 15,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 10),

        // Thông tin chi tiết mốc
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hàng tag TỪ/ĐẾN và loại mốc
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isFrom
                          ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))
                          : (isDark ? const Color(0xFF374151) : const Color(0xFFFED7AA)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isFrom ? 'TỪ' : 'ĐẾN',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isFrom
                            ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))
                            : const Color(0xFFC2410C),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    endpoint.typeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),

              // Tên mốc (Tên điểm bán / địa điểm chấm công / nhãn missing)
              Text(
                endpoint.displayName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: endpoint.isMissing
                      ? const Color(0xFFDC2626)
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),

              // Thông tin phụ: Mã và Thời gian
              if (endpoint.displayCode != null || formattedTime != null) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (endpoint.displayCode != null) ...[
                      Text(
                        'Mã: ${endpoint.displayCode!}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white38 : const Color(0xFF64748B),
                        ),
                      ),
                      if (formattedTime != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '•',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                    ],
                    if (formattedTime != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 11,
                            color: isDark ? Colors.white38 : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$timePrefix: $formattedTime',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Vẽ đoạn nối dọc và con số km giữa mốc từ và mốc đến
  Widget _buildConnectorAndDistance(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Đường kẻ dọc nối 2 icon
          SizedBox(
            width: 28,
            child: Center(
              child: Container(
                width: 2,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Khối hiển thị quãng đường chặng
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceContainer
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.two_wheeler_rounded, // Goong bike theo spec §1
                    size: 16,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),

                  // Con số quãng đường đường bộ (§3)
                  Text(
                    leg.displayDistance,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: leg.isOk || leg.isSkippedShort
                          ? (isDark ? const Color(0xFF34D399) : const Color(0xFF0D9488))
                          : leg.isMissingAnchor
                              ? const Color(0xFFDC2626)
                              : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                    ),
                  ),

                  if (leg.isMissingAnchor) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Thiếu mốc',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ] else if (leg.isPending || leg.isProviderError) ...[
                    const SizedBox(width: 6),
                    Text(
                      '(đang tính toán)',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Đường chim bay đối chứng (nếu có)
                  if (leg.displayHaversineKm != null)
                    Text(
                      'Chim bay: ${leg.displayHaversineKm!}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.white38 : const Color(0xFF64748B),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Giao diện fallback khi không có endpoint from/to
  Widget _buildLegacyDistanceRow(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quãng đường đường bộ:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  leg.displayDistance,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: leg.isOk || leg.isSkippedShort
                        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF0D9488))
                        : leg.isMissingAnchor
                            ? const Color(0xFFDC2626)
                            : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                  ),
                ),
                if (leg.isMissingAnchor) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Thiếu mốc',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ] else if (leg.isPending || leg.isProviderError) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(đang tính toán)',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        if (leg.displayHaversineKm != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Chim bay đối chứng',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                leg.displayHaversineKm!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

