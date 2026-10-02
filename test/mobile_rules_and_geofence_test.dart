import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/rules/mobile_rules_model.dart';
import 'package:vthm_dms/core/utils/image_upload_helper.dart';
import 'package:vthm_dms/features/forms/data/models/route_customer_model.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';

void main() {
  group('MobileRules Specification Tests (GET /dms/mobile-rules - §1)', () {
    test('Parses backend response correctly with all thresholds and units', () {
      final json = {
        "visit": {
          "require_geofence": true,
          "default_radius_m": 100,
          "block_on_mock_location": false,
          "min_duration_minutes": 5,
          "min_photos": 2,
          "closed_min_photos": 1,
          "route_scope": "assigned",
          "auto_close_after_hours": 12,
        },
        "position": {"min_photos": 1, "block_on_mock_location": false},
        "clock": {"skew_tolerance_minutes": 15, "offline_max_queue_hours": 24},
      };

      final rules = MobileRules.fromJson(json);

      expect(rules.visit.requireGeofence, isTrue);
      expect(rules.visit.defaultRadiusM, 100);
      expect(rules.visit.blockOnMockLocation, isFalse);
      expect(rules.visit.minDurationMinutes, 5);
      expect(rules.visit.minPhotos, 2);
      expect(rules.visit.closedMinPhotos, 1);
      expect(rules.visit.routeScope, 'assigned');
      expect(rules.visit.autoCloseAfterHours, 12);

      expect(rules.position.minPhotos, 1);
      expect(rules.position.blockOnMockLocation, isFalse);

      expect(rules.clock.skewToleranceMinutes, 15);
      expect(rules.clock.offlineMaxQueueHours, 24);
    });

    test('Provides fallback defaults matching spec when keys are missing or offline', () {
      const rules = MobileRules();

      expect(rules.visit.requireGeofence, isTrue);
      expect(rules.visit.defaultRadiusM, 100);
      expect(rules.visit.minDurationMinutes, 5);
      expect(rules.visit.minPhotos, 2);
      expect(rules.visit.closedMinPhotos, 1);
      expect(rules.position.minPhotos, 1);
      expect(rules.clock.skewToleranceMinutes, 15);
      expect(rules.clock.offlineMaxQueueHours, 24);
    });

    test('Serializes to JSON correctly for local persistence', () {
      const rules = MobileRules();
      final json = rules.toJson();

      expect(json['visit']['default_radius_m'], 100);
      expect(json['position']['min_photos'], 1);
      expect(json['clock']['offline_max_queue_hours'], 24);

      final restored = MobileRules.fromJson(json);
      expect(restored.visit.defaultRadiusM, 100);
      expect(restored.visit.requireGeofence, isTrue);
    });
  });

  group('RouteCustomerItem Specification Tests (GET /dms/routes/customers - §2)', () {
    test('Parses lat, lng (strings) and geofence_radius_m from backend response', () {
      final json = {
        "id": 2348,
        "code": "08180024",
        "name": "Đại Việt",
        "address": "Quầy thuốc Đỗ Dung, Mỹ Hưng, Mỹ Lộc, Nam Định",
        "lat": "20.4427685",
        "lng": "106.1307546",
        "geofence_radius_m": null,
      };

      final item = RouteCustomerItem.fromJson(json);

      expect(item.id, 2348);
      expect(item.code, "08180024");
      expect(item.name, "Đại Việt");
      expect(item.lat, closeTo(20.4427685, 0.000001));
      expect(item.lng, closeTo(106.1307546, 0.000001));
      expect(item.geofenceRadiusM, isNull);
    });

    test('Parses custom geofence_radius_m when defined', () {
      final json = {
        "id": 8338,
        "code": "08150022",
        "name": "Tạp hóa Lan",
        "lat": "21.3093",
        "lng": "105.6049",
        "geofence_radius_m": 150,
      };

      final item = RouteCustomerItem.fromJson(json);
      expect(item.geofenceRadiusM, 150);
    });
  });

  group('Geofence Distance & Button Dimming Logic (§2)', () {
    const rules = MobileRules(
      visit: VisitRules(
        requireGeofence: true,
        defaultRadiusM: 100,
      ),
    );

    test('Uses custom geofenceRadiusM if provided, otherwise defaultRadiusM', () {
      const dealerWithCustom = DealerEntity(
        id: '1',
        order: '01',
        name: 'Đại lý A',
        address: 'Hà Nội',
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
        lat: 21.0,
        lng: 105.0,
        geofenceRadiusM: 150,
      );

      const dealerWithDefault = DealerEntity(
        id: '2',
        order: '02',
        name: 'Đại lý B',
        address: 'Hà Nội',
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
        lat: 21.0,
        lng: 105.0,
        geofenceRadiusM: null,
      );

      final radiusA = dealerWithCustom.geofenceRadiusM ?? rules.visit.defaultRadiusM;
      final radiusB = dealerWithDefault.geofenceRadiusM ?? rules.visit.defaultRadiusM;

      expect(radiusA, 150);
      expect(radiusB, 100);
    });

    test('Never blocks when lat/lng is null (§2: server luôn cho qua, app cũng cho qua)', () {
      const dealerWithoutCoords = DealerEntity(
        id: '3',
        order: '03',
        name: 'Đại lý C',
        address: 'Hà Nội',
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
        lat: null,
        lng: null,
      );

      final bool hasCoords = dealerWithoutCoords.lat != null && dealerWithoutCoords.lng != null;
      final bool isOutOfGeofence = hasCoords && rules.visit.requireGeofence;

      expect(isOutOfGeofence, isFalse, reason: 'Chưa có toạ độ thì không được chặn');
    });

    test('Correctly computes out-of-geofence warning message when distance exceeds radius', () {
      const dealer = DealerEntity(
        id: '4',
        order: '04',
        name: 'Đại lý D',
        address: 'Nam Định',
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
        lat: 20.44,
        lng: 106.13,
      );

      final allowedRadius = dealer.geofenceRadiusM ?? rules.visit.defaultRadiusM;
      const distance = 165.4;

      final isOutOfGeofence = rules.visit.requireGeofence && distance > allowedRadius;
      expect(isOutOfGeofence, isTrue);

      final warningMsg = 'Bạn đang cách cửa hàng ${distance.round()} m, cần vào trong $allowedRadius m';
      expect(warningMsg, 'Bạn đang cách cửa hàng 165 m, cần vào trong 100 m');
    });

    test('Does not flag out-of-geofence if requireGeofence is disabled', () {
      const laxRules = MobileRules(
        visit: VisitRules(requireGeofence: false, defaultRadiusM: 100),
      );

      const distance = 300.0;
      final isOutOfGeofence = laxRules.visit.requireGeofence && distance > laxRules.visit.defaultRadiusM;
      expect(isOutOfGeofence, isFalse);
    });
  });

  group('ImageUploadHelper Specification Tests (§1.1 & §3)', () {
    test('Allowed extensions contains jpg, jpeg, png, gif, webp, bmp but excludes heic/heif', () {
      expect(ImageUploadHelper.hasValidExtension('photo.jpg'), isTrue);
      expect(ImageUploadHelper.hasValidExtension('photo.jpeg'), isTrue);
      expect(ImageUploadHelper.hasValidExtension('photo.png'), isTrue);
      expect(ImageUploadHelper.hasValidExtension('photo.webp'), isTrue);
      expect(ImageUploadHelper.hasValidExtension('photo.heic'), isFalse);
      expect(ImageUploadHelper.hasValidExtension('photo.HEIF'), isFalse);
      expect(ImageUploadHelper.hasValidExtension('document.pdf'), isFalse);
    });

    test('getValidFileName normalizes extension to jpg if missing or not allowed', () {
      expect(ImageUploadHelper.getValidFileName('image.heic'), 'image.jpg');
      expect(ImageUploadHelper.getValidFileName('image.HEIC'), 'image.jpg');
      expect(ImageUploadHelper.getValidFileName('capture_123'), 'capture_123.jpg');
      expect(ImageUploadHelper.getValidFileName('photo.png'), 'photo.png');
      expect(ImageUploadHelper.getValidFileName('photo.jpg'), 'photo.jpg');
    });

    test('maxFileSizeBytes is exactly 10 MB (10240 KB)', () {
      expect(ImageUploadHelper.maxFileSizeBytes, 10 * 1024 * 1024);
    });
  });
}
