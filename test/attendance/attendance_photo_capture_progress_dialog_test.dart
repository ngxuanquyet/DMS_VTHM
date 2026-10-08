import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/widgets/app_button.dart';
import 'package:vthm_dms/features/attendance/presentation/widgets/attendance_photo_capture_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kiểm tra dialog gửi lượt chấm công: Thay Lottie bằng Thanh tiến trình loader', () {
    testWidgets('1. AppButton khi loading sử dụng CircularProgressIndicator và không dùng Lottie', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              text: 'Gửi chấm công',
              isLoading: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      // Tuyệt đối không chứa bất kỳ Lottie animation nào
      expect(find.byType(Lottie), findsNothing);
      // Sử dụng CircularProgressIndicator chuẩn
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('2. AttendancePhotoCaptureDialog hiển thị giao diện ban đầu và không dùng Lottie', (tester) async {
      SharedPreferences.setMockInitialValues({});

      final dummyPosition = Position(
        latitude: 21.028511,
        longitude: 105.854444,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 10.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 1.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AttendancePhotoCaptureDialog(
                position: dummyPosition,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề và nút
      expect(find.text('Chụp ảnh xác thực chấm công'), findsOneWidget);
      expect(find.text('Gửi chấm công'), findsOneWidget);
      expect(find.text('Hủy bỏ'), findsOneWidget);

      // Tuyệt đối không chứa bất kỳ Lottie animation nào trong dialog
      expect(find.byType(Lottie), findsNothing);
    });
  });
}
