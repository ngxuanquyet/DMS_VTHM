import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vthm_dms/core/rules/mobile_rules_model.dart';
import 'package:vthm_dms/core/rules/mobile_rules_service.dart';
import 'package:vthm_dms/core/services/anti_fraud_service.dart';
import 'package:vthm_dms/core/widgets/anti_fraud_warning_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AntiFraudService Tests', () {
    setUp(() {
      AntiFraudService.resetSessionWarning();
    });

    test('Normal position report is compliant', () async {
      final container = ProviderContainer();
      final service = container.read(antiFraudServiceProvider);

      final normalPos = Position(
        longitude: 105.854215,
        latitude: 21.028511,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 10.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        isMocked: false,
      );

      final report = await service.checkDeviceCompliance(position: normalPos);

      expect(report.isCompliant, isTrue);
      expect(report.hasMockGps, isFalse);
      expect(report.hasClockSkew, isFalse);
    });

    test('Mock position flags risk and sets hasMockGps = true', () async {
      final container = ProviderContainer();
      final service = container.read(antiFraudServiceProvider);

      final mockPos = Position(
        longitude: 105.854215,
        latitude: 21.028511,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 10.0,
        altitudeAccuracy: 1.0,
        heading: 0.0,
        headingAccuracy: 1.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        isMocked: true,
      );

      final report = await service.checkDeviceCompliance(position: mockPos);

      expect(report.isCompliant, isFalse);
      expect(report.hasMockGps, isTrue);
      expect(report.risks.any((r) => r.title.contains('Mock Location')), isTrue);
    });

    test('Clock skew detection calculates difference from server time', () async {
      final container = ProviderContainer();
      final service = container.read(antiFraudServiceProvider);

      // Ghi nhận mốc server time lệch 30 phút so với giờ máy
      final serverTimeSkewed = DateTime.now().subtract(const Duration(minutes: 30));
      AntiFraudService.recordServerTime(serverTimeSkewed);

      final skewMinutes = AntiFraudService.getEstimatedClockSkewMinutes();
      expect(skewMinutes >= 29 && skewMinutes <= 31, isTrue);

      final report = await service.checkDeviceCompliance();
      expect(report.hasClockSkew, isTrue);
      expect(report.isCompliant, isFalse);
      expect(report.risks.any((r) => r.title.contains('Clock Skew')), isTrue);
    });

    test('Clean server time does not trigger clock skew', () async {
      final container = ProviderContainer();
      final service = container.read(antiFraudServiceProvider);

      // Server time đồng bộ chính xác (chỉ lệch 0 giây)
      AntiFraudService.recordServerTime(DateTime.now());

      final skewMinutes = AntiFraudService.getEstimatedClockSkewMinutes();
      expect(skewMinutes.abs() < 2, isTrue);

      final report = await service.checkDeviceCompliance();
      expect(report.hasClockSkew, isFalse);
    });
  });

  group('AntiFraud Widgets & Dialog Tests', () {
    testWidgets('AntiFraudWarningDialog shows entry warning correctly', (tester) async {
      const report = ComplianceReport(
        isCompliant: false,
        hasMockGps: true,
        hasClockSkew: true,
        clockSkewMinutes: 25,
        risks: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    AntiFraudWarningDialog.showAppEntryWarning(context, report: report);
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Cảnh báo tuân thủ thiết bị'), findsOneWidget);
      expect(find.textContaining('Mock GPS'), findsOneWidget);
      expect(find.textContaining('Clock Skew'), findsOneWidget);
      expect(find.text('ĐÃ HIỂU & TIẾP TỤC'), findsOneWidget);

      await tester.ensureVisible(find.text('ĐÃ HIỂU & TIẾP TỤC'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ĐÃ HIỂU & TIẾP TỤC'));
      await tester.pumpAndSettle();

      expect(find.text('Cảnh báo tuân thủ thiết bị'), findsNothing);
    });

    testWidgets('AntiFraudWarningDialog shows blocked action correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    AntiFraudWarningDialog.showActionBlocked(
                      context,
                      actionTitle: 'Chấm công',
                      reason: 'Phát hiện Fake GPS',
                      resolution: 'Hãy tắt Mock Location',
                    );
                  },
                  child: const Text('Show Blocked'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Blocked'));
      await tester.pumpAndSettle();

      expect(find.text('Từ chối Chấm công'), findsOneWidget);
      expect(find.text('Phát hiện Fake GPS'), findsOneWidget);
      expect(find.text('Hãy tắt Mock Location'), findsOneWidget);
      expect(find.text('ĐÃ HIỂU'), findsOneWidget);

      await tester.tap(find.text('ĐÃ HIỂU'));
      await tester.pumpAndSettle();

      expect(find.text('Từ chối Chấm công'), findsNothing);
    });
  });
}
