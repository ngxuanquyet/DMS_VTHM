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
  Duration delay = Duration.zero;
  double accuracy = 5;
  Duration fixAge = Duration.zero;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    currentCalls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (error != null) throw error!;
    return Position(
      latitude: 21.03,
      longitude: 105.85,
      timestamp: DateTime.now().subtract(fixAge),
      accuracy: accuracy,
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

  test('nhiều nơi cùng gọi ⇒ dùng chung MỘT lượt GPS; xong rồi gọi lại thì lấy lượt mới', () async {
    fake.delay = const Duration(milliseconds: 20);
    final results = await Future.wait([
      service.getFreshPosition(),
      service.getFreshPosition(),
      service.getFreshPosition(),
    ]);
    expect(results.every((p) => p?.latitude == 21.03), isTrue);
    expect(fake.currentCalls, 1);

    // Gọi lại sau khi lượt trước xong — không treo, không trả lượt cũ.
    final again = await service.getFreshPosition().timeout(const Duration(seconds: 2));
    expect(again?.latitude, 21.03);
    expect(fake.currentCalls, 2);
  });

  group('getRecentOrFreshPosition — bấm Chấm công dùng lại vị trí vừa lấy (09/11/2026)', () {
    test('vị trí mới lấy còn trong hạn và đủ chính xác ⇒ trả ngay, KHÔNG bật GPS lần hai', () async {
      await service.getFreshPosition();
      expect(fake.currentCalls, 1);

      final reused = await service.getRecentOrFreshPosition(
        maxAge: const Duration(seconds: 30),
        maxAccuracyM: 50,
      );
      expect(reused?.latitude, 21.03);
      expect(fake.currentCalls, 1, reason: 'không được bắt GPS lại');
    });

    test('sai số lớn hơn ngưỡng ⇒ bắt GPS mới', () async {
      fake.accuracy = 80;
      await service.getFreshPosition();
      fake.accuracy = 10;

      final pos = await service.getRecentOrFreshPosition(
        maxAge: const Duration(seconds: 30),
        maxAccuracyM: 50,
      );
      expect(pos?.accuracy, 10);
      expect(fake.currentCalls, 2);
    });

    test('đang có lượt lấy mới chạy dở ⇒ chờ lượt đó thay vì trả bản cũ', () async {
      await service.getFreshPosition(); // bản cũ 21.03
      fake.delay = const Duration(milliseconds: 30);
      final inflight = service.getFreshPosition();
      final viaReuse = service.getRecentOrFreshPosition(maxAge: const Duration(seconds: 30), maxAccuracyM: 50);
      expect(identical(inflight, viaReuse), isTrue);
      await Future.wait([inflight, viaReuse]);
      expect(fake.currentCalls, 2);
    });

    test('fix hệ điều hành trả sẵn đã cũ (timestamp quá hạn) ⇒ không dùng lại', () async {
      fake.fixAge = const Duration(minutes: 3);
      await service.getFreshPosition();
      fake.fixAge = Duration.zero;
      await service.getRecentOrFreshPosition(maxAge: const Duration(seconds: 30), maxAccuracyM: 50);
      expect(fake.currentCalls, 2);
    });

    test('accuracy = 0 (máy không biết sai số) ⇒ không coi là chính xác, bắt GPS mới', () async {
      fake.accuracy = 0;
      await service.getFreshPosition();
      fake.accuracy = 5;
      await service.getRecentOrFreshPosition(maxAge: const Duration(seconds: 30), maxAccuracyM: 50);
      expect(fake.currentCalls, 2);
    });

    test('maxAge = 0 (tham số tắt) ⇒ luôn bắt GPS mới', () async {
      await service.getFreshPosition();
      await service.getRecentOrFreshPosition(maxAge: Duration.zero, maxAccuracyM: 50);
      expect(fake.currentCalls, 2);
    });

    test('chưa từng lấy vị trí mới (chỉ có cache của checkAndGetLocation) ⇒ bắt GPS mới', () async {
      LocationService.updateCachedPosition(Position(
        latitude: 1,
        longitude: 1,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ));
      final pos = await service.getRecentOrFreshPosition(
        maxAge: const Duration(seconds: 30),
        maxAccuracyM: 50,
      );
      expect(pos?.latitude, 21.03, reason: 'không dùng cache hệ thống — có thể từ hàng giờ trước');
      expect(fake.currentCalls, 1);
    });
  });
}
