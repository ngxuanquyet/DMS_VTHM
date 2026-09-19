import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:vthm_dms/core/widgets/app_loading.dart';
import 'package:vthm_dms/core/widgets/bottom_nav_bar.dart';
import 'package:vthm_dms/core/widgets/voice_input_mic_button.dart';
import 'package:vthm_dms/features/auth/domain/entities/user_entity.dart';
import 'package:vthm_dms/features/customer/presentation/screens/customer_screen.dart';
import 'package:vthm_dms/features/forms/domain/entities/form_entity.dart';
import 'package:vthm_dms/features/route/presentation/widgets/checkout_success_dialog.dart';
import 'package:vthm_dms/features/route/presentation/widgets/route_circular_menu.dart';
import 'package:vthm_dms/main.dart';

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
      MaterialApp(
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
      MaterialApp(
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
    );
    await tester.tap(find.byIcon(Icons.widgets_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Sắp xếp cự ly'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(sortClicked, isTrue);
  });

  testWidgets('CustomerScreen renders floating sync button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CustomerScreen(),
        ),
      ),
    );

    await tester.pump();
    expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
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
}


