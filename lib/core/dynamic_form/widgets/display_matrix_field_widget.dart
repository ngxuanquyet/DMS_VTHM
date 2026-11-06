import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/form_fields/form_field_parts.dart';
import '../../utils/rich_image_cache.dart' show richImageCacheProvider;
import '../../widgets/note_field_widget.dart' show RichImageView;

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
  /// Token ảnh minh hoạ (rich-image) theo thứ tự hiện — bấm tên cột mở ảnh cùng [hint] (chốt 04/11/2026); nhiều ảnh thì vuốt
  /// xem từng ảnh, góc trên ghi "i/n" (06/11/2026).
  final List<String> illustrationTokens;
  final int minPhotos;
  final int maxPhotos;

  const DisplayMatrixType({
    required this.code,
    required this.name,
    this.unit = '',
    this.decimals = 0,
    this.faceFactor = 1,
    this.hint,
    this.illustrationTokens = const [],
    this.minPhotos = 0,
    this.maxPhotos = 0,
  });

  /// Số ảnh tối thiểu HIỆU LỰC — không vượt tối đa (server cũng kẹp), tránh đòi ảnh khi không có nút chụp.
  int get effectiveMinPhotos => minPhotos > maxPhotos ? maxPhotos : minPhotos;

  /// Có gì để mở khi bấm tên cột (ảnh minh hoạ hoặc câu hướng dẫn).
  bool get hasGuide => illustrationTokens.isNotEmpty || (hint ?? '').trim().isNotEmpty;

  /// Đọc danh sách ảnh: `illustration_tokens` (server từ 06/11/2026), thiếu thì `illustration_token` một ảnh (server cũ).
  static List<String> tokensOf(Map t) {
    final list = t['illustration_tokens'];
    if (list is List) return [for (final x in list) if (x is String && x.isNotEmpty) x];
    final one = t['illustration_token'];
    return one is String && one.isNotEmpty ? [one] : const [];
  }
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
              illustrationTokens: DisplayMatrixType.tokensOf(t),
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

