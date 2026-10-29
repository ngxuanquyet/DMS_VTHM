import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/dynamic_form/dynamic_form_builder.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/services/erp_catalog_service.dart';
import '../../../../core/services/erp_link_request_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_snackbar.dart';
import 'erp_link_picker_sheet.dart';

/// Giá trị của ô "Khách hàng ERP" (`erp_links`, #24331) trong form điểm bán — lưu trong dữ liệu form dưới dạng map JSON.
///
/// - [customerId] > 0: form SỬA / màn chi tiết của điểm bán đã có (đọc mối nối hiện có từ server).
/// - [add]: khách thêm mới (tạo + sửa) · [changeRole]: mã ⇒ vai mới của mối nối đang có · [remove]: mã xin gỡ (chỉ sửa).
/// - [unknown]: "Chưa xác định NPP" (chỉ tạo).
class ErpLinksValue {
  final int? customerId;
  final List<ErpLinkPick> add;
  final Map<String, String> changeRole;
  final Set<String> remove;
  final bool unknown;

  const ErpLinksValue({
    this.customerId,
    this.add = const [],
    this.changeRole = const {},
    this.remove = const {},
    this.unknown = false,
  });

  /// Đọc từ giá trị form (map JSON, hoặc `null`).
  factory ErpLinksValue.fromJson(dynamic raw) {
    if (raw is! Map) return const ErpLinksValue();
    final m = Map<String, dynamic>.from(raw);
    return ErpLinksValue(
      customerId: (m['customer_id'] as num?)?.toInt(),
      add: m['add'] is List
          ? (m['add'] as List).whereType<Map>().map((e) {
              final x = Map<String, dynamic>.from(e);
              return ErpLinkPick(
                code: x['code']?.toString() ?? '',
                name: x['name']?.toString() ?? '',
                address: x['address']?.toString(),
                channelId: (x['channel_id'] as num?)?.toInt(),
                channelName: x['channel_name']?.toString(),
                role: x['role']?.toString() ?? ErpLinkRole.c2,
                matchReason: x['match_reason']?.toString() ?? 'manual',
              );
            }).where((p) => p.code.isNotEmpty).toList()
          : const [],
      changeRole: m['change_role'] is Map
          ? Map<String, dynamic>.from(m['change_role'] as Map).map((k, v) => MapEntry(k, v.toString()))
          : const {},
      remove: m['remove'] is List ? (m['remove'] as List).map((e) => e.toString()).toSet() : const {},
      unknown: m['unknown'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        if (customerId != null) 'customer_id': customerId,
        'add': add
            .map((p) => {
                  'code': p.code,
                  'name': p.name,
                  'address': p.address,
                  'channel_id': p.channelId,
                  'channel_name': p.channelName,
                  'role': p.role,
                  'match_reason': p.matchReason,
                })
            .toList(),
        'change_role': changeRole,
        'remove': remove.toList(),
        'unknown': unknown,
      };

  ErpLinksValue copyWith({List<ErpLinkPick>? add, Map<String, String>? changeRole, Set<String>? remove, bool? unknown}) =>
      ErpLinksValue(
        customerId: customerId,
        add: add ?? this.add,
        changeRole: changeRole ?? this.changeRole,
        remove: remove ?? this.remove,
        unknown: unknown ?? this.unknown,
      );

  /// Bắt buộc khi TẠO: ≥1 khách hoặc tick "Chưa xác định NPP".
  bool get satisfiesRequired => add.isNotEmpty || unknown;

  /// Có thay đổi cần gửi (sửa / màn chi tiết).
  bool get hasChanges => add.isNotEmpty || changeRole.isNotEmpty || remove.isNotEmpty;

  /// `erp_links` gửi kèm khi TẠO điểm bán.
  List<Map<String, dynamic>> createLinks() => add.map((p) => p.toPayload()).toList();

  /// `erp_link_changes` gửi kèm khi SỬA — mỗi mục một đề xuất.
  List<Map<String, dynamic>> editChanges() => [
        for (final p in add) {'action': ErpLinkAction.add, ...p.toPayload()},
        for (final e in changeRole.entries) {'code': e.key, 'action': ErpLinkAction.changeRole, 'role': e.value},
        for (final c in remove) {'code': c, 'action': ErpLinkAction.remove},
      ];
}

/// Ô "Khách hàng ERP" (#24331, spec DIEM-BAN-KHACH-ERP §12) — form tạo = form sửa = màn chi tiết.
///
/// Tạo: danh sách khách thêm mới + nút "+ Thêm khách hàng" (khung chọn: gợi ý theo tên/SĐT/địa chỉ đang nhập + tìm trên danh mục
/// lưu máy) + ô tick "Chưa xác định NPP". Sửa / chi tiết: thêm mối nối hiện có (Đã duyệt), đề xuất chờ duyệt, đề xuất bị từ chối
/// kèm lý do; mối nối đã duyệt có "Đổi vai" / "Gỡ nối". Mọi thay đổi là ĐỀ XUẤT chờ quản lý duyệt — NV không huỷ được đề xuất.
class ErpLinksFormField extends ConsumerStatefulWidget {
  final String label;
  final bool isRequired;
  final ErpLinksValue value;
  final String? errorText;
  final ValueChanged<ErpLinksValue> onChanged;

  const ErpLinksFormField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.isRequired = false,
    this.errorText,
  });

