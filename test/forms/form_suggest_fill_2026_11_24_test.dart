import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';
import 'package:vthm_dms/features/forms/data/services/form_suggest_store.dart';
import 'package:vthm_dms/features/forms/data/services/forms_api_service.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/presentation/screens/market_form_fill_screen.dart';
import 'package:vthm_dms/features/forms/presentation/viewmodels/forms_view_model.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';
import 'package:vthm_dms/features/profile/domain/entities/user_profile_detail_entity.dart';
import 'package:vthm_dms/features/profile/domain/entities/user_profile_entity.dart';
import 'package:vthm_dms/features/profile/domain/entities/user_relation_entity.dart';
import 'package:vthm_dms/features/profile/domain/repositories/profile_repository.dart';
import 'package:vthm_dms/features/profile/presentation/viewmodels/profile_view_model.dart';

import '../helpers/fake_inter_fonts.dart';

/// Chốt 24/11/2026: chạm gợi ý «Tên ứng viên NPP» ⇒ tự điền CẢ phiếu theo phiếu cũ mới nhất của tên đó (server đã bỏ ảnh);
/// đã nhập ô khác ⇒ hỏi trước khi ghi đè, chọn «Chỉ điền tên» thì giữ nguyên phần đã nhập.
class _Paths extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  final Directory dir;
  _Paths(this.dir);

  @override
  Future<String?> getTemporaryPath() async => dir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;
}

class _Api extends Fake implements FormsApiService {
  @override
  Future<FormSuggestions> getSuggestions(int formId) async => (
    fields: {
      'ten': ['NPP Linh Thìn'],
    },
    fills: {
      'ten': {
        'NPP Linh Thìn': <String, dynamic>{
          'ten': 'NPP Linh Thìn',
          'sdt': '0393938521',
          'ghi_chu': 'phiếu cũ',
          // Lựa chọn «C» admin đã gỡ khỏi ô ⇒ bỏ khi dựng; dòng bảng lặp mang `line_id` của phiếu cũ ⇒ cấp mới.
          'kenh': ['A', 'C'],
          'bang': [
            {'line_id': 'cu0000000000000a', 'cot': 'X'},
          ],
        },
      },
    },
  );
}

class _Profile implements ProfileRepository {
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
  Future<UserProfileDetailEntity> getUserProfileDetail() async => throw UnimplementedError();

  @override
  Future<List<UserRelationEntity>> getUserRelations() async => [];

  @override
  Future<void> updateDarkMode(bool isDark) async {}
}

MarketFormBlockEntity _o(String code, String type, [Map<String, dynamic>? cfg]) => MarketFormBlockEntity(
  ref: code,
  type: 'field',
  required: false,
  resolved: MarketFormResolvedEntity(code: code, label: 'Ô $code', inputType: type, config: cfg),
);

