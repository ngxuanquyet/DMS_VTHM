import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/form_fields/form_field_parts.dart';

/// Một thương hiệu trong `config.matrix.brands` của ô Ma trận trưng bày (#24767).
class DisplayMatrixBrand {
  final String code;
  final String name;
  final bool isOwn;

  const DisplayMatrixBrand({required this.code, required this.name, this.isOwn = false});
}

/// Một loại trưng bày trong `config.matrix.types` (đơn vị, hệ số ra mặt, số ảnh tối thiểu/tối đa ĐÃ áp số riêng của biểu mẫu).
class DisplayMatrixType {
  final String code;
  final String name;
  final String unit;
  final int decimals;
  final double faceFactor;
  final String? hint;
  final int minPhotos;
  final int maxPhotos;

  const DisplayMatrixType({
    required this.code,
    required this.name,
    this.unit = '',
    this.decimals = 0,
    this.faceFactor = 1,
    this.hint,
    this.minPhotos = 0,
    this.maxPhotos = 0,
  });

  /// Số ảnh tối thiểu HIỆU LỰC — không vượt tối đa (server cũng kẹp), tránh đòi ảnh khi không có nút chụp.
  int get effectiveMinPhotos => minPhotos > maxPhotos ? maxPhotos : minPhotos;
}

/// Trần một ô đếm — khớp `DisplayMatrixField::MAX_COUNT` của server.
const num kDisplayMatrixMaxCount = 100000;

/// Danh mục của MỘT ô ma trận — server bơm vào `config.matrix` (dòng đang bật, đã áp số ảnh riêng của biểu mẫu).
class DisplayMatrixConfig {
  final List<DisplayMatrixBrand> brands;
  final List<DisplayMatrixType> types;

  const DisplayMatrixConfig({this.brands = const [], this.types = const []});

  /// Đọc từ `config` của ô (Map đã giải mã); thiếu/lạ ⇒ danh mục rỗng.
  static DisplayMatrixConfig fromConfig(Map? config) {
    final m = config?['matrix'];
    if (m is! Map) return const DisplayMatrixConfig();
    int i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    return DisplayMatrixConfig(
      brands: [
        for (final b in (m['brands'] is List ? m['brands'] as List : const []))
          if (b is Map && b['code'] != null)
            DisplayMatrixBrand(code: '${b['code']}', name: '${b['name'] ?? b['code']}', isOwn: b['is_own'] == true),
      ],
      types: [
        for (final t in (m['types'] is List ? m['types'] as List : const []))
          if (t is Map && t['code'] != null)
            DisplayMatrixType(
              code: '${t['code']}',
              name: '${t['name'] ?? t['code']}',
              unit: '${t['unit'] ?? ''}',
              decimals: i(t['decimals']).clamp(0, 2),
              faceFactor: t['face_factor'] is num ? (t['face_factor'] as num).toDouble() : double.tryParse('${t['face_factor']}') ?? 1,
              hint: t['hint']?.toString(),
              minPhotos: i(t['min_photos']),
              maxPhotos: i(t['max_photos']),
            ),
      ],
    );
  }
}

/// Số đếm của ô: `{mã thương hiệu: {mã loại: số}}` — CHỈ ô đã nhập (ô trống = 0 khi cộng, chốt C1).
typedef DisplayMatrixCounts = Map<String, Map<String, num>>;

/// Tổng số mặt + % SOS — CÙNG công thức server (`DisplayMatrixField::totals()`): số × hệ số, % trên số chưa làm tròn.
class DisplayMatrixTotals {
  final Map<String, double> facesByBrand;
  final double facesTotal;
  final double? sosOwnPct;

  const DisplayMatrixTotals({required this.facesByBrand, required this.facesTotal, this.sosOwnPct});

