import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../daily_report/presentation/widgets/visit_detail_bottom_sheet.dart';
import '../../../visit/data/repositories/visit_repository_impl.dart';
import '../../../visit/domain/entities/visit_entity.dart';
import '../../domain/entities/customer_entity.dart';
import '../viewmodels/customer_view_model.dart';
import '../viewmodels/rejected_read_status_notifier.dart';
import '../widgets/customer_card.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';

/// Màn hình chuyên biệt hiển thị danh sách Điểm bán & Lượt viếng thăm bị từ chối duyệt.
/// Theo đúng yêu cầu: Mỗi điểm bán sẽ hiển thị kèm các lượt viếng thăm của nó ở ngay bên dưới,
/// không tách làm 2 màn.
class RejectedCustomersScreen extends ConsumerStatefulWidget {
  const RejectedCustomersScreen({super.key});

  @override
  ConsumerState<RejectedCustomersScreen> createState() =>
      _RejectedCustomersScreenState();
}

class _RejectedCustomersScreenState
    extends ConsumerState<RejectedCustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<VisitEntity> _allVisits = [];
  bool _isLoadingVisits = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadVisits();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markCurrentCustomersAsRead();
    });
  }

  void _markCurrentCustomersAsRead() {
    final customerState = ref.read(customerViewModelProvider);
    final rejected = customerState.allCustomers.where((c) => c.isRejectedApproval);
    ref.read(rejectedReadStatusProvider.notifier).markAllAsRead(rejected);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVisits() async {
    setState(() => _isLoadingVisits = true);
    try {
      final repo = ref.read(visitRepositoryProvider);
      final localVisits = await repo.getAllLocalVisits();
      List<VisitEntity> todayVisits = [];
      try {
        todayVisits = await repo.getVisitsByDate(DateTime.now());
      } catch (_) {}

      final mergedMap = <dynamic, VisitEntity>{};
      for (final v in localVisits) {
        final key = v.id > 0 ? v.id : (v.clientUuid ?? v.id);
        mergedMap[key] = v;
      }
      for (final v in todayVisits) {
        final key = v.id > 0 ? v.id : (v.clientUuid ?? v.id);
        mergedMap[key] = v;
      }

      final list = mergedMap.values.toList()
        ..sort((a, b) {
          final aTime = a.checkinAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.checkinAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });

      if (mounted) {
        setState(() {
          _allVisits = list;
          _isLoadingVisits = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingVisits = false);
      }
    }
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      ref.read(customerViewModelProvider.notifier).loadCustomers(isRefresh: true),
      _loadVisits(),
    ]);
    _markCurrentCustomersAsRead();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CustomerState>(customerViewModelProvider, (prev, next) {
      final rejected = next.allCustomers.where((c) => c.isRejectedApproval);
      ref.read(rejectedReadStatusProvider.notifier).markAllAsRead(rejected);
    });
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final customerState = ref.watch(customerViewModelProvider);

    // 1. Lọc các điểm bán bị từ chối từ CustomerState
    final rejectedCustomerMap = <dynamic, CustomerEntity>{};
    for (final c in customerState.allCustomers) {
      if (c.isRejectedApproval) {
        final key = c.id > 0 ? c.id : (c.clientUuid ?? c.id);
        rejectedCustomerMap[key] = c;
      }
    }

    // 2. Dự phòng: Nếu có lượt viếng thăm mang customer_approval_status == 'rejected'
    // nhưng điểm bán chưa nằm trong rejectedCustomerMap, tự tổng hợp placeholder
    for (final v in _allVisits) {
      if (v.customerApprovalStatus == 'rejected') {
        final key = v.customerId;
        if (!rejectedCustomerMap.containsKey(key)) {
          rejectedCustomerMap[key] = CustomerEntity(
            id: v.customerId,
            code: v.customerCode ?? 'KH${v.customerId}',
            name: v.customerName.isNotEmpty ? v.customerName : 'Điểm bán #${v.customerId}',
            address: v.customerAddress ?? 'Chưa cập nhật địa chỉ',
            type: 'Điểm bán',
            route: 'Tuyến viếng thăm',
            contactPerson: '',
            phone: '',
            approvalStatus: 'rejected',
            approvalLabel: 'Bị từ chối',
            approvalNote: 'Lượt viếng thăm tại điểm bán này đã bị từ chối phê duyệt.',
          );
        }
      }
    }

    var rejectedCustomers = rejectedCustomerMap.values.toList();

    // 3. Lọc theo thanh tìm kiếm
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      rejectedCustomers = rejectedCustomers.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.code.toLowerCase().contains(q) ||
            c.address.toLowerCase().contains(q) ||
            (c.phone.isNotEmpty && c.phone.contains(q)) ||
            (c.approvalNote != null && c.approvalNote!.toLowerCase().contains(q));
      }).toList();
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Điểm bán bị từ chối',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              '${rejectedCustomers.length} điểm bán kèm lượt viếng thăm',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới dữ liệu',
            onPressed: _handleRefresh,
          ),
        ],
      ),
      body: AppRefreshIndicator(
        onRefresh: _handleRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // Ô tìm kiếm
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                ),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên, mã, số ĐT, địa chỉ hoặc lý do...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Danh sách điểm bán + Lượt viếng thăm đi kèm
            if ((customerState.isLoading || _isLoadingVisits) && rejectedCustomers.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            else if (rejectedCustomers.isEmpty)
              _buildEmptyState(isDark)
            else
              ...rejectedCustomers.map((customer) {
                // Lấy tất cả lượt viếng thăm gắn liền với điểm bán này
                final visitsForCustomer = _allVisits.where((v) {
                  if (customer.id > 0 && v.customerId == customer.id) return true;
                  if (customer.code.isNotEmpty && v.customerCode == customer.code) return true;
                  if (customer.clientUuid != null &&
                      customer.clientUuid!.isNotEmpty &&
                      v.clientUuid == customer.clientUuid) {
                    return true;
                  }
                  return false;
                }).toList();

                return _CompoundRejectedDealerCard(
                  customer: customer,
                  visits: visitsForCustomer,
                  isDark: isDark,
                  onRefresh: _handleRefresh,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.task_alt_rounded,
                size: 38,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Không tìm thấy kết quả phù hợp'
                  : 'Không có điểm bán bị từ chối',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF181C1B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Vui lòng thử tìm kiếm với từ khoá khác.'
                  : 'Tuyệt vời! Hiện tại bạn không có điểm bán hoặc lượt viếng thăm nào bị từ chối phê duyệt.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : const Color(0xFF6F7A74),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ tổng hợp: Điểm bán bị từ chối kèm toàn bộ lượt viếng thăm đi kèm ở ngay bên dưới.
class _CompoundRejectedDealerCard extends StatelessWidget {
  final CustomerEntity customer;
  final List<VisitEntity> visits;
  final bool isDark;
  final VoidCallback onRefresh;

  const _CompoundRejectedDealerCard({
    required this.customer,
    required this.visits,
    required this.isDark,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDecisionTime = customer.approvalAt != null
        ? () {
            try {
              final parsed = DateTime.parse(customer.approvalAt!);
              return DateFormat('HH:mm - dd/MM/yyyy').format(parsed.toLocal());
            } catch (_) {
              return customer.approvalAt!;
            }
          }()
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x66DC2626) : const Color(0xFFFECACA),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── PHẦN 1: THÔNG TIN ĐIỂM BÁN ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hàng Header: Mã KH + Badge "Bị từ chối" + Nhãn Loại
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0x334B5563) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                        ),
                      ),
                      child: Text(
                        customer.code.isNotEmpty ? customer.code : 'KH#${customer.id}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Badge "Bị từ chối"
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0x33DC2626) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFEF4444), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cancel_outlined,
                            size: 12,
                            color: Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            customer.displayApprovalLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Chip loại điểm bán
                    if (customer.type.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: customer.accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          customer.type,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: customer.accentColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Tên điểm bán
                Text(
                  customer.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF181C1B),
                  ),
                ),
                const SizedBox(height: 6),

                // Tuyến đường
                if (customer.route.isNotEmpty)
                  Row(
                    children: [
                      const Icon(
                        Icons.alt_route_rounded,
                        size: 13,
                        color: Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        customer.route,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 4),

                // Địa chỉ
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        customer.address,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],
                ),

                // Số điện thoại / Người liên hệ
                if (customer.phone.isNotEmpty || customer.contactPerson.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${customer.contactPerson.isNotEmpty ? customer.contactPerson : 'Chưa có tên'} • ${customer.phone.isNotEmpty ? customer.phone : 'Chưa có SĐT'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),

                // HỘP LÝ DO TỪ CHỐI (Nổi bật, dễ nhận diện)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x33DC2626) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0x66DC2626) : const Color(0xFFFCA5A5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.report_gmailerrorred_rounded,
                            size: 16,
                            color: Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Lý do từ chối từ Quản trị viên:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customer.approvalNote?.isNotEmpty == true
                            ? customer.approvalNote!
                            : 'Chưa có ghi chú lý do chi tiết từ quản trị viên.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFFB91C1C),
                          height: 1.35,
                        ),
                      ),
                      if (formattedDecisionTime != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Quyết định lúc: $formattedDecisionTime',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: isDark ? Colors.white54 : const Color(0xFF7F1D1D),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Các nút hành động cho điểm bán
                Row(
                  children: [
                    // Nút Xem chi tiết hồ sơ
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white : const Color(0xFF181C1B),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          side: BorderSide(
                            color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text(
                          'Xem chi tiết điểm bán',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () => context.push('/customers/detail', extra: customer),
                      ),
                    ),

                    // Nút Gọi điện thoại
                    if (customer.phone.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      IconButton.outlined(
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.phone_rounded, size: 16, color: Color(0xFF006E15)),
                        tooltip: 'Gọi điện thoại',
                        onPressed: () => CustomerCard.defaultMakePhoneCall(context, customer.phone),
                      ),
                    ],

                    // Nút Chỉ đường
                    if (customer.lat != null && customer.lng != null) ...[
                      const SizedBox(width: 6),
                      IconButton.outlined(
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.directions_outlined, size: 16, color: Color(0xFF0284C7)),
                        tooltip: 'Chỉ đường',
                        onPressed: () => CustomerCard.defaultOpenDirections(
                          context,
                          lat: customer.lat,
                          lng: customer.lng,
                          address: customer.address,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // ── PHẦN 2: LƯỢT VIẾNG THĂM ĐI KÈM Ở DƯỚI (Không tách màn) ──
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF171C19) : const Color(0xFFF3F6F3),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                ),
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header của mục viếng thăm
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF006E15).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.directions_walk_rounded,
                        size: 15,
                        color: Color(0xFF006E15),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'LƯỢT VIẾNG THĂM ĐI KÈM (${visits.length})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: isDark ? Colors.white : const Color(0xFF181C1B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (visits.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history_toggle_off_rounded,
                          size: 16,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Chưa ghi nhận lượt viếng thăm nào cho điểm bán này.',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...visits.map((v) => _VisitItemRow(visit: v, isDark: isDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dòng hiển thị một lượt viếng thăm đi kèm của điểm bán bị từ chối
class _VisitItemRow extends StatelessWidget {
  final VisitEntity visit;
  final bool isDark;

  const _VisitItemRow({required this.visit, required this.isDark});

  @override
  Widget build(BuildContext context) {
    // Giờ check-in / check-out
    String timeRange = '--:--';
    if (visit.checkinAt != null) {
      final cin = DateFormat('HH:mm').format(visit.checkinAt!.toLocal());
      final cout = visit.checkoutAt != null
          ? DateFormat('HH:mm').format(visit.checkoutAt!.toLocal())
          : 'Đang mở';
      final dateStr = DateFormat('dd/MM/yyyy').format(visit.checkinAt!.toLocal());
      timeRange = '$cin - $cout • $dateStr';
    }

    // Thời lượng
    String durationStr = '--';
    if (visit.durationSeconds != null && visit.durationSeconds! > 0) {
      final m = (visit.durationSeconds! % 3600) ~/ 60;
      final h = visit.durationSeconds! ~/ 3600;
      durationStr = h > 0 ? '${h}h ${m}m' : '$m phút';
    } else if (visit.isOpen) {
      durationStr = 'Đang mở';
    }

    // Kết quả
    final isClosed = visit.visitResult == 'closed';
    final isOpen = visit.isOpen;

    Color statusColor = const Color(0xFF006E15);
    String statusText = 'Mở cửa';
    if (isClosed) {
      statusColor = const Color(0xFFD97706);
      statusText = 'Đóng cửa';
    } else if (isOpen) {
      statusColor = const Color(0xFF0284C7);
      statusText = 'Đang ghé';
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
        ),
      ),
      child: InkWell(
        onTap: () => showVisitDetailBottomSheet(context, visit),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    timeRange,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF181C1B),
                    ),
                  ),
                ),
                Text(
                  durationStr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: isDark ? Colors.white38 : Colors.black26,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  size: 13,
                  color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Text(
                  '${visit.photoCount} ảnh',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.assignment_outlined,
                  size: 13,
                  color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Text(
                  '${visit.formCount} biểu mẫu',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                  ),
                ),
                if (visit.isOnRoute) ...[
                  const SizedBox(width: 12),
                  const Text('• Trong tuyến',
                      style: TextStyle(fontSize: 11, color: Color(0xFF006E15), fontWeight: FontWeight.w600)),
                ] else ...[
                  const SizedBox(width: 12),
                  const Text('• Ngoài tuyến',
                      style: TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
