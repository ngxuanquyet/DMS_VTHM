import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/route/presentation/widgets/visit_exit_options_dialog.dart';

void main() {
  Widget buildTestWidget({required String dealerName, ValueChanged<String?>? onResult}) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await VisitExitOptionsDialog.show(
                  context: context,
                  dealerName: dealerName,
                );
                onResult?.call(result);
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );
  }

  void setupPhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('VisitExitOptionsDialog Widget Tests', () {
    testWidgets('renders all dialog UI components accurately', (tester) async {
      setupPhoneViewport(tester);

      await tester.pumpWidget(buildTestWidget(dealerName: 'testttt1244'));

      // Open the dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Check header
      expect(find.text('Tạm rời điểm bán?'), findsOneWidget);
      expect(find.text('Điểm: testttt1244'), findsOneWidget);
      expect(find.text('Đang tiến hành'), findsOneWidget);

      // Check description
      expect(
        find.text('Bạn đang có một lượt viếng thăm chưa hoàn tất. Vui lòng chọn cách xử lý:'),
        findsOneWidget,
      );

      // Check option cards
      expect(find.text('1. Tạm rời'), findsOneWidget);
      expect(
        find.text('Lưu trạng thái viếng thăm. Có thể tiếp tục bất kỳ lúc nào mà không tạo lượt mới.'),
        findsOneWidget,
      );

      expect(find.text('2. Ở lại'), findsOneWidget);
      expect(
        find.text('Đóng thông báo và tiếp tục làm việc tại điểm bán này.'),
        findsOneWidget,
      );

      expect(find.text('3. Hủy lượt'), findsOneWidget);
      expect(
        find.text('Hủy hoàn toàn lượt check-in hiện tại. Dữ liệu chưa lưu sẽ bị xóa.'),
        findsOneWidget,
      );

      // Check bottom action buttons
      expect(find.text('Ở lại'), findsOneWidget);
      expect(find.text('TẠM RỜI'), findsOneWidget);
      expect(find.text('HỦY LƯỢT CHECK-IN'), findsOneWidget);
    });

    testWidgets('tapping "TẠM RỜI" button returns "pause"', (tester) async {
      setupPhoneViewport(tester);
      String? result;
      await tester.pumpWidget(
        buildTestWidget(
          dealerName: 'testttt1244',
          onResult: (val) => result = val,
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('TẠM RỜI'));
      await tester.pumpAndSettle();

      expect(result, 'pause');
      expect(find.byType(VisitExitOptionsDialog), findsNothing);
    });

    testWidgets('tapping card "1. Tạm rời" returns "pause"', (tester) async {
      setupPhoneViewport(tester);
      String? result;
      await tester.pumpWidget(
        buildTestWidget(
          dealerName: 'testttt1244',
          onResult: (val) => result = val,
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('1. Tạm rời'));
      await tester.pumpAndSettle();

      expect(result, 'pause');
      expect(find.byType(VisitExitOptionsDialog), findsNothing);
    });

    testWidgets('tapping "Ở lại" button returns "stay"', (tester) async {
      setupPhoneViewport(tester);
      String? result;
      await tester.pumpWidget(
        buildTestWidget(
          dealerName: 'testttt1244',
          onResult: (val) => result = val,
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ở lại'));
      await tester.pumpAndSettle();

      expect(result, 'stay');
      expect(find.byType(VisitExitOptionsDialog), findsNothing);
    });

    testWidgets('tapping card "2. Ở lại" returns "stay"', (tester) async {
      setupPhoneViewport(tester);
      String? result;
      await tester.pumpWidget(
        buildTestWidget(
          dealerName: 'testttt1244',
          onResult: (val) => result = val,
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('2. Ở lại'));
      await tester.pumpAndSettle();

      expect(result, 'stay');
      expect(find.byType(VisitExitOptionsDialog), findsNothing);
    });

    testWidgets('tapping "HỦY LƯỢT CHECK-IN" button returns "cancel"', (tester) async {
      setupPhoneViewport(tester);
      String? result;
      await tester.pumpWidget(
        buildTestWidget(
          dealerName: 'testttt1244',
          onResult: (val) => result = val,
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('HỦY LƯỢT CHECK-IN'));
      await tester.pumpAndSettle();

      expect(result, 'cancel');
      expect(find.byType(VisitExitOptionsDialog), findsNothing);
    });

    testWidgets('tapping card "3. Hủy lượt" returns "cancel"', (tester) async {
      setupPhoneViewport(tester);
      String? result;
      await tester.pumpWidget(
        buildTestWidget(
          dealerName: 'testttt1244',
          onResult: (val) => result = val,
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('3. Hủy lượt'));
      await tester.pumpAndSettle();

      expect(result, 'cancel');
      expect(find.byType(VisitExitOptionsDialog), findsNothing);
    });
  });
}
