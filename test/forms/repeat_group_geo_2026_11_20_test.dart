import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/core/dynamic_form/repeat_group.dart';
import 'package:vthm_dms/core/dynamic_form/widgets/repeat_group_field_widget.dart';
import 'package:vthm_dms/core/services/geo_catalog_service.dart';

/// Nhóm trường lặp có ô con địa giới (20/11/2026): ô xã/huyện cũ của dòng i lọc theo ô tỉnh CỦA CHÍNH dòng i.
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
    {'id': 1, 'full_name': 'Tỉnh Phú Thọ', 'is_active': true},
    {'id': 2, 'full_name': 'Thành phố Hà Nội', 'is_active': true},
  ],
  'wards': [
    {'id': 11, 'province_id': 1, 'full_name': 'Phường Việt Trì', 'is_active': true},
    {'id': 21, 'province_id': 2, 'full_name': 'Phường Ba Đình', 'is_active': true},
  ],
  'old_provinces': [
    {'id': 101, 'name': 'Hoà Bình', 'full_name': 'Tỉnh Hoà Bình'},
  ],
  'old_districts': [
    {'id': 1001, 'old_province_id': 101, 'name': 'Lương Sơn', 'full_name': 'Huyện Lương Sơn'},
  ],
});

/// Cột nhóm như schema điểm bán (`group.columns[]`, `depends_on` phẳng).
final _customerGroup = {
  'min_rows': 0,
  'max_rows': 0,
  'columns': [
    {'code': 'tinh', 'label': 'Tỉnh', 'input_type': 'ref_province'},
    {
      'code': 'xa',
      'label': 'Xã',
      'input_type': 'ref_ward',
      'depends_on': [
        {'field_code': 'tinh', 'as': 'provinceId'},
      ],
    },
  ],
};

void main() {
  test('đặc tả: depends_on của cột (điểm bán phẳng, biểu mẫu thị trường ở config)', () {
    final spec = RepeatGroupSpec.fromCustomerSchema(_customerGroup)!;
    expect(spec.columns[0].type, DynamicFormFieldType.geoProvince);
    expect(spec.columns[1].dependsOn, 'tinh');

    final eng = RepeatGroupSpec.fromEngineItems([
      {
        'ref': 'tc',
        'resolved': {'code': 'tc', 'label': 'Tỉnh cũ', 'input_type': 'ref_old_province', 'config': {}},
      },
      {
        'ref': 'hc',
        'resolved': {
          'code': 'hc',
          'label': 'Huyện cũ',
          'input_type': 'ref_old_district',
          'config': {
            'depends_on': [
              {'field_code': 'tc', 'as': 'oldProvinceId'},
            ],
          },
        },
      },
    ], {});
    expect(eng.columns[1].type, DynamicFormFieldType.geoOldDistrict);
    expect(eng.columns[1].dependsOn, 'tc');
  });

  testWidgets('cascade TRONG DÒNG: xã dòng 2 lọc theo tỉnh dòng 2; đổi tỉnh dòng 1 chỉ bỏ xã dòng 1', (tester) async {
    final spec = RepeatGroupSpec.fromCustomerSchema(_customerGroup)!;
    List<Map<String, dynamic>> value = [
      {'line_id': 'a', 'tinh': 1, 'xa': 11},
      {'line_id': 'b', 'tinh': 2},
    ];
    await tester.pumpWidget(ProviderScope(
      overrides: [geoCatalogServiceProvider.overrideWithValue(_FakeGeoCatalogService(_catalog))],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => RepeatGroupFieldWidget(
                field: const DynamicFormField(code: 'diem', label: 'Điểm', type: DynamicFormFieldType.repeatGroup),
                spec: spec,
                value: value,
                onChanged: (rows) => setState(() => value = rows),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Dòng 1 hiện tên tỉnh + xã; dòng 2 xã chưa chọn ⇒ mở được, chỉ xã của Hà Nội.
    expect(find.text('Phường Việt Trì'), findsOneWidget);
    await tester.tap(find.text('Chọn xã'));
    await tester.pumpAndSettle();
    expect(find.text('Phường Ba Đình'), findsOneWidget);
    expect(find.text('Phường Việt Trì'), findsOneWidget, reason: 'chỉ là ô dòng 1, không có trong danh sách dòng 2');
    await tester.tap(find.text('Phường Ba Đình'));
    await tester.pumpAndSettle();
    expect(value[1], containsPair('xa', 21));

    // Đổi tỉnh dòng 1 ⇒ bỏ xã dòng 1, dòng 2 giữ nguyên.
    await tester.tap(find.text('Tỉnh Phú Thọ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thành phố Hà Nội').last);
    await tester.pumpAndSettle();
    expect(value[0], containsPair('tinh', 2));
    expect(value[0].containsKey('xa'), isFalse);
    expect(value[0]['line_id'], 'a');
    expect(value[1], containsPair('xa', 21));
  });

  testWidgets('dòng mới: ô xã khoá tới khi chọn tỉnh của dòng', (tester) async {
    final spec = RepeatGroupSpec.fromCustomerSchema(_customerGroup)!;
    await tester.pumpWidget(ProviderScope(
      overrides: [geoCatalogServiceProvider.overrideWithValue(_FakeGeoCatalogService(_catalog))],
      child: MaterialApp(
        home: Scaffold(
          body: RepeatGroupFieldWidget(
            field: const DynamicFormField(code: 'diem', label: 'Điểm', type: DynamicFormFieldType.repeatGroup),
            spec: spec,
            value: const [
              {'line_id': 'a'},
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Chọn tỉnh/thành trước'), findsOneWidget);
  });

  test('màn xem: in TÊN tra danh mục máy; chưa có danh mục ⇒ in id (không vỡ)', () {
    final spec = RepeatGroupSpec.fromCustomerSchema(_customerGroup)!;
    final row = {'line_id': 'a', 'tinh': 1, 'xa': 11};
    GeoCatalogService.memoryForTest = _catalog;
    addTearDown(() => GeoCatalogService.memoryForTest = null);
    expect(spec.rowText(row), 'Tỉnh Phú Thọ – Phường Việt Trì');
    GeoCatalogService.memoryForTest = null;
    expect(spec.rowText(row), '1 – 11');
  });
}
