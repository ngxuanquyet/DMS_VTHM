import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/core/utils/rich_image_cache.dart';
import 'package:vthm_dms/features/route/presentation/providers/user_routes_provider.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/route_field_widget.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';

const _routes = [
  UserRouteEntity(id: 11, name: 'Tuyến Thứ 2', code: 'T2'),
  UserRouteEntity(id: 22, name: 'Tuyến Thứ 3', code: 'T3'),
];

MarketFormBlockEntity _routeBlock({bool required = false}) => MarketFormBlockEntity(
      ref: 'tuyen',
      type: 'field',
      required: required,
      resolved: const MarketFormResolvedEntity(code: 'tuyen', label: 'Tuyến bán hàng', inputType: 'ref_dms_route'),
    );

MarketFormBlockEntity _note(String label, String? desc) => MarketFormBlockEntity(
      ref: 'hd',
      type: 'field',
      required: false,
      resolved: MarketFormResolvedEntity(code: 'hd', label: label, inputType: 'note', description: desc),
    );

MarketFormBlockEntity _heading(String code, String label, {dynamic config, String? desc}) => MarketFormBlockEntity(
      ref: code,
      type: 'field',
      required: false,
      resolved: MarketFormResolvedEntity(
        code: code,
        label: label,
        inputType: 'heading',
        config: config,
        description: desc,
      ),
    );

/// Bộ đệm ảnh giả: không mạng, không tệp.
class _FakeRichImageCache extends RichImageCache {
  final List<String> calls = [];
  _FakeRichImageCache() : super(ApiClient(Dio()));

  @override
  Future<File?> load(String token) async {
    calls.add(token);
    return null;
  }
}

/// ApiClient giả trả byte ảnh, đếm số lần gọi.
class _BytesApiClient extends ApiClient {
  final List<Map<String, dynamic>> calls = [];
  List<int> body = const [0x89, 0x50, 0x4E, 0x47, 1, 2];
  _BytesApiClient() : super(Dio());

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    calls.add({'path': path, 'query': queryParameters, 'type': options?.responseType});
    return body;
  }
}

