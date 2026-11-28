import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/widgets/display_matrix_field_widget.dart';
import 'package:vthm_dms/core/services/product_catalog_service.dart';
import 'package:vthm_dms/features/forms/domain/services/dynamic_rule_evaluator.dart';

/// Mã SKU hàng của ta theo loại trong ma trận SOS (`config.matrix.own_skus`, chủ hệ thống yêu cầu 27/11/2026): ô mã dưới ảnh của
/// loại, chỉ hiện + bắt buộc khi loại có số > 0 ở thương hiệu "của ta" (số HIỆU LỰC, tính cả số hiện trạng hồ sơ); cùng luật server.
void main() {
  final cfg = DisplayMatrixConfig.fromConfig({
    'matrix': {
      'own_skus': true,
      'brands': [
        {'code': 'vthm', 'name': 'VTHM', 'is_own': true},
        {'code': 'kova', 'name': 'Kova'},
      ],
      'types': [
        {'code': 'ke', 'name': 'Kệ', 'max_photos': 3},
        {'code': 'op', 'name': 'Ốp', 'max_photos': 0},
      ],
    },
  });

  test('đọc công tắc own_skus; withCustom giữ công tắc', () {
    expect(cfg.ownSkus, isTrue);
    expect(cfg.withCustom(const DisplayMatrixCustom(brands: [(code: 'x_a', name: 'A')])).ownSkus, isTrue);
    expect(DisplayMatrixConfig.fromConfig({'matrix': {'brands': [], 'types': []}}).ownSkus, isFalse);
  });

  test('loại có hàng của ta = số > 0 ở thương hiệu is_own; thiếu mã ⇒ lỗi, đối thủ không tính', () {
    final counts = {
      'vthm': {'ke': 2, 'op': 0},
      'kova': {'op': 5},
    };
    expect(DisplayMatrixFieldWidget.ownTypes(counts, cfg), {'ke'});
    expect(DisplayMatrixFieldWidget.skusError(counts, const {}, cfg), contains('Kệ'));
    expect(
      DisplayMatrixFieldWidget.skusError(counts, {
        'ke': [
          {'id': 1, 'code': 'A'},
        ],
      }, cfg),
      isNull,
    );
    // Công tắc tắt ⇒ không đòi.
    expect(
      DisplayMatrixFieldWidget.skusError(counts, const {}, DisplayMatrixConfig.fromConfig({'matrix': {'brands': [], 'types': []}})),
      isNull,
    );
  });

  test('giá trị gửi: khoá skus luôn có khi bật (kể cả rỗng); chỉ có mã vẫn là giá trị; sameValue so cả mã', () {
    expect(displayMatrixValue({'vthm': {'ke': 1}}, const {}, const DisplayMatrixCustom(), skus: const {}),
        containsPair('skus', const <String, dynamic>{}));
    expect(displayMatrixValue({'vthm': {'ke': 1}}, const {}, const DisplayMatrixCustom()), isNot(contains('skus')));
    final chiMa = displayMatrixValue(const {}, const {}, const DisplayMatrixCustom(), skus: {
      'ke': [
        {'id': 7},
      ],
    });
    expect(chiMa, isNotNull);
    expect(displayMatrixValue(const {}, const {}, const DisplayMatrixCustom(), skus: const {}), isNull);

    final a = {
      'counts': {
        'vthm': {'ke': 1},
      },
      'photos': {},
      'skus': {
        'ke': [
          {'id': 1, 'code': 'A'},
        ],
      },
    };
    final b = {
      ...a,
      'skus': {
        'ke': [
          {'id': 2, 'code': 'B'},
        ],
      },
    };
    expect(DisplayMatrixFieldWidget.sameValue(a, Map.of(a)), isTrue);
    expect(DisplayMatrixFieldWidget.sameValue(a, b), isFalse, reason: 'chỉ đổi mã cũng phải gửi');
    expect(DisplayMatrixFieldWidget.skusOf({
      'skus': {
        'ke': [
          {'id': 'x'},
          {'id': 3},
        ],
        'op': [],
      },
    }), {
      'ke': [
        {'id': 3},
      ],
    });
  });

  test('giá trị CHỈ có mã là có dữ liệu — bước làm sạch lúc nộp không bỏ, điều kiện "có giá trị" coi là có', () {
    final chiMa = {
      'counts': {},
      'photos': {},
      'skus': {
        'ke': [
          {'id': 7, 'code': 'A'},
        ],
      },
    };
    expect(displayMatrixHasData(chiMa), isTrue);
    expect(DynamicRuleEvaluator.isEmptyValue(chiMa), isFalse);
    expect(displayMatrixHasData({'counts': {}, 'photos': {}, 'skus': {'ke': []}}), isFalse);
  });

  test('danh mục mã: CHỈ tìm theo kích thước + mã thiết kế 5 số (luật server 27/11/2026), khớp đúng xếp trước; nhãn gọn như server', () {
    final cat = ProductCatalog.fromJson([
      {'id': 1, 'code': '19101001113', 'name': 'Gạch 300X600, mã 00111', 'size': '300X600', 'design': '00111'},
      {'id': 2, 'code': '29101001113', 'name': 'Gạch 600X600, mã 08535', 'size': '600X600', 'design': '08535'},
      {'id': 0, 'code': 'bo', 'name': 'id hỏng'},
    ]);
    expect(cat.items, hasLength(2));
    expect(cat.search('600x600 08535').map((e) => e.id), [2]);
    expect(cat.search('600 x 600').map((e) => e.id), [2], reason: '«600 x 600» gộp một từ, không thành «600» + «X»');
    expect(cat.search('600×600, 08535').map((e) => e.id), [2]);
    expect(cat.search('600*600').map((e) => e.id), [2]);
    expect(cat.search('600').map((e) => e.id), [1, 2], reason: 'theo kích thước rồi mã thiết kế');
    expect(cat.search('1910'), isEmpty, reason: 'không tìm theo mã vật tư');
    expect(cat.search('gach'), isEmpty, reason: 'không tìm theo tên hàng');
    expect(cat.search('a'), isEmpty, reason: 'từ 2 ký tự');
    expect(ProductCatalog.tokens(' 600 x 600 , 08535 ; x 08535 '), ['600X600', '08535']);
    // Khớp ĐÚNG kích thước đứng trước cỡ chỉ chứa nó (1600X600 chứa «600X600»), kể cả khi thứ tự chữ xếp nó sau.
    final cat2 = ProductCatalog.fromJson([
      {'id': 5, 'code': 'A', 'name': 'x', 'size': '1600X600', 'design': '00001'},
      {'id': 6, 'code': 'B', 'name': 'x', 'size': '600X600', 'design': '00002'},
      {'id': 7, 'code': 'C', 'name': 'x', 'size': '', 'design': '60060'},
    ]);
    expect(cat2.search('600x600').map((e) => e.id), [6, 5]);
    expect(cat2.search('60060').map((e) => e.id), [7]);
    expect(ProductSkuItem.labelOf({'code': '1', 'name': 'Gạch 600X600, mã 08535'}), '600X600 · 08535');
    expect(ProductSkuItem.labelOf({'code': 'C1', 'name': 'Keo dán'}), 'C1 - Keo dán');
  });

  testWidgets('ô mã chỉ vẽ ở loại có hàng của ta — tính cả số hiện trạng hồ sơ (ô trống giữ số cũ)', (tester) async {
    Future<void> ve({required DisplayMatrixCounts counts, DisplayMatrixCounts hints = const {}}) => tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DisplayMatrixFieldWidget(
                label: 'SOS',
                config: cfg,
                counts: counts,
                hintCounts: hints,
                onChanged: (_, __) {},
                skuSection: (t) => Text('SKU-${t.code}'),
              ),
            ),
          ),
        ));

    await ve(counts: {
      'vthm': {'ke': 2},
      'kova': {'op': 3},
    });
    expect(find.text('SKU-ke'), findsOneWidget);
    expect(find.text('SKU-op'), findsNothing, reason: 'Ốp chỉ có hàng đối thủ');

    // Phiếu cập nhật hiện trạng: chưa gõ gì, hồ sơ có hàng của ta ở Ốp ⇒ ô mã Ốp hiện (loại không chụp ảnh vẫn có ô mã).
    await ve(counts: const {}, hints: {
      'vthm': {'op': 4},
    });
    expect(find.text('SKU-op'), findsOneWidget);
    expect(find.text('SKU-ke'), findsNothing);

    // Gõ 0 cho hàng của ta ⇒ ô mã ẩn.
    await ve(counts: {
      'vthm': {'op': 0},
    }, hints: {
      'vthm': {'op': 4},
    });
    expect(find.text('SKU-op'), findsNothing);
  });
}