/// Ô **Ma trận trưng bày SOS** (#24767, spec `MA-TRAN-TRUNG-BAY-SOS-2026-11-03.md` §4) vẽ thành BẢNG (chốt 04/11/2026, theo mẫu
/// MobiWork): dòng = thương hiệu ("của ta" đứng đầu, tô nền), cột = loại trưng bày (tên + đơn vị; bấm tên cột xem ảnh minh hoạ +
/// hướng dẫn đếm). Cột Thương hiệu ghim trái, cột Tổng (số mặt + % SOS) ghim phải, các cột loại vuốt ngang. Nút "Phóng to" mở
/// bảng toàn màn hình, ép xoay ngang; số gõ ở đó dùng CHUNG ô nhập với bảng trong phiếu.
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

  /// Số HIỆN TRẠNG của điểm bán (ô ma trận bật "Cập nhật hiện trạng điểm bán", #24789) — chủ hệ thống chốt 06/11/2026: ô
  /// CHƯA SỬA hiện số này như số thật, Tổng / % SOS tính trên cả ma trận; nhưng [onChanged] chỉ mang ô ĐÃ GÕ — ô không sửa
  /// giữ số trên server (luật 05/11), số trong máy có thể cũ hơn server, gửi lại là đè số mới. Ô bị xoá trống hiện mờ số này.
  final DisplayMatrixCounts hintCounts;

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
    this.hintCounts = const {},
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

  /// Hai giá trị ô ma trận cùng NỘI DUNG — số đếm (không kể thứ tự khoá, 2 = 2.0) + ảnh từng loại. Màn sửa không gửi, form
  /// không kiểm ô trùng giá trị đang lưu (#24698 vòng 4, C3).
  static bool sameValue(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    // Chỉ giá trị dạng ô ma trận — map khác (vị trí…) không có counts/photos sẽ bị coi là "giống nhau".
    bool laMaTran(dynamic v) => v is Map && (v.containsKey('counts') || v.containsKey('photos'));
    if (!laMaTran(a) || !laMaTran(b)) return false;
    if (!_sameCounts(countsOf(a), countsOf(b))) return false;
    Map<String, List<String>> anh(Map v) => {
          if (v['photos'] is Map)
            for (final e in (v['photos'] as Map).entries)
              if (e.value is List && (e.value as List).isNotEmpty) '${e.key}': [for (final x in e.value as List) '$x'],
        };
    final pa = anh(a), pb = anh(b);
    return pa.length == pb.length && pa.entries.every((e) => listEquals(e.value, pb[e.key]));
  }

  /// Số dùng để tính Tổng / % SOS: ô đã gõ lấy số gõ, ô trống lấy [hints] (số hiện trạng — ô trống giữ số cũ khi nộp).
  static DisplayMatrixCounts withHints(DisplayMatrixCounts counts, DisplayMatrixCounts hints) {
    if (hints.isEmpty) return counts;
    final out = <String, Map<String, num>>{for (final e in hints.entries) e.key: Map.of(e.value)};
    counts.forEach((b, row) => (out[b] ??= {}).addAll(row));
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

/// Trạng thái NHẬP của một bảng ma trận — ô nhập, lỗi ô, số đếm — dùng cho bảng trong phiếu và màn phóng to. Mỗi màn một bộ
/// riêng (một TextEditingController chỉ gắn MỘT ô: hai ô chung controller thì bộ gõ tiếng Việt giật con trỏ / lặp chữ).
mixin _MatrixEditing<T extends StatefulWidget> on State<T> {
  final Map<String, TextEditingController> _ctrl = {};

  /// Ô đang gõ dở/sai dạng (vd `2,5,`) — hiện lỗi NGAY dưới bảng thay vì lặng lẽ bỏ số khỏi tổng.
  final Map<String, String> _cellErr = {};

  /// Số đếm hiện tại (chỉ thương hiệu/loại đang hỏi).
  DisplayMatrixCounts _counts = const {};

  DisplayMatrixConfig get _config;
  DisplayMatrixCounts get _hints;
  void Function(DisplayMatrixCounts counts, bool hasInvalidCell) get _onChanged;

  /// Còn ô gõ sai dạng số (số không vào bộ đếm).
  bool get _hasInvalidCell => _cellErr.values.contains(_loiSaiDang);

  TextEditingController _controller(String brand, String type) => _ctrl.putIfAbsent('$brand::$type', () {
        // Ô chưa gõ hiện số hiện trạng ([DisplayMatrixFieldWidget.hintCounts]) như số thật — chỉ để xem, không vào [_counts].
        final n = _counts[brand]?[type] ?? _hints[brand]?[type];
        return TextEditingController(text: n == null ? '' : fmtMatrixNumber(n));
      });

  /// Ghi lại chữ mọi ô theo [_counts] (số đổi từ ngoài: nạp nháp, quay về từ màn phóng to). Controller cũ bỏ đi SAU khung hình
  /// — ô đang vẽ còn giữ nó tới lúc dựng lại.
  void _resyncControllers() {
    final cu = _ctrl.values.toList();
    _ctrl.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in cu) {
        c.dispose();
      }
    });
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _set(String brand, DisplayMatrixType type, String text) {
    final next = <String, Map<String, num>>{for (final e in _counts.entries) e.key: Map.of(e.value)};
    final t = text.trim();
    final n = num.tryParse(t.replaceAll(',', '.'));
    final k = '$brand::${type.code}';
    final err = t.isEmpty ? null : (n == null ? _loiSaiDang : DisplayMatrixFieldWidget.cellError(n, type));
    if (t.isEmpty || n == null) {
      next[brand]?.remove(type.code);
      if (next[brand]?.isEmpty ?? false) next.remove(brand);
    } else {
      // Số sai luật (lẻ quá, vượt trần) VẪN ghi để bước Lưu chặn với câu lỗi — bỏ đi thì tổng tụt mà không ai biết.
      (next[brand] ??= {})[type.code] = n;
    }
    final asked = DisplayMatrixFieldWidget.onlyAsked(next, _config);
    setState(() {
      err == null ? _cellErr.remove(k) : _cellErr[k] = err;
      _counts = asked;
    });
    _onChanged(asked, _hasInvalidCell);
  }

  /// Bấm tên cột: ảnh minh hoạ + hướng dẫn đếm + quy đổi ra mặt.
  void _showGuide(DisplayMatrixType type) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (type.illustrationTokens.isNotEmpty)
                // Ảnh to/dọc mà để tự do thì phình theo bề ngang, ở màn phóng to (xoay ngang) tràn khỏi màn hình (báo 04/11/2026)
                // ⇒ kẹp trong khung ≤ nửa chiều cao màn, giữ tỉ lệ; chụm hai ngón để xem chi tiết.
                ConstrainedBox(
                  key: const ValueKey('matrix_guide_image'),
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.5,
                    maxWidth: MediaQuery.sizeOf(ctx).width * 0.8,
                  ),
                  child: type.illustrationTokens.length == 1
                      ? InteractiveViewer(maxScale: 4, child: RichImageView(token: type.illustrationTokens.first))
                      : _IllustrationGallery(
                          tokens: type.illustrationTokens,
                          width: MediaQuery.sizeOf(ctx).width * 0.8,
                          // Chừa chỗ khung hộp thoại (tiêu đề, nút, lề) + câu hướng dẫn: màn ngang ~380px mà lấy nửa màn thì
                          // câu hướng dẫn trôi khỏi tầm nhìn (đo ảnh chụp 06/11/2026).
                          height: (MediaQuery.sizeOf(ctx).height - 270)
                              .clamp(math.min(140.0, MediaQuery.sizeOf(ctx).height * 0.5), MediaQuery.sizeOf(ctx).height * 0.5),
                        ),
                ),
              if ((type.hint ?? '').trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(type.hint!.trim())),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Đếm theo ${type.unit.isEmpty ? 'đơn vị' : type.unit} · 1 ${type.unit} = ${fmtMatrixNumber(type.faceFactor)} mặt',
                  style: AppTypography.labelSmall(color: AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Đã hiểu'))],
      ),
    );
  }

  /// Bảng nhập ([keyPrefix] khác nhau giữa phiếu và màn phóng to: hai bảng cùng nằm trong cây khi màn phóng to mở).
  Widget _table({required String keyPrefix, required double cellWidth, required DisplayMatrixTotals totals}) => _MatrixTable(
        // "Của ta" đứng đầu (đếm VTHM trước rồi lần lượt đối thủ); còn lại giữ thứ tự danh mục.
        brands: [..._config.brands.where((b) => b.isOwn), ..._config.brands.where((b) => !b.isOwn)],
        types: _config.types,
        totals: totals,
        controller: _controller,
        cellErr: _cellErr,
        hints: _hints,
        keyPrefix: keyPrefix,
        cellWidth: cellWidth,
        onCell: _set,
        onHeaderTap: _showGuide,
      );

  /// Dòng "Tổng N mặt ngành hàng · SOS của ta X%".
  Widget _totalLine(DisplayMatrixTotals totals) => Text(
        'Tổng ${fmtMatrixNumber(totals.facesTotal)} mặt ngành hàng'
        '${totals.sosOwnPct == null ? '' : ' · SOS của ta ${fmtMatrixPct(totals.sosOwnPct!)}%'}',
        style: AppTypography.bodyMedium(
          color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
        ).copyWith(fontWeight: FontWeight.w600),
      );

  /// Câu lỗi của các ô đang sai ("VTHM · Ốp mẫu: …") — hiện dưới bảng (lỗi trong ô sẽ làm lệch chiều cao dòng).
  List<String> get _errorLines {
    final brands = {for (final b in _config.brands) b.code: b.name};
    final types = {for (final t in _config.types) t.code: t.name};
    return [
      for (final e in _cellErr.entries) '${brands[e.key.split('::').first] ?? ''} · ${types[e.key.split('::').last] ?? ''}: ${e.value}',
    ];
  }
}

