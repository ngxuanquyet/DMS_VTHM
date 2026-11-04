import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/dynamic_form/widgets/display_matrix_field_widget.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Một lần đo SOS của hồ sơ điểm bán (`GET /crm/customers/{id}/sos-history`, #24789).
class CustomerSosHistoryItem {
  final int id;
  final DateTime? measuredAt;
  final String source;
  final int? submissionId;
  final bool applied;
  final bool unchanged;
  final double? facesTotal;
  final double? sosOwnPct;
  final String? userName;
  final dynamic value;

  const CustomerSosHistoryItem({
    required this.id,
    this.measuredAt,
    required this.source,
    this.submissionId,
    this.applied = true,
    this.unchanged = false,
    this.facesTotal,
    this.sosOwnPct,
    this.userName,
    this.value,
  });

  factory CustomerSosHistoryItem.fromJson(Map json) {
    double? d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v');
    return CustomerSosHistoryItem(
      id: json['id'] is num ? (json['id'] as num).toInt() : 0,
      measuredAt: DateTime.tryParse('${json['measured_at'] ?? ''}')?.toLocal(),
      source: '${json['source'] ?? ''}',
      submissionId: json['submission_id'] is num ? (json['submission_id'] as num).toInt() : null,
      applied: json['applied'] != false,
      unchanged: json['unchanged'] == true,
      facesTotal: json['faces_total'] == null ? null : d(json['faces_total']),
      sosOwnPct: json['sos_own_pct'] == null ? null : d(json['sos_own_pct']),
      userName: json['user_name']?.toString(),
      value: json['value'],
    );
  }
}

/// Mục "Lịch sử SOS" ở chi tiết điểm bán (#24789): vài lần đo ô Ma trận trưng bày gần nhất (phiếu khảo sát / sửa hồ sơ) để
/// nhân viên xem trước khi đếm lại; chạm một dòng ⇒ tóm tắt số mặt + % SOS từng thương hiệu. Cần mạng (không lưu trên máy);
/// không có quyền / lỗi ⇒ ẩn hẳn mục.
class CustomerSosHistoryCard extends ConsumerStatefulWidget {
  final int customerId;

  /// Bọc nội dung vào khung mục của màn cha; không gọi khi bị ẩn.
  final Widget Function(Widget content) sectionBuilder;

  /// Số dòng gần nhất.
  final int limit;

  const CustomerSosHistoryCard({super.key, required this.customerId, required this.sectionBuilder, this.limit = 5});

  @override
  ConsumerState<CustomerSosHistoryCard> createState() => _CustomerSosHistoryCardState();
}

class _CustomerSosHistoryCardState extends ConsumerState<CustomerSosHistoryCard> {
  List<CustomerSosHistoryItem>? _items;
  bool _hidden = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(apiClientProvider)
          .get('/crm/customers/${widget.customerId}/sos-history', queryParameters: {'per-page': widget.limit});
      final data = res is Map && res['data'] is List ? res['data'] as List : const [];
      if (!mounted) return;
      setState(() {
        _items = [for (final r in data) if (r is Map) CustomerSosHistoryItem.fromJson(r)];
        _loading = false;
        _hidden = false; // mở lúc mất mạng (ẩn) rồi có mạng lại ⇒ hiện
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hidden = _items == null;
      });
    }
  }

  String _date(DateTime? t) {
    if (t == null) return '—';
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(t.day)}/${p(t.month)}/${t.year} ${p(t.hour)}:${p(t.minute)}';
  }

  void _showDetail(CustomerSosHistoryItem it) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_date(it.measuredAt), style: AppTypography.titleMedium()),
            const SizedBox(height: 8),
            Text(displayMatrixSummary(it.value) ?? 'Hồ sơ không còn số nào sau lần đo này.'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(connectivityProvider.select((s) => s.isOnline), (prev, next) {
      if (prev == false && next) _load();
    });
    if (_hidden) return const SizedBox.shrink();
    final items = _items;
    if (items != null && items.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;

    final Widget content = _loading && items == null
        ? const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        : Column(
            children: [
              for (final it in items ?? const <CustomerSosHistoryItem>[])
                ListTile(
                  key: ValueKey('sos_history_${it.id}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onTap: () => _showDetail(it),
                  title: Text(
                    '${_date(it.measuredAt)} · ${it.source == 'survey' ? 'Phiếu khảo sát' : 'Sửa hồ sơ'}'
                    '${it.unchanged ? ' · không đổi' : ''}${it.applied ? '' : ' · đến muộn, không áp'}',
                    style: AppTypography.bodyMedium(),
                  ),
                  subtitle: Text(
                    '${fmtMatrixNumber(it.facesTotal ?? 0)} mặt'
                    '${it.sosOwnPct == null ? '' : ' · SOS của ta ${fmtMatrixPct(it.sosOwnPct!)}%'}'
                    '${it.userName == null ? '' : ' · ${it.userName}'}',
                    style: AppTypography.labelSmall(color: muted),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
            ],
          );

    return widget.sectionBuilder(content);
  }
}
