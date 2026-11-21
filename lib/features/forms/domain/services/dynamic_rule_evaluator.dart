import '../../domain/entities/market_form_entity.dart';

/// Bộ đánh giá cây điều kiện hiển thị biểu mẫu động `show_if`
/// Tuân thủ đặc tả kỹ thuật: specs/api/API-DIEU-KIEN-HIEN-THI-BIEU-MAU-2026-09-25.md
class DynamicRuleEvaluator {
  /// Ô lưu DANH SÁCH giá trị (chọn nhiều) — bản app của `RuleEvaluator::isListType()` (server) / `isListType` (SPA, #24038).
  static bool isListType(String inputType, {bool hasOptions = false, bool multiple = false}) =>
      inputType == 'multiselect' ||
      (inputType == 'checkbox' && hasOptions) ||
      (multiple && (inputType == 'ref_customer' || inputType == 'ref_erp_partner'));

  /// Đánh giá cây điều kiện hiển thị của một block
  /// - `rule`: dynamic (Map, List, hoặc null)
  /// - `read`: hàm đọc giá trị của trường hoặc biến ngữ cảnh theo path
  /// - `lists`: mã các ô DANH SÁCH ([isListType]) — đọc như danh sách: rỗng ⇒ `[]`, vô hướng ⇒ một phần tử. Cùng luật server
  ///   (`RuleEvaluator`) và SPA (`lib/dynamicRule.ts`) — bảng ca chung `test/fixtures/dynamicRule.cases.json` (#24038).
  static bool evalRule(dynamic rule, dynamic Function(String path) read, [Set<String> lists = const {}]) {
    // null / vắng mặt / {} => true (luôn hiện theo §2)
    if (rule == null) return true;
    if (rule is Map && rule.isEmpty) return true;

    // [ ... ] (mảng tuần tự, không có all/any) => AND ngầm (hiểu như all)
    if (rule is List) {
      if (rule.isEmpty) return true;
      return rule.every((child) => evalRule(child, read, lists));
    }

    if (rule is Map) {
      // 1. { "all": [ ... ] } -> AND: mọi nhánh con phải đúng
      if (rule.containsKey('all')) {
        final children = rule['all'];
        if (children is List) {
          if (children.isEmpty) return true;
          return children.every((child) => evalRule(child, read, lists));
        }
        return false;
      }

      // 2. { "any": [ ... ] } -> OR: chỉ cần một nhánh đúng
      if (rule.containsKey('any')) {
        final children = rule['any'];
        if (children is List) {
          if (children.isEmpty) return false;
          return children.any((child) => evalRule(child, read, lists));
        }
        return false;
      }

      // 3. { "field": ..., "op": ..., "value": ... } -> Lá: một phép so sánh
      if (rule.containsKey('field')) {
        final field = rule['field']?.toString().trim();
        if (field == null || field.isEmpty) return false;

        final op = rule['op']?.toString().trim();
        if (op == null || op.isEmpty) return false;

        final expected = rule['value'];
        final raw = read(field);
        final actual = lists.contains(field) ? _toList(raw) : raw;

        return _evalLeaf(op, actual, expected);
      }

      // Luật 3 (§2): object không có all/any/field => trả false, KHÔNG ném lỗi
      return false;
    }

    return false;
  }

  /// Đọc như DANH SÁCH: mảng giữ nguyên, rỗng ⇒ `[]`, vô hướng ⇒ một phần tử.
  static List _toList(dynamic v) {
    if (v is List) return v;
    return isEmptyValue(v) ? const [] : [v];
  }

  /// Đánh giá phép so sánh tại một nút lá
  static bool _evalLeaf(String op, dynamic actual, dynamic expected) {
    switch (op) {
      // Bằng / khác
      case '=':
      case '==':
        return looseEquals(actual, expected);
      case '!=':
      case '<>':
        return !looseEquals(actual, expected);

      // So sánh thứ tự (ưu tiên số, không phải số thì so chuỗi như ngày ISO)
      case '>':
        final cmp = compareOrder(actual, expected);
        return cmp != null && cmp > 0;
      case '>=':
        final cmp = compareOrder(actual, expected);
        return cmp != null && cmp >= 0;
      case '<':
        final cmp = compareOrder(actual, expected);
        return cmp != null && cmp < 0;
      case '<=':
        final cmp = compareOrder(actual, expected);
        return cmp != null && cmp <= 0;

      // Thuộc / không thuộc danh sách — giá trị so không phải danh sách ⇒ cả hai không trúng (như server).
      case 'in':
      case 'not_in':
        if (expected is! List) return false;
        final items = actual is List ? actual : [actual];
        final hit = items.any((item) => expected.any((exp) => looseEquals(item, exp)));
        return op == 'in' ? hit : !hit;

      // Mảng: so PHẦN TỬ. Chuỗi: chuỗi con, không phân biệt hoa thường; chuỗi tìm rỗng không trúng.
      case 'contains':
        if (actual is List) {
          return actual.any((item) => looseEquals(item, expected));
        }
        if (actual is! String || (expected is! String && expected is! num)) return false;
        final needle = expected.toString().toLowerCase();
        return needle.isNotEmpty && actual.toLowerCase().contains(needle);

      // Trong khoảng đóng [a, b] (mảng đúng 2 phần tử)
      case 'between':
        if (expected is! List || expected.length < 2) return false;
        final cmpLow = compareOrder(actual, expected[0]);
        final cmpHigh = compareOrder(actual, expected[1]);
        if (cmpLow == null || cmpHigh == null) return false;
        return cmpLow >= 0 && cmpHigh <= 0;

      // Rỗng / khác rỗng
      case 'is_empty':
        return isEmptyValue(actual);
      case 'not_empty':
        return !isEmptyValue(actual);

      // Luật 3: Toán tử lạ => trả false, KHÔNG ném lỗi
      default:
        return false;
    }
  }

