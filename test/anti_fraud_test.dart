import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vthm_dms/core/services/anti_fraud_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AntiFraudService Tests', () {
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
  });
}
