import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/dynamic_form/dynamic_form_builder.dart';
import 'package:vthm_dms/core/dynamic_form/models/dynamic_form_field.dart';
import 'package:vthm_dms/core/errors/app_exceptions.dart';
import 'package:vthm_dms/core/services/erp_partner_options_service.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';

/// Giả lập GET /dms/erp-partner-options — ghi lại tham số để kiểm app gửi đúng `field`/`q`/`page`/`ids`.
class FakeErpPartnerOptionsService implements ErpPartnerOptionsService {
  final List<ErpPartnerOption> all;
  final bool failSearch;
  final List<Map<String, dynamic>> searchCalls = [];
  final List<Map<String, dynamic>> lookupCalls = [];

  FakeErpPartnerOptionsService(this.all, {this.failSearch = false});

  @override
  Future<ErpPartnerOptionsPage> search({
    required String field,
    String query = '',
    int page = 1,
  }) async {
    searchCalls.add({'field': field, 'q': query, 'page': page});
    if (failSearch) {
      throw const NetworkException('Không có kết nối mạng. Vui lòng kiểm tra lại.');
    }
    final q = query.trim().toLowerCase();
    final items = all
        .where((e) => q.isEmpty || e.name.toLowerCase().contains(q) || e.code.contains(q))
        .toList();
    return ErpPartnerOptionsPage(items: items, page: page, hasMore: false);
  }

  @override
  Future<List<ErpPartnerOption>> lookup({
    required String field,
    required List<String> codes,
  }) async {
    lookupCalls.add({'field': field, 'codes': codes});
    return all.where((e) => codes.contains(e.code)).toList();
  }
}

const _partners = [
  ErpPartnerOption(code: '00160001', name: 'ABUL KHAIR STEEL', channelName: 'Kênh xuất khẩu'),
  ErpPartnerOption(code: '01200001', name: 'NPP Minh Phát', address: 'Hà Nội'),
  ErpPartnerOption(code: '01200002', name: 'NPP Hoàng Long'),
];

MarketFormBlockEntity _block({bool multiple = false}) => MarketFormBlockEntity(
      ref: 'npp_cap_hang',
      type: 'field',
      required: true,
      resolved: MarketFormResolvedEntity(
        code: 'npp_cap_hang',
        label: 'NPP cấp hàng',
        inputType: 'ref_erp_partner',
        config: {
          'channel_ids': [1, 3],
          'multiple': multiple,
        },
      ),
    );

