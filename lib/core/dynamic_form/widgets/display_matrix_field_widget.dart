import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../utils/string_utils.dart';
import '../../theme/app_typography.dart';
import '../../widgets/form_fields/form_field_parts.dart';
import '../../utils/rich_image_cache.dart' show richImageCacheProvider;
import '../../widgets/note_field_widget.dart' show RichImageView;

/// Một thương hiệu trong `config.matrix.brands` của ô Ma trận trưng bày (#24767).
class DisplayMatrixBrand {
  final String code;
  final String name;
  final bool isOwn;

  /// Thương hiệu GÕ TAY (ngoài danh mục, mã `x_…` — đợt 2, D2): chỉ sống trong phiếu / hồ sơ.
  final bool custom;

  /// `false` = dòng danh mục đã tắt / xoá (server gửi kèm chỉ để nhận số cũ) — không dùng để khớp tên gõ tay (hợp đồng §2).
  final bool active;

  const DisplayMatrixBrand({
    required this.code,
    required this.name,
    this.isOwn = false,
    this.custom = false,
    this.active = true,
  });
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

  /// Loại trưng bày GÕ TAY (mã `x_…`, đợt 2 — D3): một cột chung cho mọi thương hiệu, hệ số 1 mặt, ảnh tối thiểu 1 (D4).
  final bool custom;

  /// Như [DisplayMatrixBrand.active].
  final bool active;

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
    this.custom = false,
    this.active = true,
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
///
/// Đợt 2 (hợp đồng `API-MA-TRAN-SOS-DOT2-2026-11-19.md`): [withCustom] ghép thêm thương hiệu / loại GÕ TAY của giá trị đang
/// nhập — cấu hình HIỆU LỰC mà bảng, tổng / % SOS, kiểm số và khối ảnh đều dùng, nên mục gõ tay đi qua đúng luật của mục
/// danh mục.
class DisplayMatrixConfig {
  final List<DisplayMatrixBrand> brands;
  final List<DisplayMatrixType> types;

  /// Công tắc ô (D5, `config.matrix.photos_when_zero`): mọi loại có ảnh tối thiểu > 0 phải đủ ảnh dù loại đó toàn 0.
  final bool photosWhenZero;

  /// Số thương hiệu tối thiểu phải có số > 0 (`config.matrix.min_brands`, 19/11/2026); 0 = không bắt.
  final int minBrands;

  /// Đơn vị gợi ý cho loại gõ tay (`config.matrix.units`; server cũ không gửi ⇒ đơn vị của các loại danh mục).
  final List<String> units;

  /// Luật loại gõ tay (`config.matrix.custom_type`): số lẻ, ảnh tối thiểu / tối đa.
  final int customDecimals;
  final int customMinPhotos;
  final int customMaxPhotos;

  const DisplayMatrixConfig({
    this.brands = const [],
    this.types = const [],
    this.photosWhenZero = false,
    this.minBrands = 0,
    this.units = const [],
    this.customDecimals = 2,
    this.customMinPhotos = 1,
    this.customMaxPhotos = 10,
  });

  /// Cấu hình HIỆU LỰC: danh mục + mục gõ tay của [custom] (mã đã có trong danh mục thì bỏ qua — danh mục thắng).
  DisplayMatrixConfig withCustom(DisplayMatrixCustom custom) {
    if (custom.isEmpty) return this;
    final b = {for (final x in brands) x.code};
    final t = {for (final x in types) x.code};
    return DisplayMatrixConfig(
      brands: [
        ...brands,
        for (final x in custom.brands)
          if (!b.contains(x.code)) DisplayMatrixBrand(code: x.code, name: x.name, custom: true),
      ],
      types: [
        ...types,
        for (final x in custom.types)
          if (!t.contains(x.code))
            DisplayMatrixType(
              code: x.code,
              name: x.name,
              unit: x.unit,
              decimals: customDecimals,
              minPhotos: customMinPhotos,
              maxPhotos: customMaxPhotos,
              custom: true,
            ),
      ],
      photosWhenZero: photosWhenZero,
      minBrands: minBrands,
      units: units,
      customDecimals: customDecimals,
      customMinPhotos: customMinPhotos,
      customMaxPhotos: customMaxPhotos,
    );
  }