  /// Luật 1 (§2): 0, "0", false KHÔNG phải rỗng.
  /// Chỉ null, chuỗi rỗng (sau trim), và mảng/map rỗng mới là rỗng.
  /// Object chứa toàn giá trị rỗng/null (như {address: "", lat: null, lng: null}) cũng là rỗng (§3).
  static bool isEmptyValue(dynamic v) {
    if (v == null) return true;
    if (v is String) return v.trim().isEmpty;
    if (v is List) return v.isEmpty;
    if (v is Map) {
      if (v.isEmpty) return true;
      // Ô ma trận trưng bày `{counts, photos, custom?}`: rỗng khi không có số và không có ảnh (thêm thẻ / cột mà chưa nhập gì).
      if (v.containsKey('counts') && v.containsKey('photos')) {
        final c = v['counts'];
        final p = v['photos'];
        return !(c is Map && c.values.any((r) => r is Map && r.isNotEmpty)) &&
            !(p is Map && p.values.any((l) => l is List && l.isNotEmpty));
      }
      return v.values.every((val) => val == null || (val is String && val.trim().isEmpty));
    }
    return false;
  }

  /// So bằng — bản app của `RuleEvaluator::looseEquals()`: một vế là mảng ⇒ so hai danh sách theo thứ tự (vế vô hướng = danh
  /// sách một phần tử); một vế đúng/sai ⇒ so đúng/sai (1/true/yes/co/có); hai vế là số thập phân (kể cả chuỗi số) ⇒ so số;
  /// còn lại so chuỗi.
  static bool looseEquals(dynamic a, dynamic b) {
    if (a is List || b is List) {
      final la = _toList(a);
      final lb = _toList(b);
      if (la.length != lb.length) return false;
      for (var i = 0; i < la.length; i++) {
        if (!looseEquals(la[i], lb[i])) return false;
      }
      return true;
    }
    if (a is bool || b is bool) return _toBool(a) == _toBool(b);
    final numA = _num(a);
    final numB = _num(b);
    if (numA != null && numB != null) return numA == numB;
    return (a ?? '').toString() == (b ?? '').toString();
  }

  static bool _toBool(dynamic v) {
    if (v is String) return const ['1', 'true', 'yes', 'co', 'có'].contains(v.trim().toLowerCase());
    if (v is num) return v != 0;
    if (v is bool) return v;
    return v != null;
  }

  /// Chuỗi số THẬP PHÂN như `is_numeric()` của PHP — `num.tryParse` còn nhận `0x10` mà server coi là chữ.
  static final RegExp _decimal = RegExp(r'^[+-]?(\d+(\.\d*)?|\.\d+)([eE][+-]?\d+)?$');

  static num? _num(dynamic v) {
    if (v is num) return v.isFinite ? v : null;
    if (v is String && _decimal.hasMatch(v.trim())) return num.tryParse(v.trim());
    return null;
  }

  /// So sánh thứ tự: ưu tiên số; rỗng hoặc lệch kiểu (một bên số, một bên không) ⇒ `null` (mọi toán tử thứ tự ra false, như
  /// `RuleEvaluator::compare()`); còn lại so chuỗi (ngày ISO YYYY-MM-DD so chuỗi vẫn đúng thứ tự).
  static int? compareOrder(dynamic a, dynamic b) {
    final numA = _num(a);
    final numB = _num(b);
    if (numA != null && numB != null) return numA.compareTo(numB);
    if (isEmptyValue(a) || isEmptyValue(b) || (numA == null) != (numB == null)) return null;
    return a.toString().compareTo(b.toString());
  }

