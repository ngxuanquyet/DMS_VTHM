import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vthm_dms/core/utils/rich_image_cache.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/matrix_photo_key.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/core/dynamic_form/widgets/display_matrix_field_widget.dart';
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
        {'code': 'ke_lat', 'name': 'Kệ lật', 'unit': 'tấm', 'decimals': 0, 'face_factor': 1, 'min_photos': 1, 'max_photos': 3,
          'hint': 'Mỗi tấm lật xem được = 1 mặt'},
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

  testWidgets('bảng: dòng "của ta" đứng đầu; gõ số ⇒ tổng/SOS cập nhật; ô trống không gửi', (tester) async {
    final key = GlobalKey<MarketFormRendererState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: MarketFormRenderer(key: key, blocks: [o(required: false)]))),
    ));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('VTHM')).dy, lessThan(tester.getTopLeft(find.text('Đối thủ A')).dy));

    await tester.enterText(find.byKey(const ValueKey('matrix_vthm_ke_lat')), '6');
    await tester.enterText(find.byKey(const ValueKey('matrix_vthm_op_mau')), '1,5');
    await tester.pump();
    expect(find.text('Tổng 9 mặt ngành hàng · SOS của ta 100%'), findsOneWidget);

    // Gõ sai dạng ⇒ báo lỗi ngay dưới ô (không lặng lẽ bỏ khỏi tổng).
    await tester.enterText(find.byKey(const ValueKey('matrix_vthm_op_mau')), '1,25');
    await tester.pump();
    expect(find.text('VTHM · Ốp mẫu: tối đa 1 chữ số thập phân'), findsOneWidget);
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

  testWidgets('cột Tổng = số mặt + % SOS từng thương hiệu; bấm tên cột có hướng dẫn ⇒ mở hướng dẫn + quy đổi', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: MarketFormRenderer(blocks: [o(required: false)]))),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('matrix_vthm_op_mau')), '3');
    await tester.enterText(find.byKey(const ValueKey('matrix_rival_ke_lat')), '2');
    await tester.pump();
    final tongVthm = find.byKey(const ValueKey('matrix_total_vthm'));
    expect(find.descendant(of: tongVthm, matching: find.text('6')), findsOneWidget);
    expect(find.descendant(of: tongVthm, matching: find.text('75%')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('matrix_head_ke_lat')));
    await tester.pumpAndSettle();
    expect(find.text('Mỗi tấm lật xem được = 1 mặt'), findsOneWidget);
    expect(find.text('Đếm theo tấm · 1 tấm = 1 mặt'), findsOneWidget);
    await tester.tap(find.text('Đã hiểu'));
    await tester.pumpAndSettle();
  });

  testWidgets('Phóng to: ép xoay ngang, gõ ở màn phóng to ⇒ về phiếu; đóng ⇒ trả hướng dọc', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final key = GlobalKey<MarketFormRendererState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: MarketFormRenderer(key: key, blocks: [o(required: false)]))),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('matrix_sos_fullscreen')));
    await tester.pumpAndSettle();
    final huong = calls.where((c) => c.method == 'SystemChrome.setPreferredOrientations').map((c) => c.arguments).toList();
    expect(huong.first, ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight']);

    await tester.enterText(find.byKey(const ValueKey('matrix_full_vthm_op_mau')), '1,5');
    await tester.pump();
    expect(find.text('Tổng 3 mặt ngành hàng · SOS của ta 100%'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('matrix_fullscreen_close')));
    await tester.pumpAndSettle();

    // Bảng trong phiếu thấy số vừa gõ (chung ô nhập) và câu trả lời có số.
    expect(find.descendant(of: find.byKey(const ValueKey('matrix_vthm_op_mau')), matching: find.text('1,5')), findsOneWidget);
    expect(key.currentState!.validateAndGetAnswers()!['sos']['counts'], {'vthm': {'op_mau': 1.5}});
    final sau = calls.where((c) => c.method == 'SystemChrome.setPreferredOrientations').map((c) => c.arguments).toList();
    expect(sau.sublist(sau.length - 2), [['DeviceOrientation.portraitUp'], <String>[]]);
  });

  testWidgets('#24698 vòng 4: Phóng to còn ô sai dạng ⇒ không cho thu nhỏ; sửa lại rồi thu nhỏ ⇒ phiếu không kẹt cờ sai dạng',
      (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final key = GlobalKey<MarketFormRendererState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: MarketFormRenderer(key: key, blocks: [o(required: false)]))),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('matrix_sos_fullscreen')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('matrix_full_vthm_op_mau')), '2,5,');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('matrix_fullscreen_close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('matrix_full_vthm_op_mau')), findsOneWidget, reason: 'lỗi cũ: đóng được, số mất im lặng');

    await tester.enterText(find.byKey(const ValueKey('matrix_full_vthm_op_mau')), '2,5');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('matrix_fullscreen_close')));
    await tester.pumpAndSettle();
    expect(key.currentState!.validateAndGetAnswers()?['sos']['counts'], {'vthm': {'op_mau': 2.5}},
        reason: 'lỗi cũ: kẹt cờ "ô đếm nhập sai dạng số", không nộp được');
  });

  testWidgets('cỡ chữ hệ thống 1,5× ⇒ bảng không tràn dòng', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: Scaffold(body: SingleChildScrollView(child: MarketFormRenderer(blocks: [o(required: false)]))),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('matrix_vthm_ke_lat')), '4');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('gõ số rất dài ⇒ số mặt + % SOS thu nhỏ trong ô Tổng, không tràn sang dòng dưới (05/11/2026)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: MarketFormRenderer(blocks: [o(required: false)]))),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('matrix_vthm_ke_lat')), '123456789012345');
    await tester.enterText(find.byKey(const ValueKey('matrix_rival_ke_lat')), '987654321098765');
    await tester.pump();
    expect(tester.takeException(), isNull);

    for (final b in ['rival', 'vthm']) {
      final total = find.byKey(ValueKey('matrix_total_$b'));
      // Ô Tổng của dòng = Container cha gần nhất của khối số; mọi chữ trong khối phải nằm gọn trong ô đó.
      final cellRect = tester.getRect(find.ancestor(of: total, matching: find.byType(Container)).first);
      for (final t in tester.widgetList<Text>(find.descendant(of: total, matching: find.byType(Text)))) {
        final r = tester.getRect(find.byWidget(t));
        expect(cellRect.top <= r.top && r.bottom <= cellRect.bottom, isTrue, reason: '"${t.data}" của $b tràn khỏi ô Tổng');
        expect(cellRect.left <= r.left && r.right <= cellRect.right, isTrue, reason: '"${t.data}" của $b tràn ngang');
      }
    }
  });

  testWidgets('ảnh minh hoạ ở màn ngang ⇒ khung ảnh kẹp ≤ nửa chiều cao màn hình, không tràn', (tester) async {
    // Ca chủ hệ thống báo 04/11: phóng to (xoay ngang) rồi bấm tên cột, ảnh minh hoạ to tràn màn hình.
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    const cfg = {
      'matrix': {
        'brands': [
          {'code': 'vthm', 'name': 'VTHM', 'is_own': true},
        ],
        'types': [
          {'code': 'ke_lat', 'name': 'Kệ lật', 'unit': 'tấm', 'face_factor': 1, 'hint': 'Đếm từng tấm', 'illustration_token': 'abcdefgh1234'},
        ],
      },
    };
    await tester.pumpWidget(ProviderScope(
      overrides: [richImageCacheProvider.overrideWithValue(_FakeCache())],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MarketFormRenderer(blocks: [
              MarketFormBlockEntity(
                ref: 'sos',
                type: 'field',
                required: false,
                resolved: const MarketFormResolvedEntity(code: 'sos', label: 'SOS', inputType: 'display_matrix', config: cfg),
              ),
            ]),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('matrix_head_ke_lat')));
    await tester.pumpAndSettle();
    final khung = tester.widget<ConstrainedBox>(find.byKey(const ValueKey('matrix_guide_image')));
    expect(khung.constraints.maxHeight, 180);
    expect(khung.constraints.maxWidth, 640);
    expect(tester.takeException(), isNull);
  });

  Map<String, dynamic> cfgHoSo({int minPhotos = 0}) => {
        'matrix': {
          'brands': [
            {'code': 'rival', 'name': 'Đối thủ A', 'is_own': false},
            {'code': 'vthm', 'name': 'VTHM', 'is_own': true},
          ],
          'types': [
            {'code': 'ke_lat', 'name': 'Kệ lật', 'unit': 'tấm', 'decimals': 0, 'face_factor': 1, 'min_photos': minPhotos,
              'max_photos': 3},
            {'code': 'op_mau', 'name': 'Ốp mẫu', 'unit': 'm²', 'decimals': 1, 'face_factor': 2, 'min_photos': 0, 'max_photos': 0},
          ],
        },
        'update_customer_field': 'sos_ho_so',
      };

  Future<GlobalKey<MarketFormRendererState>> moPhieuHoSo(WidgetTester tester, {bool required = false, int minPhotos = 0}) async {
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
                resolved: MarketFormResolvedEntity(
                    code: 'sos', label: 'SOS', inputType: 'display_matrix', config: cfgHoSo(minPhotos: minPhotos)),
              ),
            ],
            customerData: const {
              'sos_ho_so': {
                'counts': {
                  'vthm': {'ke_lat': 7, 'op_mau': 2.5},
                  'rival': {'ke_lat': 4},
                  'da_bo': {'ke_lat': 9},
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

  testWidgets('ô cập nhật hồ sơ điểm bán: hiện ĐỦ số hiện trạng, % SOS tính cả ma trận, sửa một số ⇒ % đổi theo; chỉ gửi ô '
      'đã sửa (chốt 06/11/2026)', (tester) async {
    final key = await moPhieuHoSo(tester, minPhotos: 1);
    String o(String b, String t) => tester.widget<TextField>(find.byKey(ValueKey('matrix_${b}_$t'))).controller!.text;
    expect(o('vthm', 'ke_lat'), '7', reason: 'lỗi cũ: ô trống, chỉ hiện mờ ⇒ % SOS không tính số cũ');
    expect(o('vthm', 'op_mau'), '2,5');
    expect(o('rival', 'ke_lat'), '4');
    // 7 + 2,5×2 = 12 mặt của ta, 4 mặt đối thủ ⇒ 75%.
    expect(find.text('Tổng 16 mặt ngành hàng · SOS của ta 75%'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('matrix_vthm_op_mau')), '0,5');
    await tester.pump();
    expect(find.text('Tổng 12 mặt ngành hàng · SOS của ta 66,7%'), findsOneWidget);

    // Xoá trống một ô ⇒ ô hiện mờ số cũ và VẪN tính bằng số đó (khi nộp ô trống giữ số cũ của hồ sơ).
    await tester.enterText(find.byKey(const ValueKey('matrix_rival_ke_lat')), '');
    await tester.pump();
    expect(tester.widget<TextField>(find.byKey(const ValueKey('matrix_rival_ke_lat'))).decoration!.hintText, '4');
    expect(find.text('Tổng 12 mặt ngành hàng · SOS của ta 66,7%'), findsOneWidget);

    // Chỉ gửi ô đã sửa — ô không sửa giữ số trên server (số trong máy có thể cũ); loại không sửa không bị bắt ảnh.
    expect(key.currentState!.validateAndGetAnswers()!['sos'], {
      'counts': {
        'vthm': {'op_mau': 0.5},
      },
      'photos': <String, List<String>>{},
    });
  });

  testWidgets('ô BẮT BUỘC không sửa ô nào ⇒ coi là xác nhận, gửi cả ma trận đang hiện (chốt 06/11/2026)', (tester) async {
    final key = await moPhieuHoSo(tester, required: true);
    expect(key.currentState!.validateAndGetAnswers()!['sos'], {
      'counts': {
        'vthm': {'ke_lat': 7, 'op_mau': 2.5},
        'rival': {'ke_lat': 4},
      },
      'photos': <String, List<String>>{},
    }, reason: 'không bị chặn "không được để trống" khi bảng đang hiện đủ số; thương hiệu đã bỏ không gửi');
  });

  testWidgets('ô BẮT BUỘC: lượt nộp hỏng vì ô KHÁC không biến cả ma trận số cũ thành "đã sửa"', (tester) async {
    // Kệ lật cần 1 ảnh ⇒ xác nhận cả ma trận (có kệ lật > 0) bị chặn vì thiếu ảnh.
    final key = await moPhieuHoSo(tester, required: true, minPhotos: 1);
    expect(key.currentState!.validateAndGetAnswers(), isNull);
    await tester.pump();

    await tester.enterText(find.byKey(const ValueKey('matrix_vthm_op_mau')), '0,5');
    await tester.pump();
    expect(key.currentState!.validateAndGetAnswers()!['sos'], {
      'counts': {
        'vthm': {'op_mau': 0.5},
      },
      'photos': <String, List<String>>{},
    }, reason: 'lỗi: lượt nộp hỏng ghi số xác nhận vào câu trả lời ⇒ sửa thêm một ô là gửi cả ma trận số cũ');
  });

  testWidgets('màn sửa hồ sơ điểm bán: hiện đủ số đang lưu, sửa một số ⇒ % SOS đổi theo', (tester) async {
    final cfg = DisplayMatrixConfig.fromConfig(matrix);
    DisplayMatrixCounts so = {
      'vthm': {'ke_lat': 6},
      'rival': {'ke_lat': 2},
    };
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) => DisplayMatrixFieldWidget(
              label: 'SOS',
              config: cfg,
              counts: so,
              onChanged: (c, _) => setState(() => so = c),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const ValueKey('matrix_vthm_ke_lat'))).controller!.text, '6');
    expect(find.text('Tổng 8 mặt ngành hàng · SOS của ta 75%'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('matrix_vthm_ke_lat')), '2');
    await tester.pump();
    expect(find.text('Tổng 4 mặt ngành hàng · SOS của ta 50%'), findsOneWidget);
  });

  test('withHints: ô đã gõ thắng, ô trống lấy số hiện trạng', () {
    expect(
      DisplayMatrixFieldWidget.withHints({
        'vthm': {'a': 0},
      }, {
        'vthm': {'a': 5, 'b': 2},
        'rival': {'a': 1},
      }),
      {
        'vthm': {'a': 0, 'b': 2},
        'rival': {'a': 1},
      },
    );
  });
}

/// Bộ đệm ảnh giả — không có tệp (ô ảnh hiện khung chờ), đủ để đo khung kẹp ảnh.
class _FakeCache implements RichImageCache {
  @override
  Future<File?> load(String token) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
