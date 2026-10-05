import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/position_declaration_entity.dart';
import '../viewmodels/position_declaration_view_model.dart';

/// Màn hình Lịch sử khai báo vị trí
/// Hiển thị danh sách các lần khai báo trong quá khứ lưu trữ cục bộ (local storage),
/// hỗ trợ lọc theo trạng thái đồng bộ, xem chi tiết và phóng to ảnh đính kèm.
class PositionDeclarationHistoryScreen extends ConsumerStatefulWidget {
  const PositionDeclarationHistoryScreen({super.key});

  @override
  ConsumerState<PositionDeclarationHistoryScreen> createState() =>
      _PositionDeclarationHistoryScreenState();
}

class _PositionDeclarationHistoryScreenState
    extends ConsumerState<PositionDeclarationHistoryScreen> {
  String _selectedFilter = 'all'; // 'all' | 'synced' | 'pending' | 'error'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(positionDeclarationViewModelProvider.notifier).loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(positionDeclarationViewModelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final history = state.history;

    // Lọc theo trạng thái
    final filteredList = history.where((item) {
      if (_selectedFilter == 'synced') return item.isSynced;
      if (_selectedFilter == 'pending') return item.isPending;
      if (_selectedFilter == 'error') return item.hasError;
      return true;
    }).toList();

    // Thống kê nhanh
    final totalCount = history.length;
    final syncedCount = history.where((e) => e.isSynced).length;
    final pendingCount = history.where((e) => e.isPending).length;
    final errorCount = history.where((e) => e.hasError).length;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.surfaceVariant,
      appBar: AppBar(
        title: const Text(
          'Lịch sử khai báo vị trí',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        foregroundColor: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: () {
              ref
                  .read(positionDeclarationViewModelProvider.notifier)
                  .loadHistory();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_location_alt_rounded),
            tooltip: 'Khai báo mới',
            onPressed: () async {
              await context.push('/position-declaration');
              if (mounted) {
                ref
                    .read(positionDeclarationViewModelProvider.notifier)
                    .loadHistory();
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_new_position_declaration',
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text(
          'Khai báo mới',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        onPressed: () async {
          await context.push('/position-declaration');
          if (mounted) {
            ref
                .read(positionDeclarationViewModelProvider.notifier)
                .loadHistory();
          }
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref
              .read(positionDeclarationViewModelProvider.notifier)
              .loadHistory();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. Khối tổng quan số liệu
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildSummaryGrid(
                  isDark: isDark,
                  total: totalCount,
                  synced: syncedCount,
                  pending: pendingCount,
                  error: errorCount,
                ),
              ),
            ),

            // 2. Thanh lọc trạng thái
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildFilterChip('Tất cả ($totalCount)', 'all', isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('Đã đồng bộ ($syncedCount)', 'synced', isDark),
                    const SizedBox(width: 8),
                    _buildFilterChip('Chờ gửi ($pendingCount)', 'pending', isDark),
                    if (errorCount > 0) ...[
                      const SizedBox(width: 8),
                      _buildFilterChip('Lỗi ($errorCount)', 'error', isDark),
                    ],
                  ],
                ),
              ),
            ),

            // 3. Danh sách lượt khai báo
            if (filteredList.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(isDark, history.isEmpty),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = filteredList[index];
                      return _buildDeclarationCard(context, item, isDark);
                    },
                    childCount: filteredList.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryGrid({
    required bool isDark,
    required int total,
    required int synced,
    required int pending,
    required int error,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2420) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E7E2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: Color(0xFF0D9488),
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Tổng quan khai báo cục bộ',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: 'Tổng số lượt',
                  value: '$total',
                  color: const Color(0xFF0D9488),
                  bgColor: const Color(0xFFCCFBF1),
                  icon: Icons.list_alt_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryItem(
                  label: 'Đã đồng bộ',
                  value: '$synced',
                  color: const Color(0xFF10B981),
                  bgColor: const Color(0xFFD1FAE5),
                  icon: Icons.cloud_done_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryItem(
                  label: 'Chờ đồng bộ',
                  value: '$pending',
                  color: const Color(0xFFF59E0B),
                  bgColor: const Color(0xFFFEF3C7),
                  icon: Icons.cloud_queue_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF0D9488),
      backgroundColor: isDark ? const Color(0xFF262D28) : Colors.white,
      side: BorderSide(
        color: isSelected
            ? const Color(0xFF0D9488)
            : (isDark ? Colors.white12 : const Color(0xFFE2E7E2)),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = value);
        }
      },
    );
  }

  Widget _buildEmptyState(bool isDark, bool isCompletelyEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompletelyEmpty
                    ? Icons.location_off_rounded
                    : Icons.filter_alt_off_rounded,
                size: 54,
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isCompletelyEmpty
                  ? 'Chưa có lượt khai báo vị trí nào'
                  : 'Không tìm thấy lượt khai báo phù hợp',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isCompletelyEmpty
                  ? 'Các lần khai báo vị trí thực tế của bạn sẽ được lưu trữ an toàn trong máy và tự động đồng bộ khi có kết nối mạng.'
                  : 'Vui lòng chọn bộ lọc khác để xem các lượt khai báo vị trí.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (isCompletelyEmpty) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_location_alt_rounded),
                label: const Text(
                  'Khai báo vị trí ngay',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onPressed: () async {
                  await context.push('/position-declaration');
                  if (mounted) {
                    ref
                        .read(positionDeclarationViewModelProvider.notifier)
                        .loadHistory();
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeclarationCard(
    BuildContext context,
    PositionDeclarationEntity item,
    bool isDark,
  ) {
    // Phân tích màu sắc lý do
    Color reasonColor = const Color(0xFF0D9488);
    if (item.reasonColor != null && item.reasonColor!.isNotEmpty) {
      try {
        final hex = item.reasonColor!.replaceAll('#', '');
        reasonColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    // Thời gian khai báo
    String timeStr = item.clientTime;
    try {
      if (item.createdAtMs > 0) {
        final dt = DateTime.fromMillisecondsSinceEpoch(item.createdAtMs);
        timeStr = DateFormat('HH:mm - dd/MM/yyyy').format(dt);
      } else if (item.clientTime.isNotEmpty) {
        final dt = DateTime.parse(item.clientTime).toLocal();
        timeStr = DateFormat('HH:mm - dd/MM/yyyy').format(dt);
      }
    } catch (_) {}

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
          onTap: () => _showDetailBottomSheet(context, item, isDark),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hàng 1: Lý do & Trạng thái đồng bộ
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: reasonColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.category_rounded,
                              size: 14, color: reasonColor),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(
                              item.reasonDisplay,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: reasonColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _buildSyncStatusBadge(item),
                  ],
                ),
                const SizedBox(height: 10),

                // Hàng 2: Tiêu đề hoặc ghi chú (nếu có)
                if (item.title != null && item.title!.isNotEmpty) ...[
                  Text(
                    item.title!,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],

                if (item.note != null && item.note!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Text(
                      item.note!,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Hàng 3: Địa chỉ & Toạ độ
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: Color(0xFF0D9488),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        (item.address != null && item.address!.isNotEmpty)
                            ? item.address!
                            : 'Toạ độ: ${item.lat.toStringAsFixed(6)}, ${item.lng.toStringAsFixed(6)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : const Color(0xFF374151),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Hàng 4: Thời gian, Sai số GPS & Gian lận
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    if (item.accuracyM != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.gps_fixed_rounded,
                            size: 13,
                            color: item.accuracyM! <= 20
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Sai số ±${item.accuracyM!.toStringAsFixed(0)}m',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: item.accuracyM! <= 20
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    if (item.isMockLocation)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Cảnh báo GPS ảo',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                  ],
                ),

                // Hàng 5: Ảnh đính kèm (nếu có)
                if (item.localPhotoPaths.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 56,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: item.localPhotoPaths.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, photoIdx) {
                        final path = item.localPhotoPaths[photoIdx];
                        return _buildPhotoThumbnail(context, path, isDark);
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

  Widget _buildSyncStatusBadge(PositionDeclarationEntity item) {
    if (item.isSynced) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 13, color: Color(0xFF10B981)),
            const SizedBox(width: 4),
            Text(
              item.id != null ? 'Đã đồng bộ (#${item.id})' : 'Đã đồng bộ',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF10B981),
              ),
            ),
          ],
        ),
      );
    }

    if (item.hasError) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 13, color: Color(0xFFEF4444)),
            SizedBox(width: 4),
            Text(
              'Lỗi đồng bộ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_queue_rounded,
              size: 13, color: Color(0xFFF59E0B)),
          SizedBox(width: 4),
          Text(
            'Chờ đồng bộ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail(
      BuildContext context, String path, bool isDark) {
    final file = File(path);
    final exists = file.existsSync();

    return GestureDetector(
      onTap: () {
        if (exists) {
          _showFullScreenImage(context, file);
        }
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
          border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFD1D5DB),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: exists
            ? Image.file(file, fit: BoxFit.cover)
            : const Center(
                child: Icon(Icons.image_not_supported_rounded,
                    size: 20, color: Colors.grey),
              ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, File file) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(file, fit: BoxFit.contain),
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
                onPressed: () => Navigator.of(dialogCtx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailBottomSheet(
    BuildContext context,
    PositionDeclarationEntity item,
    bool isDark,
  ) {
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
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFF0D9488), size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Chi tiết lượt khai báo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(sheetCtx).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              _buildDetailRow('Lý do khai báo', item.reasonDisplay),
              if (item.title != null && item.title!.isNotEmpty)
                _buildDetailRow('Tiêu đề', item.title!),
              if (item.note != null && item.note!.isNotEmpty)
                _buildDetailRow('Ghi chú', item.note!),
              _buildDetailRow(
                  'Toạ độ GPS', '${item.lat.toStringAsFixed(6)}, ${item.lng.toStringAsFixed(6)}'),
              if (item.accuracyM != null)
                _buildDetailRow(
                    'Độ chính xác GPS', '±${item.accuracyM!.toStringAsFixed(1)} mét'),
              if (item.address != null && item.address!.isNotEmpty)
                _buildDetailRow('Địa chỉ', item.address!),
              _buildDetailRow('Thời điểm bấm', item.clientTime),
              if (item.declaredAt != null)
                _buildDetailRow('Server ghi nhận', item.declaredAt!),
              _buildDetailRow('Trạng thái đồng bộ', item.syncStatus.toUpperCase()),
              if (item.syncError != null)
                _buildDetailRow('Chi tiết lỗi', item.syncError!, isError: true),
              _buildDetailRow('Mã chống trùng (UUID)', item.clientUuid),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isError ? const Color(0xFFEF4444) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  final IconData icon;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.12) : bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : const Color(0xFF4B5563),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
