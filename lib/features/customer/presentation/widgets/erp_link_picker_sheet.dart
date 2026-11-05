import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/services/erp_catalog_service.dart';
import '../../../../core/services/erp_link_request_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Một khách ERP (nhà phân phối) NV đã chọn ở bước nối.
class ErpLinkPick {
  final String code;
  final String name;
  final String? address;
  final int? channelId;
  final String? channelName;

  /// `phone` · `tax_code` · `name_address` (từ gợi ý) hoặc `manual` (tự tìm).
  final String matchReason;

  ErpLinkPick({
    required this.code,
    required this.name,
    required this.matchReason,
    this.address,
    this.channelId,
    this.channelName,
  });

  ErpLinkPick copy() => ErpLinkPick(
        code: code,
        name: name,
        matchReason: matchReason,
        address: address,
        channelId: channelId,
        channelName: channelName,
      );

  /// Một mục của `erp_links` gửi kèm khi tạo điểm bán — không có vai (bỏ 05/11/2026).
  Map<String, dynamic> toPayload() => {'code': code, 'match_reason': matchReason};
}

/// Kết quả khung chọn: các khách ERP đã chọn (có thể rỗng — NV bỏ hết khách đã chọn).
class ErpLinkPickResult {
  final List<ErpLinkPick> picks;

  const ErpLinkPickResult({required this.picks});
}

/// Khung chọn khách ERP cho ô "Khách hàng ERP" (#24327, #24331, spec DIEM-BAN-KHACH-ERP §11–§12) — chọn NHIỀU nhà phân phối
/// điểm bán thuộc về (không còn vai — chủ hệ thống bỏ 05/11/2026); chỉ khách thuộc kênh danh mục cho phép. Thẻ gợi ý
/// (theo SĐT/MST/tên, khi có mạng; dự phòng theo tên trên máy) + ô tìm trên danh mục lưu máy (chạy cả khi mất mạng).
/// Ô tick "Chưa xác định NPP" nằm ở ô trong form, không ở đây. Đóng khung ⇒ `pop(null)` (giữ nguyên lựa chọn cũ).
class ErpLinkPickerSheet extends StatefulWidget {
  /// Danh mục lưu máy; `null` = chưa từng tải (mất mạng từ lần đầu) ⇒ chỉ còn gợi ý (nếu có) và ô tick.
  final ErpCatalog? catalog;
  final List<ErpLinkSuggestion> suggestions;
  final List<ErpLinkPick> initial;

  /// Khách đã nối / đã đề xuất cho điểm bán này — không hiện lại.
  final Set<String> excludeCodes;

  const ErpLinkPickerSheet({
    super.key,
    required this.catalog,
    this.suggestions = const [],
    this.initial = const [],
    this.excludeCodes = const {},
  });

  @override
  State<ErpLinkPickerSheet> createState() => _ErpLinkPickerSheetState();
}

class _ErpLinkPickerSheetState extends State<ErpLinkPickerSheet> {
  static const Duration _cho = Duration(milliseconds: 250);

  final TextEditingController _o = TextEditingController();
  Timer? _hen;
  late final List<ErpLinkPick> _chon = widget.initial.map((p) => p.copy()).toList();

  /// Từ khoá ĐÃ tìm (khớp với [_ketQua]) — không phải chữ đang gõ.
  String _daTim = '';
  List<ErpCatalogItem> _ketQua = const [];

  @override
  void dispose() {
    _hen?.cancel();
    _o.dispose();
    super.dispose();
  }

  void _doiChu(String v) {
    _hen?.cancel();
    _hen = Timer(_cho, () {
      if (!mounted) return;
      final q = v.trim();
      setState(() {
        _daTim = q;
        _ketQua = q.length < 2 ? const [] : (widget.catalog?.search(q) ?? const []);
      });
    });
    setState(() {}); // cập nhật nút xoá chữ
  }

  /// Khách thuộc kênh [channelId] có nối được không; danh mục chưa có ⇒ cho qua (server kiểm lại).
  bool _kenhDuoc(int? channelId) => widget.catalog?.allowsChannel(channelId) ?? true;

  void _them(ErpLinkPick p) => setState(() => _chon.add(p));

