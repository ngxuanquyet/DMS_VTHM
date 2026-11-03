import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';

/// Ảnh đối chiếu cách vẽ form Thêm điểm bán ↔ biểu mẫu khảo sát/thu thập (#24756). Chạy
/// `flutter test test/forms/form_ui_unify_shots_test.dart --dart-define=SHOT_PREFIX=after` để xuất PNG (có lỗi bắt buộc
/// đang hiện) vào docs/shots/debug/20261103-dms-form-ui-unify/; không có SHOT_PREFIX thì chỉ dựng (không ghi tệp).
const _prefix = String.fromEnvironment('SHOT_PREFIX');
const _outDir = '../docs/shots/debug/20261103-dms-form-ui-unify';

Future<void> _loadFonts() async {
  const reg = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';
  const bold = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf';
  ByteData bytes(String path) => ByteData.sublistView(File(path).readAsBytesSync());
  if (!File(reg).existsSync() || !File(bold).existsSync()) return; // máy không có phông ⇒ ảnh chữ ô vuông, test vẫn chạy

  // google_fonts (Inter) tìm phông trong tài sản ứng dụng trước khi tải mạng ⇒ giả tài sản `google_fonts/Inter-*.ttf`
  // bằng DejaVu Sans (đủ dấu tiếng Việt) — không tải mạng, đúng tên họ phông app dùng.
  final fonts = {
    'google_fonts/Inter-Regular.ttf': reg,
    'google_fonts/Inter-Medium.ttf': reg,
    'google_fonts/Inter-SemiBold.ttf': bold,
    'google_fonts/Inter-Bold.ttf': bold,
  };
  GoogleFonts.config.allowRuntimeFetching = false;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (message) async {
    final key = utf8.decode(message!.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes));
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<String, Object>{for (final k in fonts.keys) k: <Object>[]});
    }
    final path = fonts[key];
    return path == null ? null : bytes(path);
  });

  Future<void> load(String family, String path) async {
    final loader = FontLoader(family)..addFont(Future.value(bytes(path)));
    await loader.load();
  }

  await load('Roboto', reg);
  const icons = '/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  if (File(icons).existsSync()) await load('MaterialIcons', icons);
}

const _opts = [DynamicFormOption(label: 'Đại lý', value: 1), DynamicFormOption(label: 'Bán lẻ', value: 2)];
const _nganh = [DynamicFormOption(label: 'Sữa', value: 'sua'), DynamicFormOption(label: 'Bánh kẹo', value: 'banh')];

const _customerFields = [
  DynamicFormField(code: 'name', label: 'Tên điểm bán', type: DynamicFormFieldType.text, isRequired: true, section: 'Thông tin điểm bán'),
  DynamicFormField(code: 'ghi_chu', label: 'Ghi chú', type: DynamicFormFieldType.longText, helperText: 'Mô tả ngắn', section: 'Thông tin điểm bán'),
  DynamicFormField(code: 'doanh_so', label: 'Doanh số tháng', type: DynamicFormFieldType.number, section: 'Thông tin điểm bán'),
  DynamicFormField(
      code: 'loai', label: 'Loại điểm bán', type: DynamicFormFieldType.singleChoice, isRequired: true, options: _opts,
      choiceDisplay: 'dropdown', section: 'Thông tin điểm bán'),
  DynamicFormField(
      code: 'muc', label: 'Mức độ hợp tác', type: DynamicFormFieldType.singleChoice, options: _opts, choiceDisplay: 'list',
      section: 'Thông tin điểm bán'),
  DynamicFormField(
      code: 'nganh', label: 'Ngành hàng', type: DynamicFormFieldType.multipleChoice, isRequired: true, options: _nganh,
      section: 'Thông tin điểm bán'),
  DynamicFormField(code: 'ngay', label: 'Ngày mở cửa', type: DynamicFormFieldType.date, section: 'Thông tin điểm bán'),
  DynamicFormField(code: 'co_kho', label: 'Có kho riêng', type: DynamicFormFieldType.boolean, section: 'Thông tin điểm bán'),
];

