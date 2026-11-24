import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';
import 'package:vthm_dms/core/errors/app_exceptions.dart';
import 'package:vthm_dms/features/attendance/data/models/attendance_model.dart';
import 'package:vthm_dms/features/attendance/data/repositories/attendance_repository_impl.dart';
import 'package:vthm_dms/features/attendance/data/services/attendance_api_service.dart';
import 'package:vthm_dms/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:vthm_dms/features/auth/data/services/auth_api_service.dart';
import 'package:vthm_dms/features/employee_tracking/data/datasources/employee_tracking_api_service.dart';
import 'package:vthm_dms/features/employee_tracking/presentation/services/employee_tracking_service.dart';
import 'package:vthm_dms/features/forms/data/services/form_draft_store.dart';

/// Rà soát 24/11/2026 (#25868, nhóm B — đăng nhập, chấm công, theo dõi vị trí, khai báo vị trí).
class _Paths extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  final Directory dir;
  _Paths(this.dir);

  @override
  Future<String?> getTemporaryPath() async => dir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;

  @override
  Future<String?> getApplicationSupportPath() async => dir.path;
}

class _AuthApi extends Fake implements AuthApiService {}

/// API chấm công giả: [error] != null ⇒ mọi lời gọi ném lỗi đó.
class _AttApi extends Fake implements AttendanceApiService {
  Object? error;

  @override
  Future<AttendanceConfigModel> getConfig({double? lat, double? lng}) async {
    if (error != null) throw error!;
    return AttendanceConfigModel.fromJson({
      'can_punch': true,
      'group': {'code': 'OFFICE', 'name': 'Văn phòng', 'enforce_geofence': false},
      'photo': {'min_photos': 1, 'max_photos': 3, 'require_both': false},
      'locations': <dynamic>[],
    });
  }

  @override
  Future<AttendancePunchModel> punch(AttendancePunchRequestModel request) async => throw error!;

  @override
  Future<AttendancePhotoItemModel> uploadPunchPhoto(
    int punchId, {
    required File file,
    required String photoType,
    DateTime? takenAt,
    double? lat,
    double? lng,
  }) async =>
      throw error!;
}

