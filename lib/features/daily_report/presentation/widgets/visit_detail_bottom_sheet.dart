import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';

/// Modal chi tiết một lượt viếng thăm
void showVisitDetailBottomSheet(BuildContext context, VisitEntity visit) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  String formatTime(DateTime? dt) {
    if (dt == null) return '--:--';
    return DateFormat('HH:mm:ss - dd/MM/yyyy').format(dt.toLocal());
  }

  String formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '0 phút';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '$s giây';
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2420) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF006E15).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.store_mall_directory_rounded,
                      color: Color(0xFF006E15),
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
                              : 'Chi tiết lượt viếng thăm #${visit.id}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (visit.customerCode != null &&
                            visit.customerCode!.isNotEmpty)
                          Text(
                            'Mã ĐB: ${visit.customerCode}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Các trường thông tin
              _detailRow('Mã lượt viếng thăm', '#${visit.id}'),
              if (visit.customerAddress != null &&
                  visit.customerAddress!.isNotEmpty)
                _detailRow('Địa chỉ điểm bán', visit.customerAddress!),
              _detailRow(
                'Tuyến bán hàng',
                visit.isOnRoute
                    ? (visit.routeName ?? 'Trong tuyến chỉ định')
                    : 'Ngoài tuyến',
              ),
              _detailRow(
                'Kết quả viếng thăm',
                visit.visitResult == 'closed'
                    ? 'Cửa hàng đóng cửa'
                    : (visit.isOpen ? 'Đang thực hiện' : 'Thành công (Mở cửa)'),
              ),
              if (visit.closedNote != null && visit.closedNote!.isNotEmpty)
                _detailRow('Lý do đóng cửa', visit.closedNote!),
              _detailRow('Giờ Check-in', formatTime(visit.checkinAt)),
              if (visit.checkoutAt != null)
                _detailRow('Giờ Check-out', formatTime(visit.checkoutAt)),
              _detailRow('Thời lượng viếng thăm', formatDuration(visit.durationSeconds)),
              _detailRow('Số ảnh chụp thực địa', '${visit.photoCount} ảnh'),
              _detailRow('Số biểu mẫu nộp', '${visit.formCount} phiếu'),
              if (visit.checkoutLat != null && visit.checkoutLng != null)
                _detailRow('Toạ độ Check-out',
                    '${visit.checkoutLat!.toStringAsFixed(6)}, ${visit.checkoutLng!.toStringAsFixed(6)}'),

              // Hiển thị ảnh nếu có photoUrls
              if (visit.photoUrls.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Hình ảnh thực địa đính kèm:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: visit.photoUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final url = visit.photoUrls[idx];
                      return GestureDetector(
                        onTap: () => _showFullImageDialog(context, url),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 80,
                            height: 80,
                            color: Colors.black12,
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image_rounded,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

void _showFullImageDialog(BuildContext context, String url) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(24),
                  child: const Text('Không thể tải ảnh'),
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
        ],
      ),
    ),
  );
}
