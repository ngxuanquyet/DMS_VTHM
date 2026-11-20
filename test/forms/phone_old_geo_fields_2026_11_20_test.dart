import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/core/services/geo_catalog_service.dart';
import 'package:vthm_dms/core/utils/phone_utils.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';

/// Ba loại ô mới (20/11/2026): `phone`, `ref_old_province` → `ref_old_district`. App vẽ/kiểm/gửi theo `input_type`.
class _FakeGeoCatalogService implements GeoCatalogService {
  final GeoCatalog catalog;
  _FakeGeoCatalogService(this.catalog);

  @override
  GeoCatalog? get cached => catalog;

  @override
  Future<GeoCatalog?> load({bool force = false}) async => catalog;
}

final _catalog = GeoCatalog.fromJson({
  'version': 'v2',
  'provinces': [
    {'id': 1, 'name': 'Phú Thọ', 'full_name': 'Tỉnh Phú Thọ', 'is_active': true},
  ],
  'wards': const [],
  'old_provinces': [
    {'id': 101, 'name': 'Hoà Bình', 'full_name': 'Tỉnh Hoà Bình'},
    {'id': 102, 'name': 'Vĩnh Phúc', 'full_name': 'Tỉnh Vĩnh Phúc'},
  ],
  'old_districts': [
    {'id': 1001, 'old_province_id': 101, 'name': 'Lương Sơn', 'full_name': 'Huyện Lương Sơn'},
    {'id': 1002, 'old_province_id': 101, 'name': 'Kim Bôi', 'full_name': 'Huyện Kim Bôi'},
    {'id': 2001, 'old_province_id': 102, 'name': 'Tam Đảo', 'full_name': 'Huyện Tam Đảo'},
  ],
});

const _oldGeoBlocks = [
  MarketFormBlockEntity(
    ref: 'tinh_cu',
    type: 'field',
    required: true,
    colSpan: 12,
    resolved: MarketFormResolvedEntity(code: 'tinh_cu', label: 'Tỉnh cũ', inputType: 'ref_old_province'),
  ),
  MarketFormBlockEntity(
    ref: 'huyen_cu',
    type: 'field',
    required: true,
    colSpan: 12,
    resolved: MarketFormResolvedEntity(
      code: 'huyen_cu',
      label: 'Huyện cũ',
      inputType: 'ref_old_district',
      config: {
        'depends_on': [
          {'field_code': 'tinh_cu', 'as': 'oldProvinceId'},
        ],
      },
    ),
  ),
];

const _phoneBlocks = [
  MarketFormBlockEntity(
    ref: 'sdt',
    type: 'field',
    required: false,
    colSpan: 12,
    resolved: MarketFormResolvedEntity(code: 'sdt', label: 'SĐT chủ quán', inputType: 'phone'),
  ),
];

Future<void> _pick(WidgetTester tester, String fieldText, String unit) async {
  await tester.tap(find.text(fieldText));
  await tester.pumpAndSettle();
  await tester.tap(find.text(unit).last);
  await tester.pumpAndSettle();
}

