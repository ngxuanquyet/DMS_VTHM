import '../../domain/entities/market_form_entity.dart';

/// Bộ đánh giá cây điều kiện hiển thị biểu mẫu động `show_if`
/// Tuân thủ đặc tả kỹ thuật: specs/api/API-DIEU-KIEN-HIEN-THI-BIEU-MAU-2026-09-25.md
class DynamicRuleEvaluator {
  /// Đánh giá cây điều kiện hiển thị của một block
  /// - `rule`: dynamic (Map, List, hoặc null)
  /// - `read`: hàm đọc giá trị của trường hoặc biến ngữ cảnh theo path
  static bool evalRule(dynamic rule, dynamic Function(String path) read) {
    // null / vắng mặt / {} => true (luôn hiện theo §2)
    if (rule == null) return true;
    if (rule is Map && rule.isEmpty) return true;

    // [ ... ] (mảng tuần tự, không có all/any) => AND ngầm (hiểu như all)
    if (rule is List) {
      if (rule.isEmpty) return true;
      return rule.every((child) => evalRule(child, read));
    }

    if (rule is Map) {
      // 1. { "all": [ ... ] } -> AND: mọi nhánh con phải đúng
      if (rule.containsKey('all')) {
        final children = rule['all'];
        if (children is List) {
          if (children.isEmpty) return true;
          return children.every((child) => evalRule(child, read));
        }
        return false;
      }

      // 2. { "any": [ ... ] } -> OR: chỉ cần một nhánh đúng
      if (rule.containsKey('any')) {
        final children = rule['any'];
        if (children is List) {
          if (children.isEmpty) return false;
          return children.any((child) => evalRule(child, read));
        }
        return false;
      }

      // 3. { "field": ..., "op": ..., "value": ... } -> Lá: một phép so sánh
      if (rule.containsKey('field')) {
        final field = rule['field']?.toString()?.trim();
        if (field == null || field.isEmpty) return false;

        final op = rule['op']?.toString()?.trim();
        if (op == null || op.isEmpty) return false;

        final expected = rule['value'];
        final actual = read(field);

        return _evalLeaf(op, actual, expected);
      }

      // Luật 3 (§2): object không có all/any/field => trả false, KHÔNG ném lỗi
      return false;
    }

    return false;
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

      // Thuộc / không thuộc danh sách
      case 'in':
        if (expected is! List) return false;
        if (actual == null) return false;
        if (actual is List) {
          return actual.any((item) => expected.any((exp) => looseEquals(item, exp)));
        }
        return expected.any((exp) => looseEquals(actual, exp));

      case 'not_in':
        if (expected is! List) return false;
        if (actual == null) return true;
        if (actual is List) {
          return !actual.any((item) => expected.any((exp) => looseEquals(item, exp)));
        }
        return !expected.any((exp) => looseEquals(actual, exp));

      // Chuỗi chứa chuỗi con, hoặc mảng có phần tử (vô hướng)
      case 'contains':
        if (actual == null || expected == null) return false;
        if (actual is List) {
          return actual.any((item) => looseEquals(item, expected));
        }
        return actual.toString().contains(expected.toString());

      // Trong khoảng đóng [a, b] (mảng đúng 2 phần tử)
      case 'between':
        if (expected is! List || expected.length != 2) return false;
        if (actual == null) return false;
        final low = expected[0];
        final high = expected[1];
        final cmpLow = compareOrder(actual, low);
        final cmpHigh = compareOrder(actual, high);
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
  static bool isEmptyValue(dynamic v) {
    if (v == null) return true;
    if (v is String) return v.trim().isEmpty;
    if (v is List) return v.isEmpty;
    if (v is Map) return v.isEmpty;
    return false;
  }

  /// Luật 2 (§2): So bằng thì nới lỏng kiểu số <-> chuỗi ("2" và 2 bằng nhau).
  static bool looseEquals(dynamic a, dynamic b) {
    if (a == b) return true;
    if (a == null || b == null) return false;

    // Nới lỏng số ↔ chuỗi
    final numA = a is num ? a : num.tryParse(a.toString().trim());
    final numB = b is num ? b : num.tryParse(b.toString().trim());
    if (numA != null && numB != null) {
      return numA == numB;
    }

    return a.toString().trim() == b.toString().trim();
  }

  /// So sánh thứ tự: ưu tiên số; không phải số thì so chuỗi (ngày ISO YYYY-MM-DD so chuỗi vẫn đúng thứ tự).
  static int? compareOrder(dynamic a, dynamic b) {
    if (a == null || b == null) return null;

    final numA = a is num ? a : num.tryParse(a.toString().trim());
    final numB = b is num ? b : num.tryParse(b.toString().trim());
    if (numA != null && numB != null) {
      return numA.compareTo(numB);
    }

    return a.toString().trim().compareTo(b.toString().trim());
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
    final out = <String, bool>{};
    final hidden = <String>{};

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

    for (final b in blocks) {
      final shown = evalRule(b.showIf, read);
      final code = b.resolved.code;
      final ref = b.ref;

      if (code.isNotEmpty) out[code] = shown;
      if (ref.isNotEmpty && ref != code) out[ref] = shown;

      if (!shown) {
        if (code.isNotEmpty) hidden.add(code);
        if (ref.isNotEmpty) hidden.add(ref);
      }
    }

    return out;
  }
}