void main() {
  late Directory docs;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyUserData: jsonEncode({'id': 42}),
    });
    docs = Directory.systemTemp.createTempSync('suggest_fill');
    PathProviderPlatform.instance = _Paths(docs);
    fakeInterFonts();
    // Màn đọc trạng thái mạng — plugin không có trong test, luồng sự kiện để im.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
      const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
      MockStreamHandler.inline(onListen: (_, __) {}),
    );
  });

  tearDown(() => docs.deleteSync(recursive: true));

  MarketFormConfigEntity config(int configId) => MarketFormConfigEntity(
    configId: configId,
    formId: 914,
    code: 'create_npp',
    name: 'Khảo sát NPP',
    kind: 'collect',
    isRequired: false,
    sortOrder: 1,
    schema: MarketFormSchemaEntity(
      blocks: [
        _o('ten', 'text', {'suggest_from_history': true}),
        _o('sdt', 'text'),
        _o('ghi_chu', 'text'),
        const MarketFormBlockEntity(
          ref: 'kenh',
          type: 'field',
          required: false,
          resolved: MarketFormResolvedEntity(
            code: 'kenh',
            label: 'Kênh',
            inputType: 'checkbox',
            options: [MarketFormOptionEntity(value: 'A', label: 'A'), MarketFormOptionEntity(value: 'B', label: 'B')],
          ),
        ),
        const MarketFormBlockEntity(
          ref: 'bang',
          type: 'group',
          required: false,
          resolved: MarketFormResolvedEntity(
            code: 'bang',
            label: 'Bảng',
            inputType: 'group_table',
            groupItems: [
              {
                'ref': 'cot',
                'required': false,
                'resolved': {'code': 'cot', 'label': 'Cột', 'input_type': 'text'},
              },
            ],
          ),
        ),
      ],
    ),
  );

  Widget app(int configId, {String kind = 'collect'}) => ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(_Profile()),
      formSuggestStoreProvider.overrideWithValue(FormSuggestStore(_Api())),
    ],
    child: MaterialApp(
      home: MarketFormFillScreen(
        args: MarketFormFillArgs(config: config(configId), kind: kind),
      ),
    ),
  );

  Map<String, dynamic> answers(WidgetTester tester) =>
      tester.state<MarketFormRendererState>(find.byType(MarketFormRenderer)).currentAnswers;

  void expectFilled(WidgetTester tester) {
    final a = answers(tester);
    expect({for (final k in ['ten', 'sdt', 'ghi_chu', 'kenh']) k: a[k]}, {
      'ten': 'NPP Linh Thìn',
      'sdt': '0393938521',
      'ghi_chu': 'phiếu cũ',
      'kenh': ['A'],
    });
    final row = (a['bang'] as List).single as Map;
    expect(row['cot'], 'X');
    expect(row['line_id'], isNot('cu0000000000000a'));
    expect(row['line_id'], matches(RegExp(r'^[0-9a-f]{16}$')));
  }

  Future<void> chonGoiY(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).first, 'linh');
    await tester.pumpAndSettle();
    await tester.tap(find.text('NPP Linh Thìn'));
    await tester.pumpAndSettle();
  }

  // MỘT ca cho cả hai kịch bản: kho nháp ghi nối tiếp qua chuỗi TĨNH — chuỗi mở trong vùng thời gian giả của ca trước không
  // bao giờ xong ở ca sau (màn ca sau treo ở bước đọc nháp). Mỗi kịch bản một biểu mẫu (nháp theo biểu mẫu, không lẫn).
  testWidgets(
    'chạm gợi ý ⇒ điền cả phiếu; đã nhập ô khác ⇒ hỏi («Chỉ điền tên» giữ phần đã nhập / «Điền theo phiếu cũ» ghi đè)',
    (tester) async {
      // 1. Phiếu trống ⇒ điền ngay, không hỏi.
      await tester.pumpWidget(app(105));
      await tester.pumpAndSettle();
      await chonGoiY(tester);
      expect(find.text('Điền theo phiếu cũ?'), findsNothing);
      expectFilled(tester);
      expect(find.text('0393938521'), findsOneWidget, reason: 'ô hiện đúng giá trị đã điền');
      await tester.pump(const Duration(seconds: 5));

      // 2. Đã nhập ô khác ⇒ hỏi.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(106));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(2), 'đang gõ');
      await tester.pumpAndSettle();

      await chonGoiY(tester);
      expect(find.text('Điền theo phiếu cũ?'), findsOneWidget);
      await tester.tap(find.text('Chỉ điền tên'));
      await tester.pumpAndSettle();
      expect(answers(tester), {'ten': 'NPP Linh Thìn', 'ghi_chu': 'đang gõ'});

      await chonGoiY(tester);
      await tester.tap(find.text('Điền theo phiếu cũ'));
      await tester.pumpAndSettle();
      expectFilled(tester);
      await tester.pump(const Duration(seconds: 5));

      // 3. Phiếu khảo sát (gắn điểm bán của lượt) ⇒ chỉ điền tên, không chép phiếu cũ.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(107, kind: 'survey'));
      await tester.pumpAndSettle();
      await chonGoiY(tester);
      expect(find.text('Điền theo phiếu cũ?'), findsNothing);
      expect(answers(tester), {'ten': 'NPP Linh Thìn'});
      await tester.pump(const Duration(seconds: 5));
    },
  );
}