/// Câu lỗi ô gõ sai dạng số — cũng là dấu nhận ra ô sai dạng trong `_cellErr`.
const _loiSaiDang = 'Số không hợp lệ';

/// Hai bộ số đếm giống hệt nhau.
bool _sameCounts(DisplayMatrixCounts a, DisplayMatrixCounts b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    final o = b[e.key];
    if (o == null || o.length != e.value.length) return false;
    for (final c in e.value.entries) {
      if (o[c.key] != c.value) return false;
    }
  }
  return true;
}

class _DisplayMatrixFieldWidgetState extends State<DisplayMatrixFieldWidget> with _MatrixEditing<DisplayMatrixFieldWidget> {
  @override
  DisplayMatrixConfig get _config => widget.config;
  @override
  DisplayMatrixCounts get _hints => widget.hintCounts;
  @override
  void Function(DisplayMatrixCounts counts, bool hasInvalidCell) get _onChanged => widget.onChanged;

  @override
  void initState() {
    super.initState();
    _counts = DisplayMatrixFieldWidget.onlyAsked(widget.counts, widget.config);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefetchIllustrations());
  }

  @override
  void didUpdateWidget(DisplayMatrixFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final moi = DisplayMatrixFieldWidget.onlyAsked(widget.counts, widget.config);
    // Số do CHÍNH ô này gõ quay về y hệt ⇒ giữ nguyên (ô đang gõ dở "2," không bị viết lại); khác ⇒ đổi từ ngoài, ghi lại ô.
    if (!_sameCounts(moi, _counts)) {
      _counts = moi;
      _cellErr.clear();
      _resyncControllers();
    }
  }

  /// Tải sẵn ảnh minh hoạ vào bộ đệm khi phiếu mở (còn mạng) — tới điểm bán mất sóng vẫn xem được. Ngoài ProviderScope (test)
  /// thì bỏ qua.
  void _prefetchIllustrations() {
    if (!mounted) return;
    try {
      final cache = ProviderScope.containerOf(context, listen: false).read(richImageCacheProvider);
      for (final t in widget.config.types) {
        for (final tok in t.illustrationTokens) {
          cache.load(tok).ignore();
        }
      }
    } catch (_) {}
  }

  /// Mở bảng toàn màn hình, ép xoay ngang; đóng thì trả về dọc rồi nhả cho máy tự xoay. Màn phóng to giữ BẢN SAO số đếm + gọi
  /// thẳng `onChanged` của phiếu — ô trong phiếu có bị dựng lại giữa chừng thì số gõ ở màn phóng to vẫn về phiếu.
  Future<void> _openFullscreen() async {
    FocusScope.of(context).unfocus();
    final nav = Navigator.of(context);
    DisplayMatrixCounts? ketQua;
    bool? baoCuoi; // cờ sai dạng màn phóng to báo phiếu lần cuối; null = không gõ gì
    try {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      ketQua = await nav.push<DisplayMatrixCounts>(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _MatrixFullscreen(
          config: _config,
          label: widget.label,
          counts: _counts,
          hints: _hints,
          onChanged: (c, invalid) {
            baoCuoi = invalid;
            _onChanged(c, invalid);
          },
        ),
      ));
    } finally {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      await SystemChrome.setPreferredOrientations(const []);
    }
    // Màn phóng to bị gỡ không qua nút Thu nhỏ (ketQua null) ⇒ phiếu giữ đúng cờ nó báo lần cuối, không đụng.
    if (!mounted || baoCuoi == null || ketQua == null) return;
    // Màn phóng to không cho đóng khi còn ô sai dạng ⇒ bộ số trả về là số đúng. Phiếu đang giữ cờ của lần gõ cuối ở màn phóng
    // to; báo lại theo trạng thái THẬT của bảng trong phiếu khi số đổi hoặc cờ lệch — không thì bước Lưu chặn "ô đếm nhập sai
    // dạng số" mà không ô nào hiện lỗi (#24698 vòng 4).
    final doiSo = !_sameCounts(ketQua, _counts);
    if (doiSo) {
      setState(() {
        _counts = ketQua!;
        _cellErr.clear();
        _resyncControllers();
      });
    }
    if (doiSo || baoCuoi != _hasInvalidCell) _onChanged(_counts, _hasInvalidCell);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final totals = DisplayMatrixTotals.compute(
        DisplayMatrixFieldWidget.withHints(_counts, DisplayMatrixFieldWidget.onlyAsked(_hints, cfg)), cfg);
    final muted = Theme.of(context).brightness == Brightness.dark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    final coHuongDan = cfg.types.any((t) => t.hasGuide);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormFieldLabel(label: widget.label, isRequired: widget.isRequired, description: widget.description),
        const SizedBox(height: kFormLabelGap),
        if (cfg.brands.isEmpty || cfg.types.isEmpty)
          Text(
            'Biểu mẫu chưa có thương hiệu hoặc loại trưng bày nào — báo quản trị.',
            style: AppTypography.bodySmall(color: AppColors.error),
          )
        else ...[
          if (coHuongDan)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('Bấm tên cột để xem ảnh minh hoạ / cách đếm', style: AppTypography.labelSmall(color: muted)),
            ),
          _table(keyPrefix: 'matrix', cellWidth: 104, totals: totals),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Row(
            children: [
              Expanded(child: _totalLine(totals)),
              if (cfg.brands.isNotEmpty && cfg.types.isNotEmpty)
                TextButton.icon(
                  key: ValueKey('matrix_${widget.fieldCode}_fullscreen'),
                  onPressed: _openFullscreen,
                  icon: const Icon(Icons.open_in_full_rounded, size: 18),
                  label: const Text('Phóng to'),
                ),
            ],
          ),
        ),
        for (final line in _errorLines) FormFieldErrorText(line),
        if (widget.photoSection != null)
          for (final t in cfg.types)
            if (t.maxPhotos > 0) Padding(padding: const EdgeInsets.only(bottom: 8), child: widget.photoSection!(t)),
        if (widget.errorText != null) FormFieldErrorText(widget.errorText!),
      ],
    );
  }
}

