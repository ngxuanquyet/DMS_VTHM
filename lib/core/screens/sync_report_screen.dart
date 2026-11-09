import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../network/connectivity_provider.dart';
import '../sync/sync_entity_group.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/offline_sync_badge.dart';

/// Báo cáo gửi dữ liệu — nhân viên tự soát dữ liệu đã lên máy chủ hết chưa: hàng chờ hiện tại (chờ gửi / lỗi) + dữ
/// liệu đã gửi theo từng ngày (nhật ký trên máy, [AppDatabase.sentLogRetention]). Chỉ thấy những gì gửi từ MÁY NÀY.
class SyncReportScreen extends ConsumerStatefulWidget {
  const SyncReportScreen({super.key});

  @override
  ConsumerState<SyncReportScreen> createState() => _SyncReportScreenState();
}

class _SyncReportScreenState extends ConsumerState<SyncReportScreen> {
  /// Ngày đang xem của phần "Đã gửi" (0h giờ máy).
  DateTime _day = _startOfDay(DateTime.now());

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnline = ref.watch(connectivityProvider).isOnline;
    final pendingEntries = ref.watch(allPendingQueueEntriesProvider).value ?? const <SyncQueueEntry>[];
    final deadEntries = ref.watch(deadQueueEntriesProvider).value ?? const <SyncQueueEntry>[];
    final sentLogs = ref.watch(sentLogsProvider).value ?? const <SyncSentLog>[];

    final groupedPending = SyncEntityGroupHelper.groupEntries(pendingEntries);
    // Như huy hiệu: danh sách chưa tới (stream đến sau) thì lấy số đếm.
    final pendingCount =
        groupedPending.isNotEmpty ? groupedPending.length : (ref.watch(pendingSyncCountProvider).value ?? 0);
    final deadCount = deadEntries.length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Báo cáo gửi dữ liệu',
              style: AppTypography.titleMedium(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              'Đã gửi lên máy chủ · Hàng chờ trên máy',
              style: AppTypography.bodySmall(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ).copyWith(fontSize: 11),
            ),
          ],
        ),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _StatusCard(pendingCount: pendingCount, deadCount: deadCount, isOnline: isOnline, isDark: isDark),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SyncStatBox(
                  title: 'Đang chờ gửi',
                  count: '$pendingCount',
                  color: const Color(0xFF3B82F6),
                  bgColor: const Color(0xFFEFF6FF),
                  icon: Icons.hourglass_top_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SyncStatBox(
                  title: 'Lỗi đồng bộ',
                  count: '$deadCount',
                  color: deadCount > 0 ? const Color(0xFFE11D48) : const Color(0xFF10B981),
                  bgColor: deadCount > 0 ? const Color(0xFFFFE4E6) : const Color(0xFFECFDF5),
                  icon: deadCount > 0 ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                ),
              ),
            ],
          ),
          if (pendingCount > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: isOnline ? () => sendSyncQueueNow(context, ref) : null,
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
          ],

          // Hàng chờ hiện tại
          const SizedBox(height: 20),
          _SectionTitle(title: 'Hàng chờ hiện tại', trailing: '$pendingCount mục', isDark: isDark),
          const SizedBox(height: 8),
          if (groupedPending.isEmpty)
            _EmptyNote(text: 'Không còn dữ liệu nào chờ gửi trên máy.', isDark: isDark)
          else
            for (final g in groupedPending) buildGroupedSyncEntryTile(context, g, isDark),
          if (deadEntries.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mục cần kiểm tra lại:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFE11D48)),
                ),
                TextButton(
                  onPressed: () => clearAllDeadSyncEntries(context, ref, deadEntries),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                  child: const Text('Xoá tất cả', style: TextStyle(fontSize: 12, color: Color(0xFFE11D48))),
                ),
              ],
            ),
            for (final e in deadEntries) buildDeadSyncEntryTile(context, ref, e, isDark),
          ],

          // Đã gửi theo ngày
          const SizedBox(height: 20),
          ..._buildSentSection(context, sentLogs, isDark),
        ],
      ),
    );
  }

  List<Widget> _buildSentSection(BuildContext context, List<SyncSentLog> logs, bool isDark) {
    final today = _startOfDay(DateTime.now());
    final oldest = today.subtract(AppDatabase.sentLogRetention);
    final dayStart = _day.millisecondsSinceEpoch;
    final dayEnd = _day.add(const Duration(days: 1)).millisecondsSinceEpoch;
    final dayEntries = logs
        .where((l) => l.sentAt >= dayStart && l.sentAt < dayEnd)
        .map(_toQueueEntry)
        .toList();

    // Nhóm nghiệp vụ trong ngày, mới gửi xong trước; giờ gửi = mục cuối cùng của nhóm lên máy chủ.
    int lastSent(GroupedSyncItem g) =>
        g.entries.map((e) => e.nextAttemptAt ?? 0).fold(0, (a, b) => a > b ? a : b);
    final groups = [...SyncEntityGroupHelper.groupEntries(dayEntries)]
      ..sort((a, b) => lastSent(b).compareTo(lastSent(a)));

    final dayLabel = _day == today
        ? 'Hôm nay, ${DateFormat('dd/MM').format(_day)}'
        : _day == today.subtract(const Duration(days: 1))
            ? 'Hôm qua, ${DateFormat('dd/MM').format(_day)}'
            : DateFormat('dd/MM/yyyy').format(_day);

    return [
      _SectionTitle(title: 'Đã gửi lên máy chủ', trailing: '${groups.length} mục', isDark: isDark),
      const SizedBox(height: 8),
      Row(
        children: [
          IconButton(
            tooltip: 'Ngày trước',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _day.isAfter(oldest) ? () => setState(() => _day = _shiftDay(_day, -1)) : null,
          ),
          Expanded(
            child: Text(
              dayLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Ngày sau',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: _day.isBefore(today) ? () => setState(() => _day = _shiftDay(_day, 1)) : null,
          ),
        ],
      ),
      if (groups.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Đã gửi: ${SyncEntityGroupHelper.buildSummaryText(dayEntries)}',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF4B5563)),
          ),
        ),
      if (groups.isEmpty)
        _EmptyNote(text: 'Không có dữ liệu nào gửi lên trong ngày này.', isDark: isDark)
      else
        for (final g in groups)
          buildGroupedSyncEntryTile(
            context,
            g,
            isDark,
            statusLabel: DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(lastSent(g))),
          ),
      const SizedBox(height: 8),
      Text(
        'Nhật ký trên máy này, giữ ${AppDatabase.sentLogRetention.inDays} ngày gần nhất.',
        style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF6F7A74)),
      ),
    ];
  }

  /// Lùi/tiến theo NGÀY LỊCH (không cộng 24h — ngày đổi giờ không lệch sang 23h/1h).
  static DateTime _shiftDay(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

  /// Dòng nhật ký → dạng dòng hàng đợi `done` để gom nhóm bằng cùng [SyncEntityGroupHelper]; giờ gửi nằm ở
  /// `nextAttemptAt` như dòng done của hàng đợi.
  static SyncQueueEntry _toQueueEntry(SyncSentLog l) => SyncQueueEntry(
        // Dòng gửi trực tuyến không có dòng hàng đợi (queueId = 0) ⇒ lấy -id nhật ký cho khỏi trùng nhau.
        id: l.queueId > 0 ? l.queueId : -l.id,
        entity: l.entity,
        op: l.op,
        clientUuid: l.clientUuid,
        parentUuid: l.parentUuid,
        payload: l.payload,
        state: 'done',
        attempts: 0,
        nextAttemptAt: l.sentAt,
        createdAt: l.createdAt,
        createdElapsed: 0,
        bootId: '',
        serverId: l.serverId,
        ownerUserId: l.ownerUserId,
      );
}

