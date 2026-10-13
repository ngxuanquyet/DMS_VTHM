import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../network/connectivity_provider.dart';
import '../sync/sync_entity_group.dart';
import '../sync/sync_service.dart';
import '../theme/app_colors.dart';
import '../utils/string_utils.dart';
import '../../features/customer/presentation/viewmodels/customer_view_model.dart';

/// Huy hiệu hiển thị trạng thái dữ liệu ngoại tuyến và số lượng bản ghi đang chờ đồng bộ
class OfflineSyncBadge extends ConsumerWidget {
  final bool showLabel;

  const OfflineSyncBadge({super.key, this.showLabel = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCountAsync = ref.watch(pendingSyncCountProvider);
    final pendingEntriesAsync = ref.watch(allPendingQueueEntriesProvider);
    final deadCountAsync = ref.watch(deadSyncCountProvider);
    final isOnline = ref.watch(connectivityProvider).isOnline;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pendingEntries = pendingEntriesAsync.value ?? [];
    final groupedPending = SyncEntityGroupHelper.groupEntries(pendingEntries);
    final displayPendingCount = groupedPending.isNotEmpty
        ? groupedPending.length
        : (pendingCountAsync.value ?? 0);
    final deadCount = deadCountAsync.value ?? 0;

    // Nếu online và không có bản ghi nào chờ -> ẩn hoặc hiện trạng thái xanh nhẹ
    if (isOnline && displayPendingCount == 0 && deadCount == 0) {
      if (!showLabel) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_done_rounded, size: 14, color: Color(0xFF10B981)),
            SizedBox(width: 4),
            Text(
              'Đã đồng bộ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF10B981),
              ),
            ),
          ],
        ),
      );
    }

    final hasError = deadCount > 0;
    final badgeColor = hasError
        ? const Color(0xFFE11D48)
        : (!isOnline ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6));

    final badgeBgColor = hasError
        ? const Color(0xFFFFE4E6)
        : (!isOnline ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF));

    final badgeIcon = hasError
        ? Icons.error_outline_rounded
        : (!isOnline ? Icons.cloud_off_rounded : Icons.cloud_upload_outlined);

    final badgeText = hasError
        ? '$deadCount lỗi'
        : (!isOnline
            ? (displayPendingCount > 0 ? '$displayPendingCount chờ' : 'Ngoại tuyến')
            : '$displayPendingCount chờ');

    return InkWell(
      onTap: () => showOfflineSyncModal(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? badgeColor.withValues(alpha: 0.2) : badgeBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: badgeColor.withValues(alpha: isDark ? 0.4 : 0.6),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(badgeIcon, size: 15, color: badgeColor),
            const SizedBox(width: 5),
            Text(
              badgeText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: badgeColor,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mở Modal chi tiết hàng đợi ngoại tuyến
void showOfflineSyncModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const _OfflineSyncDetailSheet(),
  );
}

class _OfflineSyncDetailSheet extends ConsumerWidget {
  const _OfflineSyncDetailSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCount = ref.watch(pendingSyncCountProvider).value ?? 0;
    final deadCount = ref.watch(deadSyncCountProvider).value ?? 0;
    final pendingEntries = ref.watch(allPendingQueueEntriesProvider).value ?? [];
    final deadEntries = ref.watch(deadQueueEntriesProvider).value ?? [];
    final isOnline = ref.watch(connectivityProvider).isOnline;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final groupedPending = SyncEntityGroupHelper.groupEntries(pendingEntries);
    final displayPendingCount = groupedPending.isNotEmpty ? groupedPending.length : pendingCount;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2420) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thanh kéo modal
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Tiêu đề & Trạng thái mạng
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isOnline
                          ? const Color(0xFF10B981).withValues(alpha: 0.12)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                      color: isOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dữ liệu ngoại tuyến',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isOnline
                              ? 'Thiết bị đang có kết nối Internet'
                              : 'Đang ngắt mạng - dữ liệu được lưu an toàn trên máy',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : const Color(0xFF6F7A74),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Thẻ tóm tắt số lượng
              Row(
                children: [
                  Expanded(
                    child: _SyncStatBox(
                      title: 'Đang chờ gửi',
                      count: '$displayPendingCount',
                      color: const Color(0xFF3B82F6),
                      bgColor: const Color(0xFFEFF6FF),
                      icon: Icons.hourglass_top_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SyncStatBox(
                      title: 'Lỗi đồng bộ',
                      count: '$deadCount',
                      color: deadCount > 0 ? const Color(0xFFE11D48) : const Color(0xFF10B981),
                      bgColor: deadCount > 0 ? const Color(0xFFFFE4E6) : const Color(0xFFECFDF5),
                      icon: deadCount > 0 ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Danh sách chi tiết các mục đang chờ
              if (groupedPending.isNotEmpty || displayPendingCount > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Danh sách dữ liệu chờ gửi:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${groupedPending.isNotEmpty ? groupedPending.length : displayPendingCount} mục',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : const Color(0xFF6F7A74),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: groupedPending.isNotEmpty
                      ? ListView.builder(
                          shrinkWrap: true,
                          itemCount: groupedPending.length,
                          itemBuilder: (ctx, idx) => _buildGroupedEntryTile(ctx, groupedPending[idx], isDark),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.cloud_upload_outlined, color: Color(0xFF3B82F6), size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '$displayPendingCount mục đang chờ gửi lên hệ thống...',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ] else if (deadEntries.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 40, color: Color(0xFF10B981)),
                      const SizedBox(height: 8),
                      Text(
                        'Toàn bộ dữ liệu đã được cập nhật thành công!',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF181C1B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Danh sách mục lỗi nếu có
              if (deadEntries.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Mục cần kiểm tra lại:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFE11D48)),
                    ),
                    TextButton(
                      onPressed: () async {
                        final db = ref.read(appDatabaseProvider);
                        for (final e in deadEntries) {
                          if (e.entity == 'customer') {
                            await ref.read(customerViewModelProvider.notifier).deletePendingCustomer(e.clientUuid);
                          }
                        }
                        await db.clearDeadEntries();
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Xoá tất cả', style: TextStyle(fontSize: 12, color: Color(0xFFE11D48))),
                    ),
                  ],
                ),
                Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: deadEntries.length,
                    itemBuilder: (ctx, idx) => _buildDeadQueueEntryTile(ctx, ref, deadEntries[idx], isDark),
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Nút bấm gửi dữ liệu ngay
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: isOnline
                      ? () async {
                          Navigator.of(context).pop();
                          try {
                            await ref.read(syncServiceProvider).syncQueue(force: true);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đang tiến hành gửi dữ liệu lên hệ thống...'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Chưa thể gửi dữ liệu: ${StringUtils.formatUserFriendlyError(e)}'),
                                  backgroundColor: AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006E15),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.sync_rounded, size: 20),
                  label: Text(
                    isOnline ? 'Gửi dữ liệu ngay' : 'Không có kết nối mạng',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncStatBox extends StatelessWidget {
  final String title;
  final String count;
  final Color color;
  final Color bgColor;
  final IconData icon;

  const _SyncStatBox({
    required this.title,
    required this.count,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.14) : bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.3 : 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : const Color(0xFF6F7A74),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildGroupedEntryTile(BuildContext context, GroupedSyncItem item, bool isDark) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: isDark ? item.color.withValues(alpha: 0.1) : item.bgColor.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: item.color.withValues(alpha: isDark ? 0.3 : 0.4)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? item.color.withValues(alpha: 0.2) : Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(item.icon, color: item.color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : const Color(0xFF6F7A74),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: item.isSending
                ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                : item.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            item.isSending ? 'Đang gửi' : 'Chờ gửi',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: item.isSending ? const Color(0xFF3B82F6) : item.color,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildDeadQueueEntryTile(BuildContext context, WidgetRef ref, SyncQueueEntry entry, bool isDark) {
  final lastError = StringUtils.formatUserFriendlyError(entry.lastError);
  String title = 'Dữ liệu cần kiểm tra lại';
  if (entry.entity == 'customer') {
    title = 'Thông tin khách hàng mới';
  } else if (entry.entity == 'form_submission') {
    title = 'Phiếu khảo sát thị trường';
  } else if (entry.entity == 'declaration') {
    title = 'Khai báo vị trí';
  } else if (entry.entity == 'attendance_punch') {
    title = 'Lượt chấm công';
  } else if (entry.entity == 'attendance_photo') {
    title = 'Ảnh chấm công';
  } else if (entry.entity == 'visit') {
    title = 'Lượt ghé thăm điểm bán';
  } else if (entry.entity == 'photo' || entry.entity == 'visit_photo') {
    title = 'Ảnh thực địa điểm bán';
  }

  return Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFFE11D48).withValues(alpha: 0.12) : const Color(0xFFFFE4E6),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE11D48),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                lastError,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white60 : const Color(0xFF6F7A74),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFE11D48)),
          tooltip: 'Xóa mục này',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          visualDensity: VisualDensity.compact,
          onPressed: () async {
            if (entry.entity == 'customer') {
              await ref.read(customerViewModelProvider.notifier).deletePendingCustomer(entry.clientUuid);
            }
            await (ref.read(appDatabaseProvider).delete(ref.read(appDatabaseProvider).syncQueueEntries)
                  ..where((tbl) => tbl.id.equals(entry.id)))
                .go();
          },
        ),
      ],
    ),
  );
}
