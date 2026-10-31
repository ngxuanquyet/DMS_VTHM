import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vthm_dms/core/location/location_provider.dart';
import 'package:vthm_dms/core/map/goong_models.dart';
import 'package:vthm_dms/core/map/goong_providers.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/features/attendance/domain/entities/attendance_entity.dart';
import 'package:vthm_dms/features/attendance/presentation/widgets/gps_location_card.dart';

class _FakeConnectivityNotifier extends ConnectivityNotifier {
  _FakeConnectivityNotifier(bool initial) : super() {
    state = ConnectivityState(isOnline: initial);
  }
}

class _FakeLocationNotifier extends StateNotifier<LocationState> implements LocationNotifier {
  _FakeLocationNotifier()
      : super(const LocationState(
          isServiceEnabled: true,
          permission: LocationPermission.whileInUse,
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const dummyLocation = AttendanceLocationEntity(
    address: 'Vị trí hiện tại',
    gpsAccuracy: 'Sai số: 5m',
    latitude: 21.0285,
    longitude: 105.8542,
  );

  testWidgets('GpsLocationCard renders offline placeholder with coordinates when offline', (tester) async {
    final container = ProviderContainer(
      overrides: [
        connectivityProvider.overrideWith((ref) => _FakeConnectivityNotifier(false)),
        currentPointProvider.overrideWith((ref) async => const GoongLatLng(21.02851, 105.85421)),
        locationProvider.overrideWith((ref) => _FakeLocationNotifier()),
        reverseGeocodeProvider.overrideWith((ref, point) async => null),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GpsLocationCard(location: dummyLocation),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Badge chuyển sang GPS: Ngoại tuyến
    expect(find.text('GPS: Ngoại tuyến'), findsOneWidget);

    // 2. Tiêu đề và nội dung placeholder ngoại tuyến
    expect(find.text('Định vị GPS ngoại tuyến'), findsOneWidget);
    expect(find.textContaining('21.02851, 105.85421'), findsWidgets);
    expect(find.textContaining('Bản đồ tạm ẩn khi không có kết nối mạng'), findsOneWidget);

    // 3. Nút lấy lại toạ độ GPS (My location icon)
    expect(find.byIcon(Icons.my_location), findsOneWidget);
  });

  testWidgets('GpsLocationCard renders online badge and map placeholder in test mode when online', (tester) async {
    final container = ProviderContainer(
      overrides: [
        connectivityProvider.overrideWith((ref) => _FakeConnectivityNotifier(true)),
        currentPointProvider.overrideWith((ref) async => const GoongLatLng(21.02851, 105.85421)),
        locationProvider.overrideWith((ref) => _FakeLocationNotifier()),
        reverseGeocodeProvider.overrideWith((ref, point) async => null),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GpsLocationCard(location: dummyLocation),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Badge online
    expect(find.text('GPS: ±8m'), findsOneWidget);

    // 2. Không hiện thông báo ngoại tuyến
    expect(find.text('Định vị GPS ngoại tuyến'), findsNothing);
  });
}
