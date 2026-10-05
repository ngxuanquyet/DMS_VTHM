import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/widgets/microphone_permission_dialog.dart';

void main() {
  testWidgets(
      'MicrophonePermissionDialog renders permissionDenied with Go to Settings and Later options (no retry button)',
      (tester) async {
    bool settingsClicked = false;
    bool dismissClicked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  MicrophonePermissionDialog.show(
                    context,
                    type: MicrophoneDialogType.permissionDenied,
                    onOpenSettings: () => settingsClicked = true,
                    onDismiss: () => dismissClicked = true,
                  );
                },
                child: const Text('Mở Dialog'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở Dialog'));
    await tester.pumpAndSettle();

    // Xác minh giao diện dialog khi quyền bị từ chối
    expect(find.text('Quyền Microphone bị từ chối'), findsOneWidget);
    expect(find.text('ĐI ĐẾN CÀI ĐẶT'), findsOneWidget);
    expect(find.text('Để sau'), findsOneWidget);
    expect(find.byIcon(Icons.mic_off_outlined), findsOneWidget);
    // Xác minh KHÔNG có nút 'Thử yêu cầu lại'
    expect(find.text('Thử yêu cầu lại'), findsNothing);

    // Bấm nút ĐI ĐẾN CÀI ĐẶT
    await tester.tap(find.text('ĐI ĐẾN CÀI ĐẶT'));
    await tester.pumpAndSettle();
    expect(settingsClicked, isTrue);

    // Mở lại dialog và bấm Để sau
    await tester.tap(find.text('Mở Dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();
    expect(dismissClicked, isTrue);
  });

  testWidgets(
      'MicrophonePermissionDialog renders permissionDeniedForever with Go to Settings option',
      (tester) async {
    bool settingsClicked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  MicrophonePermissionDialog.show(
                    context,
                    type: MicrophoneDialogType.permissionDeniedForever,
                    onOpenSettings: () => settingsClicked = true,
                  );
                },
                child: const Text('Mở Dialog Khóa'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở Dialog Khóa'));
    await tester.pumpAndSettle();

    // Xác minh giao diện dialog khi bị từ chối vĩnh viễn
    expect(find.text('Quyền Microphone bị vô hiệu hóa'), findsOneWidget);
    expect(find.text('ĐI ĐẾN CÀI ĐẶT'), findsOneWidget);
    expect(find.text('Để sau'), findsOneWidget);
    expect(find.byIcon(Icons.mic_off_rounded), findsOneWidget);
    expect(find.text('Thử yêu cầu lại'), findsNothing);

    // Bấm nút Đi đến cài đặt
    await tester.tap(find.text('ĐI ĐẾN CÀI ĐẶT'));
    await tester.pumpAndSettle();
    expect(settingsClicked, isTrue);
  });
}