  /// Thương hiệu DANH MỤC ĐANG DÙNG trùng tên gõ [name] theo mã chuẩn hoá (§2: "kova" = "KOVA") — `null` nếu không trùng.
  DisplayMatrixBrand? catalogBrandNamed(String name) {
    final k = displayMatrixSlug(name);
    if (k.isEmpty) return null;
    return brands.where((b) => !b.custom && b.active && displayMatrixSlug(b.name) == k).firstOrNull;
  }

  /// Loại DANH MỤC trùng tên gõ [name] (cùng luật [catalogBrandNamed]).
  DisplayMatrixType? catalogTypeNamed(String name) {
    final k = displayMatrixSlug(name);
    if (k.isEmpty) return null;
    return types.where((t) => !t.custom && t.active && displayMatrixSlug(t.name) == k).firstOrNull;
  }

  /// Đọc từ `config` của ô (Map đã giải mã); thiếu/lạ ⇒ danh mục rỗng.
  static DisplayMatrixConfig fromConfig(Map? config) {
    final m = config?['matrix'];
    if (m is! Map) return const DisplayMatrixConfig();
    int i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    final ct = m['custom_type'] is Map ? m['custom_type'] as Map : const {};
    final types = [
      for (final t in (m['types'] is List ? m['types'] as List : const []))
        if (t is Map && t['code'] != null) t,
    ];
    final units = m['units'] is List
        ? [for (final u in m['units'] as List) if ('$u'.trim().isNotEmpty) '$u'.trim()]
        : ({for (final t in types) '${t['unit'] ?? ''}'.trim()}..remove('')).toList();
    return DisplayMatrixConfig(
      photosWhenZero: m['photos_when_zero'] == true,
      minBrands: m['min_brands'] == null ? 0 : i(m['min_brands']),
      units: units,
      customDecimals: ct['decimals'] == null ? 2 : i(ct['decimals']).clamp(0, 2),
      customMinPhotos: ct['min_photos'] == null ? 1 : i(ct['min_photos']),
      customMaxPhotos: ct['max_photos'] == null ? 10 : i(ct['max_photos']),
      brands: [
        for (final b in (m['brands'] is List ? m['brands'] as List : const []))
          if (b is Map && b['code'] != null)
            DisplayMatrixBrand(
              code: '${b['code']}',
              name: '${b['name'] ?? b['code']}',
              isOwn: b['is_own'] == true,
              active: b['active'] != false,
            ),
      ],
      types: [
        for (final t in types)
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
              active: t['active'] != false,
            ),
      ],
    );
  }
}

/// Tên gõ tay đã chuẩn hoá (hợp đồng §2): cắt hai đầu, gộp khoảng trắng liên tiếp, tối đa 60 ký tự.
String displayMatrixNormName(String name) {
  final s = name.trim().replaceAll(RegExp(r'\s+'), ' ');
  return s.length > 60 ? s.substring(0, 60).trimRight() : s;
}

/// Slug của tên (hợp đồng §2): chữ thường, bỏ dấu tiếng Việt (đ → d), bỏ HẾT ký tự ngoài `[a-z0-9]` (gộp liền — "Kô va" =
/// "KOVA" = `kova`), tối đa 40 ký tự. Chuỗi rỗng = tên không dùng được.
String displayMatrixSlug(String name) {
  final s = StringUtils.toUnaccentedLower(displayMatrixNormName(name)).replaceAll(RegExp(r'[^a-z0-9]+'), '');
  return s.length > 40 ? s.substring(0, 40) : s;
}

/// Mã mục gõ tay: `x_` + [displayMatrixSlug]; tên không dùng được ⇒ `null`. Server chuẩn hoá lại bằng đúng luật này.
String? displayMatrixCustomCode(String name) {
  final s = displayMatrixSlug(name);
  return s.isEmpty ? null : 'x_$s';
}

/// Trần kỹ thuật mỗi giá trị (hợp đồng §3) — server cũng chặn.
const int kDisplayMatrixMaxCustomBrands = 20;
const int kDisplayMatrixMaxCustomTypes = 10;

/// Thương hiệu / loại trưng bày GÕ TAY của MỘT giá trị ô ma trận — gửi lên ở khoá `custom` (hợp đồng §3), đọc lại từ `custom`
/// (bản nháp) và từ mục `custom: true` của `snapshot` (giá trị server đã lưu — §4).
class DisplayMatrixCustom {
  final List<({String code, String name})> brands;
  final List<({String code, String name, String unit})> types;

  const DisplayMatrixCustom({this.brands = const [], this.types = const []});

  bool get isEmpty => brands.isEmpty && types.isEmpty;