  static DisplayMatrixTotals compute(DisplayMatrixCounts counts, DisplayMatrixConfig cfg) {
    final factor = {for (final t in cfg.types) t.code: t.faceFactor};
    final byBrand = <String, double>{for (final b in cfg.brands) b.code: 0};
    counts.forEach((b, row) {
      row.forEach((t, n) => byBrand[b] = (byBrand[b] ?? 0) + n.toDouble() * (factor[t] ?? 1));
    });
    final total = byBrand.values.fold<double>(0, (a, b) => a + b);
    final own = cfg.brands.where((b) => b.isOwn).fold<double>(0, (a, b) => a + (byBrand[b.code] ?? 0));
    return DisplayMatrixTotals(facesByBrand: byBrand, facesTotal: total, sosOwnPct: total > 0 ? own / total * 100 : null);
  }

  /// % SOS của một thương hiệu; `null` khi chưa có mặt nào.
  double? sosOf(String brand) => facesTotal > 0 ? (facesByBrand[brand] ?? 0) / facesTotal * 100 : null;

  /// Tổng số đếm của một loại trên mọi thương hiệu (luật ảnh C2: chỉ bắt ảnh khi > 0).
  static num sumOfType(DisplayMatrixCounts counts, String type) =>
      counts.values.fold<num>(0, (a, row) => a + (row[type] ?? 0));
}

/// Số theo kiểu Việt: dấu phẩy thập phân, tối đa 2 chữ số lẻ, bỏ số 0 thừa.
String fmtMatrixNumber(num n) {
  final r = (n * 100).round() / 100;
  final s = r == r.truncateToDouble() ? r.toInt().toString() : r.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
  return s.replaceAll('.', ',');
}

/// Phần trăm làm tròn 1 chữ số, kiểu Việt.
String fmtMatrixPct(double p) => fmtMatrixNumber((p * 10).round() / 10);

/// Ô **Ma trận trưng bày SOS** (#24767, spec `MA-TRAN-TRUNG-BAY-SOS-2026-11-03.md` §4): mỗi thương hiệu một thẻ (thẻ "của ta"
/// đứng đầu, mở sẵn), trong thẻ là các loại trưng bày kèm đơn vị + nút ⓘ hướng dẫn đếm; tổng mặt và % SOS tự tính khi gõ.
///
/// Phần ẢNH theo loại do màn chứa vẽ ([photoSection]) — dùng chung bộ chụp/tải ảnh của biểu mẫu thị trường.
class DisplayMatrixFieldWidget extends StatefulWidget {
  /// Mã ô — phân biệt trạng thái mở/thu thẻ khi một biểu mẫu có nhiều ô ma trận.
  final String fieldCode;
  final String label;
  final String? description;
  final bool isRequired;
  final DisplayMatrixConfig config;
  final DisplayMatrixCounts counts;
  final String? errorText;
  /// Số đếm mới + có ô nào đang gõ sai dạng không (màn chứa chặn bước Lưu).
  final void Function(DisplayMatrixCounts counts, bool hasInvalidCell) onChanged;
  final Widget Function(DisplayMatrixType type)? photoSection;

  const DisplayMatrixFieldWidget({
    super.key,
    this.fieldCode = '',
    required this.label,
    this.description,
    this.isRequired = false,
    required this.config,
    required this.counts,
    this.errorText,
    required this.onChanged,
    this.photoSection,
  });

  /// Đọc `counts` từ giá trị đã lưu (nháp / phiếu cũ): `{counts: {...}}`; bỏ ô không phải số.
  static DisplayMatrixCounts countsOf(dynamic value) {
    final raw = value is Map ? value['counts'] : null;
    final out = <String, Map<String, num>>{};
    if (raw is Map) {
      raw.forEach((b, row) {
        if (row is! Map) return;
        final r = <String, num>{};
        row.forEach((t, v) {
          final n = v is num ? v : num.tryParse('$v'.replaceAll(',', '.'));
          if (n != null) r['$t'] = n;
        });
        if (r.isNotEmpty) out['$b'] = r;
      });
    }
    return out;
  }

