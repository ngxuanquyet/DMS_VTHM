import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/utils/geo.dart';
import 'package:vthm_dms/features/attendance/data/models/attendance_model.dart';
import 'package:vthm_dms/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:vthm_dms/features/attendance/data/services/attendance_api_service.dart';
import 'package:vthm_dms/features/attendance/domain/entities/attendance_entity.dart';
import 'package:vthm_dms/features/attendance/domain/usecases/attendance_usecases.dart';
import 'package:vthm_dms/features/attendance/presentation/viewmodels/attendance_view_model.dart';

/// Bấm "Chấm công" mất ~3s (09/11/2026): GPS bắt lại + một vòng gọi `config`. Khối `gps` của config cấp ngưỡng dùng lại vị
/// trí; khoảng cách tới địa điểm tính trên máy, không gọi lại máy chủ.
class _CountingClient extends ApiClient {
  _CountingClient() : super(Dio());

  int configCalls = 0;
  Map<String, dynamic>? gps;
  /// Lượt config kế tiếp chỉ trả lời khi test cho phép (mạng "treo" có kiểm soát, không ngủ theo đồng hồ).
  Completer<void>? holdConfig;
  /// Hoàn thành khi có lượt config VÀO tới client — mốc chờ xác định thay cho đếm sau một quãng ngủ.
  Completer<void> configEntered = Completer<void>();

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters, dynamic options}) async {
    if (path.contains('/attendance/mobile/config')) {
      configCalls++;
      if (!configEntered.isCompleted) configEntered.complete();
      final hold = holdConfig;
      if (hold != null) await hold.future;
      return {
        'success': true,
        'data': {
          'can_punch': true,
          'group': {'code': 'MARKET', 'name': 'Khối thị trường', 'enforce_geofence': true},
          'photo': {'min_photos': 2, 'max_photos': 10, 'require_both': true},
          if (gps != null) 'gps': gps,
          'locations': [
            {
              'id': 6,
              'code': 'VP',
              'name': 'Văn phòng',
              'kind': 'radius',
              'kind_label': 'Vùng bán kính cố định',
              'lat': 21.0277644,
              'lng': 105.8341598,
              'radius_m': 200,
              'distance_m': 44,
            }
          ],
        },
      };
    }
    if (path.contains('/attendance/mobile/history')) return {'success': true, 'data': <dynamic>[]};
    if (path.contains('/attendance/mobile/shifts') || path.contains('/attendance/mobile/days')) {
      return {'success': true, 'data': <dynamic>[]};
    }
    return {'success': true, 'data': null};
  }
}

