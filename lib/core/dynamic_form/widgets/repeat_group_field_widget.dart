import 'dart:convert';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/geo_select_field_widget.dart';
import '../choice_other.dart';
import '../models/dynamic_form_field.dart';
import '../repeat_group.dart';
import 'boolean_field_widget.dart';
import 'datetime_field_widget.dart';
import 'dynamic_form_field_wrapper.dart';
import 'long_text_field_widget.dart';
import 'multiple_choice_field_widget.dart';
import 'number_field_widget.dart';
import 'single_choice_field_widget.dart';
import 'text_field_widget.dart';

/// Ô NHÓM TRƯỜNG LẶP (`group_table`) — DANH SÁCH THẺ (chốt 19/11/2026): mỗi đối tượng một thẻ `#1`, `#2`… chứa đủ ô con,
/// nút Xoá trên thẻ, nút "+ Thêm `tên nhóm`" dưới cùng (ẩn khi đủ `max_rows`). Dùng chung cho form điểm bán và biểu mẫu
/// thị trường — đặc tả ở [RepeatGroupSpec].
///
/// 🔴 Widget TỰ GIỮ mảng dòng: gõ chữ trong ô con chỉ dựng lại chính nhóm, màn chứa không phải dựng lại cả biểu mẫu mỗi
/// phím. Nếu giữ dòng ở màn chứa mà màn đó không dựng lại sau mỗi lần báo, các ô con giữ bản dòng CŨ ⇒ gõ ô A rồi ô B là
/// mất chữ ở ô A. Giá trị đổi TỪ NGOÀI (nạp bản nháp, đặt lại form) vẫn được nhận ở [didUpdateWidget].
///
/// Ô con vẽ bằng CHÍNH các widget ô cơ bản của form động, khoá theo `line_id` + mã ô con: xoá thẻ giữa danh sách không làm
/// chữ đang gõ nhảy sang thẻ khác.
class RepeatGroupFieldWidget extends StatefulWidget {
  /// Ô nhóm (nhãn, mô tả, bắt buộc, chỉ đọc).
  final DynamicFormField field;

  /// Đặc tả nhóm: số dòng + ô con.
  final RepeatGroupSpec spec;

  /// Giá trị hiện tại (mảng dòng).
  final dynamic value;

  /// Lỗi của nhóm ([RepeatGroupSpec.validate]); `null` = không.
  final String? errorText;

  /// Báo mảng dòng MỚI (luôn là bản sao).
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  /// Giá trị nhóm đang lưu (màn sửa điểm bán) — ô SĐT của dòng còn y giá trị đang lưu không báo lỗi; `null` = không.
  final dynamic savedValue;

  const RepeatGroupFieldWidget({
    super.key,
    required this.field,
    required this.spec,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.savedValue,
  });

  @override
  State<RepeatGroupFieldWidget> createState() => _RepeatGroupFieldWidgetState();
}

class _RepeatGroupFieldWidgetState extends State<RepeatGroupFieldWidget> {
  late List<Map<String, dynamic>> _rows;

  /// Danh sách vừa báo ra — màn chứa trả lại ĐÚNG tham chiếu này thì không có gì mới (khỏi mã hoá JSON mỗi phím gõ).
  List<Map<String, dynamic>>? _lastEmittedList;

  /// «Khác…» đang mở của ô con lựa chọn: `<line_id>|<mã ô>` → chữ đang gõ (xem [ChoiceOther]).
  final Map<String, String> _other = {};

  @override
  void initState() {
    super.initState();
    _load(widget.value);
  }

  @override
  void didUpdateWidget(covariant RepeatGroupFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cùng một danh sách (màn chứa dựng lại vì ô khác) / chính danh sách mình vừa báo ⇒ không có gì mới.
    if (identical(widget.value, oldWidget.value) || identical(widget.value, _lastEmittedList)) return;
    // Giá trị đổi TỪ NGOÀI (nạp nháp, đặt lại form) ⇒ nạp lại nếu nội dung khác thứ đang hiện.
    if (jsonEncode(RepeatGroupSpec.rowsOf(widget.value)) != jsonEncode(_rows)) _load(widget.value);
  }

