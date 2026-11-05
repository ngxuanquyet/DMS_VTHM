import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/features/attendance/data/models/attendance_model.dart';
import 'package:vthm_dms/features/attendance/domain/entities/attendance_entity.dart';
import 'package:vthm_dms/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:vthm_dms/features/attendance/domain/usecases/attendance_usecases.dart';
import 'package:vthm_dms/features/attendance/presentation/viewmodels/attendance_view_model.dart';

/// Địa điểm người dùng CHỌN được gửi lên server khi chấm (05/11/2026: ANV chọn văn phòng vẫn bị ghi "Mọi nơi" vì app
/// không gửi lựa chọn). Địa điểm app TỰ chọn theo khoảng cách thì không gửi — server tự dò.

/// Kho giả: ghi lại `geofenceId` của mỗi lượt chấm.
class _Repo implements AttendanceRepository {
  final sent = <int?>[];

  @override
  Future<AttendanceConfigEntity> getConfig({double? lat, double? lng}) async => const AttendanceConfigEntity(
        canPunch: true,
        group: AttendanceGroupEntity(code: 'G', name: 'G', enforceGeofence: true),
        photo: AttendancePhotoConfigEntity(minPhotos: 0, maxPhotos: 2),
        locations: [
          AttendanceLocationItemEntity(id: 1, code: 'VP', name: 'Văn phòng', radiusM: 200, distanceM: 45),
          AttendanceLocationItemEntity(id: 3, code: 'EV', name: 'Mọi nơi', kind: 'everywhere'),
        ],
      );

  @override
  Future<AttendancePunchEntity> punch({
    required double lat,
    required double lng,
    double? accuracyM,
    bool? isMockLocation,
    String? clientUuid,
    int? geofenceId,
  }) async {
    sent.add(geofenceId);
    return AttendancePunchEntity(
      id: sent.length,
      punchAt: '2026-11-05T16:25:00+07:00',
      clientUuid: clientUuid ?? '',
      lat: lat,
      lng: lng,
      requirements: const AttendanceRequirementsEntity(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Position _pos() => Position(
      latitude: 21.39498,
      longitude: 105.59322,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  late _Repo repo;
  late AttendanceViewModel vm;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = _Repo();
    vm = AttendanceViewModel(
      getConfigUseCase: GetAttendanceConfigUseCase(repo),
      punchUseCase: PunchAttendanceUseCase(repo),
      uploadPhotoUseCase: UploadPunchPhotoUseCase(repo),
      getHistoryUseCase: GetAttendanceHistoryUseCase(repo),
      getAttendanceDetailUseCase: GetAttendanceDetailUseCase(repo),
      attendanceRepository: repo,
    );
    await Future<void>.delayed(Duration.zero);
    final config = await repo.getConfig();
    // ignore: invalid_use_of_protected_member
    vm.state = vm.state.copyWith(config: config, selectedLocation: config.closestLocation);
  });

  test('người dùng TỰ chọn địa điểm ⇒ gửi id địa điểm đó', () async {
    vm.selectLocation(vm.state.config!.locations.first);
    await vm.punch(position: _pos(), addToHistory: false);
    expect(repo.sent, [1], reason: 'lỗi cũ: app không gửi lựa chọn ⇒ server ghi "Mọi nơi"');
  });

  test('địa điểm app TỰ chọn theo khoảng cách ⇒ không gửi, để server tự dò', () async {
    expect(vm.state.locationPickedByUser, isFalse);
    await vm.punch(position: _pos(), addToHistory: false);
    expect(repo.sent, [null]);
  });

  test('payload gửi lên (kể cả hàng đợi ngoại tuyến) mang geofence_id', () {
    const req = AttendancePunchRequestModel(clientUuid: 'u', lat: 1, lng: 2, geofenceId: 7);
    expect(req.toJson()['geofence_id'], 7);
    expect(const AttendancePunchRequestModel(clientUuid: 'u', lat: 1, lng: 2).toJson().containsKey('geofence_id'), isFalse);
  });
}