  /// Đọc từ giá trị ô: `custom.{brands,types}` trước, rồi mục `custom: true` của `snapshot`; trùng mã giữ bản đầu.
  static DisplayMatrixCustom fromValue(dynamic value) {
    if (value is! Map) return const DisplayMatrixCustom();
    final b = <String, ({String code, String name})>{};
    final t = <String, ({String code, String name, String unit})>{};
    void doc(dynamic list, bool fromSnap, bool isType) {
      if (list is! List) return;
      for (final x in list) {
        if (x is! Map || x['code'] == null || (fromSnap && x['custom'] != true)) continue;
        final code = '${x['code']}';
        if (!code.startsWith('x_')) continue;
        final name = displayMatrixNormName('${x['name'] ?? code}');
        if (isType) {
          t.putIfAbsent(code, () => (code: code, name: name, unit: '${x['unit'] ?? ''}'.trim()));
        } else {
          b.putIfAbsent(code, () => (code: code, name: name));
        }
      }
    }

    final c = value['custom'] is Map ? value['custom'] as Map : const {};
    final snap = value['snapshot'] is Map ? value['snapshot'] as Map : const {};
    doc(c['brands'], false, false);
    doc(snap['brands'], true, false);
    doc(c['types'], false, true);
    doc(snap['types'], true, true);
    return DisplayMatrixCustom(brands: b.values.toList(), types: t.values.toList());
  }

  /// Hợp hai bộ (trùng mã giữ bản của `this`).
  DisplayMatrixCustom merge(DisplayMatrixCustom other) {
    if (other.isEmpty) return this;
    final b = {for (final x in brands) x.code: x};
    final t = {for (final x in types) x.code: x};
    for (final x in other.brands) {
      b.putIfAbsent(x.code, () => x);
    }
    for (final x in other.types) {
      t.putIfAbsent(x.code, () => x);
    }
    return DisplayMatrixCustom(brands: b.values.toList(), types: t.values.toList());
  }

  /// Chỉ giữ mục được DÙNG trong [counts] / [photos] (mục gõ tay của hồ sơ mà phiếu không chạm thì khỏi gửi).
  DisplayMatrixCustom onlyUsed(DisplayMatrixCounts counts, Map photos) {
    final loai = <String>{for (final r in counts.values) ...r.keys, ...photos.keys.map((k) => '$k')};
    return DisplayMatrixCustom(
      brands: [for (final x in brands) if (counts.containsKey(x.code)) x],
      types: [for (final x in types) if (loai.contains(x.code)) x],
    );
  }

  /// Bỏ mục của [fromHints] (mục gõ tay của HỒ SƠ điểm bán) mà phiếu không dùng — mục người dùng tự thêm thì giữ.
  DisplayMatrixCustom minusUnused(DisplayMatrixCustom fromHints, DisplayMatrixCounts counts, Map photos) {
    final dung = onlyUsed(counts, photos);
    final b = {for (final x in fromHints.brands) x.code};
    final t = {for (final x in fromHints.types) x.code};
    return DisplayMatrixCustom(
      brands: [for (final x in brands) if (!b.contains(x.code) || dung.brands.any((y) => y.code == x.code)) x],
      types: [for (final x in types) if (!t.contains(x.code) || dung.types.any((y) => y.code == x.code)) x],
    );
  }

  DisplayMatrixCustom withoutBrand(String code) =>
      DisplayMatrixCustom(brands: [for (final x in brands) if (x.code != code) x], types: types);

  DisplayMatrixCustom withoutType(String code) =>
      DisplayMatrixCustom(brands: brands, types: [for (final x in types) if (x.code != code) x]);

  DisplayMatrixCustom withBrand(String code, String name) =>
      brands.any((x) => x.code == code) ? this : DisplayMatrixCustom(brands: [...brands, (code: code, name: name)], types: types);

  DisplayMatrixCustom withType(String code, String name, String unit) => types.any((x) => x.code == code)
      ? this
      : DisplayMatrixCustom(brands: brands, types: [...types, (code: code, name: name, unit: unit)]);

  /// Khoá `custom` gửi lên (hợp đồng §3).
  Map<String, dynamic> toJson() => {
        'brands': [for (final x in brands) {'code': x.code, 'name': x.name}],
        'types': [for (final x in types) {'code': x.code, 'name': x.name, 'unit': x.unit}],
      };
}

