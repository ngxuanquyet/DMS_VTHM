import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/errors/app_exceptions.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:vthm_dms/features/attendance/data/services/attendance_api_service.dart';
import 'package:vthm_dms/features/attendance/domain/usecases/attendance_usecases.dart';
import 'package:vthm_dms/features/attendance/presentation/viewmodels/attendance_view_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';

class MockAttendanceApiClient extends ApiClient {
  MockAttendanceApiClient() : super(Dio());

  Map<String, dynamic>? nextConfigResponse;
  Map<String, dynamic>? nextPunchResponse;
  Map<String, dynamic>? nextPhotoResponse;
  Map<String, dynamic>? nextHistoryResponse;
  Exception? errorToThrow;

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters, dynamic options}) async {
    if (errorToThrow != null) throw errorToThrow!;
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
          'locations': [
            {
              'id': 6,
              'code': 'TESTCC-DOC1',
              'name': '[TEST-CC] Văn phòng tài liệu mobile',
              'lat': 21.0277644,
              'lng': 105.8341598,
              'radius_m': 200,
              'distance_m': 44,
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
            'id': 8723,
            'punch_at': '2026-10-05 13:30:19+07',
            'client_uuid': '11111111-2222-4333-8444-555555550003',
            'lat': 21.028,
            'lng': 105.8345,
            'accuracy_m': 12.5,
            'geofence_id': 6,
            'geofence_name': '[TEST-CC] Văn phòng tài liệu mobile',
            'is_outside_geofence': false,
            'is_mock_location': false,
            'is_time_tampered': false,
            'photos': [
              {
                'id': 9,
                'file_id': 15647,
                'token': 'bb27eae9a0bd2a724e62067a8bfe6577',
                'url': '/attendance/punch-photos/public/bb27eae9a0bd2a724e62067a8bfe6577',
                'photo_type': 'front',
                'photo_type_label': 'Ảnh chân dung',
                'photo_type_color': 'primary',
                'taken_at': '2026-10-05 13:30:25+07',
                'sort_order': 0,
              },
              {
                'id': 10,
                'file_id': 15648,
                'token': 'cc38fbf0b1ce3b835f73178b9c0ef688',
                'url': '/attendance/punch-photos/public/cc38fbf0b1ce3b835f73178b9c0ef688',
                'photo_type': 'back',
                'photo_type_label': 'Ảnh khung cảnh',
                'photo_type_color': 'secondary',
                'taken_at': '2026-10-05 13:30:35+07',
                'sort_order': 1,
              }
            ],
            'requirements': {
              'photo_count': 2,
              'min_photos': 2,
              'max_photos': 10,
              'need_front': false,
              'need_back': false,
              'require_both': true,
              'satisfied': true,
            },
          }
        ],
      };
    }
    return {};
  }

  @override
  Future<dynamic> post(String path, {dynamic data, Map<String, dynamic>? queryParameters, dynamic options}) async {
    if (errorToThrow != null) throw errorToThrow!;
    if (path.contains('/attendance/mobile/punch')) {
      return nextPunchResponse ?? {
        'success': true,
        'message': 'Đã ghi nhận chấm công lúc 13:30.',
        'data': {
          'id': 8723,
          'punch_at': '2026-10-05 13:30:19+07',
          'client_uuid': data is Map ? data['client_uuid'] : 'test-uuid',
          'lat': 21.028,
          'lng': 105.8345,
          'accuracy_m': 12.5,
          'geofence_id': 6,
          'geofence_name': '[TEST-CC] Văn phòng tài liệu mobile',
          'is_outside_geofence': false,
          'is_mock_location': false,
          'is_time_tampered': false,
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

  group('Kiểm tra tích hợp API Chấm Công Mobile theo SPEC 2026-10-05', () {
    late MockAttendanceApiClient mockClient;
    late AttendanceApiService apiService;
    late AttendanceRepositoryImpl repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockClient = MockAttendanceApiClient();
      apiService = AttendanceApiService(mockClient);
      repository = AttendanceRepositoryImpl(apiService);
    });

    test('1. GET /attendance/mobile/config — vẽ màn hình và kiểm tra cấu hình địa điểm', () async {
      final config = await repository.getConfig(lat: 21.028, lng: 105.8345);

      expect(config.canPunch, isTrue);
      expect(config.blockedReason, isNull);
      expect(config.group.code, 'MARKET');
      expect(config.group.enforceGeofence, isTrue);
      expect(config.photo.minPhotos, 2);
      expect(config.photo.maxPhotos, 10);
      expect(config.photo.requireBoth, isTrue);

      expect(config.locations.length, 1);
      final loc = config.locations.first;
      expect(loc.id, 6);
      expect(loc.code, 'TESTCC-DOC1');
      expect(loc.radiusM, 200);
      expect(loc.distanceM, 44);
      expect(loc.isWithinRadius, isTrue);
      expect(config.isWithinAnyGeofence(), isTrue);
    });

    test('2. GET /attendance/mobile/config — chặn khi tài khoản chưa có mã nhân viên (§1.2)', () async {
      mockClient.nextConfigResponse = {
        'success': true,
        'message': 'Thành công',
        'data': {
          'can_punch': false,
          'blocked_reason': 'Tài khoản của bạn chưa có mã nhân viên — liên hệ nhân sự để chấm công được.',
          'group': {'code': 'MARKET', 'name': 'Khối thị trường', 'enforce_geofence': true},
          'photo': {'min_photos': 2, 'max_photos': 10, 'require_both': true},
          'locations': [],
        },
      };

      final config = await repository.getConfig();
      expect(config.canPunch, isFalse);
      expect(config.blockedReason, contains('chưa có mã nhân viên'));
      expect(config.locations, isEmpty);
    });

    test('3. POST /attendance/mobile/punch — chấm công thành công trả về punch_id và requirements', () async {
      final punch = await repository.punch(
        lat: 21.028,
        lng: 105.8345,
        accuracyM: 12.5,
      );

      expect(punch.id, 8723);
      expect(punch.timeFormatted, '13:30');
      expect(punch.duplicate, isFalse);
      expect(punch.requirements.satisfied, isFalse);
      expect(punch.requirements.needFront, isTrue);
      expect(punch.requirements.needBack, isTrue);
      expect(punch.requirements.minPhotos, 2);
    });

    test('4. POST /attendance/mobile/punch — xử lý gửi trùng cùng UUID trả duplicate: true (§3.2)', () async {
      mockClient.nextPunchResponse = {
        'success': true,
        'message': 'Lượt chấm này đã được ghi nhận trước đó.',
        'data': {
          'id': 8723,
          'punch_at': '2026-10-05 13:30:19+07',
          'client_uuid': 'duplicate-uuid',
          'lat': 21.028,
          'lng': 105.8345,
          'accuracy_m': 12.5,
          'geofence_id': 6,
          'geofence_name': '[TEST-CC] Văn phòng tài liệu mobile',
          'is_outside_geofence': false,
          'is_mock_location': false,
          'is_time_tampered': false,
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
          'duplicate': true,
        },
      };

      final punch = await repository.punch(
        lat: 21.028,
        lng: 105.8345,
        clientUuid: 'duplicate-uuid',
      );

      expect(punch.duplicate, isTrue);
      expect(punch.id, 8723);
    });

    test('5. POST /attendance/mobile/punch — lỗi 422 ngoài vùng ném ra ServerException nguyên văn tiếng Việt (§3.1)', () async {
      mockClient.errorToThrow = const ServerException(
        'Bạn đang cách [TEST-CC] Văn phòng tài liệu mobile khoảng 5956m. Hãy tới gần hơn rồi chấm công.',
        422,
      );

      expect(
        () => repository.punch(lat: 21.08, lng: 105.9),
        throwsA(isA<ServerException>().having(
          (e) => e.message,
          'message',
          contains('khoảng 5956m'),
        )),
      );
    });

    test('6. GET /attendance/mobile/history — đọc lịch sử và tạo link ảnh chuẩn', () async {
      final history = await repository.getHistory(days: 7);

      expect(history.length, 1);
      final item = history.first;
      expect(item.id, 8723);
      expect(item.timeFormatted, '13:30');
      expect(item.requirements.satisfied, isTrue);
      expect(item.photos.length, 2);

      final front = item.frontPhoto;
      expect(front, isNotNull);
      expect(front!.photoType, 'front');
      expect(front.getFullUrl('https://api-app.vthmgroup.vn'),
          'https://api-app.vthmgroup.vn/attendance/punch-photos/public/bb27eae9a0bd2a724e62067a8bfe6577');

      final back = item.backPhoto;
      expect(back, isNotNull);
      expect(back!.photoType, 'back');
    });

    test('7. GET /attendance/mobile/history — an toàn khi geofence_name bị null do địa điểm đã bị xoá (§5)', () async {
      mockClient.nextHistoryResponse = {
        'success': true,
        'message': 'Thành công',
        'data': [
          {
            'id': 8720,
            'punch_at': '2026-10-04 08:15:00+07',
            'client_uuid': 'uuid-old',
            'lat': 21.028,
            'lng': 105.8345,
            'geofence_id': 999,
            'geofence_name': null,
            'is_outside_geofence': false,
            'is_mock_location': false,
            'is_time_tampered': false,
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
          }
        ],
      };

      final history = await repository.getHistory(days: 7);
      expect(history.first.geofenceName, isNull);
      expect(history.first.timeFormatted, '08:15');
    });

    test('8. AttendanceViewModel.submitPunchWithPhotos — chỉ lưu lịch sử khi gửi lượt chấm công thật thành công', () async {
      final vm = AttendanceViewModel(
        getConfigUseCase: GetAttendanceConfigUseCase(repository),
        punchUseCase: PunchAttendanceUseCase(repository),
        uploadPhotoUseCase: UploadPunchPhotoUseCase(repository),
        getHistoryUseCase: GetAttendanceHistoryUseCase(repository),
        getAttendanceDetailUseCase: GetAttendanceDetailUseCase(repository),
        toggleAttendanceUseCase: ToggleAttendanceUseCase(repository),
      );

      // Ban đầu chưa có lượt nào trong lịch sử
      expect(vm.state.history, isEmpty);

      // Khi server từ chối (ví dụ 422 ngoài vùng), lịch sử KHÔNG ĐƯỢC thêm lượt nào
      mockClient.errorToThrow = const ServerException('Bạn đang cách địa điểm 5000m.', 422);
      final dummyPos = Position(
        latitude: 21.028,
        longitude: 105.8345,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      final failed = await vm.submitPunchWithPhotos(position: dummyPos);
      expect(failed, isFalse);
      expect(vm.state.history, isEmpty);
      expect(vm.state.errorMessage, contains('Bạn đang cách địa điểm 5000m.'));

      // Khi server trả thành công
      mockClient.errorToThrow = null;
      mockClient.nextHistoryResponse = {
        'success': true,
        'message': 'Thành công',
        'data': [
          {
            'id': 8725,
            'punch_at': '2026-10-05 16:30:00+07',
            'client_uuid': 'uuid-new-real',
            'lat': 21.028,
            'lng': 105.8345,
            'geofence_id': 6,
            'geofence_name': '[TEST-CC] Văn phòng tài liệu mobile',
            'is_outside_geofence': false,
            'is_mock_location': false,
            'is_time_tampered': false,
            'photos': [
              {
                'id': 1,
                'file_id': 100,
                'token': 'tok1',
                'url': '/url1',
                'photo_type': 'front',
                'photo_type_label': 'Ảnh chân dung',
                'photo_type_color': 'primary',
                'taken_at': '2026-10-05 16:30:10+07',
                'sort_order': 0,
              }
            ],
            'requirements': {
              'photo_count': 1,
              'min_photos': 2,
              'max_photos': 10,
              'need_front': false,
              'need_back': true,
              'require_both': true,
              'satisfied': false,
            },
          }
        ],
      };

      final success = await vm.submitPunchWithPhotos(position: dummyPos);
      expect(success, isTrue);
      expect(vm.state.history.length, 1);
      expect(vm.state.history.first.id, 8725);
    });
  });
}
