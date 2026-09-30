import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/widgets/app_empty_state.dart';
import 'package:vthm_dms/core/widgets/app_error_dialog.dart';

void main() {
  group('AppEmptyState Widget Tests', () {
    testWidgets('renders icon, title, description and calls onAction callback', (tester) async {
      bool actionCalled = false;
      bool secondaryCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppEmptyState(
              icon: Icons.storefront_outlined,
              title: 'Chưa có điểm bán nào',
              description: 'Danh sách điểm bán hiện đang trống hoặc chưa được đồng bộ.',
              actionText: 'Tải lại',
              onAction: () => actionCalled = true,
              secondaryActionText: 'Thêm mới',
              onSecondaryAction: () => secondaryCalled = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
      expect(find.text('Chưa có điểm bán nào'), findsOneWidget);
      expect(
        find.text('Danh sách điểm bán hiện đang trống hoặc chưa được đồng bộ.'),
        findsOneWidget,
      );
      expect(find.text('Tải lại'), findsOneWidget);
      expect(find.text('Thêm mới'), findsOneWidget);

      await tester.tap(find.text('Tải lại'));
      await tester.pump();
      expect(actionCalled, isTrue);

      await tester.tap(find.text('Thêm mới'));
      await tester.pump();
      expect(secondaryCalled, isTrue);
    });
  });

  group('AppErrorDialog Widget Tests', () {
    testWidgets('shows popup dialog with message and triggers retry', (tester) async {
      bool retryTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  AppErrorDialog.show(
                    context,
                    title: 'Lỗi đồng bộ',
                    message: 'Không thể kết nối tới máy chủ.',
                    onRetry: () => retryTriggered = true,
                  );
                },
                child: const Text('Kích hoạt lỗi'),
              ),
            ),
          ),
        ),
      );

      // Nhấn nút kích hoạt popup
      await tester.tap(find.text('Kích hoạt lỗi'));
      await tester.pumpAndSettle();

      // Kiểm tra dialog popup xuất hiện
      expect(find.text('Lỗi đồng bộ'), findsOneWidget);
      expect(find.text('Không thể kết nối tới máy chủ.'), findsOneWidget);
      expect(find.text('Đóng'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      // Bấm nút thử lại
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(retryTriggered, isTrue);
      // Dialog đã được đóng
      expect(find.text('Lỗi đồng bộ'), findsNothing);
    });
  });
}
