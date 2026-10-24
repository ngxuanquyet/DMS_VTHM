import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/services/geo_catalog_service.dart';
import 'package:vthm_dms/features/forms/data/models/market_form_submission_model.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';

/// Danh mục giả đã "lưu máy" — ô Tỉnh/Xã đọc offline, không gọi mạng.
class _FakeGeoCatalogService implements GeoCatalogService {
  final GeoCatalog catalog;
  _FakeGeoCatalogService(this.catalog);

  @override
  GeoCatalog? get cached => catalog;

  @override
  Future<GeoCatalog?> load({bool force = false}) async => catalog;
}

GeoUnit _unit(int id, int? provinceId, String fullName, {bool active = true}) => GeoUnit(
      id: id,
      provinceId: provinceId,
      code: '$id',
      name: fullName,
      fullName: fullName,
      unitType: '',
      isActive: active,
    );

final _catalog = GeoCatalog(
  version: 'v1',
  provinces: [_unit(1, null, 'Tỉnh Phú Thọ'), _unit(2, null, 'Thành phố Hà Nội')],
  wards: [
    _unit(11, 1, 'Phường Việt Trì'),
    _unit(12, 1, 'Xã Thanh Ba'),
    _unit(21, 2, 'Phường Ba Đình'),
    _unit(22, 2, 'Phường Hoàn Kiếm', active: false),
  ],
);

/// Hai ô như server lưu: ô xã mang `depends_on` trỏ ô tỉnh đứng trên (FormEditorService::linkWardsToProvinces).
const _blocks = [
  MarketFormBlockEntity(
    ref: 'tinh',
    type: 'field',
    required: true,
    colSpan: 12,
    resolved: MarketFormResolvedEntity(code: 'tinh', label: 'Tỉnh/thành', inputType: 'ref_province'),
  ),
  MarketFormBlockEntity(
    ref: 'xa',
    type: 'field',
    required: true,
    colSpan: 12,
    resolved: MarketFormResolvedEntity(
      code: 'xa',
      label: 'Xã/phường',
      inputType: 'ref_ward',
      config: {
        'depends_on': [
          {'field_code': 'tinh', 'as': 'provinceId'},
        ],
      },
    ),
  ),
];

void main() {
  _detailLabelTests();

  Future<GlobalKey<MarketFormRendererState>> pump(WidgetTester tester) async {
    final key = GlobalKey<MarketFormRendererState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [geoCatalogServiceProvider.overrideWithValue(_FakeGeoCatalogService(_catalog))],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: MarketFormRenderer(key: key, blocks: _blocks)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return key;
  }

  Future<void> pick(WidgetTester tester, String fieldText, String unit) async {
    await tester.tap(find.text(fieldText));
    await tester.pumpAndSettle();
    await tester.tap(find.text(unit).last);
    await tester.pumpAndSettle();
  }

  testWidgets('Ô xã khoá tới khi chọn tỉnh, chỉ bày xã của tỉnh đó, gửi ID số', (tester) async {
    final key = await pump(tester);

    expect(find.text('Chọn tỉnh/thành trước'), findsOneWidget);
    await tester.tap(find.text('Chọn tỉnh/thành trước'));
    await tester.pumpAndSettle();
    expect(find.text('Phường Việt Trì'), findsNothing, reason: 'chưa chọn tỉnh thì không mở danh sách xã');

    await pick(tester, 'Chọn tỉnh/thành', 'Tỉnh Phú Thọ');
    await tester.tap(find.text('Chọn xã/phường'));
    await tester.pumpAndSettle();
    expect(find.text('Phường Việt Trì'), findsOneWidget);
    expect(find.text('Xã Thanh Ba'), findsOneWidget);
    expect(find.text('Phường Ba Đình'), findsNothing, reason: 'xã tỉnh khác không được hiện');
    await tester.tap(find.text('Xã Thanh Ba'));
    await tester.pumpAndSettle();

    expect(key.currentState!.validateAndGetAnswers(), containsPair('tinh', 1));
    expect(key.currentState!.validateAndGetAnswers(), containsPair('xa', 12));
  });

  testWidgets('Đổi tỉnh thì bỏ xã cũ; xã bắt buộc để trống thì chặn nộp', (tester) async {
    final key = await pump(tester);

    await pick(tester, 'Chọn tỉnh/thành', 'Tỉnh Phú Thọ');
    await pick(tester, 'Chọn xã/phường', 'Phường Việt Trì');
    await pick(tester, 'Tỉnh Phú Thọ', 'Thành phố Hà Nội');

    expect(find.text('Phường Việt Trì'), findsNothing);
    expect(key.currentState!.validateAndGetAnswers(), isNull);
    await tester.pumpAndSettle();
    expect(find.textContaining('Xã/phường không được để trống'), findsOneWidget);

    // Đơn vị đã tắt không được chọn MỚI.
    await tester.tap(find.text('Chọn xã/phường'));
    await tester.pumpAndSettle();
    expect(find.text('Phường Ba Đình'), findsOneWidget);
    expect(find.textContaining('Hoàn Kiếm'), findsNothing);
  });
}

void _detailLabelTests() {
  test('Chi tiết phiếu: ô danh mục/Tỉnh/Xã hiện tên lúc nộp, ô thường không có tên', () {
    final d = MarketFormSubmissionDetailModel.fromJson({
      'id': 5,
      'answers': {'tinh': 1, 'xa': 12, 'kenh': [3, 4], 'ghi_chu': 'abc'},
      'choice_labels': {
        'tinh': 'Tỉnh Phú Thọ',
        'xa': 'Xã Thanh Ba',
        'kenh': ['Kênh A', 'Kênh B'],
      },
    });
    expect(d.choiceLabelOf('tinh'), 'Tỉnh Phú Thọ');
    expect(d.choiceLabelOf('xa'), 'Xã Thanh Ba');
    expect(d.choiceLabelOf('kenh'), 'Kênh A, Kênh B');
    expect(d.choiceLabelOf('ghi_chu'), isNull);
    // Phiếu cũ không có choice_labels (NULL) vẫn đọc được.
    expect(MarketFormSubmissionDetailModel.fromJson({'id': 1, 'choice_labels': null}).choiceLabelOf('tinh'), isNull);
  });
}
