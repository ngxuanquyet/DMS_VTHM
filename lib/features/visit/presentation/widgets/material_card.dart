import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_fullscreen_image_viewer.dart';
import '../../../forms/domain/entities/market_form_entity.dart';
import '../../data/models/visit_material_model.dart';
import 'material_condition_badges.dart';

/// Trạng thái hiển thị của một thẻ vật tư.
enum MaterialCardStatus {
  /// Loại bắt buộc chưa kiểm/khai — viền nét đứt, màu cảnh báo.
  required,

  /// Đã có tại điểm, lượt này chưa kiểm.
  pending,

  /// Đã kiểm trong lượt này / đã khai lúc tạo.
  checked,

  /// Không gắn nhãn trạng thái (màn tạo điểm bán, dòng đã khai).
  none,
}

/// Thẻ một loại vật tư — DÙNG CHUNG cho mục Vật tư của lượt viếng thăm và bước Vật tư của form tạo điểm bán:
/// tổng số lượng + thanh tỉ lệ + số theo từng tình trạng, tối đa [maxDetailRows] ô chi tiết đã điền (nhãn theo biểu mẫu
/// chi tiết của loại), dải ảnh (chạm xem to), chân thẻ người/ngày kiểm.
///
/// [counts] null = chưa khai (thẻ rỗng); tổng 0 = "không có tại điểm" (thẻ mờ một dòng).
/// [collapsible] = thẻ mở ra ở dạng thu gọn (tên + trạng thái + tổng số), nút mũi tên xuống để xem đủ.
class MaterialCard extends StatefulWidget {
  final AppStrings strings;
  final OutletMaterialType type;
  final List<MaterialCondition> conditions;
  final Map<String, int>? counts;
  final Map<String, dynamic>? details;
  final List<MaterialPhoto> photos;
  final MaterialCardStatus status;
  final String? footer;
  final VoidCallback onTap;

  /// Nút bên phải tiêu đề (vd ✕ bỏ khai ở màn tạo); null = nhãn trạng thái.
  final Widget? action;

  /// Gộp chi tiết thành 1–2 dòng "Nhãn: giá trị · …" (màn tạo điểm bán).
  final bool compactDetails;

  /// Thu gọn mặc định, nút mũi tên mở/đóng phần chi tiết (mục Vật tư của lượt viếng thăm).
  final bool collapsible;

  static const int maxDetailRows = 3;
  static const int maxPhotoThumbs = 4;

  const MaterialCard({
    super.key,
    required this.strings,
    required this.type,
    required this.conditions,
    required this.counts,
    required this.status,
    required this.onTap,
    this.details,
    this.photos = const [],
    this.footer,
    this.action,
    this.compactDetails = false,
    this.collapsible = false,
  });

  @override
  State<MaterialCard> createState() => _MaterialCardState();
}

