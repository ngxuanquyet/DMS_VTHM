/// Ô CÔNG THỨC (`input_type = formula`) của biểu mẫu động — bộ tính + định dạng DÙNG CHUNG cho biểu mẫu điểm bán
/// (`DynamicFormBuilder`) và biểu mẫu thị trường (`MarketFormRenderer`).
///
/// App tính để HIỂN THỊ (kể cả offline); server tính lại và lưu. Bản này CHÉP NGỮ NGHĨA của server — sửa một bên thì
/// sửa cả bên kia:
///  - [evaluate] ↔ `common/modules/formfield/services/FormulaEvaluator.php::evaluate()`: số, mã ô, `+ - * /`, ngoặc, dấu
///    một ngôi, `round(x[, n])` (nửa ra xa số 0), `min/max` (bỏ tham số rỗng), `sum(bang.cot)`, `count(bang)`; có thể mở
///    đầu `=`. Ô trống / không phải số đọc thành 0; chia 0 chỉ làm BIỂU THỨC CON rỗng; một vế rỗng ⇒ phép tính rỗng
///    (dừng sớm đúng chỗ PHP dừng). Tính bằng double (PHP tràn int thì sang float). KHÔNG eval, không ném lỗi.
///  - [value] ↔ `FormValidator::formulaValue()`: cờ `blank_if_missing` (ô tham chiếu trống ⇒ kết quả rỗng) + làm tròn
///    theo `decimals` (chỉ khi có cấu hình).
///  - [computeAll] ↔ `FormValidator::computeFormulas()`: tính trên TOÀN BỘ giá trị (kể cả ô ẩn), ghi kết quả ĐÃ làm tròn
///    ngược vào dữ liệu, lặp tới khi đứng yên.
///  - Hàm ngày (`date_diff`, `date_add`, `hour_diff`) chưa có ở app ⇒ ra rỗng.
class FormulaEvaluator {
  FormulaEvaluator._();

  static final RegExp _dateLike = RegExp(r'^\d{4}-\d{2}-\d{2}');

  /// Tính [formula]; [read] trả giá trị thô của ô theo mã (bảng lặp: danh sách map). `null` = không tính được.
  static num? evaluate(String? formula, dynamic Function(String code) read) {
    final src = _strip(formula);
    if (src.isEmpty) return null;
    try {
      final tokens = _tokenize(src);
      if (tokens == null || tokens.isEmpty) return null;
      final p = _Parser(tokens, read);
      final v = p.expr();
      if (!p.done) return null;
      if (v == null || !v.isFinite) return null;
      return v;
    } catch (_) {
      return null;
    }
  }

