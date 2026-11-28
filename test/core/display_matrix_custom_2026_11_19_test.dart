import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/widgets/display_matrix_field_widget.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/domain/services/dynamic_rule_evaluator.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';

/// Ma trận SOS đợt 2 (hợp đồng `API-MA-TRAN-SOS-DOT2-2026-11-19.md`): thương hiệu thêm dần, thương hiệu / loại gõ tay
/// (`custom`), công tắc `photos_when_zero`, loại gõ tay bắt ít nhất 1 ảnh.
void main() {
  Map<String, dynamic> matrix({bool photosWhenZero = false, int? minBrands}) => {
        'matrix': {
          'brands': [
            {'code': 'vthm', 'name': 'VTHM', 'is_own': true},
            {'code': 'kova', 'name': 'KOVA', 'is_own': false},
            {'code': 'dulux', 'name': 'Dulux', 'is_own': false},
          ],
          'types': [
            {'code': 'ke_lat', 'name': 'Kệ lật', 'unit': 'tấm', 'decimals': 0, 'face_factor': 1, 'min_photos': 1, 'max_photos': 3},
            {'code': 'op_mau', 'name': 'Ốp mẫu', 'unit': 'm²', 'decimals': 1, 'face_factor': 2, 'min_photos': 0, 'max_photos': 0},
          ],
          'photos_when_zero': photosWhenZero,
          if (minBrands != null) 'min_brands': minBrands,
          'units': ['m²', 'tấm'],
          'custom_type': {'decimals': 2, 'face_factor': 1, 'min_photos': 1, 'max_photos': 10},
        },
      };

  MarketFormBlockEntity o(Map<String, dynamic> cfg) => MarketFormBlockEntity(
        ref: 'sos',
        type: 'field',
        required: false,
        resolved: MarketFormResolvedEntity(code: 'sos', label: 'Số mặt trưng bày', inputType: 'display_matrix', config: cfg),
      );

  Future<GlobalKey<MarketFormRendererState>> mo(WidgetTester tester, {Map<String, dynamic>? cfg, Map<String, dynamic>? answers}) async {
    final key = GlobalKey<MarketFormRendererState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MarketFormRenderer(key: key, blocks: [o(cfg ?? matrix())], initialAnswers: answers ?? const {}),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return key;
  }

  Future<void> bam(WidgetTester tester, String k) async {
    await tester.ensureVisible(find.byKey(ValueKey(k)));
    // Cuộn (kể cả cuộn NGANG trong ma trận) chỉ áp ở khung hình sau — bấm ngay là bấm vào toạ độ cũ.
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(k)));
    await tester.pumpAndSettle();
  }

  Future<void> goTen(WidgetTester tester, String ten, {String? donVi}) async {
    await tester.enterText(find.byKey(const ValueKey('matrix_name_input')), ten);
    if (donVi != null) await tester.enterText(find.byKey(const ValueKey('matrix_unit_input')), donVi);
    await tester.tap(find.byKey(const ValueKey('matrix_name_ok')));
    await tester.pumpAndSettle();
  }

  group('mã mục gõ tay (§2)', () {
    test('slug: bỏ dấu, đ → d, bỏ hết ký tự ngoài [a-z0-9] (gộp liền)', () {
      expect(displayMatrixSlug('Kệ gỗ'), 'kego');
      expect(displayMatrixSlug('Đồng Tâm'), 'dongtam');
      expect(displayMatrixSlug('  --Sơn   Hà Nội 2!! '), 'sonhanoi2');
      for (final t in ['Kô va', 'Kova', 'KOVA', 'kô-VA']) {
        expect(displayMatrixSlug(t), 'kova', reason: t);
      }
      // Dấu tổ hợp (NFD, bàn phím một số máy gõ ra) cũng bỏ được.
      expect(displayMatrixSlug('Ke\u0323 go\u0302\u0303'), 'kego');
      expect(displayMatrixSlug('!!! ---'), '');
      expect(displayMatrixSlug('${'a' * 30} ${'b' * 30}'), 'a' * 30 + 'b' * 10);
    });

    test('mã = x_ + slug; tên không dùng được ⇒ null; tên chuẩn hoá ≤ 60 ký tự', () {
      expect(displayMatrixCustomCode('Kệ gỗ'), 'x_kego');
      expect(displayMatrixCustomCode('  '), isNull);
      expect(displayMatrixNormName('  Kệ    gỗ  '), 'Kệ gỗ');
      expect(displayMatrixNormName('x' * 80).length, 60);
    });

    test('tên gõ trùng danh mục theo slug ⇒ trả mục danh mục', () {
      final cfg = DisplayMatrixConfig.fromConfig(matrix());
      expect(cfg.catalogBrandNamed('kova')?.code, 'kova');
      expect(cfg.catalogBrandNamed(' Dulux ')?.code, 'dulux');
      expect(cfg.catalogBrandNamed('Nippon'), isNull);
      expect(cfg.catalogTypeNamed('ke lat')?.code, 'ke_lat');
    });
  });

  group('đọc config + giá trị', () {
    test('config: photos_when_zero, units, custom_type; withCustom thêm mục gõ tay (hệ số 1, tối thiểu 1 ảnh)', () {
      final cfg = DisplayMatrixConfig.fromConfig(matrix(photosWhenZero: true));
      expect(cfg.photosWhenZero, isTrue);
      expect(cfg.units, ['m²', 'tấm']);
      final eff = cfg.withCustom(const DisplayMatrixCustom(
        brands: [(code: 'x_nippon', name: 'Nippon')],
        types: [(code: 'x_kego', name: 'Kệ gỗ', unit: 'tấm')],
      ));
      expect(eff.brands.last.custom, isTrue);
      final t = eff.types.last;
      expect([t.code, t.custom, t.faceFactor, t.decimals, t.minPhotos, t.maxPhotos], ['x_kego', true, 1, 2, 1, 10]);
      // Thiếu `units` (server cũ) ⇒ lấy đơn vị của danh mục.
      final cu = DisplayMatrixConfig.fromConfig({'matrix': {'types': (matrix()['matrix'] as Map)['types']}});
      expect(cu.units.toSet(), {'tấm', 'm²'});
    });

    test('fromValue: đọc custom + mục custom:true của snapshot, bỏ mục danh mục; toJson đúng hình hợp đồng', () {
      final c = DisplayMatrixCustom.fromValue({
        'counts': {'x_nippon': {'x_kego': 2}},
        'custom': {'brands': [{'code': 'x_toa', 'name': 'TOA'}]},
        'snapshot': {
          'brands': [
            {'code': 'vthm', 'name': 'VTHM', 'is_own': true},
            {'code': 'x_nippon', 'name': 'Nippon', 'custom': true},
          ],
          'types': [
            {'code': 'ke_lat', 'name': 'Kệ lật'},
            {'code': 'x_kego', 'name': 'Kệ gỗ', 'unit': 'tấm', 'custom': true},
          ],
        },
      });
      expect(c.toJson(), {
        'brands': [{'code': 'x_toa', 'name': 'TOA'}, {'code': 'x_nippon', 'name': 'Nippon'}],
        'types': [{'code': 'x_kego', 'name': 'Kệ gỗ', 'unit': 'tấm'}],
      });
      expect(DisplayMatrixCustom.fromValue(null).isEmpty, isTrue);
    });

    test('minusUnused: mục gõ tay của hồ sơ mà phiếu không dùng thì khỏi gửi; mục tự thêm giữ', () {
      const hoSo = DisplayMatrixCustom(brands: [(code: 'x_nippon', name: 'Nippon')], types: [(code: 'x_kego', name: 'Kệ gỗ', unit: 'tấm')]);
      final c = hoSo.withBrand('x_toa', 'TOA');
      final gui = c.minusUnused(hoSo, {'vthm': {'x_kego': 1}}, const {});
      expect(gui.brands.map((x) => x.code), ['x_toa']);
      expect(gui.types.map((x) => x.code), ['x_kego']);
    });

    test('photosError: loại gõ tay có số ⇒ cần 1 ảnh; photos_when_zero ⇒ bắt cả loại toàn 0 (loại gõ tay: khi được dùng)', () {
      const custom = DisplayMatrixCustom(types: [(code: 'x_kego', name: 'Kệ gỗ', unit: 'tấm')]);
      final cfg = DisplayMatrixConfig.fromConfig(matrix()).withCustom(custom);
      expect(DisplayMatrixFieldWidget.photosError({'vthm': {'x_kego': 2}}, const {}, cfg), 'Kệ gỗ: cần ít nhất 1 ảnh.');
      expect(DisplayMatrixFieldWidget.photosError({'vthm': {'x_kego': 2}}, {'x_kego': ['a' * 32]}, cfg), isNull);
      expect(DisplayMatrixFieldWidget.photosError({'vthm': {'op_mau': 1}}, const {}, cfg), isNull);

      final bat = DisplayMatrixConfig.fromConfig(matrix(photosWhenZero: true)).withCustom(custom);
      expect(DisplayMatrixFieldWidget.photosError({'vthm': {'op_mau': 1}}, const {}, bat), 'Kệ lật: cần ít nhất 1 ảnh.');
      // Loại gõ tay chỉ bị đòi khi ĐƯỢC DÙNG (có ô số — kể cả 0 — hoặc ảnh), như server.
      expect(DisplayMatrixFieldWidget.photosError({'vthm': {'op_mau': 1}}, {'ke_lat': ['a' * 32]}, bat), isNull);
      expect(DisplayMatrixFieldWidget.photosError({'vthm': {'op_mau': 1, 'x_kego': 0}}, {'ke_lat': ['a' * 32]}, bat),
          'Kệ gỗ: cần ít nhất 1 ảnh.');
      // Loại tối đa 0 ảnh (Ốp mẫu) không bao giờ bị đòi ảnh.
      expect(DisplayMatrixFieldWidget.photosError({'vthm': {'op_mau': 1}}, {'ke_lat': ['a' * 32], 'x_kego': ['b' * 32]}, bat), isNull);
    });

    test('displayMatrixValue: chỉ có mục gõ tay vẫn giữ giá trị; rỗng hết ⇒ null', () {
      expect(displayMatrixValue({}, {}, const DisplayMatrixCustom()), isNull);
      expect(displayMatrixValue({}, {}, const DisplayMatrixCustom(brands: [(code: 'x_toa', name: 'TOA')]))?['custom'], isNotNull);
    });
  });

  group('phiếu thị trường (D1)', () {
    testWidgets('mở ra chỉ có thương hiệu của ta; thêm thương hiệu danh mục từ danh sách; xoá thẻ ⇒ xoá số', (tester) async {
      final key = await mo(tester);
      expect(find.text('VTHM'), findsOneWidget);
      expect(find.text('KOVA'), findsNothing);

      await bam(tester, 'matrix_sos_add_brand');
      expect(find.byKey(const ValueKey('matrix_add_brand_vthm')), findsNothing, reason: 'thẻ đang hiện không vào danh sách');
      await tester.tap(find.byKey(const ValueKey('matrix_add_brand_kova')));
      await tester.pumpAndSettle();
      expect(find.text('KOVA'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('matrix_kova_op_mau')), '2');
      await tester.pump();
      expect(key.currentState!.validateAndGetAnswers()!['sos']['counts'], {'kova': {'op_mau': 2}});

      await bam(tester, 'matrix_remove_brand_kova');
      expect(find.text('KOVA'), findsNothing);
      expect(key.currentState!.validateAndGetAnswers()!['sos'], isNull);
    });

    testWidgets('"Nhập tên khác…" trùng danh mục (gõ "kova") ⇒ chọn KOVA, không sinh mã x_', (tester) async {
      final key = await mo(tester);
      await bam(tester, 'matrix_sos_add_brand');
      await tester.tap(find.byKey(const ValueKey('matrix_add_brand_other')));
      await tester.pumpAndSettle();
      await goTen(tester, ' kova ');
      expect(find.text('KOVA'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('matrix_kova_op_mau')), '1');
      await tester.pump();
      final sos = key.currentState!.validateAndGetAnswers()!['sos'] as Map;
      expect(sos['counts'], {'kova': {'op_mau': 1}});
      expect(sos.containsKey('custom'), isFalse);
    });

    testWidgets('thương hiệu gõ tay + loại gõ tay ⇒ cột chung, bắt 1 ảnh, payload có custom', (tester) async {
      final key = await mo(tester);
      await bam(tester, 'matrix_sos_add_brand');
      await tester.tap(find.byKey(const ValueKey('matrix_add_brand_other')));
      await tester.pumpAndSettle();
      await goTen(tester, 'Nippon  Paint');
      expect(find.text('Nippon Paint'), findsOneWidget);

      await bam(tester, 'matrix_sos_add_type');
      await goTen(tester, 'Kệ gỗ', donVi: 'tấm');
      // Cột chung: mọi thẻ đều có ô của loại mới.
      expect(find.byKey(const ValueKey('matrix_vthm_x_kego')), findsOneWidget);
      expect(find.byKey(const ValueKey('matrix_x_nipponpaint_x_kego')), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('matrix_x_nipponpaint_x_kego')), '2,5');
      await tester.pump();
      expect(key.currentState!.validateAndGetAnswers(), isNull);
      await tester.pump();
      expect(find.textContaining('Kệ gỗ: cần ít nhất 1 ảnh'), findsOneWidget);

      // Bỏ số ⇒ không còn bắt ảnh; mục gõ tay vẫn gửi trong custom.
      await tester.enterText(find.byKey(const ValueKey('matrix_x_nipponpaint_x_kego')), '');
      await tester.enterText(find.byKey(const ValueKey('matrix_vthm_op_mau')), '1');
      await tester.pump();
      final sos = key.currentState!.validateAndGetAnswers()!['sos'] as Map;
      expect(sos['counts'], {'vthm': {'op_mau': 1}});
      expect(sos['custom'], {
        'brands': [{'code': 'x_nipponpaint', 'name': 'Nippon Paint'}],
        'types': [{'code': 'x_kego', 'name': 'Kệ gỗ', 'unit': 'tấm'}],
      });

      // Gỡ loại gõ tay ⇒ cột + mục custom biến mất.
      await bam(tester, 'matrix_remove_type_x_kego');
      expect(find.byKey(const ValueKey('matrix_vthm_x_kego')), findsNothing);
      expect((key.currentState!.validateAndGetAnswers()!['sos'] as Map)['custom']['types'], isEmpty);
    });

    testWidgets('gõ tên loại trùng danh mục ⇒ báo đã có, không thêm cột', (tester) async {
      await mo(tester);
      await bam(tester, 'matrix_sos_add_type');
      await goTen(tester, 'ke lat', donVi: 'tấm');
      expect(find.text('"Kệ lật" đã có trong bảng.'), findsOneWidget);
      expect(find.byKey(const ValueKey('matrix_vthm_x_kelat')), findsNothing);
    });

    testWidgets('bản nháp có custom ⇒ dựng lại thẻ + cột, gửi lại custom', (tester) async {
      final key = await mo(tester, answers: {
        'sos': {
          'counts': {'x_toa': {'x_kego': 3}},
          'photos': {'x_kego': ['a' * 32]},
          'custom': {
            'brands': [{'code': 'x_toa', 'name': 'TOA'}],
            'types': [{'code': 'x_kego', 'name': 'Kệ gỗ', 'unit': 'tấm'}],
          },
        },
      });
      expect(find.text('TOA'), findsOneWidget);
      expect(find.byKey(const ValueKey('matrix_vthm_x_kego')), findsOneWidget);
      final sos = key.currentState!.validateAndGetAnswers()!['sos'] as Map;
      expect(sos['counts'], {'x_toa': {'x_kego': 3}});
      expect(sos['photos'], {'x_kego': ['a' * 32]});
      expect((sos['custom'] as Map)['brands'], [{'code': 'x_toa', 'name': 'TOA'}]);
    });

    testWidgets('photos_when_zero: loại toàn 0 vẫn bắt ảnh', (tester) async {
      final key = await mo(tester, cfg: matrix(photosWhenZero: true));
      await tester.enterText(find.byKey(const ValueKey('matrix_vthm_op_mau')), '1');
      await tester.pump();
      expect(key.currentState!.validateAndGetAnswers(), isNull);
      await tester.pump();
      expect(find.textContaining('Kệ lật: cần ít nhất 1 ảnh'), findsOneWidget);
    });
  });

  group('vá sau review', () {
    Future<GlobalKey<MarketFormRendererState>> moHoSo(WidgetTester tester,
        {bool required = true, bool photosWhenZero = false, int? minBrands}) async {
      final cfg = matrix(photosWhenZero: photosWhenZero, minBrands: minBrands)..['update_customer_field'] = 'sos_ho_so';
      final key = GlobalKey<MarketFormRendererState>();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarketFormRenderer(
              key: key,
              blocks: [
                MarketFormBlockEntity(
                  ref: 'sos',
                  type: 'field',
                  required: required,
                  resolved: MarketFormResolvedEntity(code: 'sos', label: 'SOS', inputType: 'display_matrix', config: cfg),
                ),
              ],
              customerData: {
                'sos_ho_so': {
                  'counts': {'vthm': {'op_mau': 2}, 'x_toa': {'op_mau': 3}},
                  'photos': {'x_kego': ['a' * 32]},
                  'snapshot': {
                    'brands': [{'code': 'x_toa', 'name': 'TOA', 'custom': true}],
                    'types': [{'code': 'x_kego', 'name': 'Kệ gỗ', 'unit': 'tấm', 'custom': true}],
                  },
                },
              },
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return key;
    }

    testWidgets('ô bắt buộc không sửa ⇒ xác nhận số hồ sơ, custom khai ĐỦ mục gõ tay của hồ sơ có số (server đòi)', (tester) async {
      final key = await moHoSo(tester);
      expect(find.text('TOA'), findsOneWidget);
      final sos = key.currentState!.validateAndGetAnswers()!['sos'] as Map;
      expect(sos['counts'], {'vthm': {'op_mau': 2}, 'x_toa': {'op_mau': 3}});
      expect(sos['custom'], {
        'brands': [{'code': 'x_toa', 'name': 'TOA'}],
        'types': <Map>[],
      });
    });

    testWidgets('photos_when_zero: loại gõ tay của hồ sơ mà phiếu không dùng KHÔNG bị đòi ảnh (như server)', (tester) async {
      final key = await moHoSo(tester, required: false, photosWhenZero: true);
      await tester.enterText(find.byKey(const ValueKey('matrix_vthm_op_mau')), '1');
      await tester.pump();
      expect(key.currentState!.validateAndGetAnswers(), isNull);
      await tester.pump();
      expect(find.textContaining('Kệ lật: cần ít nhất 1 ảnh'), findsOneWidget);
      // Loại gõ tay hồ sơ chỉ có ẢNH (không số) không hiện cột ở phiếu — gỡ được rồi lại hiện là nút hỏng.
      expect(find.byKey(const ValueKey('matrix_vthm_x_kego')), findsNothing);
      expect(find.textContaining('Kệ gỗ: cần'), findsNothing);
    });

    testWidgets('chỉ thêm thẻ gõ tay, không nhập số ⇒ ô rỗng: bắt buộc báo trống, không bắt buộc không gửi', (tester) async {
      final key = await mo(tester);
      await bam(tester, 'matrix_sos_add_brand');
      await tester.tap(find.byKey(const ValueKey('matrix_add_brand_other')));
      await tester.pumpAndSettle();
      await goTen(tester, 'TOA');
      expect(find.text('TOA'), findsOneWidget);
      expect(key.currentState!.validateAndGetAnswers()!.containsKey('sos'), isFalse);
    });

    testWidgets('xoá một thẻ không làm mất chữ sai dạng ở ô khác (cờ lỗi khớp chữ đang hiện)', (tester) async {
      await mo(tester);
      await bam(tester, 'matrix_sos_add_brand');
      await tester.tap(find.byKey(const ValueKey('matrix_add_brand_kova')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('matrix_vthm_op_mau')), '1,25');
      await tester.pump();
      await bam(tester, 'matrix_remove_brand_kova');
      expect(find.descendant(of: find.byKey(const ValueKey('matrix_vthm_op_mau')), matching: find.text('1,25')), findsOneWidget);
      expect(find.text('VTHM · Ốp mẫu: tối đa 1 chữ số thập phân'), findsOneWidget);
    });

    test('onlyUsed: thương hiệu và loại trùng mã không tính chéo', () {
      const c = DisplayMatrixCustom(brands: [(code: 'x_ke', name: 'Kệ')], types: [(code: 'x_ke', name: 'Kệ', unit: 'tấm')]);
      final u = c.onlyUsed({'vthm': {'x_ke': 1}}, const {});
      expect(u.brands, isEmpty);
      expect(u.types.single.code, 'x_ke');
    });

    testWidgets('form điểm bán: danh mục rỗng ⇒ cảnh báo, không bảng / nút thêm', (tester) async {
      await mo(tester, cfg: {'matrix': {'brands': [], 'types': []}});
      expect(find.text('Biểu mẫu chưa có thương hiệu hoặc loại trưng bày nào — báo quản trị.'), findsOneWidget);
      expect(find.byKey(const ValueKey('matrix_sos_add_brand')), findsNothing);
    });

    test('luật hiện / bắt buộc: ô ma trận chỉ có custom là RỖNG', () {
      expect(DynamicRuleEvaluator.isEmptyValue({'counts': {}, 'photos': {}, 'custom': {'brands': [{'code': 'x_toa', 'name': 'TOA'}]}}), isTrue);
      expect(DynamicRuleEvaluator.isEmptyValue({'counts': {'vthm': {'ke_lat': 0}}, 'photos': {}}), isFalse);
      expect(DynamicRuleEvaluator.isEmptyValue({'counts': {}, 'photos': {'ke_lat': ['a' * 32]}}), isFalse);
    });

    test('§2: chỉ khớp tên với dòng danh mục ĐANG DÙNG', () {
      final cfg = DisplayMatrixConfig.fromConfig({
        'matrix': {
          'brands': [{'code': 'kova', 'name': 'KOVA', 'active': false}],
          'types': [{'code': 'ke_lat', 'name': 'Kệ lật', 'active': false}],
        },
      });
      expect(cfg.catalogBrandNamed('kova'), isNull);
      expect(cfg.catalogTypeNamed('ke lat'), isNull);
    });

    testWidgets('§2: tên gõ trùng mục gõ tay ĐÃ LƯU (mã cũ) ⇒ dùng nguyên mã đó, không sinh mã mới', (tester) async {
      final key = await mo(tester, answers: {
        'sos': {
          'counts': {'vthm': {'x_ke_go': 1}},
          'photos': {'x_ke_go': ['a' * 32]},
          'custom': {
            'brands': [{'code': 'x_toa_cu', 'name': 'TOA'}],
            'types': [{'code': 'x_ke_go', 'name': 'Kệ gỗ', 'unit': 'tấm'}],
          },
        },
      });
      await bam(tester, 'matrix_sos_add_type');
      await goTen(tester, 'KE GO', donVi: 'tấm');
      expect(find.text('"Kệ gỗ" đã có trong bảng.'), findsOneWidget);
      expect(find.byKey(const ValueKey('matrix_vthm_x_kego')), findsNothing);

      await bam(tester, 'matrix_sos_add_brand');
      await tester.tap(find.byKey(const ValueKey('matrix_add_brand_other')));
      await tester.pumpAndSettle();
      await goTen(tester, 'toa');
      expect(find.text('TOA'), findsOneWidget, reason: 'không thêm thẻ thứ hai');
      final custom = (key.currentState!.validateAndGetAnswers()!['sos'] as Map)['custom'] as Map;
      expect((custom['brands'] as List).map((x) => x['code']), ['x_toa_cu']);
      expect((custom['types'] as List).map((x) => x['code']), ['x_ke_go']);
    });
  });

  group('số thương hiệu tối thiểu (min_brands, 19/11/2026)', () {
    test('config + brandsError: đếm thương hiệu có ô > 0 (kể cả gõ tay), ô rỗng không đòi', () {
      final cfg = DisplayMatrixConfig.fromConfig(matrix(minBrands: 2));
      expect(cfg.minBrands, 2);
      expect(cfg.withCustom(const DisplayMatrixCustom()).minBrands, 2);
      expect(DisplayMatrixConfig.fromConfig(matrix()).minBrands, 0);
      expect(DisplayMatrixFieldWidget.brandsError(const {}, const {}, cfg), isNull);
      expect(
        DisplayMatrixFieldWidget.brandsError({'vthm': {'ke_lat': 3}, 'kova': {'ke_lat': 0}}, const {}, cfg),
        'cần khai số cho ít nhất 2 thương hiệu (đang có 1).',
      );
      expect(DisplayMatrixFieldWidget.brandsError({'vthm': {'ke_lat': 3}, 'x_toa': {'ke_lat': 1}}, const {}, cfg), isNull);
    });

    testWidgets('phiếu thường: một thương hiệu ⇒ chặn nộp', (tester) async {
      final key = await mo(tester, cfg: matrix(minBrands: 2));
      await tester.enterText(find.byKey(const ValueKey('matrix_vthm_op_mau')), '1');
      await tester.pump();
      expect(key.currentState!.validateAndGetAnswers(), isNull);
      await tester.pump();
      expect(find.textContaining('cần khai số cho ít nhất 2 thương hiệu (đang có 1)'), findsOneWidget);
    });
  });

  testWidgets('min_brands — phiếu cập nhật hồ sơ: đếm cả số hiện trạng (vthm + TOA của hồ sơ)', (tester) async {
    final key = GlobalKey<MarketFormRendererState>();
    final cfg = matrix(minBrands: 2)..['update_customer_field'] = 'sos_ho_so';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MarketFormRenderer(
            key: key,
            blocks: [
              MarketFormBlockEntity(
                ref: 'sos',
                type: 'field',
                required: false,
                resolved: MarketFormResolvedEntity(code: 'sos', label: 'SOS', inputType: 'display_matrix', config: cfg),
              ),
            ],
            customerData: {
              'sos_ho_so': {
                'counts': {'vthm': {'op_mau': 2}, 'x_toa': {'op_mau': 3}},
                'snapshot': {
                  'brands': [{'code': 'x_toa', 'name': 'TOA', 'custom': true}],
                  'types': <Map>[],
                },
              },
            },
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('matrix_vthm_op_mau')), '5');
    await tester.pump();
    expect(key.currentState!.validateAndGetAnswers(), isNotNull);
    // Gõ 0 cho thương hiệu hồ sơ ⇒ gỡ ⇒ còn 1.
    await tester.enterText(find.byKey(const ValueKey('matrix_x_toa_op_mau')), '0');
    await tester.pump();
    expect(key.currentState!.validateAndGetAnswers(), isNull);
  });
}