class _MaterialCardState extends State<MaterialCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final type = widget.type;
    final conditions = widget.conditions;
    final counts = widget.counts;
    final details = widget.details;
    final photos = widget.photos;
    final status = widget.status;
    final footer = widget.footer;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
    final subColor = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    final positive = Map<String, int>.from(counts ?? const {})..removeWhere((_, n) => n <= 0);
    final total = positive.values.fold<int>(0, (a, b) => a + b);
    final declared = counts != null;
    final notPresent = declared && total == 0;
    final isRequired = status == MaterialCardStatus.required;
    final hasMore = (declared && !notPresent) || (footer != null && footer.isNotEmpty);
    final collapsed = widget.collapsible && hasMore && !_expanded;

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.inventory_2_outlined, size: 20, color: isRequired ? AppColors.warning : AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            type.name,
            style: AppTypography.titleMedium(color: textColor).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        widget.action ?? _statusChip(strings, status),
        if (widget.collapsible && hasMore)
          IconButton(
            tooltip: _expanded ? strings.materialsCollapse : strings.materialsExpand,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
            style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            icon: AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.keyboard_arrow_down_rounded, color: subColor),
            ),
            onPressed: () => setState(() => _expanded = !_expanded),
          ),
      ],
    );

    final children = <Widget>[header];
    if (!declared) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 6, left: 28),
        child: Text(strings.materialsTapToDeclare, style: TextStyle(fontSize: 12, color: subColor)),
      ));
    } else if (notPresent) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 4, left: 28),
        child: Text(strings.materialsNotPresent, style: TextStyle(fontSize: 12, color: subColor)),
      ));
    } else if (collapsed) {
      // Thu gọn: chỉ dòng tổng số lượng — thanh tình trạng, chi tiết, ảnh, người kiểm hiện khi bấm mũi tên.
      children.add(Padding(
        padding: const EdgeInsets.only(top: 4, left: 28),
        child: Text(
          strings.materialsCount(total, type.unit),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor),
        ),
      ));
    } else {
      children.addAll([
        const SizedBox(height: 8),
        Text(
          strings.materialsCount(total, type.unit),
          style: AppTypography.titleMedium(color: textColor).copyWith(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        _ConditionBar(counts: positive, conditions: conditions),
        const SizedBox(height: 6),
        _ConditionLegend(counts: positive, conditions: conditions),
      ]);
      final rows = materialDetailRows(type, details, strings);
      if (rows.isNotEmpty) {
        children.addAll([const SizedBox(height: 8), Divider(height: 1, color: subColor.withValues(alpha: 0.2))]);
        children.add(widget.compactDetails ? _compactDetails(rows, textColor, subColor) : _detailTable(rows, strings, textColor, subColor));
      }
    }
    if (!collapsed && photos.isNotEmpty && !notPresent) {
      children.addAll([const SizedBox(height: 8), _PhotoStrip(photos: photos, title: type.name)]);
    }
    if (!collapsed && footer != null && footer.isNotEmpty) {
      children.addAll([
        const SizedBox(height: 6),
        Text(footer, style: TextStyle(fontSize: 11, color: subColor)),
      ]);
    }

    final content = Padding(
      padding: const EdgeInsets.all(12),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          child: CustomPaint(
            foregroundPainter: isRequired ? _DashedBorderPainter(color: AppColors.warning) : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: isRequired
                    ? null
                    : Border.all(color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
              ),
              child: Opacity(opacity: notPresent ? 0.6 : 1, child: content),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(AppStrings strings, MaterialCardStatus status) {
    final (IconData? icon, String text, Color color) = switch (status) {
      MaterialCardStatus.required => (Icons.warning_amber_rounded, strings.materialsRequired, AppColors.warning),
      MaterialCardStatus.checked => (Icons.check_circle_rounded, strings.materialsCheckedThisVisit, AppColors.success),
      MaterialCardStatus.pending => (null, strings.materialsPending, AppColors.outline),
      MaterialCardStatus.none => (null, '', AppColors.outline),
    };
    if (text.isEmpty) return const Icon(Icons.chevron_right, color: AppColors.outline);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
        Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  Widget _detailTable(List<MapEntry<String, String>> rows, AppStrings strings, Color textColor, Color subColor) {
    final shown = rows.take(MaterialCard.maxDetailRows).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 2, child: Text(r.key, style: TextStyle(fontSize: 12, color: subColor))),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Text(r.value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
                ),
              ]),
            ),
          if (rows.length > MaterialCard.maxDetailRows)
            Text(strings.materialsMoreDetails(rows.length - MaterialCard.maxDetailRows),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _compactDetails(List<MapEntry<String, String>> rows, Color textColor, Color subColor) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          rows.map((r) => '${r.key}: ${r.value}').join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: textColor),
        ),
      );
}

/// Các ô chi tiết ĐÃ ĐIỀN theo thứ tự biểu mẫu của loại: `nhãn → giá trị hiển thị` (lựa chọn ra NHÃN, không ra mã;
/// có/không ra chữ). Ô trống, ô ảnh/tệp bị bỏ. Biểu mẫu không còn ô đó (đã sửa) ⇒ hiện theo mã ô.
List<MapEntry<String, String>> materialDetailRows(OutletMaterialType type, Map<String, dynamic>? details, AppStrings strings) {
  if (details == null || details.isEmpty) return const [];
  final blocks = {for (final b in type.detailBlocks) b.resolved.code: b};
  final order = [...blocks.keys, ...details.keys.where((k) => !blocks.containsKey(k))];
  final out = <MapEntry<String, String>>[];
  for (final code in order) {
    if (code.startsWith('_')) continue;
    final block = blocks[code];
    final type = block?.resolved.inputType.toLowerCase() ?? '';
    if (block != null && (block.isImage || type == 'file')) continue;
    // Không có schema (loại đã gỡ khỏi danh mục): danh sách token/đường dẫn ảnh không phải thông tin để đọc.
    final raw = details[code];
    if (block == null && raw is List && raw.isNotEmpty && raw.every((e) => _looksLikePhoto('$e'))) {
      continue;
    }
    final text = _displayValue(details[code], block?.resolved, strings);
    if (text.isEmpty) continue;
    final label = block?.resolved.label ?? '';
    out.add(MapEntry(label.isNotEmpty ? label : code, text));
  }
  return out;
}

/// Token ảnh đã tải lên hoặc đường dẫn tệp trên máy — KHÔNG phải mọi chuỗi có "/" ("60x90/cm", "12/10").
bool _looksLikePhoto(String s) =>
    isPhotoToken(s) || s.startsWith('/') || s.startsWith('file:') || s.startsWith('content:');