Widget _wrapMarketForm(
  FakeErpPartnerOptionsService fake,
  GlobalKey<MarketFormRendererState> key, {
  bool multiple = false,
  Map<String, dynamic> initialAnswers = const {},
}) {
  return ProviderScope(
    overrides: [erpPartnerOptionsServiceProvider.overrideWithValue(fake)],
    child: MaterialApp(
      home: Scaffold(
        body: MarketFormRenderer(
          key: key,
          blocks: [_block(multiple: multiple)],
          initialAnswers: initialAnswers,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ErpPartnerOptionsPage parse', () {
    test('Giữ mã dạng chuỗi có số 0 đầu, đọc has_more/page', () {
      final page = ErpPartnerOptionsPage.fromResponse({
        'success': true,
        'data': {
          'items': [
            {'code': '00160001', 'name': 'ABUL KHAIR', 'address': null, 'channel_name': 'Kênh xuất khẩu'},
          ],
          'page': 2,
          'has_more': true,
          'field': {'channel_ids': [1, 3], 'multiple': true},
        },
      });
      expect(page.items.single.code, '00160001');
      expect(page.items.single.address, isNull);
      expect(page.items.single.displayLabel, 'ABUL KHAIR (00160001)');
      expect(page.page, 2);
      expect(page.hasMore, isTrue);
    });
  });

  group('MarketFormRenderer — ô ref_erp_partner', () {
    testWidgets('Chọn một: tìm trên server, lưu MÃ chuỗi giữ số 0 đầu', (tester) async {
      final fake = FakeErpPartnerOptionsService(_partners);
      final key = GlobalKey<MarketFormRendererState>();
      await tester.pumpWidget(_wrapMarketForm(fake, key));
      await tester.pumpAndSettle();

      expect(find.textContaining('NPP cấp hàng'), findsOneWidget);
      await tester.tap(find.text('Chạm để tìm khách hàng pháp nhân...'));
      await tester.pumpAndSettle();

      // Mở sheet là gọi trang 1 với đúng mã ô
      expect(fake.searchCalls.first, {'field': 'npp_cap_hang', 'q': '', 'page': 1});
      expect(find.text('ABUL KHAIR STEEL'), findsOneWidget);
      expect(find.text('NPP Minh Phát'), findsOneWidget);

      // Gõ từ khoá → gọi server sau debounce
      await tester.enterText(find.byType(TextField), 'minh');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      expect(fake.searchCalls.last['q'], 'minh');
      expect(find.text('ABUL KHAIR STEEL'), findsNothing);

      await tester.tap(find.text('NPP Minh Phát'));
      await tester.pumpAndSettle();

      // Sheet đóng, ô hiện tên + mã
      expect(find.text('NPP Minh Phát'), findsOneWidget);
      expect(find.text('01200001'), findsOneWidget);
      expect(key.currentState?.currentAnswers['npp_cap_hang'], '01200001');

      final answers = key.currentState?.validateAndGetAnswers();
      expect(answers, isNotNull);
      expect(answers!['npp_cap_hang'], isA<String>());
      expect(answers['npp_cap_hang'], '01200001');
    });

    testWidgets('Chọn nhiều (config.multiple): lưu mảng chuỗi mã', (tester) async {
      final fake = FakeErpPartnerOptionsService(_partners);
      final key = GlobalKey<MarketFormRendererState>();
      await tester.pumpWidget(_wrapMarketForm(fake, key, multiple: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chạm để tìm khách hàng pháp nhân...'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ABUL KHAIR STEEL'));
      await tester.pump();
      await tester.tap(find.text('NPP Hoàng Long'));
      await tester.pump();
      await tester.tap(find.text('Xong (đã chọn 2)'));
      await tester.pumpAndSettle();

      expect(find.text('ABUL KHAIR STEEL (00160001)'), findsOneWidget);
      expect(find.text('NPP Hoàng Long (01200002)'), findsOneWidget);

      final answers = key.currentState?.validateAndGetAnswers();
      expect(answers, isNotNull);
      expect(answers!['npp_cap_hang'], ['00160001', '01200002']);
    });

    testWidgets('Lỗi mạng: hiện thông báo + nút Thử lại, không crash', (tester) async {
      final fake = FakeErpPartnerOptionsService(_partners, failSearch: true);
      final key = GlobalKey<MarketFormRendererState>();
      await tester.pumpWidget(_wrapMarketForm(fake, key));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chạm để tìm khách hàng pháp nhân...'));
      await tester.pumpAndSettle();

      expect(find.text('Không có kết nối mạng. Vui lòng kiểm tra lại.'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Mở lại phiếu: tra nhãn theo ids cho mã đang lưu', (tester) async {
      final fake = FakeErpPartnerOptionsService(_partners);
      final key = GlobalKey<MarketFormRendererState>();
      await tester.pumpWidget(_wrapMarketForm(
        fake,
        key,
        initialAnswers: const {'npp_cap_hang': '01200001'},
      ));
      await tester.pumpAndSettle();

      expect(fake.lookupCalls.single, {
        'field': 'npp_cap_hang',
        'codes': ['01200001'],
      });
      expect(find.text('NPP Minh Phát'), findsOneWidget);
    });

    testWidgets('Bắt buộc mà chưa chọn thì không qua validate', (tester) async {
      final fake = FakeErpPartnerOptionsService(_partners);
      final key = GlobalKey<MarketFormRendererState>();
      await tester.pumpWidget(_wrapMarketForm(fake, key));
      await tester.pumpAndSettle();

      expect(key.currentState?.validateAndGetAnswers(), isNull);
      await tester.pump();
      expect(find.text('NPP cấp hàng không được để trống.'), findsOneWidget);
    });
  });

  group('DynamicFormBuilder (hồ sơ điểm bán) — ô ref_erp_partner', () {
    test('Schema: input_type ref_erp_partner + erp_partner.multiple', () {
      final f = DynamicFormField.fromJson({
        'code': 'npp_cap_hang',
        'label': 'NPP cấp hàng',
        'input_type': 'ref_erp_partner',
        'erp_partner': {'channel_ids': [1], 'multiple': true},
      });
      expect(f.type, DynamicFormFieldType.erpPartner);
      expect(f.erpPartnerMultiple, isTrue);
      // copyWith (màn thêm/sửa gọi để làm sạch nhãn) không được làm rơi cờ chọn nhiều
      expect(f.copyWith(label: 'NPP').erpPartnerMultiple, isTrue);

      final single = DynamicFormField.fromJson({
        'code': 'npp',
        'input_type': 'ref_erp_partner',
        'erp_partner': null,
      });
      expect(single.erpPartnerMultiple, isFalse);
    });

    testWidgets('Chọn một: getFormData trả MÃ chuỗi', (tester) async {
      final fake = FakeErpPartnerOptionsService(_partners);
      final formKey = GlobalKey<DynamicFormBuilderState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [erpPartnerOptionsServiceProvider.overrideWithValue(fake)],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DynamicFormBuilder(
                  key: formKey,
                  fields: const [
                    DynamicFormField(
                      code: 'npp_cap_hang',
                      label: 'NPP cấp hàng',
                      type: DynamicFormFieldType.erpPartner,
                      isRequired: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(formKey.currentState!.validate(), isFalse);

      await tester.tap(find.text('Chạm để tìm khách hàng pháp nhân...'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ABUL KHAIR STEEL'));
      await tester.pumpAndSettle();

      expect(formKey.currentState!.validate(), isTrue);
      expect(formKey.currentState!.getFormData()['npp_cap_hang'], '00160001');
    });
  });
}