Widget _wrap(
  List<MarketFormBlockEntity> blocks,
  GlobalKey<MarketFormRendererState> key, {
  List<UserRouteEntity> routes = _routes,
  List<int> defaultRouteIds = const [],
  Map<String, dynamic> initialAnswers = const {},
  RichImageCache? imageCache,
}) {
  return ProviderScope(
    overrides: [
      userAssignedRoutesProvider.overrideWith((ref) async => routes),
      if (imageCache != null) richImageCacheProvider.overrideWithValue(imageCache),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MarketFormRenderer(
            key: key,
            blocks: blocks,
            initialAnswers: initialAnswers,
            defaultRouteIds: defaultRouteIds,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Ô ref_dms_route — Tuyến bán hàng', () {
    testWidgets('chọn tuyến ⇒ câu trả lời là SỐ NGUYÊN id tuyến', (tester) async {
      final key = GlobalKey<MarketFormRendererState>();
      await tester.pumpWidget(_wrap([_routeBlock()], key));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<int>), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tuyến Thứ 3 (T3)').last);
      await tester.pumpAndSettle();

      final answers = key.currentState!.validateAndGetAnswers();
      expect(answers, isNotNull);
      expect(answers!['tuyen'], 22);
      expect(answers['tuyen'], isA<int>());
    });

    testWidgets('tự điền tuyến của lượt viếng thăm nếu có trong danh sách tuyến của NV', (tester) async {
      final key = GlobalKey<MarketFormRendererState>();
      // 99 không thuộc NV ⇒ bỏ qua, lấy 22.
      await tester.pumpWidget(_wrap([_routeBlock()], key, defaultRouteIds: const [99, 22]));
      await tester.pumpAndSettle();

      expect(key.currentState!.currentAnswers['tuyen'], 22);
      expect(find.text('Tuyến Thứ 3 (T3)'), findsOneWidget);
    });

    testWidgets('không tự điền tuyến ngoài danh sách; không đè giá trị nháp', (tester) async {
      final key = GlobalKey<MarketFormRendererState>();
      await tester.pumpWidget(_wrap([_routeBlock()], key, defaultRouteIds: const [99]));
      await tester.pumpAndSettle();
      expect(key.currentState!.currentAnswers.containsKey('tuyen'), isFalse);

      final key2 = GlobalKey<MarketFormRendererState>();
      await tester.pumpWidget(_wrap([_routeBlock()], key2,
          defaultRouteIds: const [22], initialAnswers: const {'tuyen': '11'}));
      await tester.pumpAndSettle();
      // Nháp chuỗi số được quy về int, không bị tự điền đè.
      expect(key2.currentState!.currentAnswers['tuyen'], 11);
    });

    testWidgets('danh sách tuyến rỗng ⇒ hiện câu cần kết nối mạng; bắt buộc thì báo lỗi', (tester) async {
      final key = GlobalKey<MarketFormRendererState>();
      await tester.pumpWidget(_wrap([_routeBlock(required: true)], key, routes: const []));
      await tester.pumpAndSettle();

      expect(find.text(RouteFieldWidget.emptyMessage), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);

      expect(key.currentState!.validateAndGetAnswers(), isNull);
      await tester.pumpAndSettle();
      expect(find.text('Tuyến bán hàng không được để trống.'), findsOneWidget);
    });

    test('idOf quy giá trị về id dương', () {
      expect(RouteFieldWidget.idOf(5), 5);
      expect(RouteFieldWidget.idOf('7'), 7);
      expect(RouteFieldWidget.idOf(0), isNull);
      expect(RouteFieldWidget.idOf('abc'), isNull);
      expect(RouteFieldWidget.idOf(null), isNull);
    });
  });

  group('Ô note — Tài liệu hướng dẫn', () {
    testWidgets('thu gọn: chỉ hiện tiêu đề, bấm mới mở nội dung HTML, bấm lại thu', (tester) async {
      final key = GlobalKey<MarketFormRendererState>();
      await tester.pumpWidget(_wrap([
        _note('Hướng dẫn chụp ảnh', '<p>Chụp <strong>toàn cảnh</strong> quầy</p><ul><li>Bước một</li></ul>'),
      ], key));
      await tester.pumpAndSettle();

      expect(find.text('Hướng dẫn chụp ảnh'), findsOneWidget);
      expect(find.textContaining('toàn cảnh', findRichText: true), findsNothing);

      await tester.tap(find.byKey(const ValueKey('note_toggle')));
      await tester.pumpAndSettle();
      expect(find.textContaining('toàn cảnh', findRichText: true), findsOneWidget);
      expect(find.textContaining('Bước một', findRichText: true), findsOneWidget);
      // Thẻ HTML không lộ ra thành chữ.
      expect(find.textContaining('<strong>', findRichText: true), findsNothing);

      await tester.tap(find.byKey(const ValueKey('note_toggle')));
      await tester.pumpAndSettle();
      expect(find.textContaining('toàn cảnh', findRichText: true), findsNothing);

      // Ô note không ghi gì vào câu trả lời.
      expect(key.currentState!.validateAndGetAnswers(), isEmpty);
    });

    testWidgets('ảnh <img data-token> tải qua bộ đệm; lỗi ⇒ ô xám, không sập', (tester) async {
      final key = GlobalKey<MarketFormRendererState>();
      final cache = _FakeRichImageCache();
      await tester.pumpWidget(_wrap([
        _note('Mẫu trưng bày', '<p>Xem ảnh</p><img data-token="abcdef0123456789abcdef0123456789">'),
      ], key, imageCache: cache));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note_toggle')));
      await tester.pumpAndSettle();

      expect(cache.calls, ['abcdef0123456789abcdef0123456789']);
      expect(find.byKey(const ValueKey('rich_image_broken')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ô note CŨ: chữ thường hiện nguyên văn; chỉ có mô tả thì hiện thẳng', (tester) async {
      final key = GlobalKey<MarketFormRendererState>();
      await tester.pumpWidget(_wrap([
        _note('Lưu ý: chụp rõ biển hiệu', null),
      ], key));
      await tester.pumpAndSettle();
      expect(find.text('Lưu ý: chụp rõ biển hiệu'), findsOneWidget);
      expect(find.byKey(const ValueKey('note_toggle')), findsNothing);

      final key2 = GlobalKey<MarketFormRendererState>();
      await tester.pumpWidget(_wrap([
        _note('', 'Dòng một\nDòng hai'),
      ], key2));
      await tester.pumpAndSettle();
      expect(find.text('Dòng một\nDòng hai'), findsOneWidget);

      final key3 = GlobalKey<MarketFormRendererState>();
      await tester.pumpWidget(_wrap([
        _note('Ghi chú', 'Nội dung chữ thường'),
      ], key3));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note_toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Nội dung chữ thường'), findsOneWidget);
    });

    test('RichImageCache gọi GET /rich-image/serve?token=… dạng byte, lưu tệp, lần sau đọc tệp', () async {
      final tmp = await Directory.systemTemp.createTemp('rich_img_test');
      addTearDown(() => tmp.delete(recursive: true));
      final api = _BytesApiClient();
      final cache = RichImageCache(api, baseDir: () async => tmp);
      const token = 'abcdef0123456789abcdef0123456789';

      final f1 = await cache.load(token);
      expect(f1, isNotNull);
      expect(await f1!.readAsBytes(), [0x89, 0x50, 0x4E, 0x47, 1, 2]);
      expect(api.calls.single['path'], '/rich-image/serve');
      expect(api.calls.single['query'], {'token': token});
      expect(api.calls.single['type'], ResponseType.bytes);

      final f2 = await cache.load(token);
      expect(f2!.path, f1.path);
      expect(api.calls.length, 1); // lấy từ bộ đệm, không gọi mạng

      expect(await cache.load('../etc/passwd'), isNull); // token lạ bị chặn

      // Thân 200 không phải ảnh (trang mạng có cổng đăng nhập) ⇒ KHÔNG lưu.
      api.body = '<html>login</html>'.codeUnits;
      expect(await cache.load('fedcba9876543210fedcba9876543210'), isNull);
      expect(File('${tmp.path}/rich_images/fedcba9876543210fedcba9876543210').existsSync(), isFalse);
    });
  });

  group('Ô heading — cấp tiêu đề', () {
    testWidgets('cấp mặc định (thiếu/không hợp lệ) = 1, cấp 2 vẽ tiêu đề con có mô tả', (tester) async {
      final key = GlobalKey<MarketFormRendererState>();
      final blocks = [
        _heading('h1', 'A. Trưng bày'),
        _heading('h1x', 'B. Giá', config: {'level': 'abc'}),
        _heading('h2', 'A.1 Quầy chính', config: {'level': 2}, desc: 'Mô tả tiêu đề con'),
        _heading('h2s', 'A.2 Kệ', config: '{"level":"2"}'),
      ];
      await tester.pumpWidget(_wrap(blocks, key));
      await tester.pumpAndSettle();

      expect(DynamicFormField.headingLevelOf({'config': blocks[0].resolved.configMap}), 1);
      expect(DynamicFormField.headingLevelOf({'config': blocks[1].resolved.configMap}), 1);
      expect(DynamicFormField.headingLevelOf({'config': blocks[2].resolved.configMap}), 2);
      expect(DynamicFormField.headingLevelOf({'config': blocks[3].resolved.configMap}), 2);

      expect(find.byKey(const ValueKey('subheading_h1')), findsNothing);
      expect(find.byKey(const ValueKey('subheading_h1x')), findsNothing);
      expect(find.byKey(const ValueKey('subheading_h2')), findsOneWidget);
      expect(find.byKey(const ValueKey('subheading_h2s')), findsOneWidget);
      expect(find.text('Mô tả tiêu đề con'), findsOneWidget);

      final big = tester.widget<Text>(find.text('A. Trưng bày'));
      final small = tester.widget<Text>(find.text('A.1 Quầy chính'));
      expect(small.style!.fontSize!, lessThan(big.style!.fontSize!));
      // Thụt vào so với tiêu đề cấp 1.
      expect(tester.getTopLeft(find.text('A.1 Quầy chính')).dx,
          greaterThan(tester.getTopLeft(find.text('A. Trưng bày')).dx));
    });
  });
}
