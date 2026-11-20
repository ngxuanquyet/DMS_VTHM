import 'dart:convert';
import 'dart:math';

import '../services/geo_catalog_service.dart';
import '../widgets/geo_select_field_widget.dart';
import 'choice_other.dart';

import 'models/dynamic_form_field.dart';

/// NHÓM TRƯỜNG LẶP (`group_table`, server 19/11/2026) — vd "Người liên hệ" = Tên + SĐT: nhân viên thêm NHIỀU đối tượng,
/// mỗi đối tượng đủ các ô con. Hợp đồng: `docs/reference/internal-api/API-NHOM-TRUONG-LAP-2026-11-19.md` (repo appnew).
///
/// Một đặc tả cho CẢ hai nơi vẽ:
///  - biểu mẫu điểm bán — ô `input_type: group_table` mang khoá `group: {min_rows, max_rows, columns[]}` ([fromCustomerSchema]);
///  - biểu mẫu thị trường — khối `type: group`, `resolved.kind = table`, ô con ở `resolved.items[]` ([fromEngineItems]).
///
/// Giá trị là MẢNG dòng `[{line_id, <mã ô con>: giá trị}]`. 🔴 `line_id` là danh tính dòng — GIỮ NGUYÊN qua mọi lần sửa
/// (server dùng để nhận ra dòng cũ); dòng mới do app sinh ([newLineId]).
class RepeatGroupSpec {
  /// Số dòng tối thiểu (0 = không giới hạn).
  final int minRows;

  /// Số dòng tối đa (0 = không giới hạn).
  final int maxRows;

  /// Ô con theo thứ tự — ô cơ bản (chữ, số, tiền, ngày, chọn, có/không) và ô địa giới (tỉnh/xã, tỉnh cũ/huyện cũ — ô con
  /// lọc theo ô tỉnh CÙNG DÒNG ở [DynamicFormField.dependsOn]).
  final List<DynamicFormField> columns;

  /// Độ dài tối thiểu / tối đa (ký tự) của ô con chữ theo mã ô — [DynamicFormField] không mang hai ràng buộc này nhưng
  /// server kiểm (`config.validation.min_length`/`max_length`): bỏ qua là phiếu ngoại tuyến bị 422 lúc đồng bộ.
  final Map<String, ({int? min, int? max})> lengths;

  const RepeatGroupSpec({this.minRows = 0, this.maxRows = 0, this.columns = const [], this.lengths = const {}});

  /// Đặc tả đã dựng theo ĐỐI TƯỢNG nguồn (Map `group` / List `items`) — form gọi lại ở mỗi lần dựng/kiểm, parse lại
  /// toàn bộ ô con mỗi phím gõ là việc thừa.
  static final Expando<RepeatGroupSpec> _cache = Expando('RepeatGroupSpec');
  static final Expando<({dynamic config, RepeatGroupSpec spec})> _engineCache = Expando('RepeatGroupSpecEngine');

  /// Từ khoá `group` của schema điểm bán (`GET /crm/customer-form/schema`).
  static RepeatGroupSpec? fromCustomerSchema(dynamic group) {
    if (group is! Map) return null;
    return _cache[group] ??= _fromCustomerSchema(group);
  }

  static RepeatGroupSpec _fromCustomerSchema(Map group) {
    final cols = [
      if (group['columns'] is List)
        for (final c in (group['columns'] as List).whereType<Map>()) Map<String, dynamic>.from(c),
    ];
    return RepeatGroupSpec(
      minRows: _int(group['min_rows']),
      maxRows: _int(group['max_rows']),
      columns: cols.map(_column).toList(),
      lengths: _lengthsOf(cols),
    );
  }

  /// Từ khối nhóm của biểu mẫu thị trường: `config` (`min_rows`/`max_rows`) + `items[]` dạng `{ref, required, resolved}`.
  static RepeatGroupSpec fromEngineItems(dynamic items, dynamic config) {
    // Đệm theo danh sách `items` (mỗi khối một danh sách riêng) KÈM đúng `config` đã dùng — cùng `items` mà khác `config`
    // (cột điểm bán không có số dòng) thì dựng lại. Danh sách rỗng có thể là hằng dùng chung ⇒ không đệm.
    if (items is! List || items.isEmpty) return _fromEngineItems(items, config);
    final hit = _engineCache[items];
    if (hit != null && identical(hit.config, config)) return hit.spec;
    final spec = _fromEngineItems(items, config);
    _engineCache[items] = (config: config, spec: spec);
    return spec;
  }

  static RepeatGroupSpec _fromEngineItems(dynamic items, dynamic config) {
    final cfg = config is Map ? config : const {};
    final cols = [
      if (items is List)
        for (final it in items.whereType<Map>())
          if (it['resolved'] is Map) _flatEngineItem(it),
    ];
    return RepeatGroupSpec(
      minRows: _int(cfg['min_rows']),
      maxRows: _int(cfg['max_rows']),
      columns: cols.map(_column).toList(),
      lengths: _lengthsOf(cols),
    );
  }