String _displayValue(dynamic v, MarketFormResolvedEntity? field, AppStrings strings) {
  if (v == null) return '';
  String one(dynamic x) {
    final s = x.toString();
    for (final o in field?.options ?? const <MarketFormOptionEntity>[]) {
      if (o.value == s) return o.label;
    }
    return s;
  }

  if (v is bool) return v ? strings.materialsYes : strings.materialsNo;
  if (v is List) return v.where((e) => e != null && e.toString().isNotEmpty).map(one).join(', ');
  if (v is Map) return '';
  // 5.0 từ JSON hiện "5"; ô có/không lưu dạng chuỗi vẫn ra Có/Không.
  if (v is double && v == v.roundToDouble()) return v.toInt().toString();
  final s = v.toString().trim();
  const boolTypes = {'checkbox', 'boolean', 'switch', 'toggle'};
  if (boolTypes.contains(field?.inputType.toLowerCase()) && field!.options.isEmpty) {
    if (s == 'true' || s == '1') return strings.materialsYes;
    if (s == 'false' || s == '0') return strings.materialsNo;
  }
  return s.isEmpty ? '' : one(s);
}

/// Thanh ngang chia tỉ lệ theo tình trạng (màu danh mục).
class _ConditionBar extends StatelessWidget {
  final Map<String, int> counts;
  final List<MaterialCondition> conditions;

  const _ConditionBar({required this.counts, required this.conditions});

  @override
  Widget build(BuildContext context) {
    final segs = <Widget>[];
    for (final c in conditions) {
      final n = counts[c.code] ?? 0;
      if (n > 0) segs.add(Expanded(flex: n, child: Container(color: conditionColor(c.color))));
    }
    // Mã tình trạng đã gỡ khỏi danh mục vẫn chiếm phần của nó.
    final known = conditions.map((c) => c.code).toSet();
    final other = counts.entries.where((e) => !known.contains(e.key)).fold<int>(0, (a, e) => a + e.value);
    if (other > 0) segs.add(Expanded(flex: other, child: Container(color: conditionColor('secondary'))));
    if (segs.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(height: 8, child: Row(children: segs)),
    );
  }
}

/// Chú giải "● Tốt 4  ● Hỏng nhẹ 1" — chữ đầy đủ, không chỉ chấm màu.
class _ConditionLegend extends StatelessWidget {
  final Map<String, int> counts;
  final List<MaterialCondition> conditions;

  const _ConditionLegend({required this.counts, required this.conditions});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
    final known = {for (final c in conditions) c.code: c};
    final items = <Widget>[];
    void add(String name, String color, int n) => items.add(Row(mainAxisSize: MainAxisSize.min, children: [
          ConditionDot(color: conditionColor(color)),
          const SizedBox(width: 4),
          Text('$name $n', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
        ]));
    for (final c in conditions) {
      final n = counts[c.code] ?? 0;
      if (n > 0) add(c.name, c.color, n);
    }
    counts.forEach((code, n) {
      if (!known.containsKey(code) && n > 0) add(code, 'secondary', n);
    });
    return Wrap(spacing: 12, runSpacing: 4, children: items);
  }
}

/// Dải ảnh thu nhỏ (tối đa [MaterialCard.maxPhotoThumbs], ô cuối "+N"); chạm mở trình xem toàn màn.
class _PhotoStrip extends StatelessWidget {
  final List<MaterialPhoto> photos;
  final String title;

  const _PhotoStrip({required this.photos, required this.title});

  @override
  Widget build(BuildContext context) {
    final items = photos
        .map((p) => FullScreenImageItem(url: p.url.isEmpty ? null : p.url, filePath: p.localPath, title: title))
        .toList();
    final shown = photos.take(MaterialCard.maxPhotoThumbs).toList();
    final more = photos.length - shown.length;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < shown.length; i++)
          GestureDetector(
            onTap: () => AppFullScreenImageViewer.open(context, items: items, initialIndex: i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(children: [
                SizedBox(width: 60, height: 60, child: _thumb(context, items[i])),
                if (more > 0 && i == shown.length - 1)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: Text('+$more',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _thumb(BuildContext context, FullScreenImageItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final broken = ColoredBox(
      color: isDark ? AppColors.darkOutlineVariant : AppColors.surfaceContainerHigh,
      child: const Icon(Icons.image_not_supported_outlined, color: AppColors.outline),
    );
    // Không `existsSync` trong build (I/O chặn luồng giao diện) — tệp mất thì errorBuilder lo.
    final url = item.resolvedUrl;
    Widget network() =>
        url == null ? broken : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => broken);
    final path = item.filePath;
    if (path != null && path.isNotEmpty) {
      // Tệp máy đã dọn sau khi tải lên ⇒ thử bản trên server.
      return Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => network());
    }
    return network();
  }
}

/// Viền nét đứt bo góc — thẻ loại bắt buộc chưa kiểm.
class _DashedBorderPainter extends CustomPainter {
  final Color color;

  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}