  /// Mã các ô được tham chiếu (định danh không theo sau bởi `(`); cú pháp không tách được ⇒ rỗng.
  static List<String> referencedFields(String? formula) {
    final tokens = _tokenize(_strip(formula));
    if (tokens == null) return const [];
    final out = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (t.kind != _K.ident) continue;
      if (i + 1 < tokens.length && tokens[i + 1].kind == _K.lparen) continue;
      if (!out.contains(t.text)) out.add(t.text);
    }
    return out;
  }

  /// Giá trị MỘT ô công thức theo cấu hình: `blankIfMissing` ⇒ ô tham chiếu trống / không phải số cho kết quả rỗng;
  /// `decimals` có ⇒ làm tròn kết quả (số ô sau và `show_if` đọc là số ĐÃ làm tròn).
  static num? value(FormulaConfig config, dynamic Function(String code) read) {
    if (config.blankIfMissing) {
      for (final ref in referencedFields(config.expr)) {
        if (!_isNumeric(read(ref))) return null;
      }
    }
    final v = evaluate(config.expr, read);
    final d = config.decimals;
    if (v == null || d == null) return v;
    return roundHalfAway(v, d.clamp(0, 4));
  }

  /// Tính mọi ô công thức ([configs] theo đúng thứ tự khai báo) trên [data] — TOÀN BỘ giá trị, kể cả ô đang ẩn và giá
  /// trị đang lưu. Kết quả ghi ngược vào bản sao dữ liệu để công thức khác đọc; lặp tới khi đứng yên, tối đa số ô công
  /// thức lượt (đủ cho chuỗi phụ thuộc dài nhất bất kể thứ tự, vòng tròn thì dừng ở trần) — như server.
  static Map<String, num?> computeAll(Map<String, FormulaConfig> configs, Map<String, dynamic> data) {
    final out = <String, num?>{};
    if (configs.isEmpty) return out;
    final work = Map<String, dynamic>.from(data);
    for (var lap = 0; lap < configs.length; lap++) {
      var changed = false;
      configs.forEach((code, cfg) {
        final v = value(cfg, (c) => work[c]);
        if (!out.containsKey(code) || out[code] != v) changed = true;
        out[code] = v;
        work[code] = v;
      });
      if (!changed) break;
    }
    return out;
  }

  /// Ép giá trị ô về số; trống / không phải số ⇒ `null` (dùng cho màn xem giá trị đã lưu).
  static num? toNum(dynamic v) {
    if (v is num) return v.isFinite ? v : null;
    if (v is String) {
      final n = double.tryParse(v.trim());
      return n != null && n.isFinite ? n : null;
    }
    return null;
  }

  /// Khớp `is_int || is_float || is_numeric(trim(chuỗi))` của server.
  static bool _isNumeric(dynamic v) => toNum(v) != null;

  /// Ép giá trị ô về số cho phép tính — trống / không phải số ⇒ 0 (khớp `toNum` của server).
  static double _num0(dynamic v) => toNum(v)?.toDouble() ?? 0;

  /// Làm tròn [digits] chữ số thập phân, nửa ra xa số 0 (khớp `round()` PHP). Dời dấu phẩy bằng chuỗi mũ
  /// (`1.005e2` = 100.5) thay vì nhân `10^n` (`1.005 * 100` = 100.4999…).
  static num roundHalfAway(num x, int digits) {
    if (!x.isFinite) return x;
    final d = digits < 0 ? 0 : digits;
    final abs = x.abs().toDouble();
    var scaled = double.tryParse('${abs}e$d') ?? abs * _pow10(d);
    if (!scaled.isFinite) scaled = abs * _pow10(d);
    if (scaled.abs() >= 9e15) return x; // vượt độ chính xác double: không còn phần lẻ để làm tròn
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

  /// Định dạng theo cấu hình ô (vắng `decimals` = 0); không có cấu hình (màn xem chỉ có giá trị đã lưu) ⇒ dạng số, giữ
  /// số lẻ sẵn có (≤ 4).
  static String formatWith(num? value, FormulaConfig? config) => format(
        value,
        format: config?.format ?? 'number',
        decimals: config != null ? (config.decimals ?? 0) : _autoDecimals(value),
      );

  static int _autoDecimals(num? v) {
    if (v == null || v is int || !v.isFinite || v == v.truncate()) return 0;
    final s = v.toString();
    final dot = s.indexOf('.');
    if (dot < 0 || s.contains('e')) return 4;
    return (s.length - dot - 1).clamp(0, 4);
  }

  static String _strip(String? formula) {
    var src = (formula ?? '').trim();
    if (src.startsWith('=')) src = src.substring(1).trim();
    return src;
  }

  /// Tách token như server (`[0-9.]+`, `[A-Za-z_][A-Za-z0-9_.]*`, toán tử, ngoặc, phẩy); ký tự lạ ⇒ `null`.
  static List<_Tok>? _tokenize(String s) {
    final out = <_Tok>[];
    var i = 0;
    while (i < s.length) {
      final c = s[i];
      if (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f' || c == '\v') {
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
        while (j < s.length && (_isIdentStart(s[j]) || _isDigit(s[j]) || s[j] == '.')) {
          j++;
        }
        out.add(_Tok(_K.ident, s.substring(i, j)));
        i = j;
        continue;
      }
      final kind = switch (c) {
        '+' || '-' || '*' || '/' => _K.op,
        '(' => _K.lparen,
        ')' => _K.rparen,
        ',' => _K.comma,
        _ => null,
      };
      if (kind == null) return null;
      out.add(_Tok(kind, c));
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

/// Cấu hình một ô công thức.
class FormulaConfig {
  /// Biểu thức (có thể mở đầu bằng `=`).
  final String expr;

  /// `number` | `currency`.
  final String format;

  /// Số chữ số thập phân 0–4; `null` = không cấu hình (server không làm tròn giá trị lưu, hiển thị 0 số lẻ).
  final int? decimals;

  /// Ô tham chiếu trống ⇒ kết quả rỗng (vắng/false = coi là 0 như server).
  final bool blankIfMissing;

  const FormulaConfig({required this.expr, this.format = 'number', this.decimals, this.blankIfMissing = false});

  /// Đọc từ map: [exprKey] là khoá biểu thức, [blankKey] là khoá cờ trống-thì-rỗng — schema điểm bán `formula:
  /// {expr, format, decimals, blank}`, `config` biểu mẫu thị trường `{formula, format, decimals, blank_if_missing}`.
  /// Không phải map / thiếu biểu thức ⇒ `null`. Chịu giá trị lệch kiểu (chuỗi số…).
  static FormulaConfig? fromMap(dynamic raw, {String exprKey = 'expr', String blankKey = 'blank'}) {
    if (raw is! Map) return null;
    final expr = raw[exprKey]?.toString().trim() ?? '';
    if (expr.isEmpty) return null;
    final fmt = raw['format']?.toString() == 'currency' ? 'currency' : 'number';
    final rawDec = raw['decimals'];
    final dec = rawDec is num ? rawDec.toInt() : int.tryParse(rawDec?.toString() ?? '');
    final blank = raw[blankKey];
    return FormulaConfig(
      expr: expr,
      format: fmt,
      decimals: dec?.clamp(0, 4),
      blankIfMissing: blank == true || blank == 1 || blank == '1' || blank == 'true',
    );
  }

  Map<String, dynamic> toJson() =>
      {'expr': expr, 'format': format, if (decimals != null) 'decimals': decimals, 'blank': blankIfMissing};
}

enum _K { num, ident, op, lparen, rparen, comma }

class _Tok {
  final _K kind;
  final String text;
  const _Tok(this.kind, this.text);
}

/// Parser đệ quy xuống chép đúng `FormulaEvaluator.php`: `null` = biểu thức con không tính được; dừng sớm ở đúng chỗ
/// PHP dừng (token còn dư ở mức ngoài cùng ⇒ cả công thức rỗng).
class _Parser {
  final List<_Tok> tokens;
  final dynamic Function(String code) read;
  int pos = 0;

  _Parser(this.tokens, this.read);

  bool get done => pos >= tokens.length;

  _Tok? _peek() => pos < tokens.length ? tokens[pos] : null;

  /// Lấy token và LUÔN tiến con trỏ (kể cả khi đã hết — như `$this->tokens[$this->pos++] ?? null`).
  _Tok? _next() {
    final t = pos < tokens.length ? tokens[pos] : null;
    pos++;
    return t;
  }

  double? expr() {
    var left = _term();
    while (true) {
      final t = _peek();
      if (t == null || t.kind != _K.op || (t.text != '+' && t.text != '-')) return left;
      pos++;
      final right = _term();
      if (left == null || right == null) return null;
      left = t.text == '+' ? left + right : left - right;
    }
  }

  double? _term() {
    var left = _unary();
    while (true) {
      final t = _peek();
      if (t == null || t.kind != _K.op || (t.text != '*' && t.text != '/')) return left;
      pos++;
      final right = _unary();
      if (left == null || right == null) return null;
      if (t.text == '/') {
        if (right == 0) return null; // chia 0 ⇒ biểu thức con rỗng
        left = left / right;
      } else {
        left = left * right;
      }
    }
  }

  double? _unary() {
    final t = _peek();
    if (t != null && t.kind == _K.op && (t.text == '-' || t.text == '+')) {
      pos++;
      final v = _unary();
      if (t.text == '+') return v;
      return v == null ? null : -v;
    }
    return _atom();
  }

  double? _atom() {
    final t = _next();
    if (t == null) return null;
    switch (t.kind) {
      case _K.num:
        return _numeric(t.text);
      case _K.lparen:
        final v = expr();
        final close = _next();
        return close != null && close.kind == _K.rparen ? v : null;
      case _K.ident:
        if (_peek()?.kind == _K.lparen) return _call(t.text.toLowerCase());
        if (t.text.contains('.')) return null; // `bang.cot` ngoài sum()
        final raw = read(t.text);
        if (raw is String && FormulaEvaluator._dateLike.hasMatch(raw)) return null; // chuỗi ngày: không phải số
        return FormulaEvaluator._num0(raw);
      default:
        return null;
    }
  }

  /// `is_numeric` của PHP cho token số (`[0-9.]+`): đúng một dấu chấm tối đa, không kết thúc… `1.` vẫn hợp lệ.
  static double? _numeric(String s) {
    if ('.'.allMatches(s).length > 1) return null;
    return double.tryParse(s.endsWith('.') ? '${s}0' : s);
  }

  List<double?>? _args() {
    _next(); // '('
    final out = <double?>[];
    if (_peek()?.kind == _K.rparen) {
      pos++;
      return out;
    }
    while (true) {
      out.add(expr());
      final t = _next();
      if (t == null) return null;
      if (t.kind == _K.rparen) return out;
      if (t.kind != _K.comma) return null;
    }
  }

  /// Tham số thô `(ident)` cho `sum(bang.cot)` / `count(bang)`.
  String? _rawIdentArg() {
    if (_peek()?.kind != _K.lparen) return null;
    final save = pos;
    pos++;
    final id = _next();
    final close = _next();
    if (id != null && id.kind == _K.ident && close != null && close.kind == _K.rparen) return id.text;
    pos = save;
    return null;
  }

  double? _call(String name) {
    if (name == 'sum' || name == 'count') {
      final path = _rawIdentArg();
      if (path == null) return null;
      if (name == 'count') {
        final rows = read(path);
        return rows is List ? rows.length.toDouble() : 0;
      }
      final dot = path.indexOf('.');
      final table = dot < 0 ? path : path.substring(0, dot);
      final col = dot < 0 ? '' : path.substring(dot + 1);
      final rows = read(table);
      if (rows is! List || col.isEmpty) return 0;
      return rows.fold<double>(0, (a, r) => a + FormulaEvaluator._num0(r is Map ? r[col] : null));
    }

    final args = _args();
    if (args == null) return null;
    switch (name) {
      case 'round':
        if (args.isEmpty || args[0] == null) return null;
        final digits = args.length > 1 && args[1] != null ? (args[1]!.truncate() < 0 ? 0 : args[1]!.truncate()) : 0;
        return FormulaEvaluator.roundHalfAway(args[0]!, digits).toDouble();
      case 'min':
      case 'max':
        final vals = args.whereType<double>().toList(); // bỏ tham số rỗng
        if (vals.isEmpty) return null;
        return vals.reduce((a, b) => name == 'min' ? (b < a ? b : a) : (b > a ? b : a));
      default:
        return null; // hàm ngoài whitelist (kể cả hàm ngày — chưa có ở app)
    }
  }
}