  /// Một ô con của engine (`{ref, required, resolved: {code, label, input_type, config: {options, validation}}}`) về dạng
  /// phẳng mà [DynamicFormField.fromJson] đọc được.
  static Map<String, dynamic> _flatEngineItem(Map it) {
    final r = Map<String, dynamic>.from(it['resolved'] as Map);
    final cfg = r['config'] is Map ? r['config'] as Map : const {};
    final val = cfg['validation'] is Map ? cfg['validation'] as Map : const {};
    // Nhãn ghi đè của nhóm cho ô con (`overrides.label`) — server áp khi báo lỗi, web áp khi vẽ.
    final ov = it['overrides'] is Map ? it['overrides'] as Map : const {};
    final nhanRieng = ov['label']?.toString().trim() ?? '';
    return {
      'code': r['code'] ?? it['ref'],
      'label': nhanRieng.isNotEmpty ? nhanRieng : r['label'],
      'input_type': r['input_type'],
      'description': r['description'],
      'required': it['required'] == true,
      'options': cfg['options'] ?? const [],
      'config': cfg,
      // Ô địa giới con (xã / huyện cũ) lọc theo ô tỉnh CÙNG DÒNG: `config.depends_on` → khoá phẳng mà fromJson đọc.
      'depends_on': cfg['depends_on'],
      'min': val['min'],
      'max': val['max'],
      'min_length': val['min_length'],
      'max_length': val['max_length'],
    };
  }

  static Map<String, ({int? min, int? max})> _lengthsOf(List<Map<String, dynamic>> cols) => {
        for (final c in cols)
          if (c['min_length'] != null || c['max_length'] != null)
            c['code'].toString(): (
              min: c['min_length'] == null ? null : _int(c['min_length']),
              max: c['max_length'] == null ? null : _int(c['max_length']),
            ),
      };

  /// Ô con → [DynamicFormField] (tên mục cố định để không rơi vào bộ đoán mục theo mã ô).
  static DynamicFormField _column(Map<String, dynamic> json) =>
      DynamicFormField.fromJson({...json, 'section': '_repeat_group'});

  static int _int(dynamic v) => v is num ? v.toInt() : (int.tryParse(v?.toString() ?? '') ?? 0);

  /// Số dòng phải có — `min_rows`, hoặc 1 khi nhóm bắt buộc.
  int effectiveMin(bool isRequired) => max(minRows, isRequired ? 1 : 0);

  /// `line_id` mới cho dòng vừa thêm: 16 ký tự hex ngẫu nhiên (cùng dạng server cấp).
  static String newLineId() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  /// Danh sách dòng từ giá trị đang có (bỏ phần tử lạ).
  static List<Map<String, dynamic>> rowsOf(dynamic value) => [
        if (value is List)
          for (final r in value.whereType<Map>()) Map<String, dynamic>.from(r),
      ];

  /// Giá trị trông như MẢNG DÒNG của nhóm (mọi phần tử là Map có `line_id`) — màn xem không có schema dùng để nhận ra nhóm.
  static bool looksLikeRows(dynamic value) =>
      value is List && value.isNotEmpty && value.every((r) => r is Map && r['line_id'] != null);

  /// Hai giá trị nhóm CÙNG NỘI DUNG — so theo từng dòng, ô trống bỏ qua, không phụ thuộc thứ tự khoá (jsonb trả khoá theo
  /// thứ tự của nó) hay tham chiếu danh sách. `null` và `[]` là một. Màn sửa dùng để biết nhóm có đổi không: so tham
  /// chiếu thì mảng chép lại cùng nội dung cũng bị gửi đi và server kiểm lại cả nhóm theo luật mới.
  static bool sameRows(dynamic a, dynamic b) {
    // Chuẩn hoá giống [pruneEmpty]: ô trống và công tắc `false` = chưa điền; vô hướng so dạng CHỮ đã cắt khoảng trắng (web /
    // Excel có thể lưu số dạng chuỗi "5", app giữ số 5). Dòng không còn gì (chỉ `line_id`) bị bỏ.
    dynamic so(dynamic x) => x is List ? x.map(so).toList() : (x is Map ? x : x.toString().trim());
    String chuan(dynamic v) => jsonEncode([
          for (final r in rowsOf(v))
            if (r.entries.any((e) => e.key != 'line_id' && !isBlank(e.value) && e.value != false))
              Map.fromEntries(
                (r.entries.where((e) => !isBlank(e.value) && e.value != false).map((e) => MapEntry(e.key, so(e.value))).toList()
                  ..sort((x, y) => x.key.compareTo(y.key))),
              ),
        ]);
    return chuan(a) == chuan(b);
  }

  /// Các dòng chữ để màn xem in (mỗi đối tượng một hàng, bỏ dòng rỗng) — một chỗ cho chi tiết điểm bán, chi tiết phiếu,
  /// lịch sử viếng thăm.
  List<String> displayLines(dynamic value) => [
        for (final r in rowsOf(value)) rowText(r),
      ].where((x) => x.isNotEmpty).toList();