/// Giá trị ô ma trận có DỮ LIỆU (số hoặc ảnh). Giá trị chỉ mang `custom` (thêm thẻ / cột mà chưa nhập gì) giữ trong form để
/// bảng còn thẻ / cột, nhưng là ô RỖNG khi kiểm bắt buộc và khi gửi (server coi là rỗng).
bool displayMatrixHasData(dynamic value) {
  if (value is! Map) return false;
  final c = value['counts'];
  final p = value['photos'];
  return (c is Map && c.values.any((r) => r is Map && r.isNotEmpty)) ||
      (p is Map && p.values.any((l) => l is List && l.isNotEmpty));
}

/// Ghép giá trị ô ma trận để lưu / gửi: `{counts, photos}` + `custom` khi có mục gõ tay. Không số, không ảnh, không mục gõ
/// tay ⇒ `null` (ô rỗng).
Map<String, dynamic>? displayMatrixValue(DisplayMatrixCounts counts, Map photos, DisplayMatrixCustom custom) {
  if (counts.isEmpty && photos.isEmpty && custom.isEmpty) return null;
  return {
    'counts': counts,
    'photos': photos,
    if (!custom.isEmpty) 'custom': custom.toJson(),
  };
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

  /// Mục GÕ TAY của giá trị đang nhập (đợt 2) — [config] là cấu hình HIỆU LỰC đã ghép chúng ([DisplayMatrixConfig.withCustom]).
  final DisplayMatrixCustom custom;

  /// Báo thay đổi CẤU TRÚC (thêm / bỏ mục gõ tay, xoá một thương hiệu / loại cùng số của nó) — màn chứa ghép lại giá trị
  /// (`custom` + `counts`). `null` ⇒ bảng chỉ nhập số, không có nút thêm / xoá (giữ hành vi cũ).
  final void Function(DisplayMatrixCustom custom, DisplayMatrixCounts counts, bool hasInvalidCell)? onCustomChanged;

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
    this.custom = const DisplayMatrixCustom(),
    this.onCustomChanged,
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

  /// Lỗi ẢNH theo loại (cùng luật server — hợp đồng §5): quá `max_photos`; thiếu `min_photos` khi loại có số > 0, hoặc
  /// LUÔN thiếu khi bật `photos_when_zero`. [cfg] là cấu hình HIỆU LỰC (có loại gõ tay — tối thiểu 1). Ô hoàn toàn rỗng (không
  /// số, không ảnh) không bị đòi ảnh — bắt buộc hay không do luật "bắt buộc" của ô. Hợp lệ ⇒ `null`; lỗi ⇒ `"<loại>: …"`.
  static String? photosError(DisplayMatrixCounts counts, Map photos, DisplayMatrixConfig cfg) {
    if (counts.isEmpty && photos.values.every((l) => l is! List || l.isEmpty)) return null;
    for (final t in cfg.types) {
      final n = photos[t.code] is List ? (photos[t.code] as List).length : 0;
      if (t.maxPhotos > 0 && n > t.maxPhotos) return '${t.name}: tối đa ${t.maxPhotos} ảnh.';
      // Loại gõ tay chỉ xét khi ĐƯỢC DÙNG trong giá trị (có ô số — kể cả 0 — hoặc ảnh), như server.
      if (t.custom && n == 0 && !counts.values.any((r) => r.containsKey(t.code))) continue;
      final can = t.effectiveMinPhotos > 0 && (cfg.photosWhenZero || DisplayMatrixTotals.sumOfType(counts, t.code) > 0);
      if (can && n < t.effectiveMinPhotos) return '${t.name}: cần ít nhất ${t.effectiveMinPhotos} ảnh.';
    }
    return null;
  }

  /// Lỗi SỐ THƯƠNG HIỆU tối thiểu (cùng luật server): thương hiệu có ít nhất một ô > 0, tính cả "của ta" + gõ tay. [counts] là
  /// số HIỆU LỰC — phiếu cập nhật hồ sơ truyền số đã ghép số hiện trạng ([withHints]). Ô hoàn toàn rỗng không bị đòi. Hợp lệ ⇒ `null`.
  static String? brandsError(DisplayMatrixCounts counts, Map photos, DisplayMatrixConfig cfg) {
    if (cfg.minBrands <= 0) return null;
    if (counts.isEmpty && photos.values.every((l) => l is! List || l.isEmpty)) return null;
    final n = counts.values.where((r) => r.values.any((v) => v > 0)).length;
    return n < cfg.minBrands ? 'cần khai số cho ít nhất ${cfg.minBrands} thương hiệu (đang có $n).' : null;
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

  /// Hàng thương hiệu ĐANG hiện ("của ta" đứng đầu) — đợt 2: thương hiệu thêm dần, không phải cả danh mục.
  List<DisplayMatrixBrand> get _brandsShown;

  /// Xoá được hàng thương hiệu / cột loại không — `null` = bảng không có nút xoá (màn phóng to).
  bool Function(DisplayMatrixBrand b)? get _canRemoveBrand => null;
  bool Function(DisplayMatrixType t)? get _canRemoveType => null;
  void Function(String code)? get _removeBrand => null;
  void Function(String code)? get _removeType => null;
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
                          // Bề ngang nội dung hộp thoại: màn dọc hẹp hơn 80% màn (lề hộp thoại 40 + đệm 24 mỗi bên).
                          width: math.max(80.0, math.min(MediaQuery.sizeOf(ctx).width * 0.8, MediaQuery.sizeOf(ctx).width - 128)),
                          // Chừa chỗ khung hộp thoại (tiêu đề, nút, lề) + câu hướng dẫn: màn ngang ~380px mà lấy nửa màn thì
                          // câu hướng dẫn trôi khỏi tầm nhìn (đo ảnh chụp 06/11/2026).
                          height: (MediaQuery.sizeOf(ctx).height - 270)
                              .clamp(math.min(140.0, MediaQuery.sizeOf(ctx).height * 0.5), MediaQuery.sizeOf(ctx).height * 0.5),
                        ),
                ),
              if ((type.hint ?? '').trim().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(type.hint!.trim())),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Đã hiểu'))],
      ),
    );
  }

  /// Bảng nhập ([keyPrefix] khác nhau giữa phiếu và màn phóng to: hai bảng cùng nằm trong cây khi màn phóng to mở).
  Widget _table({required String keyPrefix, required double cellWidth, required DisplayMatrixTotals totals}) => _MatrixTable(
        brands: _brandsShown,
        canRemoveBrand: _canRemoveBrand,
        canRemoveType: _canRemoveType,
        onRemoveBrand: _removeBrand,
        onRemoveType: _removeType,
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

  /// Thương hiệu DANH MỤC người dùng vừa thêm (chưa gõ số nên chưa có trong [_counts]).
  final Set<String> _added = {};

  /// D1: hàng hiện = "của ta" + thương hiệu đã có số (giá trị / hiện trạng) + thương hiệu gõ tay + thương hiệu vừa thêm. Bảng
  /// không sửa được cấu trúc (không có nút thêm) hiện ĐỦ danh mục như trước.
  @override
  List<DisplayMatrixBrand> get _brandsShown {
    bool hien(DisplayMatrixBrand b) =>
        !_editable ||
        b.custom || _added.contains(b.code) || _counts.containsKey(b.code) || _hints.containsKey(b.code);
    return [..._config.brands.where((b) => b.isOwn), ..._config.brands.where((b) => !b.isOwn && hien(b))];
  }

  /// Thương hiệu danh mục còn có thể thêm.
  List<DisplayMatrixBrand> get _brandsAddable {
    final hien = {for (final b in _brandsShown) b.code};
    return [for (final b in _config.brands) if (!b.custom && b.active && !hien.contains(b.code)) b];
  }

  bool get _editable => widget.onCustomChanged != null;

  /// Hàng có số HIỆN TRẠNG (hồ sơ điểm bán) không xoá được: ô trống giữ số cũ khi nộp — muốn gỡ thì gõ 0.
  @override
  bool Function(DisplayMatrixBrand b)? get _canRemoveBrand =>
      _editable ? (b) => !b.isOwn && !_hints.containsKey(b.code) : null;

  /// Chỉ cột loại GÕ TAY, và không phải cột đang mang số hiện trạng của hồ sơ (ô trống giữ số cũ — gỡ cột không xoá được số).
  @override
  bool Function(DisplayMatrixType t)? get _canRemoveType =>
      _editable ? (t) => t.custom && !_hints.values.any((r) => r.containsKey(t.code)) : null;

  @override
  void Function(String code)? get _removeBrand => _editable ? _xoaThuongHieu : null;

  @override
  void Function(String code)? get _removeType => _editable ? _xoaLoai : null;

  /// Bỏ controller của hàng / cột vừa xoá — ô khác giữ nguyên chữ đang gõ (kể cả chữ sai dạng đang báo lỗi).
  void _dropControllers(bool Function(String key) bo) {
    final cu = [for (final k in _ctrl.keys.where(bo).toList()) _ctrl.remove(k)!];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in cu) {
        c.dispose();
      }
    });
  }

  void _baoCauTruc(DisplayMatrixCustom custom, DisplayMatrixCounts counts) =>
      widget.onCustomChanged?.call(custom, counts, _hasInvalidCell);

  void _xoaThuongHieu(String code) {
    final next = {for (final e in _counts.entries) if (e.key != code) e.key: Map.of(e.value)};
    setState(() {
      _added.remove(code);
      _counts = next;
      _cellErr.removeWhere((k, _) => k.startsWith('$code::'));
      _dropControllers((k) => k.startsWith('$code::'));
    });
    _baoCauTruc(widget.custom.withoutBrand(code), next);
  }

  void _xoaLoai(String code) {
    final next = <String, Map<String, num>>{};
    _counts.forEach((b, row) {
      final r = {for (final e in row.entries) if (e.key != code) e.key: e.value};
      if (r.isNotEmpty) next[b] = r;
    });
    setState(() {
      _counts = next;
      _cellErr.removeWhere((k, _) => k.endsWith('::$code'));
      _dropControllers((k) => k.endsWith('::$code'));
    });
    _baoCauTruc(widget.custom.withoutType(code), next);
  }

  void _thongBao(String text) => ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// "+ Thêm thương hiệu": danh sách thương hiệu danh mục còn lại + "Nhập tên khác…".
  Future<void> _themThuongHieu() async {
    FocusScope.of(context).unfocus();
    final chon = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final b in _brandsAddable)
              ListTile(key: ValueKey('matrix_add_brand_${b.code}'), title: Text(b.name), onTap: () => Navigator.of(ctx).pop(b.code)),
            ListTile(
              key: const ValueKey('matrix_add_brand_other'),
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Nhập tên khác…'),
              onTap: () => Navigator.of(ctx).pop(''),
            ),
          ],
        ),
      ),
    );
    if (!mounted || chon == null) return;
    if (chon.isNotEmpty) {
      setState(() => _added.add(chon));
      return;
    }
    final ten = await _hoiTen(tieuDe: 'Thêm thương hiệu', nhan: 'Tên thương hiệu');
    if (!mounted || ten == null) return;
    // Trùng thương hiệu danh mục theo tên chuẩn hoá ⇒ chọn thương hiệu đó (hợp đồng §2).
    final trung = _config.catalogBrandNamed(ten.name);
    if (trung != null) {
      setState(() => _added.add(trung.code));
      return;
    }
    final code = displayMatrixCustomCode(ten.name);
    if (code == null) return _thongBao('Tên thương hiệu không hợp lệ.');
    // Trùng mục gõ tay ĐÃ CÓ (kể cả mục đã lưu mang mã cũ) ⇒ dùng nguyên mục đó, không sinh mã mới (§2).
    final daCo = widget.custom.brands.where((x) => x.code == code || displayMatrixSlug(x.name) == code.substring(2)).firstOrNull;
    if (daCo != null) {
      setState(() => _added.add(daCo.code));
      return;
    }
    if (widget.custom.brands.length >= kDisplayMatrixMaxCustomBrands) {
      return _thongBao('Tối đa $kDisplayMatrixMaxCustomBrands thương hiệu ngoài danh mục.');
    }
    _baoCauTruc(widget.custom.withBrand(code, displayMatrixNormName(ten.name)), _counts);
  }

  /// "+ Thêm loại trưng bày khác": tên + đơn vị ⇒ một cột chung cho mọi thương hiệu.
  Future<void> _themLoai() async {
    FocusScope.of(context).unfocus();
    final ten = await _hoiTen(tieuDe: 'Thêm loại trưng bày khác', nhan: 'Tên loại trưng bày', donVi: _config.units);
    if (!mounted || ten == null) return;
    final trung = _config.catalogTypeNamed(ten.name);
    if (trung != null) return _thongBao('"${trung.name}" đã có trong bảng.');
    final code = displayMatrixCustomCode(ten.name);
    if (code == null) return _thongBao('Tên loại trưng bày không hợp lệ.');
    final daCo = widget.custom.types.where((x) => x.code == code || displayMatrixSlug(x.name) == code.substring(2)).firstOrNull;
    if (daCo != null) return _thongBao('"${daCo.name}" đã có trong bảng.');
    if (widget.custom.types.length >= kDisplayMatrixMaxCustomTypes) {
      return _thongBao('Tối đa $kDisplayMatrixMaxCustomTypes loại trưng bày ngoài danh mục.');
    }
    _baoCauTruc(widget.custom.withType(code, displayMatrixNormName(ten.name), ten.unit), _counts);
  }

  /// Hộp nhập tên (và đơn vị khi có [donVi]) — trả `null` khi huỷ.
  Future<({String name, String unit})?> _hoiTen({required String tieuDe, required String nhan, List<String>? donVi}) =>
      showDialog<({String name, String unit})>(
        context: context,
        builder: (ctx) => _NameUnitDialog(title: tieuDe, label: nhan, units: donVi),
      );

  @override
  void initState() {
    super.initState();
    _counts = DisplayMatrixFieldWidget.onlyAsked(widget.counts, widget.config);
    // Hàng đang có số thì giữ hiện cả khi người dùng xoá trống hết ô của nó giữa lúc gõ.
    _added.addAll(_counts.keys);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefetchIllustrations());
  }

  @override
  void didUpdateWidget(DisplayMatrixFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final moi = DisplayMatrixFieldWidget.onlyAsked(widget.counts, widget.config);
    // Số do CHÍNH ô này gõ quay về y hệt ⇒ giữ nguyên (ô đang gõ dở "2," không bị viết lại); khác ⇒ đổi từ ngoài, ghi lại ô.
    if (!_sameCounts(moi, _counts)) {
      _counts = moi;
      _added.addAll(moi.keys);
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
    final hang = _brandsShown;
    try {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      ketQua = await nav.push<DisplayMatrixCounts>(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _MatrixFullscreen(
          config: _config,
          brands: hang,
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
        if (!cfg.brands.any((b) => !b.custom) || !cfg.types.any((t) => !t.custom))
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
          if (_editable)
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  key: ValueKey('matrix_${widget.fieldCode}_add_brand'),
                  onPressed: _themThuongHieu,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Thêm thương hiệu'),
                ),
                TextButton.icon(
                  key: ValueKey('matrix_${widget.fieldCode}_add_type'),
                  onPressed: _themLoai,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Thêm loại trưng bày khác'),
                ),
              ],
            ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Row(
            children: [
              Expanded(child: _totalLine(totals)),
              if (_brandsShown.isNotEmpty && cfg.types.isNotEmpty)
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

  /// Hàng thương hiệu đang hiện trong phiếu lúc mở (thêm / xoá hàng chỉ làm ở bảng trong phiếu).
  final List<DisplayMatrixBrand> brands;
  final String label;
  final DisplayMatrixCounts counts;
  final DisplayMatrixCounts hints;
  final void Function(DisplayMatrixCounts counts, bool hasInvalidCell) onChanged;

  const _MatrixFullscreen({
    required this.config,
    required this.brands,
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
  List<DisplayMatrixBrand> get _brandsShown => widget.brands;

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

  /// Hàng nào có nút xoá + việc xoá; cột loại GÕ TAY có nút gỡ ([onRemoveType]). `null` = không có nút.
  final bool Function(DisplayMatrixBrand b)? canRemoveBrand;
  final bool Function(DisplayMatrixType t)? canRemoveType;
  final void Function(String code)? onRemoveBrand;
  final void Function(String code)? onRemoveType;
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
    this.canRemoveBrand,
    this.canRemoveType,
    this.onRemoveBrand,
    this.onRemoveType,
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
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        b.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium(color: onSurface).copyWith(
                          fontWeight: b.isOwn ? FontWeight.w700 : FontWeight.w500,
                          fontStyle: b.custom ? FontStyle.italic : null,
                        ),
                      ),
                    ),
                    if (w.onRemoveBrand != null && (w.canRemoveBrand?.call(b) ?? false))
                      InkWell(
                        key: ValueKey('${w.keyPrefix}_remove_brand_${b.code}'),
                        onTap: () => w.onRemoveBrand!(b.code),
                        child: Icon(Icons.close_rounded, size: 16, color: muted),
                      ),
                  ],
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
                              if (w.onRemoveType != null && (w.canRemoveType?.call(t) ?? false))
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: InkWell(
                                    key: ValueKey('${w.keyPrefix}_remove_type_${t.code}'),
                                    onTap: () => w.onRemoveType!(t.code),
                                    child: Icon(Icons.close_rounded, size: 14, color: muted),
                                  ),
                                ),
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
/// Bề ngang CỐ ĐỊNH ([width]): hộp thoại đo bề ngang nội tại, PageView không trả lời được câu đó. Chiều cao CO theo ảnh (ảnh
/// cao nhất, không vượt [height]) — khung cố định nửa màn thì ảnh lơ lửng giữa khoảng trống, câu hướng dẫn bị đẩy xa (chủ hệ
/// thống 06/11/2026: "đẩy text lên").
class _IllustrationGallery extends ConsumerStatefulWidget {
  final List<String> tokens;
  final double width;
  final double height;

  const _IllustrationGallery({required this.tokens, required this.width, required this.height});

  @override
  ConsumerState<_IllustrationGallery> createState() => _IllustrationGalleryState();
}

class _IllustrationGalleryState extends ConsumerState<_IllustrationGallery> {
  final _page = PageController();
  int _index = 0;
  bool _zoomed = false;

  /// Tỉ lệ rộng/cao NHỎ nhất (ảnh "cao" nhất) trong các ảnh đọc được; `null` = chưa đọc xong ⇒ tạm dùng trần [height].
  double? _minAspect;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  /// Đọc kích thước ảnh từ PHẦN ĐẦU tệp (ImageDescriptor — không giải mã cả ảnh) — ảnh đã có trong bộ đệm nhờ tải trước.
  Future<void> _measure() async {
    final cache = ref.read(richImageCacheProvider);
    double? min;
    for (final token in widget.tokens) {
      try {
        final file = await cache.load(token);
        if (file == null) continue;
        final buf = await ui.ImmutableBuffer.fromUint8List(await file.readAsBytes());
        final desc = await ui.ImageDescriptor.encoded(buf);
        if (desc.width > 0 && desc.height > 0) {
          final a = desc.width / desc.height;
          if (min == null || a < min) min = a;
        }
        desc.dispose();
        buf.dispose();
      } catch (_) {}
    }
    if (mounted && min != null) setState(() => _minAspect = min);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // KHÔNG LayoutBuilder: hộp thoại hỏi kích thước nội tại, LayoutBuilder không trả lời được ⇒ tính từ [width] (nơi gọi đưa bề
    // ngang thật của nội dung hộp thoại); +8 = lề dọc của RichImageView.
    final a = _minAspect;
    final h = a == null ? widget.height : math.min(widget.height, widget.width / a + 8);
    return SizedBox(key: const ValueKey('matrix_guide_gallery'), width: widget.width, height: h, child: _pages());
  }

  Widget _pages() {
    return Stack(
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

/// Hộp nhập tên mục gõ tay (+ đơn vị khi [units] khác `null`): đơn vị chọn nhanh từ gợi ý hoặc gõ đơn vị khác.
class _NameUnitDialog extends StatefulWidget {
  final String title;
  final String label;
  final List<String>? units;

  const _NameUnitDialog({required this.title, required this.label, this.units});

  @override
  State<_NameUnitDialog> createState() => _NameUnitDialogState();
}

class _NameUnitDialogState extends State<_NameUnitDialog> {
  final _ten = TextEditingController();
  final _donVi = TextEditingController();
  String? _loi;

  @override
  void dispose() {
    _ten.dispose();
    _donVi.dispose();
    super.dispose();
  }

  void _xong() {
    final ten = displayMatrixNormName(_ten.text);
    final donVi = _donVi.text.trim();
    if (displayMatrixSlug(ten).isEmpty) return setState(() => _loi = 'Nhập tên.');
    if (widget.units != null && donVi.isEmpty) return setState(() => _loi = 'Chọn hoặc nhập đơn vị.');
    Navigator.of(context).pop((name: ten, unit: donVi.length > 20 ? donVi.substring(0, 20) : donVi));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                key: const ValueKey('matrix_name_input'),
                controller: _ten,
                autofocus: true,
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: widget.label),
              ),
              if (widget.units != null) ...[
                TextField(
                  key: const ValueKey('matrix_unit_input'),
                  controller: _donVi,
                  maxLength: 20,
                  decoration: const InputDecoration(labelText: 'Đơn vị (tấm, ô, m²…)'),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final u in widget.units!)
                      ActionChip(label: Text(u), onPressed: () => setState(() => _donVi.text = u)),
                  ],
                ),
              ],
              if (_loi != null) Padding(padding: const EdgeInsets.only(top: 6), child: FormFieldErrorText(_loi!)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Huỷ')),
          FilledButton(key: const ValueKey('matrix_name_ok'), onPressed: _xong, child: const Text('Thêm')),
        ],
      );
}