void main() {
  group('PhoneUtils — cùng luật PhoneHelper::normalize + kiểm của server', () {
    test('chuẩn hoá', () {
      expect(PhoneUtils.normalize('0365.920.961'), '0365920961');
      expect(PhoneUtils.normalize('+84 365 920 961'), '0365920961');
      expect(PhoneUtils.normalize('0084365920961'), '0365920961');
      expect(PhoneUtils.normalize('084 24 3826 1234'), '02438261234');
      expect(PhoneUtils.normalize('8412'), '8412', reason: 'phần sau 84 không đủ 9–10 số ⇒ không cắt');
      expect(PhoneUtils.normalize('  '), isNull);
      expect(PhoneUtils.normalize('abc'), isNull);
    });

    test('kiểm dạng', () {
      for (final ok in ['0912345678', '0365920961', '0587654321', '0701234567', '0812345678', '02438261234', '+84912345678']) {
        expect(PhoneUtils.validate(ok), isNull, reason: ok);
      }
      for (final sai in ['0123456789', '091234567', '09123456789', '0243826123', '0412345678', 'abc', '12345']) {
        expect(PhoneUtils.validate(sai), PhoneUtils.invalidMessage, reason: sai);
      }
      expect(PhoneUtils.validate(''), isNull, reason: 'rỗng: chỉ lỗi khi bắt buộc (phép kiểm chung)');
      expect(PhoneUtils.validate(null), isNull);
    });
  });

  group('GeoCatalog — danh mục cũ', () {
    test('đọc old_provinces/old_districts; thiếu khoá ⇒ hasOldUnits false', () {
      expect(_catalog.hasOldUnits, isTrue);
      expect(_catalog.oldProvince(101)?.fullName, 'Tỉnh Hoà Bình');
      expect(_catalog.oldDistrict(2001)?.provinceId, 102);
      expect(_catalog.oldDistrictsOf(101).map((d) => d.id), [1001, 1002]);
      expect(_catalog.oldDistrict(1001)?.isActive, isTrue, reason: 'danh mục cũ không có is_active — chọn được hết');
      final cu = GeoCatalog.fromJson({'version': 'v1', 'provinces': const [], 'wards': const []});
      expect(cu.hasOldUnits, isFalse);
      expect(cu.oldDistrictsOf(101), isEmpty);
    });

    test('DynamicFormFieldType theo input_type', () {
      expect(DynamicFormFieldType.fromString('phone'), DynamicFormFieldType.phone);
      expect(DynamicFormFieldType.fromString('ref_old_province'), DynamicFormFieldType.geoOldProvince);
      expect(DynamicFormFieldType.fromString('ref_old_district'), DynamicFormFieldType.geoOldDistrict);
      expect(GeoLevel.fromInputType('ref_old_district'), GeoLevel.oldDistrict);
    });
  });

  group('Biểu mẫu thị trường', () {
    Future<GlobalKey<MarketFormRendererState>> pump(WidgetTester tester, List<MarketFormBlockEntity> blocks,
        {GeoCatalog? catalog}) async {
      final key = GlobalKey<MarketFormRendererState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [geoCatalogServiceProvider.overrideWithValue(_FakeGeoCatalogService(catalog ?? _catalog))],
          child: MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: MarketFormRenderer(key: key, blocks: blocks))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return key;
    }

    testWidgets('Huyện cũ khoá tới khi chọn tỉnh cũ, chỉ bày huyện của tỉnh đó, đổi tỉnh bỏ huyện', (tester) async {
      final key = await pump(tester, _oldGeoBlocks);

      expect(find.text('Chọn tỉnh cũ trước'), findsOneWidget);
      await _pick(tester, 'Chọn tỉnh cũ', 'Tỉnh Hoà Bình');
      await tester.tap(find.text('Chọn huyện cũ'));
      await tester.pumpAndSettle();
      expect(find.text('Huyện Lương Sơn'), findsOneWidget);
      expect(find.text('Huyện Tam Đảo'), findsNothing, reason: 'huyện tỉnh khác không được hiện');
      // Tìm không dấu.
      await tester.enterText(find.byType(TextField).last, 'kim boi');
      await tester.pumpAndSettle();
      expect(find.text('Huyện Lương Sơn'), findsNothing);
      await tester.tap(find.text('Huyện Kim Bôi'));
      await tester.pumpAndSettle();

      final ans = key.currentState!.validateAndGetAnswers();
      expect(ans, containsPair('tinh_cu', 101));
      expect(ans, containsPair('huyen_cu', 1002));

      await _pick(tester, 'Tỉnh Hoà Bình', 'Tỉnh Vĩnh Phúc');
      expect(find.text('Huyện Kim Bôi'), findsNothing);
      expect(key.currentState!.validateAndGetAnswers(), isNull, reason: 'huyện bắt buộc đã bị bỏ khi đổi tỉnh');
    });

    testWidgets('Danh mục lưu máy chưa có đơn vị cũ ⇒ ô tỉnh cũ báo cần tải, không trống im', (tester) async {
      await pump(tester, _oldGeoBlocks,
          catalog: GeoCatalog.fromJson({'version': 'v1', 'provinces': const [], 'wards': const []}));
      expect(find.textContaining('Chưa có danh mục'), findsWidgets);
    });

    testWidgets('Ô phone: bàn phím số, số sai bị chặn, số đúng gửi đã chuẩn hoá', (tester) async {
      final key = await pump(tester, _phoneBlocks);
      final tf = tester.widget<TextField>(find.byType(TextField).first);
      expect(tf.keyboardType, TextInputType.phone);

      await tester.enterText(find.byType(TextField).first, '0123 456 789');
      await tester.pumpAndSettle();
      expect(key.currentState!.validateAndGetAnswers(), isNull);
      await tester.pumpAndSettle();
      expect(find.text(PhoneUtils.invalidMessage), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '+84 912 345 678');
      await tester.pumpAndSettle();
      expect(key.currentState!.validateAndGetAnswers(), containsPair('sdt', '0912345678'));
    });
  });

  group('Form điểm bán (DynamicFormBuilder)', () {
    const phoneField = DynamicFormField(code: 'sdt_phu', label: 'SĐT phụ', type: DynamicFormFieldType.phone);

    testWidgets('ô loại phone: số sai chặn Lưu, số đúng gửi đã chuẩn hoá', (tester) async {
      final key = GlobalKey<DynamicFormBuilderState>();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: DynamicFormBuilder(key: key, fields: const [phoneField]))),
      ));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField).first).keyboardType, TextInputType.phone);

      await tester.enterText(find.byType(TextField).first, '0912 34');
      await tester.pumpAndSettle();
      expect(key.currentState!.validate(focusFirstError: false), isFalse);
      await tester.pumpAndSettle();
      expect(find.text(PhoneUtils.invalidMessage), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '(+84) 24 3826 1234');
      await tester.pumpAndSettle();
      expect(key.currentState!.validate(focusFirstError: false), isTrue);
      expect(key.currentState!.getFormData(), containsPair('sdt_phu', '02438261234'));
    });

    testWidgets('màn sửa: số đang lưu (dù sai dạng) không đụng tới thì không chặn, không đổi', (tester) async {
      final key = GlobalKey<DynamicFormBuilderState>();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DynamicFormBuilder(
              key: key,
              fields: const [phoneField],
              initialData: const {'sdt_phu': '12345'},
              savedData: const {'sdt_phu': '12345'},
              editing: true,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(key.currentState!.validate(focusFirstError: false), isTrue);
      expect(key.currentState!.getFormData(), containsPair('sdt_phu', '12345'));
    });

    testWidgets('Tỉnh cũ → Huyện cũ theo depends_on; đổi tỉnh bỏ huyện', (tester) async {
      final fields = [
        DynamicFormField.fromJson({'code': 'tinh_cu', 'label': 'Tỉnh cũ', 'input_type': 'ref_old_province'}),
        DynamicFormField.fromJson({
          'code': 'huyen_cu',
          'label': 'Huyện cũ',
          'input_type': 'ref_old_district',
          'depends_on': [
            {'field_code': 'tinh_cu', 'as': 'oldProvinceId'},
          ],
        }),
      ];
      final key = GlobalKey<DynamicFormBuilderState>();
      await tester.pumpWidget(ProviderScope(
        overrides: [geoCatalogServiceProvider.overrideWithValue(_FakeGeoCatalogService(_catalog))],
        child: MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: DynamicFormBuilder(key: key, fields: fields))),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Chọn tỉnh cũ trước'), findsOneWidget);
      await _pick(tester, 'Chọn tỉnh cũ', 'Tỉnh Hoà Bình');
      await _pick(tester, 'Chọn huyện cũ', 'Huyện Lương Sơn');
      expect(key.currentState!.getFormData(), allOf(containsPair('tinh_cu', 101), containsPair('huyen_cu', 1001)));

      await _pick(tester, 'Tỉnh Hoà Bình', 'Tỉnh Vĩnh Phúc');
      expect(key.currentState!.getFormData()['huyen_cu'], isNull);
    });
  });
}
