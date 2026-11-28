import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/core/widgets/form_fields/form_template_parts.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/presentation/screens/market_form_fill_screen.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';
import 'package:vthm_dms/features/profile/domain/entities/user_profile_detail_entity.dart';
import 'package:vthm_dms/features/profile/domain/entities/user_profile_entity.dart';
import 'package:vthm_dms/features/profile/domain/entities/user_relation_entity.dart';
import 'package:vthm_dms/features/profile/domain/repositories/profile_repository.dart';
import 'package:vthm_dms/features/profile/presentation/viewmodels/profile_view_model.dart';
import '../helpers/fake_inter_fonts.dart';

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<UserProfileEntity> getProfile() async => const UserProfileEntity(
        id: '1',
        name: 'Test',
        employeeId: 'EMP01',
        role: 'Sales',
        department: 'Hà Nội',
        avatarUrl: '',
        email: 'test@vthm.vn',
        phone: '0123456789',
        isDarkMode: false,
        language: 'vi',
      );

  @override
  Future<UserProfileDetailEntity> getUserProfileDetail() async =>
      throw UnimplementedError();

  @override
  Future<List<UserRelationEntity>> getUserRelations() async => [];

  @override
  Future<void> updateDarkMode(bool isDark) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    fakeInterFonts();
    SharedPreferences.setMockInitialValues({});
  });

  const sampleConfig = MarketFormConfigEntity(
    configId: 2025,
    formId: 9,
    code: 'VTHM-2025',
    name: 'Khảo sát NPP Mới VTHM',
    description: 'Dành cho nhân sự Sales đi khảo sát mở mới Nhà phân phối.',
    kind: 'collect',
    isRequired: true,
    sortOrder: 1,
    schema: MarketFormSchemaEntity(
      blocks: [
        MarketFormBlockEntity(
          ref: 'h_a',
          type: 'field',
          required: false,
          colSpan: 12,
          resolved: MarketFormResolvedEntity(
            code: 'h_a',
            label: 'A. Ứng viên nhà phân phối',
            description: 'Thông tin đại diện & định danh doanh nghiệp',
            inputType: 'heading',
            config: {'level': 1},
          ),
        ),
        MarketFormBlockEntity(
          ref: 'phone',
          type: 'field',
          required: true,
          colSpan: 12,
          resolved: MarketFormResolvedEntity(
            code: 'phone',
            label: 'Số điện thoại liên hệ',
            inputType: 'phone',
            config: {'placeholder': '09xx xxx xxx'},
          ),
        ),
        MarketFormBlockEntity(
          ref: 'h_hidden',
          type: 'field',
          required: false,
          colSpan: 12,
          resolved: MarketFormResolvedEntity(
            code: 'h_hidden',
            label: 'Mục ẩn trên app',
            inputType: 'heading',
            config: {'level': 1},
          ),
        ),
        MarketFormBlockEntity(
          ref: 'secret_web_only',
          type: 'field',
          required: false,
          colSpan: 12,
          hiddenOnApp: true,
          resolved: MarketFormResolvedEntity(
            code: 'secret_web_only',
            label: 'Trường chỉ hiện trên web',
            inputType: 'text',
          ),
        ),
        MarketFormBlockEntity(
          ref: 'h_b',
          type: 'field',
          required: false,
          colSpan: 12,
          resolved: MarketFormResolvedEntity(
            code: 'h_b',
            label: 'B. Sản phẩm quan tâm',
            inputType: 'heading',
            config: {'level': 1},
          ),
        ),
        MarketFormBlockEntity(
          ref: 'products',
          type: 'field',
          required: true,
          colSpan: 12,
          resolved: MarketFormResolvedEntity(
            code: 'products',
            label: 'Ngành hàng đang kinh doanh',
            inputType: 'checkbox',
            options: [
              MarketFormOptionEntity(
                value: 'ceramic',
                label: 'Gạch ốp lát ceramic',
              ),
              MarketFormOptionEntity(
                value: 'granite',
                label: 'Gạch porcelain / granite',
              ),
            ],
          ),
        ),
        MarketFormBlockEntity(
          ref: 'territories',
          type: 'field',
          required: false,
          colSpan: 12,
          resolved: MarketFormResolvedEntity(
            code: 'territories',
            label: 'Địa bàn đề xuất phụ trách',
            inputType: 'group_table',
            groupItems: [
              {
                'ref': 'area',
                'required': false,
                'resolved': {
                  'code': 'area',
                  'label': 'Khu vực',
                  'input_type': 'text',
                },
              },
            ],
          ),
        ),
      ],
    ),
  );

  testWidgets('MarketFormFillScreen renders TopBar, HeroCard, and bottom dock',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(_FakeProfileRepository()),
        ],
        child: const MaterialApp(
          home: MarketFormFillScreen(
            args: MarketFormFillArgs(
              config: sampleConfig,
              kind: 'collect',
              dealerName: 'NPP Minh Phát',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('Khảo sát NPP Mới VTHM'), findsNWidgets(2));
    expect(find.text('NPP Minh Phát'), findsNWidgets(2));
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('THU THẬP THỊ TRƯỜNG'), findsOneWidget);
    expect(find.text('Form #VTHM-2025'), findsOneWidget);
    expect(
      find.text('Dành cho nhân sự Sales đi khảo sát mở mới Nhà phân phối.'),
      findsOneWidget,
    );
    expect(find.text('NỘP BIỂU MẪU'), findsOneWidget);
  });

  testWidgets(
      'MarketFormRenderer renders section badges, hides web-only section, phone icon, trailing checkbox, and repeat add button',
      (tester) async {
    final rendererKey = GlobalKey<MarketFormRendererState>();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarketFormRenderer(
                key: rendererKey,
                blocks: sampleConfig.schema.blocks,
                initialAnswers: const {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Section A and Section B badges & heading titles, while hidden section is omitted.
    expect(find.text('A'), findsOneWidget);
    expect(find.text('A. Ứng viên nhà phân phối'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('B. Sản phẩm quan tâm'), findsOneWidget);
    expect(find.text('Mục ẩn trên app'), findsNothing);
    expect(find.text('Trường chỉ hiện trên web'), findsNothing);

    // Phone field shows phone prefix icon.
    expect(find.byIcon(Icons.phone_outlined), findsOneWidget);

    // CheckboxListTile uses trailing control affinity.
    final checkboxTiles = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .toList();
    expect(checkboxTiles, hasLength(2));
    expect(
      checkboxTiles.every(
        (tile) => tile.controlAffinity == ListTileControlAffinity.trailing,
      ),
      isTrue,
    );

    // Repeat group shows 'Thêm ...' button.
    expect(find.text('Thêm Địa bàn đề xuất phụ trách'), findsOneWidget);
  });

  testWidgets(
      'DynamicFormBuilder uses shared FormSectionCard template for sections and coords',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DynamicFormBuilder(
                keepFieldOrder: true,
                fields: [
                  DynamicFormField(
                    code: 'name',
                    label: 'Tên điểm bán',
                    type: DynamicFormFieldType.text,
                    section: 'Thông tin chung',
                  ),
                  DynamicFormField(
                    code: 'coords',
                    label: 'Toạ độ',
                    type: DynamicFormFieldType.location,
                    section: 'Vị trí trên bản đồ',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FormSectionCard), findsNWidgets(2));
    expect(find.text('A'), findsOneWidget);
    expect(find.text('Thông tin chung'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('Vị trí trên bản đồ'), findsOneWidget);
    expect(find.text('Có thể sửa'), findsOneWidget);
  });
}
