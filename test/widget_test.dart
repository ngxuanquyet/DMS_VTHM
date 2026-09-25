import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:vthm_dms/core/widgets/app_loading.dart';
import 'package:vthm_dms/core/widgets/bottom_nav_bar.dart';
import 'package:vthm_dms/core/widgets/top_app_bar.dart';
import 'package:vthm_dms/core/widgets/voice_input_mic_button.dart';
import 'package:vthm_dms/features/auth/domain/entities/user_entity.dart';
import 'package:vthm_dms/features/customer/data/repositories/customer_repository_impl.dart';
import 'package:vthm_dms/features/customer/presentation/screens/add_customer_screen.dart';
import 'package:vthm_dms/features/customer/presentation/screens/customer_screen.dart';
import 'package:vthm_dms/features/customer/presentation/widgets/customer_card.dart';
import 'package:vthm_dms/features/customer/presentation/widgets/customer_circular_menu.dart';
import 'package:vthm_dms/features/forms/domain/entities/form_entity.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';
import 'package:vthm_dms/features/route/presentation/screens/check_in_screen.dart';
import 'package:vthm_dms/features/route/presentation/screens/route_screen.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';
import 'package:vthm_dms/features/route/presentation/widgets/checkout_success_dialog.dart';
import 'package:vthm_dms/features/route/presentation/widgets/route_circular_menu.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/customer/presentation/viewmodels/customer_view_model.dart';
import 'package:vthm_dms/main.dart';