  /// Đọc đường dẫn lồng nhau dạng `@customer.type_id` từ map ngữ cảnh (§4 & §7)
  static dynamic readPath(Map<String, dynamic> ctx, String path) {
    if (ctx.containsKey(path)) return ctx[path];
    final parts = path.split('.');
    dynamic current = ctx;
    for (final part in parts) {
      if (current is Map) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }

  /// Tính toán map hiển thị cho toàn bộ danh sách blocks (§3 & §7)
  /// - Duyệt blocks THEO ĐÚNG THỨ TỰ server trả về.
  /// - Duy trì tập `hidden`.
  /// - Khi đánh giá điều kiện, giá trị của một ô đã nằm trong `hidden` được đọc ra là `null` (§3).
  /// - Ô trình bày (`heading`, `divider`, `note`) cũng được ẩn/hiện và đưa vào `hidden` nếu ẩn (§6).
  static Map<String, bool> computeVisibility({
    required List<MarketFormBlockEntity> blocks,
    required Map<String, dynamic> answers,
    Map<String, dynamic> customerContext = const {},
  }) {
    return computeVisibilityOf<MarketFormBlockEntity>(
      items: blocks,
      showIfOf: (b) => b.showIf,
      keysOf: (b) => [b.resolved.code, b.ref],
      isListOf: (b) => b.resolved.isListValued,
      answers: answers,
      customerContext: customerContext,
    );
  }

  /// Mã các ô BẮT BUỘC THEO ĐIỀU KIỆN lúc này (`required_if`, #25067 — server `FormValidator::conditionallyRequiredCodes()`):
  /// cây điều kiện (cùng dạng `show_if`) của ô ĐANG HIỆN đánh giá đúng. Ô ẩn theo [visibility] đọc ra RỖNG và không bao giờ
  /// bắt buộc. 🔴 Điều kiện `null`/rỗng = KHÔNG bắt buộc (khác `evalRule(null) == true` của `show_if`).
  static Set<String> computeRequiredOf<T>({
    required List<T> items,
    required dynamic Function(T item) requiredIfOf,
    required List<String> Function(T item) keysOf,
    required Map<String, bool> visibility,
    required Map<String, dynamic> answers,
    Map<String, dynamic> customerContext = const {},
    bool Function(T item)? isListOf,
  }) {
    final out = <String>{};
    final lists = _listKeys(items, keysOf, isListOf);
    dynamic read(String path) {
      if (path.startsWith('@')) return readPath(customerContext, path);
      if (visibility[path] == false) return null;
      return answers[path];
    }

    for (final item in items) {
      final rule = requiredIfOf(item);
      if (rule == null || (rule is Map && rule.isEmpty) || (rule is List && rule.isEmpty)) continue;
      final keys = keysOf(item).where((k) => k.isNotEmpty).toList();
      if (keys.any((k) => visibility[k] == false)) continue;
      if (evalRule(rule, read, lists)) out.addAll(keys);
    }

    return out;
  }

  /// Bản tổng quát của [computeVisibility] cho mọi danh sách ô có `show_if` (biểu mẫu thị trường, form điểm bán…):
  /// [keysOf] trả các mã nhận diện một ô (mã rỗng bị bỏ qua) — cùng luật ẩn theo TẦNG, cùng ngữ cảnh `@customer.*`.
  static Map<String, bool> computeVisibilityOf<T>({
    required List<T> items,
    required dynamic Function(T item) showIfOf,
    required List<String> Function(T item) keysOf,
    required Map<String, dynamic> answers,
    Map<String, dynamic> customerContext = const {},
    bool Function(T item)? isListOf,
  }) {
    final out = <String, bool>{};
    final hidden = <String>{};
    final lists = _listKeys(items, keysOf, isListOf);

    dynamic read(String path) {
      // 1. Biến ngữ cảnh @customer.*
      if (path.startsWith('@')) {
        return readPath(customerContext, path);
      }
      // 2. Ô đã ẩn => coi như RỖNG (§3)
      if (hidden.contains(path)) {
        return null;
      }
      // 3. Câu trả lời của người dùng
      return answers[path];
    }

    for (final item in items) {
      final shown = evalRule(showIfOf(item), read, lists);
      final keys = keysOf(item).where((k) => k.isNotEmpty).toSet();

      for (final k in keys) {
        out[k] = shown;
      }
      if (!shown) hidden.addAll(keys);
    }

    return out;
  }

  /// Mã các ô DANH SÁCH trong [items] (mọi mã nhận diện của ô).
  static Set<String> _listKeys<T>(List<T> items, List<String> Function(T item) keysOf, bool Function(T item)? isListOf) {
    if (isListOf == null) return const {};
    return {
      for (final item in items)
        if (isListOf(item)) ...keysOf(item).where((k) => k.isNotEmpty),
    };
  }
}
