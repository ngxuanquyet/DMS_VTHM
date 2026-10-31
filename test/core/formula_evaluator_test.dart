import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/formula_evaluator.dart';
import 'package:vthm_dms/features/forms/domain/services/dynamic_rule_evaluator.dart';

/// Bộ tính ô CÔNG THỨC dùng chung (form điểm bán + biểu mẫu thị trường) — cú pháp khớp `FormulaEvaluator.php` /
/// `dynamicFormula.ts`, nhưng ô tham chiếu RỖNG ⇒ kết quả RỖNG (hợp đồng 31/10/2026).
void main() {
  num? tinh(String f, [Map<String, dynamic> v = const {}]) => FormulaEvaluator.evaluate(f, (c) => v[c]);

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

    test('ô tham chiếu rỗng / không phải số ⇒ rỗng (không coi là 0)', () {
      expect(tinh('a * b', {'a': 5}), isNull);
      expect(tinh('a * b', {'a': 5, 'b': ''}), isNull);
      expect(tinh('a * b', {'a': 5, 'b': '   '}), isNull);
      expect(tinh('a + b', {'a': 5, 'b': 'abc'}), isNull);
      expect(tinh('a + b', {'a': 5, 'b': true}), isNull);
      expect(tinh('max(a, b)', {'a': 5}), isNull);
      expect(tinh('a * 0', {'a': 0}), 0); // 0 KHÔNG phải rỗng
    });

    test('chia 0 / không hữu hạn ⇒ rỗng', () {
      expect(tinh('a / b', {'a': 5, 'b': 0}), isNull);
      expect(tinh('5 / (2 - 2)'), isNull);
      expect(tinh('a * a', {'a': 1e200}), isNull);
    });

    test('cú pháp sai / hàm lạ / ký tự lạ ⇒ rỗng, không ném lỗi', () {
      for (final f in ['', '=', '2 +', '(2 + 3', '2 + 3)', '2 3', '1.2.3', 'a.b', 'sqrt(4)', 'round()', 'min()',
          '2 ^ 3', 'a; b', 'round(2,', '* 2', null]) {
        expect(FormulaEvaluator.evaluate(f, (_) => 1), isNull, reason: 'công thức: $f');
      }
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
      expect(FormulaEvaluator.format(2.5), '3'); // nửa ra xa số 0
      expect(FormulaEvaluator.format(-2.5), '-3');
      expect(FormulaEvaluator.format(-0.4), '0'); // không hiện -0
      expect(FormulaEvaluator.format(null), '');
    });

    test('currency: như number + " đ"', () {
      expect(FormulaEvaluator.format(5 * 60000, format: 'currency'), '300.000 đ');
      expect(FormulaEvaluator.format(1500.25, format: 'currency', decimals: 1), '1.500,3 đ');
    });

    test('FormulaConfig đọc cấu hình phòng thủ', () {
      final c = FormulaConfig.fromMap({'expr': 'a*b', 'format': 'currency', 'decimals': '2'})!;
      expect([c.expr, c.format, c.decimals], ['a*b', 'currency', 2]);
      final m = FormulaConfig.fromMap({'formula': 'a', 'decimals': 9}, exprKey: 'formula')!;
      expect([m.format, m.decimals], ['number', 4]);
      expect(FormulaConfig.fromMap(null), isNull);
      expect(FormulaConfig.fromMap({'expr': '  '}), isNull);
      expect(FormulaEvaluator.formatWith(3.3333, null), '3,3333');
      expect(FormulaEvaluator.formatWith(300000, c), '300.000,00 đ');
    });
  });

  group('tính theo thứ tự cùng ẩn/hiện (computeVisibilityOf)', () {
    // Ô: [mã, show_if, công thức]
    List<(String, dynamic, String?)> o(List<(String, dynamic, String?)> x) => x;
    Map<String, num?> chay(List<(String, dynamic, String?)> items, Map<String, dynamic> answers,
        {Map<String, bool>? visOut}) {
      final out = <String, num?>{};
      final vis = DynamicRuleEvaluator.computeVisibilityOf<(String, dynamic, String?)>(
        items: items,
        showIfOf: (i) => i.$2,
        keysOf: (i) => [i.$1],
        answers: answers,
        formulaOf: (i) => i.$3,
        formulaValuesOut: out,
      );
      visOut?.addAll(vis);
      return out;
    }

    test('ô công thức tham chiếu ô công thức đứng trước', () {
      final items = o([
        ('sl', null, null),
        ('gia', null, null),
        ('thanh_tien', null, 'sl * gia'),
        ('vat', null, 'round(thanh_tien * 0.1)'),
        ('tong', null, 'thanh_tien + vat'),
      ]);
      expect(chay(items, {'sl': 5, 'gia': 60000}), {'thanh_tien': 300000, 'vat': 30000, 'tong': 330000});
      expect(chay(items, {'sl': 5}), {'thanh_tien': null, 'vat': null, 'tong': null});
    });

    test('ô sau dùng kết quả công thức trong show_if; ô ẩn đọc ra rỗng', () {
      final items = o([
        ('sl', null, null),
        ('co_gia', null, null),
        ('gia', {'field': 'co_gia', 'op': '=', 'value': 'co'}, null),
        ('thanh_tien', null, 'sl * gia'),
        ('ghi_chu_lon', {'field': 'thanh_tien', 'op': '>', 'value': 100}, null),
      ]);
      final vis = <String, bool>{};
      expect(chay(items, {'sl': 5, 'co_gia': 'co', 'gia': 30}, visOut: vis)['thanh_tien'], 150);
      expect(vis['ghi_chu_lon'], isTrue);
      vis.clear();
      // `gia` bị ẩn ⇒ đọc ra rỗng ⇒ thành tiền rỗng ⇒ ô sau ẩn
      expect(chay(items, {'sl': 5, 'co_gia': 'khong', 'gia': 30}, visOut: vis)['thanh_tien'], isNull);
      expect(vis['ghi_chu_lon'], isFalse);
    });

    test('ô công thức đang ẩn ⇒ rỗng với ô sau', () {
      final items = o([
        ('a', null, null),
        ('x', {'field': 'a', 'op': '>', 'value': 0}, 'a * 2'),
        ('y', null, 'x + 1'),
      ]);
      expect(chay(items, {'a': 3}), {'x': 6, 'y': 7});
      expect(chay(items, {'a': -3}), {'x': null, 'y': null});
    });
  });
}