class _ScrollMockCustomerViewModel extends StateNotifier<CustomerState> implements CustomerViewModel {
  _ScrollMockCustomerViewModel()
      : super(
          CustomerState(
            isLoading: false,
            allCustomers: List.generate(
              25,
              (i) => CustomerEntity(
                id: i + 1,
                code: 'KH00$i',
                name: 'Đại lý $i',
                type: 'Đại lý',
                route: 'Tuyến 1',
                address: '$i Đường Lê Lợi',
                contactPerson: 'Anh $i',
                phone: '098765432$i',
                status: 'active',
              ),
            ),
          ),
        );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('VthmApp renders and pumps splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: VthmApp(),
      ),
    );

    expect(find.byType(VthmApp), findsOneWidget);
    // Allow splash timer to complete
    await tester.pump(const Duration(seconds: 3));
  });

  test('UserEntity initializes correctly', () {
    const user = UserEntity(
      id: '2461',
      username: 'VTG926',
      employeeCode: 'VTG926',
      displayName: 'Nguyễn Xuân Quyết',
      jobTitle: 'Nhân viên Quản lý Hệ thống thông tin (MIS)',
      avatarUrl: AppConstants.userAvatarUrl,
      email: 'quyetnx@vthmgroup.vn',
    );

    expect(user.name, 'Nguyễn Xuân Quyết');
    expect(user.employeeId, 'VTG926');
    expect(user.username, 'VTG926');
    expect(user.displayName, 'Nguyễn Xuân Quyết');
  });

  test('FormItemEntity initializes correctly', () {
    const form = FormItemEntity(
      id: 'FORM-01',
      title: 'Khảo sát điểm bán',
      dealerName: 'Đại lý Thành Công',
      deadline: '17:00',
      status: FormStatusType.todo,
      statusLabel: 'Chưa thực hiện',
      questionsCount: 8,
      answeredCount: 0,
      progressPercent: 0.0,
    );

    expect(form.questionsCount, 8);
    expect(form.status, FormStatusType.todo);
  });

  testWidgets('RouteCircularMenu renders and toggles properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: RouteCircularMenu(
                    onSortByDistance: () {},
                    onSync: () {},
                    onSendOfflineData: () {},
                    onAddCustomer: () {},
                    onRefreshGps: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(RouteCircularMenu), findsOneWidget);
    // Tap the trigger FAB to expand
    await tester.tap(find.byIcon(Icons.widgets_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Check that items are shown
    expect(find.text('Thêm điểm bán'), findsOneWidget);
    expect(find.text('Gửi dữ liệu'), findsOneWidget);
    expect(find.text('Đồng bộ tuyến'), findsOneWidget);
    expect(find.text('Sắp xếp cự ly'), findsOneWidget);
    expect(find.text('Định vị GPS'), findsOneWidget);

    // Tap backdrop to close
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.widgets_rounded), findsOneWidget);

    // Reopen and tap an item callback
    bool sortClicked = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: RouteCircularMenu(
                    onSortByDistance: () => sortClicked = true,
                    onSync: () {},
                    onSendOfflineData: () {},
                    onAddCustomer: () {},
                    onRefreshGps: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.widgets_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Sắp xếp cự ly'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(sortClicked, isTrue);
  });

  testWidgets('CustomerScreen renders floating circular menu and expands options', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CustomerScreen(),
        ),
      ),
    );

    await tester.pump();
    expect(find.byIcon(Icons.widgets_rounded), findsOneWidget);

    // Mở menu tròn
    await tester.tap(find.byIcon(Icons.widgets_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Kiểm tra đủ 5 options text
    expect(find.text('Thêm mới khách hàng'), findsOneWidget);
    expect(find.text('Tải lên'), findsOneWidget);
    expect(
        find.descendant(
          of: find.byType(CustomerCircularMenu),
          matching: find.textContaining(RegExp(r'đồng bộ', caseSensitive: false)),
        ),
        findsOneWidget);
    expect(find.text('Sắp xếp theo khoảng cách'), findsOneWidget);
    expect(find.text('Định vị'), findsOneWidget);

    // Kiểm tra 5 icons tương ứng của 5 option
    expect(find.byIcon(Icons.person_add_alt_1_rounded), findsOneWidget);
    expect(find.byIcon(Icons.cloud_upload_rounded), findsOneWidget);
    expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
    expect(find.byIcon(Icons.near_me_rounded), findsOneWidget);
    expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
  });

  testWidgets('CustomerScreen renders VthmTopAppBar and omits header add button and dot', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CustomerScreen(),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(VthmTopAppBar), findsOneWidget);
    // Add button in header removed (only accessible via floating circular menu)
    expect(find.text('Thêm'), findsNothing);
    expect(find.text('Thêm khách hàng'), findsNothing);
  });

  testWidgets('RouteScreen renders header card with Tuyến and search bar matching customer template', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RouteScreen(),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Tuyến'), findsOneWidget);
    expect(find.text('Tìm điểm bán, mã KH, SĐT trên tuyến...'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('CustomerScreen hides title on scroll, leaving search field', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerViewModelProvider.overrideWith((ref) => _ScrollMockCustomerViewModel()),
        ],
        child: const MaterialApp(
          home: CustomerScreen(),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Khách hàng'), findsOneWidget);

    // Initial opacity is 1.0
    final initialOpacityFinder = find.descendant(
      of: find.byType(ClipRect),
      matching: find.byType(Opacity),
    );
    expect((tester.widget(initialOpacityFinder.first) as Opacity).opacity, 1.0);

    // Drag list upwards by 100 pixels
    await tester.drag(find.byType(ListView).first, const Offset(0, -100));
    await tester.pump();

    // After scrolling, title opacity collapses to 0.0, but search field remains visible
    expect((tester.widget(initialOpacityFinder.first) as Opacity).opacity, 0.0);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('VthmBottomNavBar renders CurvedNavigationBar with 5 items', (WidgetTester tester) async {
    int tappedIndex = -1;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: VthmBottomNavBar(
              currentIndex: 0,
              onTap: (index) => tappedIndex = index,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CurvedNavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsWidgets);
    expect(find.byIcon(Icons.storefront_rounded), findsWidgets);
    expect(find.byIcon(Icons.alt_route_rounded), findsWidgets);
    expect(find.byIcon(Icons.assignment_rounded), findsWidgets);
    expect(find.byIcon(Icons.person_rounded), findsWidgets);

    // Tap on customers tab
    await tester.tap(find.byIcon(Icons.storefront_rounded));
    await tester.pump();
    expect(tappedIndex, 1);
  });

  testWidgets('AppLoading renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppLoading(size: 60),
          ),
        ),
      ),
    );

    expect(find.byType(AppLoading), findsOneWidget);
  });

  testWidgets('CheckoutSuccessDialog renders dealer name and dismisses on confirm', (WidgetTester tester) async {
    bool confirmed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                CheckoutSuccessDialog.show(
                  context,
                  dealerName: 'Đại lý Test VTHM',
                  onConfirm: () => confirmed = true,
                );
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Check-out thành công!'), findsOneWidget);
    expect(find.text('Đại lý Test VTHM'), findsOneWidget);
    expect(find.text('HOÀN TẤT'), findsOneWidget);

    await tester.tap(find.text('HOÀN TẤT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(confirmed, isTrue);
    expect(find.text('Check-out thành công!'), findsNothing);
  });

  testWidgets('VoiceInputMicButton quick tap shows guidance snackbar', (WidgetTester tester) async {
    String? recognized;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: VoiceInputMicButton(
              onTextRecognized: (val) => recognized = val,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(VoiceInputMicButton), findsOneWidget);

    // Quick tap
    await tester.tap(find.byType(VoiceInputMicButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Must show guidance SnackBar
    expect(
      find.text('Nhấn và giữ biểu tượng mic để nói, thả tay ra khi nói xong.'),
      findsOneWidget,
    );
    expect(recognized, isNull);
  });

  testWidgets('VoiceInputMicButton long press shows floating recording HUD overlay and dismisses on release', (WidgetTester tester) async {
    String? recognized;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: VoiceInputMicButton(
              fieldName: 'Tên điểm bán',
              onTextRecognized: (val) => recognized = val,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(VoiceInputMicButton), findsOneWidget);

    // Long press start
    final gesture = await tester.startGesture(tester.getCenter(find.byType(VoiceInputMicButton)));
    await tester.pump(const Duration(milliseconds: 600));

    // Must show floating HUD overlay with REC badge and field name
    expect(find.text('REC ĐANG GHI ÂM'), findsOneWidget);
    expect(find.text('Nhập: Tên điểm bán'), findsOneWidget);
    expect(find.text('Thả tay ra để điền văn bản'), findsOneWidget);

    // Release gesture
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 600));

    // HUD should be dismissed
    expect(find.text('REC ĐANG GHI ÂM'), findsNothing);
    expect(recognized, isNull);
  });

  testWidgets('CustomerCard removes border when showBorder is false', (WidgetTester tester) async {
    final dealer = DealerEntity(
      id: '1',
      name: 'Điểm bán số 1',
      code: 'DB001',
      address: '123 Đường Test',
      phone: '0901234567',
      order: '1',
      status: DealerVisitStatus.inProgress,
      statusLabel: 'Đang ghé',
      isVip: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerCard.fromDealer(
            dealer: dealer,
            showBorder: false,
          ),
        ),
      ),
    );

    final containerFinder = find.byType(Container).first;
    final container = tester.widget<Container>(containerFinder);
    final decoration = container.decoration as BoxDecoration;

    expect(decoration.border, isNull);
  });

  testWidgets('CustomerCircularMenu closes automatically on tab switch signal', (WidgetTester tester) async {
    final container = ProviderContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: CustomerCircularMenu(
                    onAddCustomer: () {},
                    onSync: () {},
                    onSendOfflineData: () {},
                    onRefreshGps: () {},
                    onSortByDistance: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Open menu
    await tester.tap(find.byIcon(Icons.widgets_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Thêm mới khách hàng'), findsOneWidget);

    // Trigger tab switch event
    container.read(closeFloatingMenuProvider.notifier).state++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Menu should now be closed
    expect(find.byIcon(Icons.widgets_rounded), findsOneWidget);
    expect(find.text('Thêm mới khách hàng'), findsNothing);
  });

  testWidgets('RouteCircularMenu closes automatically on tab switch signal', (WidgetTester tester) async {
    final container = ProviderContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: RouteCircularMenu(
                    onSortByDistance: () {},
                    onSync: () {},
                    onSendOfflineData: () {},
                    onAddCustomer: () {},
                    onRefreshGps: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Open menu
    await tester.tap(find.byIcon(Icons.widgets_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Thêm điểm bán'), findsOneWidget);

    // Trigger tab switch event
    container.read(closeFloatingMenuProvider.notifier).state++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Menu should now be closed
    expect(find.byIcon(Icons.widgets_rounded), findsOneWidget);
    expect(find.text('Thêm điểm bán'), findsNothing);
  });

  testWidgets('CustomerCircularMenu closes when TickerMode becomes disabled and stays closed on return', (WidgetTester tester) async {
    final tickerNotifier = ValueNotifier<bool>(true);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: tickerNotifier,
              builder: (context, enabled, child) {
                return TickerMode(
                  enabled: enabled,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomerCircularMenu(
                          onAddCustomer: () {},
                          onSync: () {},
                          onSendOfflineData: () {},
                          onRefreshGps: () {},
                          onSortByDistance: () {},
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    // Open menu
    await tester.tap(find.byIcon(Icons.widgets_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Thêm mới khách hàng'), findsOneWidget);

    // Switch away (TickerMode disabled)
    tickerNotifier.value = false;
    await tester.pump();

    // Switch back (TickerMode re-enabled)
    tickerNotifier.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Must remain closed!
    expect(find.byIcon(Icons.widgets_rounded), findsOneWidget);
    expect(find.text('Thêm mới khách hàng'), findsNothing);
  });

  testWidgets('CheckInScreen exits immediately when nothing has been written', (WidgetTester tester) async {
    const dealer = DealerEntity(
      id: 'D01',
      name: 'Đại lý Test',
      code: 'DL01',
      address: '123 Đường Test',
      phone: '0901234567',
      order: '1',
      status: DealerVisitStatus.pending,
      statusLabel: 'Chưa ghé',
      isVip: false,
    );

    final container = ProviderContainer();
    try {
      container.read(checkInViewModelProvider.notifier).initCheckinWithDealer(dealer);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: CheckInScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Đại lý Test'), findsOneWidget);
      expect(find.text('Hủy check-in'), findsOneWidget);

      // Tap "Hủy check-in" button when nothing has been written
      await tester.tap(find.text('Hủy check-in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Must NOT show warning popup
      expect(find.text('Bạn có ghi chú/thông tin chưa lưu. Bạn có chắc chắn muốn thoát khỏi phiên check-in này không? Dữ liệu bạn vừa nhập sẽ bị mất.'), findsNothing);
    } finally {
      container.dispose();
    }
  });

  testWidgets('CheckInScreen shows warning dialog when note is entered and user taps exit', (WidgetTester tester) async {
    const dealer = DealerEntity(
      id: 'D01',
      name: 'Đại lý Test',
      code: 'DL01',
      address: '123 Đường Test',
      phone: '0901234567',
      order: '1',
      status: DealerVisitStatus.pending,
      statusLabel: 'Chưa ghé',
      isVip: false,
    );

    final container = ProviderContainer();
    try {
      container.read(checkInViewModelProvider.notifier).initCheckinWithDealer(dealer);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: CheckInScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Đại lý Test'), findsOneWidget);

      // Open note dialog and enter note
      await tester.tap(find.text('Ghi chú chuyến ghé'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('LƯU GHI CHÚ'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Khách muốn nhập thêm hàng tuần tới');
      await tester.tap(find.text('LƯU GHI CHÚ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Now user taps "Hủy check-in"
      await tester.tap(find.text('Hủy check-in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // MUST show warning dialog
      expect(find.text('Hủy check-in?'), findsOneWidget);
      expect(find.text('Bạn có ghi chú/thông tin chưa lưu. Bạn có chắc chắn muốn thoát khỏi phiên check-in này không? Dữ liệu bạn vừa nhập sẽ bị mất.'), findsOneWidget);
    } finally {
      container.dispose();
    }
  });

  testWidgets('AddCustomerScreen exits immediately when form is empty', (tester) async {
    final container = ProviderContainer(
      overrides: [
        customerFormSchemaProvider.overrideWith((ref) async => {
          'status': 'success',
          'data': {
            'form': {'name': 'Hồ sơ điểm bán'},
            'version': '1.0',
            'fields': [
              {
                'code': 'name',
                'label': 'Tên điểm bán',
                'type': 'text',
                'is_required': true,
                'section': 'Thông tin chung',
              }
            ],
          }
        }),
        customerMetaProvider.overrideWith((ref) async => kDefaultCustomerMeta),
      ],
    );

    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AddCustomerScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Thêm mới điểm bán'), findsOneWidget);
      expect(find.text('HỦY BỎ'), findsOneWidget);

      // Tap HỦY BỎ when nothing typed
      await tester.tap(find.text('HỦY BỎ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // No warning dialog
      expect(find.text('Rời khỏi màn hình?'), findsNothing);
    } finally {
      container.dispose();
    }
  });

  testWidgets('AddCustomerScreen shows warning dialog when data is entered and user taps HỦY BỎ', (tester) async {
    final container = ProviderContainer(
      overrides: [
        customerFormSchemaProvider.overrideWith((ref) async => {
          'status': 'success',
          'data': {
            'form': {'name': 'Hồ sơ điểm bán'},
            'version': '1.0',
            'fields': [
              {
                'code': 'name',
                'label': 'Tên điểm bán',
                'type': 'text',
                'is_required': true,
                'section': 'Thông tin chung',
              }
            ],
          }
        }),
        customerMetaProvider.overrideWith((ref) async => kDefaultCustomerMeta),
      ],
    );

    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AddCustomerScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Thêm mới điểm bán'), findsOneWidget);

      // Enter text into the first textfield
      await tester.enterText(find.byType(TextField).first, 'Tạp hóa Bình Minh');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap HỦY BỎ
      await tester.tap(find.text('HỦY BỎ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // MUST show warning dialog
      expect(find.text('Rời khỏi màn hình?'), findsOneWidget);
      expect(find.text('Dữ liệu điểm bán bạn đang nhập chưa được lưu. Nếu thoát ra, các thông tin đã nhập sẽ bị mất.'), findsOneWidget);
    } finally {
      container.dispose();
    }
  });
}


