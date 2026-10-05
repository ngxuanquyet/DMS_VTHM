import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';
import 'visit_detail_bottom_sheet.dart';

/// Thẻ hiển thị một lượt viếng thăm trong Báo cáo viếng thăm
class VisitReportCard extends StatelessWidget {
  final VisitEntity visit;

  const VisitReportCard({
    super.key,
    required this.visit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Định dạng giờ vào / ra
    String checkinStr = '--:--';
    if (visit.checkinAt != null) {
      checkinStr = DateFormat('HH:mm').format(visit.checkinAt!.toLocal());
    }

    String checkoutStr = 'Đang mở';
    if (visit.checkoutAt != null) {
      checkoutStr = DateFormat('HH:mm').format(visit.checkoutAt!.toLocal());
    }

    // Thời lượng
    String durationStr = '--';
    if (visit.durationSeconds != null && visit.durationSeconds! > 0) {
      final m = (visit.durationSeconds! % 3600) ~/ 60;
      final h = visit.durationSeconds! ~/ 3600;
      if (h > 0) {
        durationStr = '${h}h ${m}m';
      } else {
        durationStr = '$m phút';
      }
    } else if (visit.isOpen) {
      durationStr = 'Đang đếm';
    }

    // Trạng thái kết quả
    final isClosed = visit.visitResult == 'closed';
    final isOpen = visit.isOpen;
    final isCancelled = visit.isCancelled;

    Color statusColor = const Color(0xFF006E15);
    Color statusBgColor = const Color(0xFFE8F5E9);
    String statusText = 'Mở cửa';
    IconData statusIcon = Icons.check_circle_rounded;

    if (isCancelled) {
      statusColor = const Color(0xFF6B7280);
      statusBgColor = const Color(0xFFF3F4F6);
      statusText = 'Đã huỷ';
      statusIcon = Icons.cancel_rounded;
    } else if (isClosed) {
      statusColor = const Color(0xFFD97706);
      statusBgColor = const Color(0xFFFEF3C7);
      statusText = 'Đóng cửa';
      statusIcon = Icons.storefront_outlined;
    } else if (isOpen) {
      statusColor = const Color(0xFF0284C7);
      statusBgColor = const Color(0xFFE0F2FE);
      statusText = 'Đang viếng thăm';
      statusIcon = Icons.sync_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2420) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E7E2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showVisitDetailBottomSheet(context, visit),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Tên điểm bán & Badge kết quả
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.store_mall_directory_rounded,
                        color: statusColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            visit.customerName.isNotEmpty
                                ? visit.customerName
                                : 'Điểm bán #${visit.customerId}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF181C1B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (visit.customerCode != null &&
                                  visit.customerCode!.isNotEmpty) ...[
                                Text(
                                  visit.customerCode!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white54 : const Color(0xFF6F7A74),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text('•',
                                    style: TextStyle(
                                        color: isDark ? Colors.white30 : Colors.black26,
                                        fontSize: 10)),
                                const SizedBox(width: 6),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: visit.isOnRoute
                                      ? const Color(0xFF006E15).withValues(alpha: 0.08)
                                      : const Color(0xFFE59819).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  visit.isOnRoute ? 'Trong tuyến' : 'Ngoài tuyến',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: visit.isOnRoute
                                        ? const Color(0xFF006E15)
                                        : const Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? statusColor.withValues(alpha: 0.2) : statusBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 13, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // 2. Địa chỉ (nếu có)
                if (visit.customerAddress != null &&
                    visit.customerAddress!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          visit.customerAddress!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // 3. Ghi chú đóng cửa (nếu đóng cửa)
                if (isClosed &&
                    visit.closedNote != null &&
                    visit.closedNote!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7).withValues(alpha: isDark ? 0.15 : 0.8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFFDE68A).withValues(alpha: isDark ? 0.3 : 1),
                      ),
                    ),
                    child: Text(
                      'Lý do: ${visit.closedNote!}',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                Divider(
                  height: 1,
                  thickness: 0.6,
                  color: isDark ? Colors.white10 : const Color(0xFFE2E7E2),
                ),
                const SizedBox(height: 8),

                // 4. Thời gian (Vào, Ra, Thời lượng) & Kết quả công việc
                Row(
                  children: [
                    // Cụm thời gian
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$checkinStr - $checkoutStr',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              durationStr,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Cụm Ảnh & Biểu mẫu
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (visit.photoCount > 0) ...[
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 14,
                            color: const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${visit.photoCount}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD97706),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (visit.formCount > 0) ...[
                          Icon(
                            Icons.assignment_outlined,
                            size: 14,
                            color: const Color(0xFF4F46E5),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${visit.formCount}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),

                // 5. Thumbnails ảnh đính kèm (nếu có)
                if (visit.photoUrls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: visit.photoUrls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, pIdx) {
                        final url = visit.photoUrls[pIdx];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 48,
                            height: 48,
                            color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.image_rounded,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