Position _at(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 8,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('config.gps', () {
    test('server trả khối gps ⇒ đọc đúng; thiếu (server/bộ đệm cũ) ⇒ mặc định 30s · 50m', () {
      final withGps = AttendanceConfigModel.fromJson(<String, dynamic>{
        'can_punch': true,
        'group': {'code': 'A', 'name': 'A', 'enforce_geofence': true},
        'photo': <String, dynamic>{},
        'gps': {'reuse_seconds': 0, 'reuse_accuracy_m': 20},
        'locations': <dynamic>[],
      }).toEntity();
      expect(withGps.gps.reuseSeconds, 0);
      expect(withGps.gps.reuseAge, Duration.zero);
      expect(withGps.gps.reuseAccuracyM, 20);

      final legacy = AttendanceConfigModel.fromJson(<String, dynamic>{
        'can_punch': true,
        'group': {'code': 'A', 'name': 'A', 'enforce_geofence': true},
        'photo': <String, dynamic>{},
        'locations': <dynamic>[],
      }).toEntity();
      expect(legacy.gps.reuseSeconds, 30);
      expect(legacy.gps.reuseAccuracyM, 50);
      // Bộ đệm (toJson → fromJson lúc mất mạng) cũng giữ khối gps.
      final model = AttendanceConfigModel.fromJson(<String, dynamic>{
        'can_punch': true,
        'group': {'code': 'A', 'name': 'A', 'enforce_geofence': true},
        'photo': <String, dynamic>{},
        'gps': {'reuse_seconds': 10, 'reuse_accuracy_m': 20},
        'locations': <dynamic>[],
      });
      expect(AttendanceConfigModel.fromJson(model.toJson()).gps.reuseAccuracyM, 20);
    });
  });

  group('AttendanceViewModel.applyPositionLocally', () {
    late _CountingClient client;
    late AttendanceViewModel vm;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'vthm_user_data': '{"id":7}'});
      // Giá trị KHÁC mặc định (30 · 50) — để biết chắc đọc từ server chứ không phải rơi về mặc định.
      client = _CountingClient()..gps = {'reuse_seconds': 12, 'reuse_accuracy_m': 20};
      final repo = AttendanceRepositoryImpl(AttendanceApiService(client));
      vm = AttendanceViewModel(
        getConfigUseCase: GetAttendanceConfigUseCase(repo),
        punchUseCase: PunchAttendanceUseCase(repo),
        uploadPhotoUseCase: UploadPunchPhotoUseCase(repo),
        getHistoryUseCase: GetAttendanceHistoryUseCase(repo),
        getAttendanceDetailUseCase: GetAttendanceDetailUseCase(repo),
      );
      // Chờ loadInitialData trong constructor xong (có mốc rõ, không ngủ mò).
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (vm.state.config == null && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(vm.state.config, isNotNull, reason: 'config phải tải xong trước khi đo');
    });

    test('xét vùng NGAY trên máy khi mạng treo; config tải lại ngầm; phản hồi CŨ về muộn không đè; ngoài vùng vẫn chặn',
        () async {
      expect(vm.state.config?.gps.reuseSeconds, 12);
      expect(vm.state.config?.gps.reuseAccuracyM, 20);
      final callsAfterLoad = client.configCalls;
      // Mạng treo: lượt config kế tiếp không trả lời cho tới khi test thả.
      final hold = client.holdConfig = Completer<void>();
      client.configEntered = Completer<void>();

      // Đứng cách tâm ~1,1 km ⇒ ngoài bán kính 200m — xét xong dù mạng chưa trả lời.
      await vm.applyPositionLocally(_at(21.0377644, 105.8341598));
      final far = vm.state.config!.locations.single;
      expect(far.distanceM, greaterThan(1000));
      expect(vm.state.isBlockedByGeofence, isTrue);
      expect(vm.state.currentPosition?.latitude, 21.0377644);
      // Vòng tải lại ngầm đã được bắn (không chờ) — độ tươi của trạng thái hôm nay / địa điểm không mất.
      await client.configEntered.future;
      expect(client.configCalls, callsAfterLoad + 1);

      // Về đúng tâm ⇒ trong vùng, nút mở — cũng tức thì (lượt ngầm thứ hai cũng bị treo).
      await vm.applyPositionLocally(_at(21.0277644, 105.8341598));
      expect(vm.state.config!.locations.single.distanceM, 0);
      expect(vm.state.isBlockedByGeofence, isFalse);

      // Thả mạng: cả hai phản hồi (distance_m 44 của mock) về sau — lượt CŨ của vị trí xa không được đè lượt mới hơn.
      hold.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // Chỉ lượt mới nhất (seq cao nhất) được áp: mock trả 44 m cho mọi vị trí ⇒ 44, không còn số của vị trí xa.
      expect(vm.state.config!.locations.single.distanceM, 44);
      expect(vm.state.isBlockedByGeofence, isFalse);
    });
  });

  group('haversineMeters — cùng công thức với server (GeoHelper, R = 6 371 000 m)', () {
    test('khớp số server đo trên cặp toạ độ tài liệu (44 m); toạ độ NaN không ném lỗi', () {
      // API-CHAM-CONG-MOBILE §2: đứng 21.0280000/105.8345000, tâm 21.0277644/105.8341598 ⇒ server trả distance_m = 44.
      final d = haversineMeters(21.0280000, 105.8345000, 21.0277644, 105.8341598);
      expect(d.round(), 44);
      expect(haversineMeters(double.nan, 1, 2, 3).isNaN, isTrue);
    });

    test('biên bán kính: app chặn/cho qua đúng như server so số lẻ (200,4 m chặn · 199,6 m qua); GPS NaN giữ địa điểm', () {
      AttendanceConfigEntity cfg(double lat, double lng) => AttendanceConfigModel.fromJson(<String, dynamic>{
            'can_punch': true,
            'group': {'code': 'A', 'name': 'A', 'enforce_geofence': true},
            'photo': <String, dynamic>{},
            'locations': [
              {'id': 1, 'code': 'C', 'name': 'C', 'kind': 'radius', 'kind_label': 'B', 'lat': 21.0, 'lng': 105.8, 'radius_m': 200}
            ],
          }).toEntity().withDistancesFrom(lat, lng);
      // Đi thẳng theo kinh tuyến: 1 độ vĩ ≈ 111 194,9 m (R = 6 371 000) ⇒ 200,4 m ≈ 0,0018022°; 199,6 m ≈ 0,0017950°.
      final far = cfg(21.0 + 200.4 / 111194.93, 105.8).locations.single;
      expect(far.distanceM, 201);
      expect(far.isWithinRadius, isFalse);
      final near = cfg(21.0 + 199.6 / 111194.93, 105.8).locations.single;
      expect(near.distanceM, 200);
      expect(near.isWithinRadius, isTrue);
      final nan = cfg(double.nan, 105.8).locations.single;
      expect(nan.distanceM, isNull);
    });

    test('bộ đệm bị sửa tay ⇒ kẹp vào biên server (0–300 s, 5–500 m)', () {
      final m = AttendanceGpsConfigModel.fromJson(<String, dynamic>{'reuse_seconds': 86400, 'reuse_accuracy_m': 1});
      expect(m.reuseSeconds, 300);
      expect(m.reuseAccuracyM, 5);
    });
  });
}