  void _load(dynamic value) {
    _rows = RepeatGroupSpec.rowsOf(value);
    _other.clear();
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      for (final c in widget.spec.columns.where((c) => c.allowOther)) {
        final opts = c.options.map((o) => o.value);
        final khac = c.type == DynamicFormFieldType.multipleChoice
            ? ChoiceOther.foreignMulti(r[c.code], opts)
            : ChoiceOther.foreignSingle(r[c.code], opts);
        if (khac != null) _other[_otherKey(i, c.code)] = khac;
      }
    }
  }

  void _emit(List<Map<String, dynamic>> rows) {
    setState(() => _rows = rows);
    final ra = [for (final r in rows) Map<String, dynamic>.from(r)];
    _lastEmittedList = ra;
    widget.onChanged(ra);
  }

  void _set(int i, String code, dynamic v) {
    final moi = [for (final r in _rows) Map<String, dynamic>.from(r)];
    if (RepeatGroupSpec.isBlank(v)) {
      moi[i].remove(code);
    } else {
      moi[i][code] = v;
    }
    _emit(moi);
  }

  /// Ô địa giới con của dòng [i]: ghi id; đổi TỈNH (mới/cũ) ⇒ bỏ ô con (xã / huyện cũ) CÙNG DÒNG lọc theo ô này. Một lần báo.
  void _setGeo(int i, DynamicFormField c, GeoLevel level, int? id) {
    final moi = [for (final r in _rows) Map<String, dynamic>.from(r)];
    final truoc = GeoSelectFieldWidget.idOf(moi[i][c.code]);
    if (id == null) {
      moi[i].remove(c.code);
    } else {
      moi[i][c.code] = id;
    }
    if (!level.isChild && truoc != id) {
      for (final con in widget.spec.columns.where((x) => x.dependsOn == c.code)) {
        moi[i].remove(con.code);
      }
    }
    _emit(moi);
  }

  /// Khoá «Khác…» của ô con: theo `line_id`; dòng thiếu `line_id` (dữ liệu lạ) theo vị trí — không để nhiều dòng dùng chung.
  String _otherKey(int i, String code) => '${_rows[i]['line_id'] ?? '#$i'}|$code';

  /// Dòng mới: `line_id` mới + ô có/không mặc định `false` (công tắc đang hiện "Không" phải là giá trị thật — như ô có/không
  /// cấp ngoài của form).
  Map<String, dynamic> _newRow() => {
        'line_id': RepeatGroupSpec.newLineId(),
        for (final c in widget.spec.columns)
          if (c.type == DynamicFormFieldType.boolean) c.code: false,
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final field = widget.field;
    final spec = widget.spec;
    final readOnly = field.isReadOnly;
    final canAdd = !readOnly && (spec.maxRows <= 0 || _rows.length < spec.maxRows);
    final border = isDark ? AppColors.darkOutlineVariant : const Color(0xFFE2E8F0);

    return DynamicFormFieldWrapper(
      field: field.copyWith(isRequired: spec.effectiveMin(field.isRequired) > 0),
      errorText: widget.errorText,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _rows.length; i++)
            Container(
              key: ValueKey('rg_${field.code}_${_rows[i]['line_id'] ?? i}'),
              margin: const EdgeInsets.only(bottom: AppSpacing.stackMd),
              padding: const EdgeInsets.fromLTRB(AppSpacing.stackMd, AppSpacing.stackSm, AppSpacing.stackMd, 0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceContainer : const Color(0xFFF8FAFC),
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.primary.withValues(alpha: 0.2) : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#${i + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: isDark ? AppColors.primaryFixedDim : const Color(0xFF166534),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!readOnly)
                        TextButton.icon(
                          onPressed: () => _emit([..._rows]..removeAt(i)),
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                          label: const Text('Xoá', style: TextStyle(color: AppColors.error)),
                        ),
                    ],
                  ),
                  for (final c in spec.columns)
                    KeyedSubtree(
                      key: ValueKey('rg_${field.code}_${_rows[i]['line_id'] ?? i}_${c.code}'),
                      child: _cell(i, readOnly ? c.copyWith(isReadOnly: true) : c),
                    ),
                ],
              ),
            ),
          if (canAdd)
            CustomPaint(
              painter: _DashedRoundedBorderPainter(
                color: isDark ? AppColors.primaryFixedDim.withValues(alpha: 0.65) : const Color(0xFF22C55E),
                radius: 12,
              ),
              child: Material(
                color: isDark ? AppColors.primary.withValues(alpha: 0.12) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _emit([..._rows, _newRow()]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: isDark ? AppColors.primaryFixedDim : const Color(0xFF15803D),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Thêm ${field.label}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              color: isDark ? AppColors.primaryFixedDim : const Color(0xFF166534),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Một ô con — loại cơ bản + ô địa giới (server không cho loại khác vào nhóm).
  Widget _cell(int i, DynamicFormField c) {
    final v = _rows[i][c.code];
    final geo = GeoSelectFieldWidget.levelOf(c.type);
    if (geo != null) {
      // Ô con (xã / huyện cũ) lọc theo ô tỉnh của CHÍNH dòng này; không có ô cha ⇒ khoá.
      final cha = c.dependsOn;
      return GeoSelectFieldWidget(
        field: c,
        level: geo,
        provinceId: geo.isChild && cha != null ? GeoSelectFieldWidget.idOf(_rows[i][cha]) : null,
        value: v,
        onChanged: (id) => _setGeo(i, c, geo, id),
      );
    }
    void set(dynamic x) => _set(i, c.code, x);
    final khoaKhac = _otherKey(i, c.code);
    final coKhac = c.allowOther && !c.isReadOnly;

    switch (c.type) {
      case DynamicFormFieldType.longText:
        return DynamicLongTextFieldWidget(field: c, value: v?.toString(), onChanged: set);
      case DynamicFormFieldType.number:
        return DynamicNumberFieldWidget(field: c, value: v is num ? v : num.tryParse(v?.toString() ?? ''), onChanged: set);
      case DynamicFormFieldType.singleChoice:
        return DynamicSingleChoiceFieldWidget(
          field: c,
          value: v,
          onChanged: set,
          otherText: _other[khoaKhac],
          // «Khác…»: chuỗi gõ tay đặt THẲNG làm giá trị; `null` = bỏ «Khác…» (lựa chọn mới đã ghi đè giá trị).
          onOtherChanged: coKhac
              ? (t) {
                  if (t == null) {
                    setState(() => _other.remove(khoaKhac));
                    return;
                  }
                  _other[khoaKhac] = t;
                  set(t.trim());
                }
              : null,
        );
      case DynamicFormFieldType.multipleChoice:
        final list = v is List ? List<dynamic>.from(v) : <dynamic>[];
        return DynamicMultipleChoiceFieldWidget(
          field: c,
          selectedValues: list,
          onChanged: set,
          otherText: _other[khoaKhac],
          onOtherChanged: coKhac
              ? (t) {
                  if (t == null) {
                    _other.remove(khoaKhac);
                  } else {
                    _other[khoaKhac] = t;
                  }
                  set(ChoiceOther.composeMulti<dynamic>(
                    list,
                    c.options.map((o) => o.value),
                    t,
                    optionLabels: c.options.map((o) => o.label),
                  ));
                }
              : null,
        );
      case DynamicFormFieldType.date:
      case DynamicFormFieldType.time:
      case DynamicFormFieldType.datetime:
        return DynamicDateTimeFieldWidget(field: c, value: v?.toString(), onChanged: set);
      case DynamicFormFieldType.phone:
        // Lỗi dạng số hiện ngay dưới ô của DÒNG này — sau lần kiểm (nhóm đang báo lỗi), giống ô SĐT đơn.
        return DynamicTextFieldWidget(
          field: c,
          value: v?.toString(),
          onChanged: set,
          errorText: widget.errorText == null ? null : RepeatGroupSpec.phoneErrorOf(_rows[i], c, saved: widget.savedValue),
        );
      case DynamicFormFieldType.boolean:
        return DynamicBooleanFieldWidget(
          field: c,
          value: v == true || v == 1 || v == '1' || v == 'true',
          onChanged: set,
        );
      default:
        return DynamicTextFieldWidget(field: c, value: v?.toString(), onChanged: set);
    }
  }
}

class _DashedRoundedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedRoundedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