/// Thẻ kết luận: đã gửi hết hay còn dữ liệu trên máy.
class _StatusCard extends StatelessWidget {
  final int pendingCount;
  final int deadCount;
  final bool isOnline;
  final bool isDark;

  const _StatusCard({
    required this.pendingCount,
    required this.deadCount,
    required this.isOnline,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final allSent = pendingCount == 0 && deadCount == 0;
    final Color color;
    final IconData icon;
    final String title;
    final String detail;
    if (allSent) {
      color = const Color(0xFF10B981);
      icon = Icons.cloud_done_rounded;
      title = 'Đã gửi hết dữ liệu';
      detail = 'Không còn dữ liệu nào nằm chờ trên máy.';
    } else if (deadCount > 0) {
      color = const Color(0xFFE11D48);
      icon = Icons.error_outline_rounded;
      title = 'Có $deadCount mục gửi lỗi';
      detail = 'Máy chủ từ chối các mục bên dưới — xem mã lỗi và báo quản trị nếu cần.';
    } else {
      color = isOnline ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B);
      icon = isOnline ? Icons.cloud_upload_outlined : Icons.cloud_off_rounded;
      title = 'Còn $pendingCount mục chưa gửi';
      detail = isOnline
          ? 'App đang tự gửi — có thể bấm "Gửi dữ liệu ngay".'
          : 'Máy đang mất mạng — dữ liệu được giữ an toàn, sẽ tự gửi khi có mạng.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF4B5563)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String trailing;
  final bool isDark;

  const _SectionTitle({required this.title, required this.trailing, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        Text(
          trailing,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white60 : const Color(0xFF6F7A74),
          ),
        ),
      ],
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;
  final bool isDark;

  const _EmptyNote({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