/// Bộ chuyển Dio trả một phản hồi cố định (không ra mạng).
class _FixedAdapter implements HttpClientAdapter {
  final int status;
  final String body;
  final String contentType;
  _FixedAdapter(this.status, this.body, this.contentType);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromString(body, status, headers: {
      Headers.contentTypeHeader: [contentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Position _pos(DateTime timestamp) => Position(
      latitude: 21,
      longitude: 105,
      timestamp: timestamp,
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

  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('group_b_auth');
    PathProviderPlatform.instance = _Paths(docs);
  });

  tearDown(() => docs.deleteSync(recursive: true));

  group('1. Đăng xuất cưỡng bức giữ nháp theo tài khoản', () {
    Map<String, Object> prefsCoNhap() => {
          AppConstants.keyUserData: jsonEncode({'id': 7}),
          FormDraftStore.collectSlot('7'): jsonEncode({'drafts': <String, dynamic>{}}),
          FormDraftStore.customerSlot('7'): jsonEncode({'drafts': <String, dynamic>{}}),
          'dms_market_forms_list_7': '[]',
        };

    test('cưỡng bức (keepAccountDrafts) ⇒ còn hai ngăn nháp; bộ đệm biểu mẫu vẫn xoá', () async {
      SharedPreferences.setMockInitialValues(prefsCoNhap());
      await AuthRepositoryImpl(_AuthApi()).logout(keepAccountDrafts: true);
      final keys = (await SharedPreferences.getInstance()).getKeys();
      expect(keys, containsAll([FormDraftStore.collectSlot('7'), FormDraftStore.customerSlot('7')]));
      expect(keys, isNot(contains('dms_market_forms_list_7')));
      expect(keys, isNot(contains(AppConstants.keyUserData)));
    });

    test('tự đăng xuất (mặc định) ⇒ xoá mọi ngăn nháp', () async {
      SharedPreferences.setMockInitialValues(prefsCoNhap());
      await AuthRepositoryImpl(_AuthApi()).logout();
      final keys = (await SharedPreferences.getInstance()).getKeys();
      expect(keys.where((k) => k.startsWith('dms_market_forms_')), isEmpty);
    });
  });

  group('2 + 5. Chấm công: chỉ lỗi tạm / mạng / 401 mới xếp hàng; cấu hình dùng bản lưu khi gặp trang proxy', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({AppConstants.keyUserData: jsonEncode({'id': 1})});
    });

    // 500 vẫn xếp hàng (giữ mốc giờ chấm thật khi máy chủ lỗi kéo dài — group1_data_loss_round2_test); trang proxy 4xx nay
    // cũng là lỗi tạm.
    test('punch 503 / trang proxy 404 / 401 / mất mạng ⇒ xếp hàng (trả lượt lạc quan)', () async {
      for (final err in <Object>[
        const ServerException('Bảo trì', 503),
        const ServerException('<html>', 404, nonApiResponseCode),
        const ServerException('Hết phiên', 401),
        const NetworkException(),
      ]) {
        final repo = AttendanceRepositoryImpl(_AttApi()..error = err);
        final p = await repo.punch(lat: 21, lng: 105);
        expect(p.clientUuid, isNotEmpty, reason: '$err');
      }
    });

    test('cấu hình: 403 trang proxy ⇒ dùng bản lưu; 403 JSON của API ⇒ vẫn ném', () async {
      final api = _AttApi();
      final repo = AttendanceRepositoryImpl(api);
      await repo.getConfig(); // ghi bản lưu
      api.error = const ServerException('<html>', 403, nonApiResponseCode);
      final cfg = await repo.getConfig();
      expect(cfg.group.code, 'OFFICE', reason: 'phải là bản lưu, không phải cấu hình mặc định MARKET');

      api.error = const ServerException('Không có quyền', 403, 'FORBIDDEN');
      await expectLater(repo.getConfig(), throwsA(isA<ServerException>()));
    });
  });

  group('3. Điểm GPS mang đúng giờ ĐO của vị trí', () {
    final now = DateTime(2026, 11, 24, 10, 0, 0);

    test('vị trí LƯU SẴN (đo mới hỏng) ⇒ client_time = lúc đo, không phải lúc gửi', () {
      final measured = now.subtract(const Duration(minutes: 30));
      for (final src in ['app_exit', 'requested']) {
        final p = EmployeeTrackingNotifier.pointFromPosition(_pos(measured.toUtc()),
            source: src, requestId: 3, now: now, fromCache: true)!;
        expect(DateTime.parse(p.clientTime), measured, reason: src);
        expect(p.clientTime.endsWith('Z'), isFalse, reason: 'giữ dạng giờ máy như trước');
      }
    });

    test('ping định kỳ dùng vị trí LƯU SẴN ⇒ bỏ nhịp (null)', () {
      expect(
          EmployeeTrackingNotifier.pointFromPosition(_pos(now.toUtc()), source: 'auto', now: now, fromCache: true), isNull);
    });

    test('vị trí ĐO MỚI mà giờ GPS lệch xa đồng hồ máy (máy để giờ nhanh) ⇒ vẫn gửi, client_time = bây giờ', () {
      final gpsTime = now.subtract(const Duration(minutes: 30));
      final p = EmployeeTrackingNotifier.pointFromPosition(_pos(gpsTime.toUtc()), source: 'auto', now: now)!;
      expect(DateTime.parse(p.clientTime), now);
    });

    test('vị trí lưu sẵn mà giờ đo lệch về sau đồng hồ máy ⇒ lấy giờ máy', () {
      final future = now.add(const Duration(minutes: 3));
      final p = EmployeeTrackingNotifier.pointFromPosition(_pos(future.toUtc()),
          source: 'app_exit', now: now, fromCache: true)!;
      expect(DateTime.parse(p.clientTime), now);
    });
  });

  group('6. 403 trang proxy không phải bị thu quyền theo dõi vị trí', () {
    test('403 HTML ⇒ DioException (lỗi tạm), KHÔNG LocationPermissionDeniedException', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://x.invalid'))
        ..httpClientAdapter = _FixedAdapter(403, '<html>Blocked</html>', 'text/html');
      final api = EmployeeTrackingApiService(dio);
      await expectLater(api.getPendingRequest(), throwsA(isA<DioException>()));
    });

    test('403 JSON của API ⇒ vẫn là bị thu quyền', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://x.invalid'))
        ..httpClientAdapter = _FixedAdapter(403, '{"success":false,"message":"Không có quyền"}', 'application/json');
      final api = EmployeeTrackingApiService(dio);
      await expectLater(api.getPendingRequest(), throwsA(isA<LocationPermissionDeniedException>()));
    });
  });
}
