/// Ô CÔNG THỨC (`input_type = formula`) của biểu mẫu động — bộ tính + định dạng DÙNG CHUNG cho biểu mẫu điểm bán
/// (`DynamicFormBuilder`) và biểu mẫu thị trường (`MarketFormRenderer`).
///
/// App chỉ tính để HIỂN THỊ (kể cả offline); server tính lại và lưu (`common/modules/formfield/services/
/// FormulaEvaluator.php`, web `vn.vthmgroup.one/src/lib/dynamicFormula.ts`). Cú pháp phải khớp hai bản đó:
///  - số (dấu `.` thập phân), mã ô `[A-Za-z_][A-Za-z0-9_]*`, `+ - * /`, ngoặc, dấu âm/dương một ngôi;
///  - hàm `round(x[, n])` (nửa ra xa số 0), `min(a, b, …)`, `max(a, b, …)`; có thể mở đầu bằng `=`.
///
/// Ô tham chiếu RỖNG (null / chuỗi rỗng / không phải số) ⇒ kết quả RỖNG (không coi là 0). Chia 0, kết quả không hữu
/// hạn, cú pháp sai, hàm lạ ⇒ rỗng. KHÔNG eval, không bao giờ ném lỗi ra ngoài.
class FormulaEvaluator {
  FormulaEvaluator._();

  /// Tính [formula]; [read] trả giá trị hiện tại của ô theo mã. Trả `null` khi không tính được.
  static num? evaluate(String? formula, dynamic Function(String code) read) {
    if (formula == null) return null;
    var src = formula.trim();
    if (src.startsWith('=')) src = src.substring(1).trim();
    if (src.isEmpty) return null;
    try {
      final tokens = _tokenize(src);
      if (tokens.isEmpty) return null;
      final p = _Parser(tokens, read);
      final v = p.expr();
      if (!p.done) return null;
      if (!v.isFinite) return null;
      return v;
    } on _FormulaFail {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Ép giá trị ô về số; rỗng / không phải số ⇒ `null`.
  static num? toNum(dynamic v) {
    if (v is num) return v.isFinite ? v : null;
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      final n = num.tryParse(s);
      return n != null && n.isFinite ? n : null;
    }
    return null;
  }

  /// Làm tròn [digits] chữ số thập phân, nửa ra xa số 0 (khớp `round()` PHP). Dời dấu phẩy bằng chuỗi mũ
  /// (`1.005e2` = 100.5) thay vì nhân `10^n` (`1.005 * 100` = 100.4999…).
  static num roundHalfAway(num x, int digits) {
    if (!x.isFinite) return x;
    final d = digits < 0 ? 0 : digits;
    final abs = x.abs().toDouble();
    var scaled = double.tryParse('${abs}e$d') ?? abs * _pow10(d);
    if (!scaled.isFinite) scaled = abs * _pow10(d);
    final r = scaled.round();
    final back = double.tryParse('${r}e-$d') ?? r / _pow10(d);
    final out = x < 0 ? -back : back;
    return out == 0 ? 0 : out; // bỏ -0
  }

  static double _pow10(int n) {
    var p = 1.0;
    for (var i = 0; i < n; i++) {
      p *= 10;
    }
    return p;
  }

  /// Định dạng kết quả để HIỂN THỊ: làm tròn [decimals] (0–4), phân cách kiểu Việt Nam (`.` hàng nghìn, `,` thập phân),
  /// đủ [decimals] chữ số; [format] = `currency` thêm ` đ`. `null` ⇒ chuỗi rỗng.
  static String format(num? value, {String format = 'number', int decimals = 0}) {
    if (value == null || !value.isFinite) return '';
    final d = decimals.clamp(0, 4);
    final rounded = roundHalfAway(value, d);
    final fixed = rounded.abs().toStringAsFixed(d);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
      buf.write(intPart[i]);
    }
    var s = buf.toString();
    if (d > 0 && parts.length > 1) s = '$s,${parts[1]}';
    if (rounded < 0) s = '-$s';
    return format == 'currency' ? '$s đ' : s;
  }

  /// Định dạng theo cấu hình ô; không có cấu hình (màn xem chỉ có giá trị đã lưu) ⇒ dạng số, giữ số lẻ sẵn có (≤ 4).
  static String formatWith(num? value, FormulaConfig? config) =>
      format(value, format: config?.format ?? 'number', decimals: config?.decimals ?? _autoDecimals(value));

  static int _autoDecimals(num? v) {
    if (v == null || v is int || !v.isFinite || v == v.truncate()) return 0;
    final s = v.toString();
    final dot = s.indexOf('.');
    if (dot < 0 || s.contains('e')) return 4;
    return (s.length - dot - 1).clamp(0, 4);
  }

  static List<_Tok> _tokenize(String s) {
    final out = <_Tok>[];
    var i = 0;
    while (i < s.length) {
      final c = s[i];
      if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
        i++;
        continue;
      }
      if (_isDigit(c)) {
        var j = i;
        while (j < s.length && (_isDigit(s[j]) || s[j] == '.')) {
          j++;
        }
        out.add(_Tok(_K.num, s.substring(i, j)));
        i = j;
        continue;
      }
      if (_isIdentStart(c)) {
        var j = i;
        while (j < s.length && (_isIdentStart(s[j]) || _isDigit(s[j]))) {
          j++;
        }
        out.add(_Tok(_K.ident, s.substring(i, j)));
        i = j;
        continue;
      }
      switch (c) {
        case '+':
        case '-':
        case '*':
        case '/':
          out.add(_Tok(_K.op, c));
          break;
        case '(':
          out.add(_Tok(_K.lparen, c));
          break;
        case ')':
          out.add(_Tok(_K.rparen, c));
          break;
        case ',':
          out.add(_Tok(_K.comma, c));
          break;
        default:
          throw const _FormulaFail(); // ký tự ngoài whitelist
      }
      i++;
    }
    return out;
  }

  static bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  static bool _isIdentStart(String c) {
    final u = c.codeUnitAt(0);
    return (u >= 65 && u <= 90) || (u >= 97 && u <= 122) || u == 95;
  }
}