  @override
  ConsumerState<ErpLinksFormField> createState() => _ErpLinksFormFieldState();
}

class _ErpLinksFormFieldState extends ConsumerState<ErpLinksFormField> {
  Future<ErpLinkStateOfStore>? _tai;

  int? get _id => (widget.value.customerId ?? 0) > 0 ? widget.value.customerId : null;

  @override
  void initState() {
    super.initState();
    _napLai();
  }

  void _napLai() {
    final id = _id;
    _tai = id == null || !ref.read(connectivityProvider).isOnline
        ? null
        : ref.read(erpLinkRequestServiceProvider).stateOf(id).timeout(const Duration(seconds: 8));
  }

  void _doi(ErpLinksValue v) => widget.onChanged(v);

  /// Mở khung chọn để thêm khách — gợi ý theo dữ liệu đang nhập trên CÙNG form (tên, SĐT, địa chỉ).
  Future<void> _them(ErpLinkStateOfStore? state) async {
    final online = ref.read(connectivityProvider).isOnline;
    final form = context.findAncestorStateOfType<DynamicFormBuilderState>()?.getFormData() ?? const {};
    final taiDanhMuc = ref.read(erpCatalogServiceProvider).load(online: online);
    final hoiGoiY = !online
        ? Future.value(const <ErpLinkSuggestion>[])
        : ref
            .read(erpLinkRequestServiceProvider)
            .suggest(
              name: form['name']?.toString(),
              phone: form['phone']?.toString(),
              taxCode: (form['tax_code'] ?? form['ma_so_thue'])?.toString(),
              address: form['address']?.toString(),
            )
            .timeout(const Duration(seconds: 10))
            .catchError((_) => const <ErpLinkSuggestion>[]);
    final catalog = await taiDanhMuc;
    var goiY = await hoiGoiY;
    if (goiY.isEmpty && catalog != null) {
      goiY = catalog
          .suggestByName(form['name']?.toString())
          .map((i) => ErpLinkSuggestion(
                code: i.code,
                name: i.name,
                address: i.address,
                channelId: i.channelId,
                channelName: i.channelName,
                matchReason: 'name_address',
              ))
          .toList();
    }
    if (!mounted) return;
    final v = widget.value;
    final chinhKhachCu = (state?.ownerTaken ?? false) ||
        v.changeRole.values.contains(ErpLinkRole.owner);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kq = await showModalBottomSheet<ErpLinkPickResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => ErpLinkPickerSheet(
        catalog: catalog,
        suggestions: goiY,
        initial: v.add,
        ownerTaken: chinhKhachCu,
        excludeCodes: state?.codes ?? const {},
      ),
    );
    if (kq == null || !mounted) return;
    _doi(v.copyWith(add: kq.picks, unknown: kq.picks.isEmpty ? v.unknown : false));
  }

  /// Đổi vai / gỡ một mối nối đã duyệt — ghi vào thay đổi chờ gửi.
  Future<void> _sua(ErpLinkState link, ErpCatalog? catalog, bool chinhKhachKhac) async {
    final v = widget.value;
    final dangDoi = v.changeRole[link.code];
    final duoc = catalog?.rolesFor(link.channelId) ?? ErpLinkRole.all;
    final chon = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('${link.name ?? link.code} (${link.code})', style: AppTypography.titleMedium()),
            ),
            for (final r in ErpLinkRole.all)
              if (r != link.role)
                ListTile(
                  key: Key('erp-link-change-${link.code}-$r'),
                  leading: const Icon(Icons.swap_horiz_rounded),
                  title: Text('Đổi vai thành ${ErpLinkRole.label(r)}'),
                  enabled: duoc.contains(r) && !(r == ErpLinkRole.owner && chinhKhachKhac),
                  subtitle: duoc.contains(r) ? null : const Text('Kênh của khách hàng không được nối vai này'),
                  onTap: () => Navigator.pop(ctx, r),
                ),
            ListTile(
              key: Key('erp-link-remove-existing-${link.code}'),
              leading: const Icon(Icons.link_off_rounded, color: AppColors.error),
              title: const Text('Xin gỡ mối nối', style: TextStyle(color: AppColors.error)),
              onTap: () => Navigator.pop(ctx, '__remove'),
            ),
            if (dangDoi != null || v.remove.contains(link.code))
              ListTile(
                leading: const Icon(Icons.undo_rounded),
                title: const Text('Giữ nguyên (bỏ thay đổi)'),
                onTap: () => Navigator.pop(ctx, '__keep'),
              ),
          ],
        ),
      ),
    );
    if (chon == null) return;
    final doi = Map<String, String>.from(v.changeRole)..remove(link.code);
    final go = Set<String>.from(v.remove)..remove(link.code);
    if (chon == '__remove') {
      go.add(link.code);
    } else if (chon != '__keep') {
      doi[link.code] = chon;
    }
    _doi(v.copyWith(changeRole: doi, remove: go));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chuChinh = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
    final chuPhu = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    final v = widget.value;

    Widget than(ErpLinkStateOfStore? state, {String? loiTai, bool dangTai = false}) {
      final catalog = ErpCatalogService.memory;
      final chinhKhachTheoLink = (state?.links ?? const <ErpLinkState>[])
          .where((l) => !v.remove.contains(l.code) && (v.changeRole[l.code] ?? l.role) == ErpLinkRole.owner)
          .map((l) => l.code)
          .toSet();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (dangTai) _Ghi(text: 'Đang tải khách hàng của điểm bán…', color: chuPhu),
          if (loiTai != null) _Ghi(text: loiTai, color: chuPhu),
          for (final l in state?.links ?? const <ErpLinkState>[])
            _TheTrangThai(
              key: Key('erp-link-existing-${l.code}'),
              ten: l.name ?? l.code,
              ma: l.code,
              kenh: l.channelName,
              vai: l.roleLabel,
              nhan: (state?.pending.any((p) => p.code == l.code) ?? false)
                  ? 'Đã duyệt · đang có đề xuất chờ duyệt'
                  : v.remove.contains(l.code)
                  ? 'Sẽ xin gỡ nối'
                  : v.changeRole.containsKey(l.code)
                      ? 'Sẽ đổi vai: ${l.roleLabel} → ${ErpLinkRole.label(v.changeRole[l.code]!)}'
                      : 'Đã duyệt',
              mau: v.remove.contains(l.code)
                  ? AppColors.error
                  : v.changeRole.containsKey(l.code)
                      ? AppColors.secondary
                      : AppColors.success,
              // Đang có đề xuất chờ cho khách này ⇒ khoá sửa tới khi quản lý quyết (một cặp chỉ một đề xuất chờ).
              onSua: (state?.pending.any((p) => p.code == l.code) ?? false) ? null : () => _sua(l, catalog, chinhKhachTheoLink.any((c) => c != l.code) || (state?.pending.any((p) => p.action != ErpLinkAction.remove && p.role == ErpLinkRole.owner) ?? false) || v.add.any((p) => p.role == ErpLinkRole.owner)),
            ),
          for (final p in state?.pending ?? const <ErpLinkState>[])
            _TheTrangThai(
              ten: p.name ?? p.code,
              ma: p.code,
              kenh: p.channelName,
              vai: p.roleLabel,
              nhan: switch (p.action) {
                ErpLinkAction.changeRole => 'Chờ duyệt · đổi vai ${p.beforeRoleLabel ?? ''} → ${p.roleLabel}',
                ErpLinkAction.remove => 'Chờ duyệt · gỡ nối',
                _ => 'Chờ duyệt · thêm khách hàng',
              },
              mau: AppColors.warning,
            ),
          for (final r in state?.rejected ?? const <ErpLinkState>[])
            _TheTrangThai(
              ten: r.name ?? r.code,
              ma: r.code,
              kenh: r.channelName,
              vai: r.roleLabel,
              nhan: 'Đã từ chối · ${r.actionLabel ?? ''}${r.decisionNote != null && r.decisionNote!.isNotEmpty ? ' — ${r.decisionNote}' : ''}',
              mau: AppColors.error,
            ),
          for (final p in v.add)
            _TheTrangThai(
              key: Key('erp-link-new-${p.code}'),
              ten: p.name.isEmpty ? p.code : p.name,
              ma: p.code,
              kenh: p.channelName,
              vai: ErpLinkRole.label(p.role),
              // Form TẠO: không gắn nhãn (chủ hệ thống bỏ chữ "Sẽ đề xuất khi lưu" 28/10/2026); form sửa vẫn báo sẽ đề xuất thêm.
              nhan: _id == null ? null : 'Sẽ đề xuất thêm',
              // Thay đổi CHƯA gửi: màu phụ (xanh dương), tách khỏi "Đã duyệt" (xanh lá).
              mau: AppColors.secondary,
              onBo: () => _doi(v.copyWith(add: v.add.where((x) => x.code != p.code).toList())),
            ),
          if (_id != null && state != null && state.links.isEmpty && state.pending.isEmpty && v.add.isEmpty)
            _Ghi(
              text: state.unknown ? 'Đã đánh dấu "Chưa xác định NPP".' : 'Điểm bán chưa nối khách hàng nào.',
              color: AppColors.warning,
            ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('erp-links-add'),
              onPressed: () => _them(state),
              icon: const Icon(Icons.add_link_rounded),
              label: const Text('Thêm khách hàng'),
            ),
          ),
          if (_id == null && widget.isRequired && v.add.isEmpty)
            CheckboxListTile(
              key: const Key('erp-links-unknown'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: v.unknown,
              onChanged: (x) => _doi(v.copyWith(unknown: x ?? false)),
              title: Text('Chưa xác định NPP', style: AppTypography.bodyMedium(color: chuChinh)),
            ),
        ],
      );
    }

    final noiDung = _tai == null
        ? than(null, loiTai: _id != null ? 'Cần mạng để xem mối nối hiện có — vẫn thêm được khách hàng, gửi khi đồng bộ.' : null)
        : FutureBuilder<ErpLinkStateOfStore>(
            future: _tai,
            builder: (_, snap) => snap.connectionState != ConnectionState.done
                ? than(null, dangTai: true)
                : than(snap.data, loiTai: snap.hasError ? 'Không tải được mối nối hiện có.' : null),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(text: widget.label, style: AppTypography.labelLarge(color: chuChinh).copyWith(fontWeight: FontWeight.w600)),
            if (widget.isRequired) const TextSpan(text: ' *', style: TextStyle(color: AppColors.error)),
          ]),
        ),
        const SizedBox(height: 6),
        noiDung,
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(widget.errorText!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ),
      ],
    );
  }
}

