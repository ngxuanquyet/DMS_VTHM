import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/matrix_photo_key.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/display_matrix_field_widget.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';

/// Ô MA TRẬN TRƯNG BÀY SOS (`display_matrix`, #24767): mỗi thương hiệu một thẻ, số mặt + % SOS tự tính (cùng công thức
/// server), ô trống = 0 không gửi (C1), ảnh tối thiểu chỉ bắt khi loại có số > 0 (C2), ảnh theo loại đi khoá `<ô>::<loại>`.
void main() {
  const matrix = {
    'matrix': {
      'brands': [
        {'code': 'rival', 'name': 'Đối thủ A', 'is_own': false},
        {'code': 'vthm', 'name': 'VTHM', 'is_own': true},
      ],
      'types': [
        {'code': 'ke_lat', 'name': 'Kệ lật', 'unit': 'tấm', 'decimals': 0, 'face_factor': 1, 'min_photos': 1, 'max_photos': 3},
        {'code': 'op_mau', 'name': 'Ốp mẫu', 'unit': 'm²', 'decimals': 1, 'face_factor': 2, 'min_photos': 0, 'max_photos': 0},
      ],
    },
  };

  MarketFormBlockEntity o({bool required = true}) => MarketFormBlockEntity(
        ref: 'sos',
        type: 'field',
        required: required,
        resolved: const MarketFormResolvedEntity(code: 'sos', label: 'Số mặt trưng bày', inputType: 'display_matrix', config: matrix),
      );

  test('đọc config.matrix; tổng mặt + % SOS cùng công thức server', () {
    final cfg = DisplayMatrixConfig.fromConfig(matrix);
    expect(cfg.brands.map((b) => b.code), ['rival', 'vthm']);
    expect(cfg.types[1].faceFactor, 2);
    final t = DisplayMatrixTotals.compute({
      'vthm': {'ke_lat': 6, 'op_mau': 1.5},
      'rival': {'ke_lat': 9},
    }, cfg);
    expect(t.facesByBrand['vthm'], 9);
    expect(t.facesTotal, 18);
    expect(t.sosOwnPct, 50);
    expect(t.sosOf('rival'), 50);
  });

  test('khoá ảnh ma trận: tách + ghi token vào photos.<loại>, giữ counts', () {
    expect(splitMatrixPhotoKey('sos::ke_lat'), ('sos', 'ke_lat'));
    expect(splitMatrixPhotoKey('anh_mat_tien'), isNull);
    final answers = <String, dynamic>{
      'sos': {'counts': {'vthm': {'ke_lat': 2}}, 'photos': {'ke_lat': ['/tmp/a.jpg']}},
      'anh': ['/tmp/b.jpg'],
    };
    applyPhotoList(answers, 'sos::ke_lat', ['a' * 32]);
    applyPhotoList(answers, 'anh', ['b' * 32]);
    expect(answers['sos']['photos']['ke_lat'], ['a' * 32]);
    expect(answers['sos']['counts'], {'vthm': {'ke_lat': 2}});
    expect(answers['anh'], ['b' * 32]);
    expect(matrixPhotoStrings({'photos': {'x': ['p1'], 'y': ['p2']}}).toList(), ['p1', 'p2']);
    expect(isUploadedPhotoToken('d' * 32), isTrue);
    expect(isUploadedPhotoToken('/tmp/x.jpg'), isFalse);
    expect(matrixPhotoKey('sos', 'ke_lat'), 'sos::ke_lat');
  });

  test('tóm tắt phiếu đã nộp từ snapshot + totals', () {
    final s = displayMatrixSummary({
      'snapshot': {
        'brands': [
          {'code': 'vthm', 'name': 'VTHM'},
          {'code': 'rival', 'name': 'Đối thủ A'},
        ],
      },
      'totals': {
        'faces_by_brand': {'vthm': 36.5, 'rival': 14},
        'sos_by_brand': {'vthm': 72.3, 'rival': 27.7},
        'faces_total': 50.5,
      },
    });
    expect(s, 'VTHM: 36,5 mặt (72,3%)\nĐối thủ A: 14 mặt (27,7%)\nTổng 50,5 mặt ngành hàng');
    expect(displayMatrixSummary(['x']), isNull);
  });

  testWidgets('thẻ "của ta" đứng đầu + mở sẵn; gõ số ⇒ tổng/SOS cập nhật; ô trống không gửi', (tester) async {
    final key = GlobalKey<MarketFormRendererState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: MarketFormRenderer(key: key, blocks: [o(required: false)]))),
    ));
    await tester.pumpAndSettle();

    final tieuDe = tester.widgetList<ExpansionTile>(find.byType(ExpansionTile)).map((e) => (e.title as Text).data).toList();
    expect(tieuDe, ['VTHM', 'Đối thủ A']);

    await tester.enterText(find.byKey(const ValueKey('matrix_vthm_ke_lat')), '6');
    await tester.enterText(find.byKey(const ValueKey('matrix_vthm_op_mau')), '1,5');
    await tester.pump();
    expect(find.text('Tổng 9 mặt ngành hàng · SOS của ta 100%'), findsOneWidget);

    // Gõ sai dạng ⇒ báo lỗi ngay dưới ô (không lặng lẽ bỏ khỏi tổng).
    await tester.enterText(find.byKey(const ValueKey('matrix_vthm_op_mau')), '1,25');
    await tester.pump();
    expect(find.text('tối đa 1 chữ số thập phân'), findsOneWidget);
    expect(key.currentState!.validateAndGetAnswers(), isNull);
    await tester.enterText(find.byKey(const ValueKey('matrix_vthm_op_mau')), '1,5');
    await tester.pump();

    // Ảnh tối thiểu của Kệ lật (có số > 0) chưa đủ ⇒ chặn (C2).
    expect(key.currentState!.validateAndGetAnswers(), isNull);
    await tester.pump();
    expect(find.textContaining('Kệ lật: cần ít nhất 1 ảnh'), findsOneWidget);

    // Bỏ số Kệ lật ⇒ không còn bắt ảnh; ô trống không vào câu trả lời.
    await tester.enterText(find.byKey(const ValueKey('matrix_vthm_ke_lat')), '');
    await tester.pump();
    final gui = key.currentState!.validateAndGetAnswers()!;
    expect(gui['sos'], {
      'counts': {'vthm': {'op_mau': 1.5}},
      'photos': <String, List<String>>{},
    });
  });

  testWidgets('ô bắt buộc để trống ⇒ lỗi; bản nháp có ảnh token ⇒ nạp lại vào khoá ảnh của loại', (tester) async {
    final key = GlobalKey<MarketFormRendererState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: MarketFormRenderer(key: key, blocks: [o()]))),
    ));
    await tester.pumpAndSettle();
    expect(key.currentState!.validateAndGetAnswers(), isNull);
    await tester.pump();
    expect(find.text('Số mặt trưng bày không được để trống.'), findsOneWidget);

    final tok = 'c' * 32;
    final key2 = GlobalKey<MarketFormRendererState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MarketFormRenderer(
            key: key2,
            blocks: [o()],
            initialAnswers: {
              'sos': {
                'counts': {'vthm': {'ke_lat': 2}},
                'photos': {'ke_lat': [tok]},
              },
            },
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    // Ảnh chỉ có token (bản nháp) vẫn vào danh sách ảnh máy ⇒ hàng đợi giữ nguyên, không làm rơi khi tải lại ảnh khác.
    expect(key2.currentState!.getLocalPhotoPaths(), {'sos::ke_lat': [tok]});
    final gui = key2.currentState!.validateAndGetAnswers()!;
    expect(gui['sos']['photos'], {'ke_lat': [tok]});
    expect(gui['sos']['counts'], {'vthm': {'ke_lat': 2}});
  });
}