/// Màn PHÓNG TO: chỉ có bảng, xoay ngang (bên mở ép hướng). Ô nhập RIÊNG, số mỗi lần gõ đi thẳng `onChanged` của phiếu; đóng
/// thì trả bộ số cuối cho bảng trong phiếu ghi lại ô.
class _MatrixFullscreen extends StatefulWidget {
  final DisplayMatrixConfig config;
  final String label;
  final DisplayMatrixCounts counts;
  final DisplayMatrixCounts hints;
  final void Function(DisplayMatrixCounts counts, bool hasInvalidCell) onChanged;

  const _MatrixFullscreen({
    required this.config,
    required this.label,
    required this.counts,
    required this.onChanged,
    this.hints = const {},
  });

  @override
  State<_MatrixFullscreen> createState() => _MatrixFullscreenState();
}

class _MatrixFullscreenState extends State<_MatrixFullscreen> with _MatrixEditing<_MatrixFullscreen> {
  @override
  DisplayMatrixConfig get _config => widget.config;
  @override
  DisplayMatrixCounts get _hints => widget.hints;
  @override
  void Function(DisplayMatrixCounts counts, bool hasInvalidCell) get _onChanged => widget.onChanged;

  @override
  void initState() {
    super.initState();
    _counts = widget.counts;
  }

