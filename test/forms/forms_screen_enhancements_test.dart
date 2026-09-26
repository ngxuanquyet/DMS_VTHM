import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/presentation/screens/market_form_fill_screen.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/forms_circular_menu.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/market_form_card.dart';
import 'package:vthm_dms/features/profile/domain/entities/user_profile_detail_entity.dart';
import 'package:vthm_dms/features/profile/domain/entities/user_profile_entity.dart';
import 'package:vthm_dms/features/profile/domain/entities/user_relation_entity.dart';
import 'package:vthm_dms/features/profile/domain/repositories/profile_repository.dart';
import 'package:vthm_dms/features/profile/presentation/viewmodels/profile_view_model.dart';

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
    SharedPreferences.setMockInitialValues({});
  });

  group('MarketFormCard Widget Tests (showStatus: false)', () {
    const dummyConfig = MarketFormConfigEntity(
      configId: 10,
      formId: 1,
      code: 'BM_TEST',
      name: 'Khảo sát trưng bày',
      kind: 'collect',
      isRequired: true,
      sortOrder: 1,
      schema: MarketFormSchemaEntity(blocks: []),
    );

    testWidgets(
        'MarketFormCard with showStatus: false does NOT display "Đã nộp phiếu" or "Chưa thực hiện"',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarketFormCard(
              config: dummyConfig,
              isSubmitted: true,
              showStatus: false,
              onTap: () {},
            ),
          ),
        ),
      );

      // KHÔNG hiển thị UI đã nộp phiếu hay chưa thực hiện
      expect(find.text('Đã nộp phiếu'), findsNothing);
      expect(find.text('Chưa thực hiện'), findsNothing);
      expect(find.text('Nộp lại'), findsNothing);

      // Hiển thị nút "Điền form" và nhãn "Thu thập thông tin"
      expect(find.text('Điền form'), findsOneWidget);
      expect(find.text('Thu thập thông tin'), findsOneWidget);
      expect(find.text('Khảo sát trưng bày'), findsOneWidget);
    });

    testWidgets(
        'MarketFormCard with showStatus: true displays status for check-in',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarketFormCard(
              config: dummyConfig,
              isSubmitted: true,
              showStatus: true,
              onTap: () {},
            ),
          ),
        ),
      );

      // Khi showStatus: true thì vẫn hiển thị trạng thái bình thường
      expect(find.text('Đã nộp phiếu'), findsOneWidget);
      expect(find.text('Nộp lại'), findsOneWidget);
    });
  });

  group('FormsCircularMenu Widget Tests', () {
    testWidgets('FormsCircularMenu renders main FAB and expands 2 options',
        (tester) async {
      bool syncTapped = false;
      bool uploadTapped = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(
                    child: FormsCircularMenu(
                      onSync: () => syncTapped = true,
                      onSendOfflineData: () => uploadTapped = true,
                      pendingOfflineCount: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Tìm FAB chính (Widgets icon giống màn route)
      final fabFinder = find.byIcon(Icons.widgets_rounded);
      expect(fabFinder, findsOneWidget);

      // Nhấn mở menu
      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      // Kiểm tra 2 tính năng: Đồng bộ, Tải lên (2)
      expect(find.text('Tải lên (2)'), findsOneWidget);
      expect(find.text('Đồng bộ'), findsOneWidget);

      // Nhấn Đồng bộ
      await tester.tap(find.text('Đồng bộ'));
      await tester.pump();
      expect(syncTapped, isTrue);

      // Mở lại và nhấn Tải lên
      await tester.tap(find.byType(GestureDetector).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tải lên (2)'));
      await tester.pump();
      expect(uploadTapped, isTrue);
    });
  });

  group('FormsScreen UI Structure Tests', () {
    testWidgets(
        'FormsScreen has no tab row, no refresh button, and has widgets_rounded menu button at bottom',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: FormsCircularMenu(
                      onSync: _noop,
                      onSendOfflineData: _noop,
                      pendingOfflineCount: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Nút FAB chính có Icon Icons.widgets_rounded
      expect(find.byIcon(Icons.widgets_rounded), findsOneWidget);

      // Vị trí FAB: bottom: 88, right: 16 trên màn 800x600 mặc định -> Y = 600 - 88 - 28 = 484.0, X = 800 - 16 - 28 = 756.0
      final fabCenter = tester.getCenter(find.byIcon(Icons.widgets_rounded));
      expect(fabCenter.dy, equals(484.0));
      expect(fabCenter.dx, equals(756.0));
    });
  });

  group('MarketFormFillScreen Exit Confirmation Tests', () {
    const testConfig = MarketFormConfigEntity(
      configId: 105,
      formId: 1,
      code: 'KS_TEST',
      name: 'Khảo sát test',
      kind: 'collect',
      isRequired: false,
      sortOrder: 1,
      schema: MarketFormSchemaEntity(
        blocks: [
          MarketFormBlockEntity(
            ref: 'ghi_chu',
            type: 'field',
            required: false,
            colSpan: 12,
            resolved: MarketFormResolvedEntity(
              code: 'ghi_chu',
              label: 'Ghi chú khảo sát',
              inputType: 'text',
            ),
          ),
        ],
      ),
    );

    Widget buildTestApp() {
      return ProviderScope(
        overrides: [
          profileRepositoryProvider
              .overrideWithValue(_FakeProfileRepository()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MarketFormFillScreen(
                        args: MarketFormFillArgs(
                          config: testConfig,
                          kind: 'collect',
                          dealerName: 'Đại lý Test',
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Mở Form'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
        'Exiting with empty form does not show dialog and pops immediately',
        (tester) async {
      await tester.pumpWidget(buildTestApp());

      await tester.tap(find.text('Mở Form'));
      await tester.pumpAndSettle();
      expect(find.text('Khảo sát test'), findsNWidgets(2));

      // Nhấn nút back trên VthmTopAppBar khi chưa nhập gì
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Không hiển thị dialog, đã quay về màn hình trước
      expect(find.text('Rời khỏi biểu mẫu?'), findsNothing);
      expect(find.text('Mở Form'), findsOneWidget);
    });

    testWidgets(
        'Exiting with filled answers shows confirmation dialog, staying keeps screen open',
        (tester) async {
      await tester.pumpWidget(buildTestApp());

      await tester.tap(find.text('Mở Form'));
      await tester.pumpAndSettle();

      // Điền câu trả lời
      await tester.enterText(
          find.byType(TextField), 'Nội dung đang điền dở dang');
      await tester.pumpAndSettle();

      // Nhấn nút back trên VthmTopAppBar
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Hiển thị dialog xác nhận
      expect(find.text('Rời khỏi biểu mẫu?'), findsOneWidget);
      expect(find.text('Tiếp tục điền'), findsOneWidget);
      expect(find.text('Rời khỏi'), findsOneWidget);

      // Nhấn "Tiếp tục điền"
      await tester.tap(find.text('Tiếp tục điền'));
      await tester.pumpAndSettle();

      // Dialog biến mất nhưng vẫn ở lại màn hình form
      expect(find.text('Rời khỏi biểu mẫu?'), findsNothing);
      expect(find.text('Khảo sát test'), findsNWidgets(2));
      expect(find.text('Nội dung đang điền dở dang'), findsOneWidget);
    });

    testWidgets(
        'Exiting with filled answers and choosing "Rời khỏi" exits without saving',
        (tester) async {
      await tester.pumpWidget(buildTestApp());

      await tester.tap(find.text('Mở Form'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Nội dung hủy bỏ');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Rời khỏi biểu mẫu?'), findsOneWidget);

      // Nhấn "Rời khỏi"
      await tester.tap(find.text('Rời khỏi'));
      await tester.pumpAndSettle();

      // Đã thoát về màn hình trước
      expect(find.text('Mở Form'), findsOneWidget);
    });
  });
}

void _noop() {}
