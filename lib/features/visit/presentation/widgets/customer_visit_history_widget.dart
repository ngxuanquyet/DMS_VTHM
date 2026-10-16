import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/visit_history_entity.dart';
import '../../domain/usecases/visit_usecases.dart';
import 'visit_history_detail_sheet.dart';

/// Widget hiển thị danh sách lịch sử viếng thăm của một điểm bán (§2.4 SPEC 16/10/2026)
/// Dùng hiển thị trực tiếp trong màn Viếng thăm (CheckInScreen) và Chi tiết điểm bán (CustomerDetailScreen)
class CustomerVisitHistoryWidget extends ConsumerStatefulWidget {
  final int customerId;
  final String? customerName;
  final bool initiallyExpanded;

  const CustomerVisitHistoryWidget({
    super.key,
    required this.customerId,
    this.customerName,
    this.initiallyExpanded = true,
  });

  @override
  ConsumerState<CustomerVisitHistoryWidget> createState() =>
      _CustomerVisitHistoryWidgetState();
}

class _CustomerVisitHistoryWidgetState
    extends ConsumerState<CustomerVisitHistoryWidget> {
  bool _isLoading = true;
  String? _errorMessage;
  CustomerVisitHistoryResponse? _historyResponse;
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _fetchHistory();
  }

  @override
  void didUpdateWidget(covariant CustomerVisitHistoryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customerId != widget.customerId) {
      _fetchHistory();
    }
  }

  Future<void> _fetchHistory() async {
    if (widget.customerId <= 0) {
      setState(() {
        _isLoading = false;
        _historyResponse = const CustomerVisitHistoryResponse();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ref
          .read(getCustomerVisitHistoryUseCaseProvider)
          .call(widget.customerId, page: 1, perPage: 10);
      if (mounted) {
        setState(() {
          _historyResponse = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('AppException: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = _historyResponse?.items ?? [];

    String dateRangeSub = '2 tháng gần nhất';
    if (_historyResponse?.dateFrom != null && _historyResponse?.dateTo != null) {
      dateRangeSub = 'Từ ${_historyResponse!.dateFrom} đến ${_historyResponse!.dateTo}';
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2420) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E7E2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card (Tên phần + Toggle ẩn/hiện)
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF006E15).withValues(alpha: 0.2)
                          : const Color(0xFFEFF6E8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      size: 20,
                      color: Color(0xFF006E15),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Lịch sử viếng thăm',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF181C1B),
                              ),
                            ),
                            if (items.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF006E15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${items.length}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          dateRangeSub,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF006E15),
                      ),
                    )
                  else
                    Icon(
                      _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                    ),
                ],
              ),
            ),
          ),

          // Body (khi expand)
          if (_isExpanded) ...[
            const Divider(height: 1, thickness: 1),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF006E15)),
                ),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _fetchHistory,
                      child: const Text('Thử lại', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              )
            else if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_note_outlined,
                        size: 32,
                        color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Chưa có lượt viếng thăm nào trong 2 tháng gần đây',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, idx) {
                  final visit = items[idx];
                  return _buildVisitHistoryTile(ctx, visit, isDark);
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildVisitHistoryTile(
    BuildContext context,
    VisitHistoryItemEntity visit,
    bool isDark,
  ) {
    final isClosed = visit.isClosedStore;
    final statusColor = isClosed ? const Color(0xFFD97706) : const Color(0xFF006E15);
    final statusBg = isClosed
        ? (isDark ? const Color(0x33D97706) : const Color(0xFFFEF3C7))
        : (isDark ? const Color(0x33006E15) : const Color(0xFFE8F5E9));

    String checkinTimeStr = '--:--';
    if (visit.checkinAt != null && visit.checkinAt!.contains(' ')) {
      final parts = visit.checkinAt!.split(' ');
      if (parts.length >= 2 && parts[1].length >= 5) {
        checkinTimeStr = parts[1].substring(0, 5);
      }
    }

    return Material(
      color: isDark ? const Color(0xFF28302A) : const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          showVisitHistoryDetailSheet(
            context,
            customerId: widget.customerId,
            visitId: visit.id,
            initialItem: visit,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hàng 1: Người viếng thăm + Kết quả
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: const Color(0xFF006E15),
                          child: Text(
                            visit.employeeName.isNotEmpty
                                ? visit.employeeName.characters.first.toUpperCase()
                                : 'N',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            visit.employeeName,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor, width: 0.8),
                    ),
                    child: Text(
                      visit.visitResultLabel ?? (isClosed ? 'Đóng cửa' : 'Mở cửa'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Hàng 2: Ngày giờ + Thời gian lưu lại
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 12,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${visit.visitDate ?? ''} $checkinTimeStr',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.timer_outlined,
                    size: 12,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    visit.formattedDuration,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),

              // Hàng 2.5: Xem nhanh ghi chú / lý do đóng cửa nếu có
              if ((visit.closedNote != null && visit.closedNote!.isNotEmpty) ||
                  (visit.note != null && visit.note!.isNotEmpty)) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (visit.closedNote != null && visit.closedNote!.isNotEmpty)
                        ? (isDark ? const Color(0x22F59E0B) : const Color(0xFFFFFBEB))
                        : (isDark ? Colors.white10 : const Color(0xFFF3F4F6)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        (visit.closedNote != null && visit.closedNote!.isNotEmpty)
                            ? Icons.warning_amber_rounded
                            : Icons.edit_note_rounded,
                        size: 13,
                        color: (visit.closedNote != null && visit.closedNote!.isNotEmpty)
                            ? const Color(0xFFD97706)
                            : (isDark ? Colors.white70 : const Color(0xFF006E15)),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          (visit.closedNote != null && visit.closedNote!.isNotEmpty)
                              ? 'Lý do: ${visit.closedNote}'
                              : 'Ghi chú: ${visit.note}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: (visit.closedNote != null && visit.closedNote!.isNotEmpty)
                                ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E))
                                : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Hàng 3: Đếm ảnh & Đếm biểu mẫu + Nút xem chi tiết
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (visit.photoCount > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_camera_outlined, size: 11, color: Color(0xFF2563EB)),
                              const SizedBox(width: 3),
                              Text(
                                '${visit.photoCount} ảnh',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (visit.formCount > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.assignment_outlined, size: 11, color: Color(0xFF16A34A)),
                              const SizedBox(width: 3),
                              Text(
                                '${visit.formCount} phiếu',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF16A34A)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (visit.photoCount == 0 && visit.formCount == 0)
                        Text(
                          'Không có ảnh / phiếu',
                          style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38),
                        ),
                    ],
                  ),

                  // Nút xem chi tiết
                  Row(
                    children: [
                      Text(
                        'Xem chi tiết',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF006E15),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF006E15),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
