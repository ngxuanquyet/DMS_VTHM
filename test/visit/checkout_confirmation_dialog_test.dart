import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/route/presentation/widgets/checkout_confirmation_dialog.dart';

void main() {
  Widget buildTestWidget({
    required String dealerName,
    required String durationText,
    required int photoCount,
    int surveyCompletedCount = 0,
    int surveyTotalCount = 0,
    bool isClosed = false,
    double? distanceMeters,
    ValueChanged<bool>? onResult,
  }) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await CheckoutConfirmationDialog.show(
                  context: context,
                  dealerName: dealerName,
                  durationText: durationText,
                  photoCount: photoCount,
                  surveyCompletedCount: surveyCompletedCount,
                  surveyTotalCount: surveyTotalCount,
                  isClosed: isClosed,
                  distanceMeters: distanceMeters,
                );
                onResult?.call(result);
              },
              child: const Text('Open Checkout Confirmation'),
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

  group('CheckoutConfirmationDialog Widget Tests', () {
    testWidgets('renders all dialog UI components accurately for normal visit', (tester) async {
      setupPhoneViewport(tester);

      await tester.pumpWidget(
        buildTestWidget(
          dealerName: 'Đại lý Minh Phát',
          durationText: '00:18:45',
          photoCount: 4,
          surveyCompletedCount: 2,
          surveyTotalCount: 2,
          distanceMeters: 35.6,
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Checkout Confirmation'));
      await tester.pumpAndSettle();

      // Check Header
      expect(find.text('Xác nhận Check-out?'), findsOneWidget);
      expect(find.text('Điểm: Đại lý Minh Phát'), findsOneWidget);
      expect(find.text('Đủ điều kiện'), findsOneWidget);

      // Check Description
      expect(
        find.text(
          'Bạn đã hoàn tất đầy đủ các điều kiện viếng thăm. Bạn có chắc chắn muốn kết thúc và check-out tại điểm bán này không?',
        ),
        findsOneWidget,
      );

      // Check Summary items
      expect(find.text('Thời gian làm việc'), findsOneWidget);
      expect(find.text('00:18:45'), findsOneWidget);

      expect(find.text('Ảnh đã chụp'), findsOneWidget);
      expect(find.text('4 ảnh (Đạt)'), findsOneWidget);

      expect(find.text('Khảo sát biểu mẫu'), findsOneWidget);
      expect(find.text('2/2 hoàn thành'), findsOneWidget);

      expect(find.text('Vị trí check-out'), findsOneWidget);
      expect(find.text('Hợp lệ (~36m)'), findsOneWidget);

      // Check Action Buttons
      expect(find.text('Ở lại'), findsOneWidget);
      expect(find.text('CHECK-OUT'), findsOneWidget);
    });

    testWidgets('renders properly for closed store visit', (tester) async {
      setupPhoneViewport(tester);

      await tester.pumpWidget(
        buildTestWidget(
          dealerName: 'Tạp hóa Hùng Loan',
          durationText: '00:05:10',
          photoCount: 1,
          isClosed: true,
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Checkout Confirmation'));
      await tester.pumpAndSettle();

      // Check closed store description
      expect(
        find.text(
          'Bạn đã ghi nhận điểm bán đóng cửa và hoàn thành ảnh xác nhận. Bạn có chắc chắn muốn kết thúc và check-out không?',
        ),
        findsOneWidget,
      );

      // Check summary indicates closed
      expect(find.text('Trạng thái'), findsOneWidget);
      expect(find.text('Đóng cửa'), findsOneWidget);
    });

    testWidgets('tapping "CHECK-OUT" button returns true', (tester) async {
      setupPhoneViewport(tester);
      bool? result;

      await tester.pumpWidget(
        buildTestWidget(
          dealerName: 'Đại lý Minh Phát',
          durationText: '00:18:45',
          photoCount: 4,
          onResult: (val) => result = val,
        ),
      );

      await tester.tap(find.text('Open Checkout Confirmation'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('CHECK-OUT'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.byType(CheckoutConfirmationDialog), findsNothing);
    });

    testWidgets('tapping "Ở lại" button returns false', (tester) async {
      setupPhoneViewport(tester);
      bool? result;

      await tester.pumpWidget(
        buildTestWidget(
          dealerName: 'Đại lý Minh Phát',
          durationText: '00:18:45',
          photoCount: 4,
          onResult: (val) => result = val,
        ),
      );

      await tester.tap(find.text('Open Checkout Confirmation'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ở lại'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.byType(CheckoutConfirmationDialog), findsNothing);
    });
  });
}
