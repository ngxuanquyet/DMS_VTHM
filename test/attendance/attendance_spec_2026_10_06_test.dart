import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:vthm_dms/features/attendance/data/services/attendance_api_service.dart';
import 'package:vthm_dms/features/attendance/domain/entities/attendance_entity.dart';
import 'package:vthm_dms/features/attendance/presentation/states/attendance_state.dart';
import 'package:dio/dio.dart';

class MockAttendanceApiClient20261006 extends ApiClient {
  MockAttendanceApiClient20261006() : super(Dio());

  Map<String, dynamic>? nextConfigResponse;
  Map<String, dynamic>? nextPunchResponse;
  Map<String, dynamic>? nextHistoryResponse;

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters, dynamic options}) async {
    if (path.contains('/attendance/mobile/config')) {
      return nextConfigResponse ?? {
        'success': true,
        'message': 'Thành công',
        'data': {
          'can_punch': true,
          'blocked_reason': null,
          'group': {
            'code': 'MARKET',
            'name': 'Khối thị trường',
            'enforce_geofence': true,
          },
          'photo': {
            'min_photos': 2,
            'max_photos': 10,
            'require_both': true,
          },
          'today': {
            'work_date': '2026-10-06',
            'punch_count': 3,
            'first_in_at': '2026-10-06 08:55:40+07',
            'last_out_at': '2026-10-06 17:30:00+07',
            'next_action': 'out',
            'next_action_label': 'Ra',
          },
          'locations': [
            {
              'id': 16,
              'code': 'MARKET-ANY',
              'name': 'Thị trường – mọi nơi',
              'kind': 'everywhere',
              'kind_label': 'Mọi nơi',
              'lat': null,
              'lng': null,
              'radius_m': null,
              'distance_m': null,
            }
          ],
        },
      };
    }
    if (path.contains('/attendance/mobile/history')) {
      return nextHistoryResponse ?? {
        'success': true,
        'message': 'Thành công',
        'data': [
          {
            'id': 8730,
            'punch_at': '2026-10-06 17:30:00+07',
            'client_uuid': 'uuid-out',
            'lat': null,
            'lng': null,
            'direction': 'out',
            'direction_label': 'Ra',
            'photos': [],
            'requirements': {
              'photo_count': 0,
              'min_photos': 2,
              'max_photos': 10,
              'need_front': true,
              'need_back': true,
              'require_both': true,
              'satisfied': false,
            },
          },
          {
            'id': 8728,
            'punch_at': '2026-10-06 08:55:40+07',
            'client_uuid': 'uuid-in',
            'lat': null,
            'lng': null,
            'direction': 'in',
            'direction_label': 'Vào',
            'photos': [],
            'requirements': {
              'photo_count': 0,
              'min_photos': 2,
              'max_photos': 10,
              'need_front': true,
              'need_back': true,
              'require_both': true,
              'satisfied': false,
            },
          },
        ],
      };
    }
    return {};
  }

  @override
  Future<dynamic> post(String path, {dynamic data, Map<String, dynamic>? queryParameters, dynamic options}) async {
    if (path.contains('/attendance/mobile/punch')) {
      return nextPunchResponse ?? {
        'success': true,
        'message': 'Đã ghi nhận chấm công lúc 17:30.',
        'data': {
          'id': 8732,
          'punch_at': '2026-10-06 17:30:15+07',
          'client_uuid': data is Map ? data['client_uuid'] : 'test-uuid',
          'lat': 21.028,
          'lng': 105.8345,
          'direction': 'out',
          'direction_label': 'Ra',
          'photos': [],
          'requirements': {
            'photo_count': 0,
            'min_photos': 2,
            'max_photos': 10,
            'need_front': true,
            'need_back': true,
            'require_both': true,
            'satisfied': false,
          },
          'duplicate': false,
        },
      };
    }
    return {};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kiểm tra tích hợp thay đổi API Chấm Công Mobile SPEC 2026-10-06', () {
    late MockAttendanceApiClient20261006 mockClient;
    late AttendanceApiService apiService;
    late AttendanceRepositoryImpl repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockClient = MockAttendanceApiClient20261006();
      apiService = AttendanceApiService(mockClient);
      repository = AttendanceRepositoryImpl(apiService);
    });

    test('1. Địa điểm kiểu "everywhere" chịu được null ở lat/lng/radius_m/distance_m và không bị chặn geofence', () async {
      final config = await repository.getConfig();

      expect(config.locations.length, 1);
      final loc = config.locations.first;
      expect(loc.kind, 'everywhere');
      expect(loc.kindLabel, 'Mọi nơi');
      expect(loc.lat, isNull);
      expect(loc.lng, isNull);
      expect(loc.radiusM, isNull);
      expect(loc.distanceM, isNull);
      expect(loc.isEverywhere, isTrue);
      expect(loc.isWithinRadius, isTrue);

      // Bất biến: Danh sách có everywhere thì isWithinAnyGeofence luôn trả về true
      expect(config.isWithinAnyGeofence(), isTrue);

      final state = AttendanceState(config: config);
      expect(state.isWithinGeofence, isTrue);
      expect(state.isBlockedByGeofence, isFalse);
    });

    test('2. Khối today từ GET /attendance/mobile/config chứa trạng thái ca và nhãn nút tiếp theo', () async {
      final config = await repository.getConfig();

      expect(config.today, isNotNull);
      final today = config.today!;
      expect(today.workDate, '2026-10-06');
      expect(today.punchCount, 3);
      expect(today.firstInAt, '2026-10-06 08:55:40+07');
      expect(today.lastOutAt, '2026-10-06 17:30:00+07');
      expect(today.firstInTimeFormatted, '08:55');
      expect(today.lastOutTimeFormatted, '17:30');
      expect(today.nextAction, 'out');
      expect(today.nextActionLabel, 'Ra');
    });

    test('3. POST punch và GET history trả về direction và direction_label ("in", "out")', () async {
      final punch = await repository.punch(
        lat: 21.028,
        lng: 105.8345,
      );

      expect(punch.id, 8732);
      expect(punch.direction, 'out');
      expect(punch.directionLabel, 'Ra');

      final history = await repository.getHistory(days: 7);
      expect(history.length, 2);
      expect(history[0].direction, 'out');
      expect(history[0].directionLabel, 'Ra');
      expect(history[1].direction, 'in');
      expect(history[1].directionLabel, 'Vào');
    });

    test('4. Cách ly cache config theo từng tài khoản (không nhớ đệm qua nhiều user trên cùng máy)', () async {
      final prefs = await SharedPreferences.getInstance();

      // Giả lập user A đang đăng nhập
      await prefs.setString(AppConstants.keyUserData, jsonEncode({'id': 1001, 'username': 'USER_A'}));

      mockClient.nextConfigResponse = {
        'success': true,
        'message': 'OK A',
        'data': {
          'can_punch': true,
          'blocked_reason': null,
          'group': {'code': 'MARKET_A', 'name': 'Nhóm A', 'enforce_geofence': true},
          'photo': {'min_photos': 2, 'max_photos': 10, 'require_both': true},
          'locations': [
            {'id': 1, 'code': 'LOC_A', 'name': 'Văn phòng A', 'kind': 'radius', 'lat': 21.0, 'lng': 105.0, 'radius_m': 200, 'distance_m': 50}
          ],
        },
      };

      final configA = await repository.getConfig();
      expect(configA.group.code, 'MARKET_A');

      // Giả lập đăng xuất user A và user B đăng nhập
      await prefs.setString(AppConstants.keyUserData, jsonEncode({'id': 2002, 'username': 'USER_B'}));

      mockClient.nextConfigResponse = {
        'success': true,
        'message': 'OK B',
        'data': {
          'can_punch': true,
          'blocked_reason': null,
          'group': {'code': 'MARKET_B', 'name': 'Nhóm B', 'enforce_geofence': true},
          'photo': {'min_photos': 2, 'max_photos': 10, 'require_both': true},
          'locations': [
            {'id': 16, 'code': 'MARKET-ANY', 'name': 'Thị trường mọi nơi', 'kind': 'everywhere', 'lat': null, 'lng': null, 'radius_m': null, 'distance_m': null}
          ],
        },
      };

      final configB = await repository.getConfig();
      expect(configB.group.code, 'MARKET_B');
      expect(configB.locations.first.kind, 'everywhere');
    });

    test('5. User có thể chọn địa điểm chấm công linh hoạt từ danh sách, không bị fix cứng', () async {
      const loc1 = AttendanceLocationItemEntity(
        id: 101,
        code: 'VP_HN',
        name: 'Văn phòng Hà Nội',
        kind: 'radius',
        lat: 21.0285,
        lng: 105.8542,
        radiusM: 100,
        distanceM: 50, // trong bán kính
      );
      const loc2 = AttendanceLocationItemEntity(
        id: 102,
        code: 'NM_VP',
        name: 'Nhà máy Vĩnh Phúc',
        kind: 'radius',
        lat: 21.3951,
        lng: 105.5928,
        radiusM: 200,
        distanceM: 35000, // ngoài bán kính
      );
      const loc3 = AttendanceLocationItemEntity(
        id: 103,
        code: 'MARKET_ANY',
        name: 'Mọi nơi',
        kind: 'everywhere',
        kindLabel: 'Mọi nơi',
      );

      final config = AttendanceConfigEntity(
        canPunch: true,
        group: const AttendanceGroupEntity(code: 'TECH', name: 'Kỹ thuật', enforceGeofence: true),
        photo: const AttendancePhotoConfigEntity(),
        locations: [loc1, loc2, loc3],
      );

      var state = AttendanceState(
        status: AttendanceStatus.loaded,
        config: config,
      );

      // Mặc định ban đầu chọn địa điểm gần nhất (loc1)
      expect(state.activeLocation?.id, loc1.id);
      expect(state.isWithinGeofence, isTrue);
      expect(state.isBlockedByGeofence, isFalse);

      // User chủ động đổi sang Nhà máy Vĩnh Phúc (loc2)
      state = state.copyWith(selectedLocation: loc2);
      expect(state.activeLocation?.id, loc2.id);
      expect(state.activeLocation?.name, 'Nhà máy Vĩnh Phúc');
      expect(state.isWithinGeofence, isFalse);
      expect(state.isBlockedByGeofence, isTrue); // Bị chặn do ngoài bán kính loc2

      // User chủ động đổi sang Mọi nơi (loc3)
      state = state.copyWith(selectedLocation: loc3);
      expect(state.activeLocation?.id, loc3.id);
      expect(state.isWithinGeofence, isTrue);
      expect(state.isBlockedByGeofence, isFalse);
    });
  });
}