  /// Thu nhỏ — chặn khi còn ô gõ sai dạng: số đó không nằm trong bộ số trả về, bảng trong phiếu không hiện được nó ⇒ đóng
  /// là mất số mà không ai biết (#24698 vòng 4).
  void _dong() {
    if (_hasInvalidCell) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Còn ô nhập sai dạng số — sửa lại trước khi thu nhỏ.')));
      return;
    }
    Navigator.of(context).pop(_counts);
  }

  @override
  Widget build(BuildContext context) {
    final totals = DisplayMatrixTotals.compute(
        DisplayMatrixFieldWidget.withHints(_counts, DisplayMatrixFieldWidget.onlyAsked(_hints, _config)), _config);
    return PopScope<DisplayMatrixCounts>(
      canPop: false,
      // Nút Back của máy cũng trả bộ số về phiếu như nút Thu nhỏ.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _dong();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          leading: IconButton(
            key: const ValueKey('matrix_fullscreen_close'),
            icon: const Icon(Icons.close_fullscreen_rounded),
            tooltip: 'Thu nhỏ',
            onPressed: _dong,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _table(keyPrefix: 'matrix_full', cellWidth: 128, totals: totals),
                Padding(padding: const EdgeInsets.only(top: 6), child: _totalLine(totals)),
                for (final line in _errorLines) FormFieldErrorText(line),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// BẢNG nhập số: cột Thương hiệu ghim trái, cột Tổng (mặt + % SOS) ghim phải, giữa là các cột loại vuốt ngang.
///
/// ⚠️ Chiều cao dòng CỐ ĐỊNH ở cả ba khối — ba cột dựng riêng nên dòng chỉ thẳng hàng khi cùng chiều cao; tên thương hiệu dài
/// cắt sau 2 dòng, lỗi ô hiện dưới bảng (không trong ô).
class _MatrixTable extends StatefulWidget {
  final List<DisplayMatrixBrand> brands;
  final List<DisplayMatrixType> types;
  final DisplayMatrixTotals totals;
  final TextEditingController Function(String brand, String type) controller;
  final Map<String, String> cellErr;

  /// Số hiện trạng làm gợi ý mờ trong ô (rỗng = gợi ý "0").
  final DisplayMatrixCounts hints;
  final String keyPrefix;
  final double cellWidth;
  final void Function(String brand, DisplayMatrixType type, String text) onCell;
  final void Function(DisplayMatrixType type) onHeaderTap;

  const _MatrixTable({
    required this.brands,
    required this.types,
    required this.totals,
    required this.controller,
    required this.cellErr,
    this.hints = const {},
    required this.keyPrefix,
    required this.cellWidth,
    required this.onCell,
    required this.onHeaderTap,
  });

  @override
  State<_MatrixTable> createState() => _MatrixTableState();
}

class _MatrixTableState extends State<_MatrixTable> {
  static const double _headH = 56;
  static const double _rowH = 56;
  static const double _leftW = 112;
  static const double _rightW = 76;

  final ScrollController _h = ScrollController();

  @override
  void dispose() {
    _h.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final line = isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant;
    final muted = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    final onSurface = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
    final headBg = isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainer;
    final ownBg = AppColors.primaryContainer.withValues(alpha: isDark ? 0.22 : 0.16);
    final headStyle = AppTypography.labelSmall(color: muted).copyWith(fontWeight: FontWeight.w700);
    final w = widget;
    // Cỡ chữ hệ thống phóng to ⇒ nới chiều cao dòng theo (dòng cố định mà chữ to thì tràn, mất % SOS).
    final k = MediaQuery.textScalerOf(context).scale(14) / 14;
    final headH = _headH * (k < 1 ? 1 : k);
    final rowH = _rowH * (k < 1 ? 1 : k);
    return LayoutBuilder(
      builder: (context, box) {
        // Màn rộng (xoay ngang) mà ít cột ⇒ giãn cột loại cho kín bề ngang, khỏi khoảng trống trước cột Tổng.
        final cellWidth = w.types.isEmpty
            ? w.cellWidth
            : ((box.maxWidth - _leftW - _rightW - 2) / w.types.length).clamp(w.cellWidth, double.infinity).toDouble();

        Widget cell({
          required double width,
          required double height,
          Color? bg,
          required Widget child,
          Alignment align = Alignment.centerLeft,
        }) => Container(
          width: width,
          height: height,
          alignment: align,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: bg,
            border: Border(bottom: BorderSide(color: line)),
          ),
          child: child,
        );

        Color? rowBg(DisplayMatrixBrand b) => b.isOwn ? ownBg : null;

        final left = Column(
          children: [
            cell(
              width: _leftW,
              height: headH,
              bg: headBg,
              child: Text('THƯƠNG HIỆU', style: headStyle),
            ),
            for (final b in w.brands)
              cell(
                width: _leftW,
                height: rowH,
                bg: rowBg(b),
                child: Text(
                  b.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium(color: onSurface).copyWith(fontWeight: b.isOwn ? FontWeight.w700 : FontWeight.w500),
                ),
              ),
          ],
        );

        final middle = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (final t in w.types)
                  InkWell(
                    key: ValueKey('${w.keyPrefix}_head_${t.code}'),
                    onTap: t.hasGuide ? () => w.onHeaderTap(t) : null,
                    child: cell(
                      width: cellWidth,
                      height: headH,
                      bg: headBg,
                      align: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            t.name.toUpperCase(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: headStyle.copyWith(color: t.hasGuide ? AppColors.secondary : muted),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (t.unit.isNotEmpty) Text(t.unit, style: AppTypography.labelSmall(color: muted)),
                              if (t.illustrationTokens.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 3),
                                  child: Icon(Icons.image_outlined, size: 12, color: muted),
                                )
                              else if (t.hasGuide)
                                Padding(
                                  padding: const EdgeInsets.only(left: 3),
                                  child: Icon(Icons.info_outline_rounded, size: 12, color: muted),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            for (final b in w.brands)
              Row(
                children: [
                  for (final t in w.types)
                    cell(
                      width: cellWidth,
                      height: rowH,
                      bg: rowBg(b),
                      align: Alignment.center,
                      child: TextField(
                        key: ValueKey('${w.keyPrefix}_${b.code}_${t.code}'),
                        controller: w.controller(b.code, t.code),
                        keyboardType: TextInputType.numberWithOptions(decimal: t.decimals > 0),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(t.decimals > 0 ? r'[0-9.,]' : r'[0-9]'))],
                        textAlign: TextAlign.center,
                        textInputAction: TextInputAction.next,
                        style: formFieldTextStyle(isDark),
                        decoration: formFieldDecoration(
                          isDark: isDark,
                          hintText: w.hints[b.code]?[t.code] == null ? '0' : fmtMatrixNumber(w.hints[b.code]![t.code]!),
                        ).copyWith(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          enabledBorder: w.cellErr.containsKey('${b.code}::${t.code}')
                              ? OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.error),
                                )
                              : null,
                        ),
                        onChanged: (v) => w.onCell(b.code, t, v),
                      ),
                    ),
                ],
              ),
          ],
        );

        final right = Column(
          children: [
            cell(
              width: _rightW,
              height: headH,
              bg: headBg,
              align: Alignment.center,
              child: Text('TỔNG', style: headStyle),
            ),
            for (final b in w.brands)
              cell(
                width: _rightW,
                height: rowH,
                bg: rowBg(b),
                align: Alignment.center,
                // Số dài (gõ nhiều chữ số) ⇒ thu nhỏ chữ cho vừa ô, không xuống dòng — xuống dòng làm % SOS tràn sang dòng dưới.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    key: ValueKey('${w.keyPrefix}_total_${b.code}'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fmtMatrixNumber(w.totals.facesByBrand[b.code] ?? 0),
                        maxLines: 1,
                        softWrap: false,
                        style: AppTypography.bodyMedium(color: onSurface).copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (w.totals.sosOf(b.code) != null)
                        Text(
                          '${fmtMatrixPct(w.totals.sosOf(b.code)!)}%',
                          maxLines: 1,
                          softWrap: false,
                          style: AppTypography.labelSmall(color: muted),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: line),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: line)),
                ),
                child: left,
              ),
              Expanded(
                child: Scrollbar(
                  controller: _h,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _h,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 8),
                    child: middle,
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: line)),
                ),
                child: right,
              ),
            ],
          ),
        );
      },
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