  /// Chỉ giữ thương hiệu/loại ô ĐANG hỏi — số của dòng admin đã bỏ khỏi ô không hiện để xoá, gửi lại thì server từ chối.
  static DisplayMatrixCounts onlyAsked(DisplayMatrixCounts counts, DisplayMatrixConfig cfg) {
    final b = {for (final x in cfg.brands) x.code};
    final t = {for (final x in cfg.types) x.code};
    final out = <String, Map<String, num>>{};
    counts.forEach((brand, row) {
      if (!b.contains(brand)) return;
      final r = {for (final e in row.entries) if (t.contains(e.key)) e.key: e.value};
      if (r.isNotEmpty) out[brand] = r;
    });
    return out;
  }

  /// Lỗi của số đếm theo luật server (số lẻ quá số chữ số của loại, vượt trần); hợp lệ ⇒ `null`.
  static String? countsError(DisplayMatrixCounts counts, DisplayMatrixConfig cfg) {
    final byCode = {for (final t in cfg.types) t.code: t};
    for (final row in counts.values) {
      for (final e in row.entries) {
        final t = byCode[e.key];
        if (t == null) continue;
        final err = cellError(e.value, t);
        if (err != null) return '${t.name}: $err';
      }
    }
    return null;
  }

  /// Lỗi của MỘT ô đếm; hợp lệ ⇒ `null`.
  static String? cellError(num n, DisplayMatrixType t) {
    if (n < 0 || n > kDisplayMatrixMaxCount) return 'phải trong khoảng 0 đến ${fmtMatrixNumber(kDisplayMatrixMaxCount)}';
    final p = t.decimals == 0 ? 1 : (t.decimals == 1 ? 10 : 100);
    if ((n * p - (n * p).round()).abs() > 1e-9) {
      return t.decimals == 0 ? 'chỉ nhận số nguyên' : 'tối đa ${t.decimals} chữ số thập phân';
    }
    return null;
  }

  @override
  State<DisplayMatrixFieldWidget> createState() => _DisplayMatrixFieldWidgetState();
}

class _DisplayMatrixFieldWidgetState extends State<DisplayMatrixFieldWidget> {
  final Map<String, TextEditingController> _ctrl = {};

  /// Ô đang gõ dở/sai dạng (vd `2,5,`) — hiện lỗi NGAY dưới ô thay vì lặng lẽ bỏ số khỏi tổng.
  final Map<String, String> _cellErr = {};

  TextEditingController _controller(String brand, String type) => _ctrl.putIfAbsent('$brand::$type', () {
        final n = widget.counts[brand]?[type];
        return TextEditingController(text: n == null ? '' : fmtMatrixNumber(n));
      });

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _set(String brand, DisplayMatrixType type, String text) {
    final next = <String, Map<String, num>>{for (final e in widget.counts.entries) e.key: Map.of(e.value)};
    final t = text.trim();
    final n = num.tryParse(t.replaceAll(',', '.'));
    final k = '$brand::${type.code}';
    final err = t.isEmpty ? null : (n == null ? 'Số không hợp lệ' : DisplayMatrixFieldWidget.cellError(n, type));
    setState(() => err == null ? _cellErr.remove(k) : _cellErr[k] = err);
    if (t.isEmpty || n == null) {
      next[brand]?.remove(type.code);
      if (next[brand]?.isEmpty ?? false) next.remove(brand);
    } else {
      // Số sai luật (lẻ quá, vượt trần) VẪN ghi để bước Lưu chặn với câu lỗi — bỏ đi thì tổng tụt mà không ai biết.
      (next[brand] ??= {})[type.code] = n;
    }
    widget.onChanged(DisplayMatrixFieldWidget.onlyAsked(next, widget.config), _cellErr.values.contains('Số không hợp lệ'));
  }

