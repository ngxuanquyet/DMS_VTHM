import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/formula_evaluator.dart';

/// Bộ tính ô CÔNG THỨC dùng chung (form điểm bán + biểu mẫu thị trường) — ngữ nghĩa chép từ server
/// (`FormulaEvaluator.php` + `FormValidator::formulaValue/computeFormulas`).
void main() {
  num? tinh(String? f, [Map<String, dynamic> v = const {}]) => FormulaEvaluator.evaluate(f, (c) => v[c]);
  num? giaTri(FormulaConfig c, Map<String, dynamic> v) => FormulaEvaluator.value(c, (k) => v[k]);

  group('evaluate', () {
    test('ví dụ hợp đồng: so_luong 5 × gia_tri 6 = 30', () {
      expect(tinh('so_luong * gia_tri', {'so_luong': 5, 'gia_tri': 6}), 30);
      expect(tinh('= so_luong * gia_tri', {'so_luong': '5', 'gia_tri': ' 6 '}), 30);
    });

    test('thứ tự phép tính + ngoặc', () {
      expect(tinh('2 + 3 * 4'), 14);
      expect(tinh('(2 + 3) * 4'), 20);
      expect(tinh('10 / 4'), 2.5);
      expect(tinh('1.5 * 2'), 3);
      expect(tinh('((a))', {'a': 7}), 7);
    });

    test('dấu âm / dương một ngôi', () {
      expect(tinh('-a + 10', {'a': 3}), 7);
      expect(tinh('-(2 + 3)'), -5);
      expect(tinh('--4'), 4);
      expect(tinh('+4 * -2'), -8);
    });

    test('round (nửa ra xa số 0), min, max', () {
      expect(tinh('round(2.5)'), 3);
      expect(tinh('round(-2.5)'), -3);
      expect(tinh('round(1.005, 2)'), 1.01);
      expect(tinh('round(10 / 3, 2)'), 3.33);
      expect(tinh('ROUND(a, 1)', {'a': 1.25}), 1.3);
      expect(tinh('min(3, a, 9)', {'a': 1}), 1);
      expect(tinh('max(3, a, 9)', {'a': 12}), 12);
      expect(tinh('min(5)'), 5);
    });

    test('ô trống / không phải số đọc thành 0 (như server, khi không bật blank)', () {
      expect(tinh('a * b', {'a': 5}), 0);
      expect(tinh('a + b', {'a': 5, 'b': ''}), 5);
      expect(tinh('a + b', {'a': 5, 'b': 'abc'}), 5);
    });

    test('mục 3: chia 0 chỉ làm biểu thức con rỗng; min/max bỏ tham số rỗng; một vế rỗng ⇒ rỗng', () {
      expect(tinh('max(doanh_thu / so_don, 0)', {'doanh_thu': 100, 'so_don': 0}), 0);
      expect(tinh('min(a / 0, b / 0)', {'a': 1, 'b': 2}), isNull); // mọi tham số rỗng
      expect(tinh('max(a / b, 7)', {'a': 10, 'b': 2}), 7);
      expect(tinh('a / b', {'a': 5, 'b': 0}), isNull);
      expect(tinh('a / b + 1', {'a': 5, 'b': 0}), isNull);
      expect(tinh('1 - a / b', {'a': 5, 'b': 0}), isNull);
      expect(tinh('round(a / 0, 2)', {'a': 5}), isNull);
    });

    test('mục 5: không tràn int64 (tính bằng double như PHP sang float)', () {
      // 9.000.000.000 × 9.000.000.000 = 8,1e19 > int64 max (9,22e18) — int Dart sẽ quay vòng ra số âm.
      final v = tinh('a * b', {'a': 9000000000, 'b': 9000000000});
      expect(v, isNotNull);
      expect(v! > 0, isTrue);
      expect(v, closeTo(8.1e19, 1e6));
      expect(tinh('a + b', {'a': 9223372036854775807, 'b': 9223372036854775807})! > 0, isTrue);
    });

    test('cú pháp sai / hàm lạ / ký tự lạ ⇒ rỗng, không ném lỗi', () {
      for (final f in ['', '=', '2 +', '(2 + 3', '2 + 3)', '2 3', '1.2.3', 'a.b', 'sqrt(4)', 'round()', 'min()',
          '2 ^ 3', 'a; b', 'round(2,', '* 2', null]) {
        expect(FormulaEvaluator.evaluate(f, (_) => 1), isNull, reason: 'công thức: $f');
      }
    });

    test('sum/count bảng lặp như server', () {
      final v = {
        'bang': [
          {'sl': 2},
          {'sl': '3'},
          {'sl': null},
        ],
      };
      expect(tinh('sum(bang.sl)', v), 5);
      expect(tinh('count(bang)', v), 3);
      expect(tinh('count(khong_co)', v), 0);
    });
  });

  group('value (cấu hình ô)', () {
    test('mục 4: blank = true ⇒ ô tham chiếu trống cho kết quả rỗng; false/vắng ⇒ coi là 0', () {
      const rong = FormulaConfig(expr: 'a * b', blankIfMissing: true);
      const khong = FormulaConfig(expr: 'a * b');
      expect(giaTri(rong, {'a': 5}), isNull);
      expect(giaTri(rong, {'a': 5, 'b': ''}), isNull);
      expect(giaTri(rong, {'a': 5, 'b': true}), isNull);
      expect(giaTri(rong, {'a': 5, 'b': '6'}), 30);
      expect(giaTri(rong, {'a': 0, 'b': 6}), 0); // 0 KHÔNG phải trống
      expect(giaTri(khong, {'a': 5}), 0);
    });

    test('decimals làm tròn kết quả; vắng decimals thì không làm tròn', () {
      expect(giaTri(const FormulaConfig(expr: 'x / 3', decimals: 2), {'x': 10}), 3.33);
      expect(giaTri(const FormulaConfig(expr: 'x / 3'), {'x': 10}), closeTo(3.3333333, 1e-6));
    });

    test('FormulaConfig đọc cờ blank từ hai dạng schema', () {
      final dienBan = FormulaConfig.fromMap({'expr': 'a*b', 'format': 'currency', 'decimals': '2', 'blank': true})!;
      expect([dienBan.expr, dienBan.format, dienBan.decimals, dienBan.blankIfMissing], ['a*b', 'currency', 2, true]);
      final cu = FormulaConfig.fromMap({'expr': 'a'})!; // bản cũ: không blank, không decimals
      expect([cu.blankIfMissing, cu.decimals], [false, null]);
      final thiTruong = FormulaConfig.fromMap({'formula': 'a', 'decimals': 9, 'blank_if_missing': true},
          exprKey: 'formula', blankKey: 'blank_if_missing')!;
      expect([thiTruong.format, thiTruong.decimals, thiTruong.blankIfMissing], ['number', 4, true]);
      expect(FormulaConfig.fromMap(null), isNull);
      expect(FormulaConfig.fromMap({'expr': '  '}), isNull);
    });
  });

  group('computeAll (như FormValidator::computeFormulas)', () {
    test('mục 1: công thức sau đọc số ĐÃ làm tròn — A = x/3 (2 số lẻ), x = 10, B = A*3 ⇒ 9.99', () {
      final r = FormulaEvaluator.computeAll({
        'a': const FormulaConfig(expr: 'x / 3', decimals: 2),
        'b': const FormulaConfig(expr: 'a * 3', decimals: 2),
      }, {'x': 10});
      expect(r['a'], 3.33);
      expect(r['b'], closeTo(9.99, 1e-9));
    });

    test('công thức tham chiếu công thức khác — cả khi khai báo đứng SAU (lặp tới khi đứng yên)', () {
      final r = FormulaEvaluator.computeAll({
        'tong': const FormulaConfig(expr: 'thanh_tien + vat', decimals: 0),
        'thanh_tien': const FormulaConfig(expr: 'sl * gia', decimals: 0),
        'vat': const FormulaConfig(expr: 'thanh_tien * 0.1', decimals: 0),
      }, {'sl': 5, 'gia': 60000});
      expect(r, {'tong': 330000, 'thanh_tien': 300000, 'vat': 30000});
    });

    test('mục 2: tính trên TOÀN BỘ giá trị — không có khái niệm ẩn ở đây (ô ẩn vẫn mang giá trị)', () {
      final r = FormulaEvaluator.computeAll({'x': const FormulaConfig(expr: 'an * 2', blankIfMissing: true)}, {'an': 4});
      expect(r['x'], 8);
    });
  });

  group('format', () {
    test('number: phân cách hàng nghìn kiểu Việt Nam, đủ số lẻ', () {
      expect(FormulaEvaluator.format(30), '30');
      expect(FormulaEvaluator.format(1234567), '1.234.567');
      expect(FormulaEvaluator.format(10 / 3, decimals: 2), '3,33');
      expect(FormulaEvaluator.format(2, decimals: 2), '2,00');
      expect(FormulaEvaluator.format(1234.5, decimals: 1), '1.234,5');
      expect(FormulaEvaluator.format(-1234567.891, decimals: 2), '-1.234.567,89');
      expect(FormulaEvaluator.format(2.5), '3');
      expect(FormulaEvaluator.format(-2.5), '-3');
      expect(FormulaEvaluator.format(-0.4), '0');
      expect(FormulaEvaluator.format(null), '');
    });

    test('currency: như number + " đ"', () {
      expect(FormulaEvaluator.format(5 * 60000, format: 'currency'), '300.000 đ');
      expect(FormulaEvaluator.format(1500.25, format: 'currency', decimals: 1), '1.500,3 đ');
      expect(FormulaEvaluator.formatWith(300000, const FormulaConfig(expr: 'a', format: 'currency', decimals: 2)),
          '300.000,00 đ');
      expect(FormulaEvaluator.formatWith(3.3333, null), '3,3333');
      expect(FormulaEvaluator.formatWith(3.6, const FormulaConfig(expr: 'a')), '4'); // vắng decimals = 0 khi hiển thị
    });
  });
}