MarketFormBlockEntity _b(String code, String label, String type,
        {bool required = false, String? desc, List<MarketFormOptionEntity> options = const []}) =>
    MarketFormBlockEntity(
      ref: code,
      type: 'field',
      required: required,
      resolved: MarketFormResolvedEntity(code: code, label: label, inputType: type, description: desc, options: options),
    );

const _mOpts = [MarketFormOptionEntity(value: '1', label: 'Đại lý'), MarketFormOptionEntity(value: '2', label: 'Bán lẻ')];
const _mNganh = [MarketFormOptionEntity(value: 'sua', label: 'Sữa'), MarketFormOptionEntity(value: 'banh', label: 'Bánh kẹo')];

final _marketBlocks = [
  _b('h', 'Thông tin điểm bán', 'heading'),
  _b('name', 'Tên điểm bán', 'text', required: true),
  _b('ghi_chu', 'Ghi chú', 'textarea', desc: 'Mô tả ngắn'),
  _b('doanh_so', 'Doanh số tháng', 'number'),
  _b('loai', 'Loại điểm bán', 'select', required: true, options: _mOpts),
  _b('muc', 'Mức độ hợp tác', 'radio', options: _mOpts),
  _b('nganh', 'Ngành hàng', 'checkbox', required: true, options: _mNganh),
  _b('ngay', 'Ngày mở cửa', 'date'),
  _b('co_kho', 'Có kho riêng', 'boolean'),
];

Future<void> _shot(WidgetTester tester, GlobalKey boundary, String name) async {
  if (_prefix.isEmpty) return;
  // Phông google_fonts nạp bất đồng bộ — chờ xong rồi vẽ lại, không thì chữ thành ô vuông.
  await tester.runAsync(GoogleFonts.pendingFonts);
  tester.binding.reassembleApplication();
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final ro = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await ro.toImage(pixelRatio: 1.5);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_outDir/${_prefix}_$name.png');
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Phông thay thế (DejaVu) rộng hơn Inter ⇒ chữ dài có thể tràn hàng — ảnh vẫn chụp (vạch vàng đen hiện trong ảnh),
/// không đánh rớt test vì lỗi tràn.
void _ignoreOverflow() {
  final orig = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.exceptionAsString().contains('overflowed')) return;
    orig?.call(d);
  };
  addTearDown(() => FlutterError.onError = orig);
}

Widget _frame(GlobalKey boundary, Widget child) => ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RepaintBoundary(
              key: boundary,
              child: Material(color: Colors.white, child: Padding(padding: const EdgeInsets.all(16), child: child)),
            ),
          ),
        ),
      ),
    );

void main() {
  setUpAll(_loadFonts);

  testWidgets('form Thêm điểm bán — các loại ô cơ bản, lỗi bắt buộc đang hiện', (tester) async {
    tester.view.physicalSize = const Size(420 * 1.5, 2400 * 1.5);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    _ignoreOverflow();
    final boundary = GlobalKey();
    final form = GlobalKey<DynamicFormBuilderState>();
    await tester.pumpWidget(_frame(boundary, DynamicFormBuilder(key: form, fields: _customerFields, keepFieldOrder: true)));
    await tester.pumpAndSettle();
    form.currentState!.validate(focusFirstError: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('Tên điểm bán', findRichText: true), findsWidgets);
    await _shot(tester, boundary, 'customer_form');
  });

  testWidgets('biểu mẫu khảo sát/thu thập — cùng loại ô, lỗi bắt buộc đang hiện', (tester) async {
    tester.view.physicalSize = const Size(420 * 1.5, 2400 * 1.5);
    tester.view.devicePixelRatio = 1.5;
    addTearDown(tester.view.reset);
    _ignoreOverflow();
    final boundary = GlobalKey();
    final form = GlobalKey<MarketFormRendererState>();
    await tester.pumpWidget(_frame(boundary, MarketFormRenderer(key: form, blocks: _marketBlocks)));
    await tester.pumpAndSettle();
    form.currentState!.validateAndGetAnswers();
    await tester.pumpAndSettle();
    expect(find.textContaining('Tên điểm bán', findRichText: true), findsWidgets);
    await _shot(tester, boundary, 'market_form');
  });
}