/// Nhiều ảnh minh hoạ (06/11/2026): vuốt ngang xem từng ảnh, góc trên ghi "2/3" — người dùng biết là có nhiều ảnh (chủ hệ
/// thống bỏ dải thumbnail cùng ngày). Chụm hai ngón phóng to; đang phóng to thì khoá vuốt trang để kéo xem.
/// Kích thước CỐ ĐỊNH ([width] × [height]): hộp thoại đo bề ngang nội tại, PageView không trả lời được câu đó.
class _IllustrationGallery extends StatefulWidget {
  final List<String> tokens;
  final double width;
  final double height;

  const _IllustrationGallery({required this.tokens, required this.width, required this.height});

  @override
  State<_IllustrationGallery> createState() => _IllustrationGalleryState();
}

class _IllustrationGalleryState extends State<_IllustrationGallery> {
  final _page = PageController();
  int _index = 0;
  bool _zoomed = false;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              key: const ValueKey('matrix_guide_pages'),
              controller: _page,
              physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
              itemCount: widget.tokens.length,
              onPageChanged: (i) => setState(() {
                _index = i;
                _zoomed = false;
              }),
              itemBuilder: (_, i) => _ZoomableImage(
                token: widget.tokens[i],
                onZoomChanged: (z) {
                  if (z != _zoomed) setState(() => _zoomed = z);
                },
              ),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
              child: Text(
                '${_index + 1}/${widget.tokens.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Một trang ảnh trong [_IllustrationGallery] — chụm phóng to; báo lên khi đang phóng to (khoá vuốt trang).
class _ZoomableImage extends StatefulWidget {
  final String token;
  final ValueChanged<bool> onZoomChanged;

  const _ZoomableImage({required this.token, required this.onZoomChanged});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final _ctrl = TransformationController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InteractiveViewer(
        transformationController: _ctrl,
        maxScale: 4,
        onInteractionEnd: (_) => widget.onZoomChanged(_ctrl.value.getMaxScaleOnAxis() > 1.01),
        child: Center(child: RichImageView(token: widget.token)),
      );
}