/// Mục "Khách hàng ERP" trên MÀN CHI TIẾT điểm bán (#24331): mối nối đã duyệt / chờ duyệt / bị từ chối + sửa ngay tại chỗ (đổi vai,
/// xin gỡ, thêm khách) — nút "Gửi đề xuất" gửi `erp_link_changes` (mỗi thay đổi một đề xuất chờ duyệt). Cần mạng.
class ErpLinksDetailCard extends ConsumerStatefulWidget {
  /// `crm_customer.id` trên server (> 0).
  final int customerId;

  const ErpLinksDetailCard({super.key, required this.customerId});

  @override
  ConsumerState<ErpLinksDetailCard> createState() => _ErpLinksDetailCardState();
}

class _ErpLinksDetailCardState extends ConsumerState<ErpLinksDetailCard> {
  late ErpLinksValue _v = ErpLinksValue(customerId: widget.customerId);

  /// Đổi khoá sau mỗi lần gửi ⇒ ô dựng lại và đọc lại trạng thái từ server.
  int _lan = 0;
  bool _dangGui = false;

  Future<void> _gui() async {
    if (!ref.read(connectivityProvider).isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cần kết nối mạng để gửi đề xuất.')));
      return;
    }
    setState(() => _dangGui = true);
    try {
      final n = await ref.read(erpLinkRequestServiceProvider).sendChanges(widget.customerId, _v.editChanges());
      if (!mounted) return;
      setState(() {
        _v = ErpLinksValue(customerId: widget.customerId);
        _lan++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã gửi $n đề xuất nối khách hàng, chờ quản lý duyệt.'), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ErpLinksFormField(
            key: ValueKey('erp-links-detail-$_lan'),
            label: 'Mối nối với khách hàng',
            value: _v,
            onChanged: (v) => setState(() => _v = v),
          ),
          if (_v.hasChanges)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _dangGui ? null : () => setState(() => _v = ErpLinksValue(customerId: widget.customerId)),
                    child: const Text('Bỏ thay đổi'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const Key('erp-links-send'),
                    onPressed: _dangGui ? null : _gui,
                    icon: _dangGui
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded),
                    label: Text('Gửi ${_v.editChanges().length} đề xuất'),
                  ),
                ],
              ),
            ),
        ],
      );
}