  void _showHint(DisplayMatrixType type) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type.name),
        content: Text(type.hint ?? ''),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Đã hiểu'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cfg = widget.config;
    final totals = DisplayMatrixTotals.compute(widget.counts, cfg);
    // Thẻ "của ta" đứng đầu (đếm VTHM trước rồi lần lượt đối thủ); còn lại giữ thứ tự danh mục.
    final brands = [...cfg.brands.where((b) => b.isOwn), ...cfg.brands.where((b) => !b.isOwn)];
    final muted = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    String tomTat(DisplayMatrixBrand b) {
      final pct = totals.sosOf(b.code);
      return '${fmtMatrixNumber(totals.facesByBrand[b.code] ?? 0)} mặt${pct == null ? '' : ' · ${fmtMatrixPct(pct)}%'}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormFieldLabel(label: widget.label, isRequired: widget.isRequired, description: widget.description),
        const SizedBox(height: kFormLabelGap),
        if (cfg.brands.isEmpty || cfg.types.isEmpty)
          Text('Biểu mẫu chưa có thương hiệu hoặc loại trưng bày nào — báo quản trị.', style: AppTypography.bodySmall(color: AppColors.error)),
        for (final b in brands)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
            ),
            elevation: 0,
            child: ExpansionTile(
              key: PageStorageKey('matrix_${widget.fieldCode}_${b.code}'),
              initiallyExpanded: b.isOwn,
              shape: const Border(),
              title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(tomTat(b), style: AppTypography.labelSmall(color: muted)),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                for (final t in cfg.types)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(t.name, style: AppTypography.bodyMedium(color: isDark ? AppColors.darkOnSurface : AppColors.onSurface))),
                        if ((t.hint ?? '').trim().isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.info_outline_rounded, size: 18),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Cách đếm',
                            onPressed: () => _showHint(t),
                          ),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            key: ValueKey('matrix_${b.code}_${t.code}'),
                            controller: _controller(b.code, t.code),
                            keyboardType: TextInputType.numberWithOptions(decimal: t.decimals > 0),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(t.decimals > 0 ? r'[0-9.,]' : r'[0-9]')),
                            ],
                            textAlign: TextAlign.right,
                            style: formFieldTextStyle(isDark),
                            decoration: formFieldDecoration(
                              isDark: isDark,
                              hintText: '0',
                              suffixText: t.unit,
                              errorText: _cellErr['${b.code}::${t.code}'],
                            ),
                            onChanged: (v) => _set(b.code, t, v),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            'Tổng ${fmtMatrixNumber(totals.facesTotal)} mặt ngành hàng'
            '${totals.sosOwnPct == null ? '' : ' · SOS của ta ${fmtMatrixPct(totals.sosOwnPct!)}%'}',
            style: AppTypography.bodyMedium(color: muted).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        if (widget.photoSection != null)
          for (final t in cfg.types)
            if (t.maxPhotos > 0)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: widget.photoSection!(t)),
        if (widget.errorText != null) FormFieldErrorText(widget.errorText!),
      ],
    );
  }
}

/// Tóm tắt CHỮ của một giá trị ô ma trận đã nộp (màn xem phiếu / lịch sử lượt): mỗi thương hiệu một dòng "tên: N mặt (P%)",
/// dòng cuối tổng mặt — đọc `snapshot` + `totals` server chụp lúc nộp. Không phải giá trị ô ma trận ⇒ `null`.
String? displayMatrixSummary(dynamic value) {
  if (value is! Map || value['snapshot'] is! Map || value['totals'] is! Map) return null;
  final snap = value['snapshot'] as Map;
  final totals = value['totals'] as Map;
  final faces = totals['faces_by_brand'] is Map ? totals['faces_by_brand'] as Map : const {};
  final sos = totals['sos_by_brand'] is Map ? totals['sos_by_brand'] as Map : const {};
  final lines = <String>[
    for (final b in (snap['brands'] is List ? snap['brands'] as List : const []))
      if (b is Map)
        '${b['name'] ?? b['code']}: ${fmtMatrixNumber(faces[b['code']] is num ? faces[b['code']] as num : 0)} mặt'
            '${sos[b['code']] is num ? ' (${fmtMatrixPct((sos[b['code']] as num).toDouble())}%)' : ''}',
  ];
  final total = totals['faces_total'] is num ? totals['faces_total'] as num : 0;
  lines.add('Tổng ${fmtMatrixNumber(total)} mặt ngành hàng');
  return lines.join('\n');
}