  /// Chữ của cả nhóm cho màn xem: mỗi đối tượng một hàng; không có gì ⇒ `—` (ba màn xem in giống nhau).
  String displayText(dynamic value) {
    final dong = displayLines(value);
    return dong.isEmpty ? '—' : dong.join('\n');
  }

  /// Bỏ các dòng KHÔNG điền gì (mọi ô con trống, ô có/không chưa bật) — bấm nhầm "+ Thêm" không thành một đối tượng rỗng
  /// lưu lên server. Không bỏ dòng nào ⇒ trả CHÍNH danh sách cũ (màn sửa điểm bán so tham chiếu để biết ô có đổi không).
  List<Map<String, dynamic>> pruneEmpty(List<Map<String, dynamic>> rows) {
    // Không có định nghĩa ô con (nhóm hỏng / schema cũ) ⇒ không biết dòng nào trống — giữ nguyên, đừng xoá sạch dữ liệu.
    if (columns.isEmpty) return rows;
    final con = rows
        .where((r) => columns.any((c) {
              final v = r[c.code];
              return !isBlank(v) && v != false;
            }))
        .toList();
    return con.length == rows.length ? rows : con;
  }

  /// Ô trống theo cùng luật server (`FormValidator::isBlank`): null, chuỗi trắng, mảng rỗng.
  static bool isBlank(dynamic v) => v == null || (v is String && v.trim().isEmpty) || (v is List && v.isEmpty);

  /// Lỗi đầu tiên của nhóm (cùng luật server): đủ/thừa số dòng, ô con bắt buộc của từng dòng, độ dài, số ngoài khoảng,
  /// giá trị «Khác…» quá trần; `null` = hợp lệ. Nhóm không đổi ở màn sửa thì màn chứa tự bỏ qua ([sameRows]).
  String? validate(dynamic value, {required String label, required bool isRequired}) {
    final rows = rowsOf(value);
    final need = effectiveMin(isRequired);
    if (rows.length < need) return '$label: cần ít nhất $need dòng';
    if (maxRows > 0 && rows.length > maxRows) return '$label: tối đa $maxRows dòng';
    for (var i = 0; i < rows.length; i++) {
      for (final c in columns) {
        final v = rows[i][c.code];
        if (c.isRequired && isBlank(v)) return '$label, dòng ${i + 1}: ${c.label} không được để trống';
        // Chuỗi «Khác…» gõ tay (ngoài danh sách lựa chọn) — cùng trần server (`ChoiceOtherConfig::MAX_LENGTH`).
        if (c.allowOther) {
          final opts = c.options.map((o) => o.value);
          final khac = ChoiceOther.foreignMulti(v is List ? v : [v], opts);
          if (khac != null && khac.length > ChoiceOther.maxLength) return '$label, dòng ${i + 1}: ${ChoiceOther.tooLongError}';
        }
        final len = lengths[c.code];
        if (len != null && v is String && v.trim().isNotEmpty) {
          final n = v.trim().length;
          if (len.min != null && n < len.min!) return '$label, dòng ${i + 1}: ${c.label} cần ít nhất ${len.min} ký tự';
          if (len.max != null && n > len.max!) return '$label, dòng ${i + 1}: ${c.label} tối đa ${len.max} ký tự';
        }
        if (v is num && c.type == DynamicFormFieldType.number) {
          if (c.min != null && v < c.min!) return '$label, dòng ${i + 1}: ${c.label} phải ≥ ${c.min}';
          if (c.max != null && v > c.max!) return '$label, dòng ${i + 1}: ${c.label} phải ≤ ${c.max}';
        }
      }
    }
    return null;
  }

  /// Một dòng dạng chữ (`Nguyễn Văn A – 0912…`) — cùng cách server/web gộp (`RepeatGroupLayout::text()`: ô cách nhau ` – `,
  /// ô trống bỏ qua, ô lựa chọn in NHÃN, có/không in chữ). Màn xem in mỗi dòng một hàng. Thiếu định nghĩa ô con thì lấy
  /// khoá của dòng.
  String rowText(Map<String, dynamic> row) {
    final codes = columns.isNotEmpty ? columns.map((c) => c.code) : row.keys.where((k) => k != 'line_id');
    final parts = <String>[];
    for (final code in codes) {
      final col = columns.where((c) => c.code == code).firstOrNull;
      final v = row[code];
      if (isBlank(v)) continue;
      final items = v is List ? v : [v];
      parts.add(items
          .map((x) {
            if (x is bool) return x ? 'Có' : 'Không';
            // Ô địa giới lưu ID — in TÊN tra từ danh mục đã lưu máy (chưa có danh mục ⇒ ID).
            final geo = col == null ? null : GeoSelectFieldWidget.levelOf(col.type);
            if (geo != null) {
              final ten = GeoCatalogService.memory?.unitOf(geo, GeoSelectFieldWidget.idOf(x))?.fullName;
              if (ten != null && ten.isNotEmpty) return ten;
            }
            final hit = col?.options.where((o) => o.value.toString() == x.toString()).firstOrNull;
            return hit?.label ?? x.toString();
          })
          .join(', '));
    }
    return parts.join(' – ');
  }
}