/// Cấu hình hiển thị của một ô công thức.
class FormulaConfig {
  /// Biểu thức (có thể mở đầu bằng `=`).
  final String expr;

  /// `number` | `currency`.
  final String format;

  /// Số chữ số thập phân 0–4.
  final int decimals;

  const FormulaConfig({required this.expr, this.format = 'number', this.decimals = 0});

  /// Đọc từ map: [exprKey] là khoá biểu thức (`expr` ở schema điểm bán, `formula` ở `config` biểu mẫu thị trường).
  /// Không phải map / thiếu biểu thức ⇒ `null`. Chịu giá trị lệch kiểu (chuỗi số…).
  static FormulaConfig? fromMap(dynamic raw, {String exprKey = 'expr'}) {
    if (raw is! Map) return null;
    final expr = raw[exprKey]?.toString().trim() ?? '';
    if (expr.isEmpty) return null;
    final fmt = raw['format']?.toString() == 'currency' ? 'currency' : 'number';
    final rawDec = raw['decimals'];
    final dec = rawDec is num ? rawDec.toInt() : int.tryParse(rawDec?.toString() ?? '') ?? 0;
    return FormulaConfig(expr: expr, format: fmt, decimals: dec.clamp(0, 4));
  }

  Map<String, dynamic> toJson() => {'expr': expr, 'format': format, 'decimals': decimals};
}

enum _K { num, ident, op, lparen, rparen, comma }

class _Tok {
  final _K kind;
  final String text;
  const _Tok(this.kind, this.text);
}

class _FormulaFail implements Exception {
  const _FormulaFail();
}

/// Parser đệ quy xuống. Mọi lỗi (cú pháp, ô rỗng, chia 0) ném [_FormulaFail] ⇒ kết quả rỗng.
class _Parser {
  final List<_Tok> tokens;
  final dynamic Function(String code) read;
  int pos = 0;

  _Parser(this.tokens, this.read);

  bool get done => pos >= tokens.length;

  _Tok? _peek() => pos < tokens.length ? tokens[pos] : null;

  _Tok _next() {
    if (pos >= tokens.length) throw const _FormulaFail();
    return tokens[pos++];
  }

  num expr() {
    var left = _term();
    while (true) {
      final t = _peek();
      if (t == null || t.kind != _K.op || (t.text != '+' && t.text != '-')) return left;
      pos++;
      final right = _term();
      left = t.text == '+' ? left + right : left - right;
    }
  }

  num _term() {
    var left = _unary();
    while (true) {
      final t = _peek();
      if (t == null || t.kind != _K.op || (t.text != '*' && t.text != '/')) return left;
      pos++;
      final right = _unary();
      if (t.text == '/') {
        if (right == 0) throw const _FormulaFail();
        left = left / right;
      } else {
        left = left * right;
      }
    }
  }

  num _unary() {
    final t = _peek();
    if (t != null && t.kind == _K.op && (t.text == '-' || t.text == '+')) {
      pos++;
      final v = _unary();
      return t.text == '-' ? -v : v;
    }
    return _atom();
  }

  num _atom() {
    final t = _next();
    switch (t.kind) {
      case _K.num:
        final n = num.tryParse(t.text);
        if (n == null) throw const _FormulaFail();
        return n;
      case _K.lparen:
        final v = expr();
        if (_next().kind != _K.rparen) throw const _FormulaFail();
        return v;
      case _K.ident:
        if (_peek()?.kind == _K.lparen) return _call(t.text.toLowerCase());
        final v = FormulaEvaluator.toNum(read(t.text));
        if (v == null) throw const _FormulaFail(); // ô tham chiếu rỗng ⇒ kết quả rỗng
        return v;
      default:
        throw const _FormulaFail();
    }
  }

  List<num> _args() {
    _next(); // '('
    final out = <num>[];
    if (_peek()?.kind == _K.rparen) {
      pos++;
      return out;
    }
    while (true) {
      out.add(expr());
      final t = _next();
      if (t.kind == _K.rparen) return out;
      if (t.kind != _K.comma) throw const _FormulaFail();
    }
  }

  num _call(String name) {
    final args = _args();
    switch (name) {
      case 'round':
        if (args.isEmpty) throw const _FormulaFail(); // tham số thừa bị bỏ qua như server
        final digits = args.length > 1 ? (args[1].truncate() < 0 ? 0 : args[1].truncate()) : 0;
        return FormulaEvaluator.roundHalfAway(args[0], digits);
      case 'min':
      case 'max':
        if (args.isEmpty) throw const _FormulaFail();
        return args.reduce((a, b) => name == 'min' ? (b < a ? b : a) : (b > a ? b : a));
      default:
        throw const _FormulaFail(); // hàm ngoài whitelist
    }
  }
}