  void _bo(String code) => setState(() => _chon.removeWhere((p) => p.code == code));


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chuChinh = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
    final chuPhu = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    final daChon = _chon.map((p) => p.code).toSet();
    final an = {...daChon, ...widget.excludeCodes};
    // Gợi ý từ server có thể còn khách thuộc kênh không được nối (vd Kênh bán lẻ) — ẩn, không cho chọn.
    final goiY = widget.suggestions.where((s) => !an.contains(s.code) && _kenhDuoc(s.channelId)).toList();
    final ketQua = _ketQua.where((i) => !an.contains(i.code)).toList();
    final trungDaChon = _ketQua.length - ketQua.length;
    final dangTim = _daTim.length >= 2;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Điểm bán liên quan khách hàng nào?',
                  style: AppTypography.titleMedium(color: chuChinh),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Chọn các nhà phân phối điểm bán lấy hàng (chọn được nhiều) — quản lý sẽ duyệt mối nối.',
                  style: AppTypography.bodySmall(color: chuPhu),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  key: const Key('erp-link-search'),
                  controller: _o,
                  onChanged: _doiChu,
                  enabled: widget.catalog != null,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: widget.catalog == null
                        ? 'Chưa có danh mục khách hàng trên máy — cần mạng để tải lần đầu'
                        : 'Tìm khách hàng theo tên, mã, địa chỉ…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _o.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _o.clear();
                              _doiChu('');
                            },
                          ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  children: [
                    // Đã chọn luôn ở ĐẦU — NV thấy ngay mình đã chọn những ai, không phải cuộn qua danh sách lọc dài
                    // (chủ hệ thống yêu cầu 28/10/2026). Sau đó: kết quả tìm khi đang tìm, gợi ý khi không tìm.
                    if (_chon.isNotEmpty) ...[
                      _TieuDeNhom(icon: Icons.check_circle_rounded, text: 'Đã chọn (${_chon.length})', color: AppColors.success),
                      for (final p in _chon)
                        _TheDaChon(
                          pick: p,
                          onBo: () => _bo(p.code),
                        ),
                    ],
                    if (dangTim) ...[
                      _TieuDeNhom(icon: Icons.manage_search_rounded, text: 'Kết quả tìm (${ketQua.length})', color: chuPhu),
                      if (ketQua.isEmpty)
                        _GhiChu(
                          text: trungDaChon > 0
                              ? 'Khách hàng khớp "$_daTim" đã nằm trong danh sách đã chọn / đã đề xuất.'
                              : 'Không có khách hàng nào khớp "$_daTim".',
                          color: chuPhu,
                        )
                      else
                        for (final i in ketQua)
                          _TheKhach(
                            key: Key('erp-link-${i.code}'),
                            name: i.name,
                            code: i.code,
                            address: i.address,
                            channelName: i.channelName,
                            nhan: null,
                            goiY: false,
                            onThem: () => _them(ErpLinkPick(
                              code: i.code,
                              name: i.name,
                              address: i.address,
                              channelId: i.channelId,
                              channelName: i.channelName,
                              matchReason: 'manual',
                            )),
                          ),
                    ],
                    if (!dangTim) ...[
                      _TieuDeNhom(
                        icon: Icons.auto_awesome_rounded,
                        text: 'Gợi ý từ thông tin điểm bán (${goiY.length})',
                        color: AppColors.primary,
                      ),
                      if (goiY.isEmpty)
                        _GhiChu(
                          text: widget.suggestions.isEmpty
                              ? 'Không thấy khách hàng trùng SĐT, mã số thuế hay tên. Gõ tên hoặc mã vào ô tìm ở trên.'
                              : 'Đã chọn hết các gợi ý.',
                          color: chuPhu,
                        )
                      else
                        for (final s in goiY)
                          _TheKhach(
                            key: Key('erp-link-${s.code}'),
                            name: s.name,
                            code: s.code,
                            address: s.address,
                            channelName: s.channelName,
                            nhan: s.matchReasonLabel,
                            mauNhan: switch (s.matchReason) {
                              'phone' || 'tax_code' => AppColors.success,
                              _ => AppColors.warning,
                            },
                            goiY: true,
                            onThem: () => _them(ErpLinkPick(
                              code: s.code,
                              name: s.name,
                              address: s.address,
                              channelId: s.channelId,
                              channelName: s.channelName,
                              matchReason: s.matchReason.isEmpty ? 'manual' : s.matchReason,
                            )),
                          ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: FilledButton.icon(
                  key: const Key('erp-link-confirm'),
                  onPressed: () => Navigator.pop(context, ErpLinkPickResult(picks: _chon.map((p) => p.copy()).toList())),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(_chon.isEmpty ? 'Xong (chưa chọn khách hàng nào)' : 'Xác nhận ${_chon.length} khách hàng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiêu đề một nhóm thẻ.
class _TieuDeNhom extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _TieuDeNhom({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelLarge(color: color).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

/// Dòng chữ nhỏ thay cho danh sách rỗng.
class _GhiChu extends StatelessWidget {
  final String text;
  final Color color;

  const _GhiChu({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text, style: AppTypography.bodySmall(color: color)),
      );
}

/// Phần thân chung của một thẻ khách: avatar, tên, nhãn (mã · kênh · lý do), địa chỉ.
class _ThanThe extends StatelessWidget {
  final String name;
  final String code;
  final String? address;
  final String? channelName;
  final String? nhan;
  final Color? mauNhan;
  final Color mauChinh;

  const _ThanThe({
    required this.name,
    required this.code,
    required this.mauChinh,
    this.address,
    this.channelName,
    this.nhan,
    this.mauNhan,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chuChinh = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
    final chuPhu = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: mauChinh.withValues(alpha: 0.12),
          child: Icon(Icons.storefront_rounded, size: 20, color: mauChinh),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium(color: chuChinh).copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _Nhan(text: code, color: chuPhu),
                  if (channelName != null && channelName!.isNotEmpty) _Nhan(text: channelName!, color: AppColors.secondary),
                  if (nhan != null && nhan!.isNotEmpty) _Nhan(text: nhan!, color: mauNhan ?? AppColors.outline, dam: true),
                ],
              ),
              if (address != null && address!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: const EdgeInsets.only(top: 1), child: Icon(Icons.place_outlined, size: 14, color: chuPhu)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        address!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall(color: chuPhu),
                      ),
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
}

/// Khung thẻ bo góc có viền.
class _Khung extends StatelessWidget {
  final Color vien;
  final Color nen;
  final Widget child;
  final VoidCallback? onTap;

  const _Khung({required this.vien, required this.nen, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: nen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: vien)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: const EdgeInsets.fromLTRB(12, 10, 8, 10), child: child),
          ),
        ),
      );
}

/// Thẻ khách CHƯA chọn (gợi ý viền màu chủ đạo, kết quả tìm viền xám). Bấm thẻ ⇒ thêm vào danh sách đã chọn.
class _TheKhach extends StatelessWidget {
  final String name;
  final String code;
  final String? address;
  final String? channelName;
  final String? nhan;
  final Color? mauNhan;
  final bool goiY;
  final VoidCallback onThem;

  const _TheKhach({
    super.key,
    required this.name,
    required this.code,
    required this.goiY,
    required this.onThem,
    this.address,
    this.channelName,
    this.nhan,
    this.mauNhan,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chuPhu = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    return _Khung(
      vien: goiY ? AppColors.primary.withValues(alpha: 0.45) : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
      nen: goiY
          ? AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.05)
          : (isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest),
      onTap: onThem,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _ThanThe(
              name: name,
              code: code,
              address: address,
              channelName: channelName,
              nhan: nhan,
              mauNhan: mauNhan,
              mauChinh: goiY ? AppColors.primary : chuPhu,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Icons.add_circle_outline_rounded, color: goiY ? AppColors.primary : chuPhu),
          ),
        ],
      ),
    );
  }
}

/// Thẻ khách ĐÃ chọn: viền xanh lá, nút bỏ.
class _TheDaChon extends StatelessWidget {
  final ErpLinkPick pick;
  final VoidCallback onBo;

  const _TheDaChon({required this.pick, required this.onBo});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chuPhu = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    return _Khung(
      vien: AppColors.success.withValues(alpha: 0.6),
      nen: AppColors.success.withValues(alpha: isDark ? 0.12 : 0.06),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _ThanThe(
              name: pick.name,
              code: pick.code,
              address: pick.address,
              channelName: pick.channelName,
              mauChinh: AppColors.success,
            ),
          ),
          IconButton(
            key: Key('erp-link-remove-${pick.code}'),
            visualDensity: VisualDensity.compact,
            tooltip: 'Bỏ chọn',
            icon: Icon(Icons.close_rounded, color: chuPhu),
            onPressed: onBo,
          ),
        ],
      ),
    );
  }
}

/// Nhãn nhỏ bo tròn (mã, kênh, lý do khớp).
class _Nhan extends StatelessWidget {
  final String text;
  final Color color;
  final bool dam;

  const _Nhan({required this.text, required this.color, this.dam = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: dam ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
        ),
        child: Text(
          text,
          style: AppTypography.labelSmall(color: color).copyWith(fontWeight: dam ? FontWeight.w600 : FontWeight.w500),
        ),
      );
}
