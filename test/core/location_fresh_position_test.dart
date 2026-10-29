import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
// ignore: depend_on_referenced_packages
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:vthm_dms/core/services/location_service.dart';

/// Màn Tuyến / chấm công cần vị trí MỚI (29/10/2026) — `checkAndGetLocation` trả bản cache có thể từ hàng giờ trước.
class _FakeGeolocator extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  Object? error;
  int currentCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    currentCalls++;
    if (error != null) throw error!;
    return Position(
      latitude: 21.03,
      longitude: 105.85,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

void main() {
  late _FakeGeolocator fake;
  late LocationService service;

  setUp(() {
    fake = _FakeGeolocator();
    GeolocatorPlatform.instance = fake;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    service = container.read(locationServiceProvider);
  });

  test('lấy vị trí MỚI từ GPS và cập nhật cache cho màn khác', () async {
    final pos = await service.getFreshPosition();
    expect(pos?.latitude, 21.03);
    expect(fake.currentCalls, 1);
    expect(LocationService.currentCachedPosition?.latitude, 21.03);
  });

  test('tắt GPS / chưa cấp quyền / lỗi hoặc quá giờ ⇒ null, không ném lỗi', () async {
    fake.serviceEnabled = false;
    expect(await service.getFreshPosition(), isNull);

    fake
      ..serviceEnabled = true
      ..permission = LocationPermission.denied;
    expect(await service.getFreshPosition(), isNull);

    fake
      ..permission = LocationPermission.always
      ..error = Exception('timeout');
    expect(await service.getFreshPosition(), isNull);
  });
}