/// Dòng chữ nhỏ.
class _Ghi extends StatelessWidget {
  final String text;
  final Color color;

  const _Ghi({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: AppTypography.bodySmall(color: color)),
      );
}

/// Thẻ một khách ERP: tên, mã · kênh · vai, nhãn trạng thái màu; nút sửa (mối nối đã duyệt) hoặc bỏ (khách thêm mới).
class _TheTrangThai extends StatelessWidget {
  final String ten;
  final String ma;
  final String? kenh;
  final String vai;

  /// Nhãn trạng thái; `null` ⇒ không vẽ nhãn.
  final String? nhan;
  final Color mau;
  final VoidCallback? onSua;
  final VoidCallback? onBo;

  const _TheTrangThai({
    super.key,
    required this.ten,
    required this.ma,
    required this.vai,
    required this.mau,
    this.nhan,
    this.kenh,
    this.onSua,
    this.onBo,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chuChinh = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
    final chuPhu = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: mau.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mau.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.storefront_rounded, color: mau, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ten, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium(color: chuChinh).copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text([ma, if (kenh != null && kenh!.isNotEmpty) kenh!].join(' · '),
                    style: AppTypography.bodySmall(color: chuPhu)),
                // Vai là của ĐIỂM BÁN với khách ERP, không phải của khách ERP ⇒ dòng riêng "Quan hệ với NPP" (chủ hệ thống chốt
                // 28/10/2026 — luôn ghi "NPP", kể cả khách kênh bán lẻ, cùng cách gọi với ô "Chưa xác định NPP").
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.link_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: 'Quan hệ với NPP: ', style: AppTypography.bodySmall(color: chuPhu)),
                          TextSpan(
                            text: vai,
                            style: AppTypography.bodySmall(color: AppColors.primary).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
                if (nhan != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: mau.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(nhan!, style: AppTypography.labelSmall(color: mau).copyWith(fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ),
          if (onSua != null)
            IconButton(tooltip: 'Đổi vai / gỡ nối', icon: Icon(Icons.edit_rounded, color: chuPhu), onPressed: onSua),
          if (onBo != null)
            IconButton(tooltip: 'Bỏ', icon: Icon(Icons.close_rounded, color: chuPhu), onPressed: onBo),
        ],
      ),
    );
  }
}
