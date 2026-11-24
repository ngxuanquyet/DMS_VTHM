import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';
import 'package:vthm_dms/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:vthm_dms/features/auth/data/services/auth_api_service.dart';
import 'package:vthm_dms/features/employee_tracking/data/datasources/employee_tracking_local_storage.dart';
import 'package:vthm_dms/features/employee_tracking/data/models/location_ping_point_model.dart';

/// Rà soát 24/11/2026 — MÁY DÙNG CHUNG: người đăng nhập sau KHÔNG được gửi / thấy dữ liệu của người trước.
/// (1) hàng đợi GPS theo tài khoản; (2) đăng xuất xoá bản sao thông báo + bộ đệm "Quãng đường của tôi".
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

class _Api extends Fake implements AuthApiService {}

LocationPingPointModel _diem(String uuid) => LocationPingPointModel(
      lat: 21,
      lng: 105,
      clientTime: DateTime.now().toIso8601String(),
      clientUuid: uuid,
    );

Future<void> _dangNhap(int id) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(AppConstants.keyUserData, jsonEncode({'id': id}));
}

void main() {
  late Directory docs;

  setUp(() {
    docs = Directory.systemTemp.createTempSync('shared_device');
    PathProviderPlatform.instance = _Paths(docs);
  });

  tearDown(() => docs.deleteSync(recursive: true));

  test('hàng đợi GPS theo tài khoản: B không thấy điểm của A; A đăng nhập lại vẫn còn; chưa rõ tài khoản ⇒ không ghi', () async {
    SharedPreferences.setMockInitialValues({
      // Hàng đợi khoá chung đời cũ — không rõ của ai ⇒ bỏ.
      'dms_location_pending_queue_v1': jsonEncode([_diem('cu').toJson()]),
    });
    final store = EmployeeTrackingLocalStorage();

    await _dangNhap(1);
    await store.enqueuePoint(_diem('a1'));
    expect((await store.getAllPoints()).map((p) => p.clientUuid), ['a1']);
    expect((await SharedPreferences.getInstance()).containsKey('dms_location_pending_queue_v1'), isFalse);

    await _dangNhap(2);
    expect(await store.getAllPoints(), isEmpty, reason: 'B không gửi điểm GPS của A bằng token của mình');

    (await SharedPreferences.getInstance()).remove(AppConstants.keyUserData);
    await store.enqueuePoint(_diem('khong-ro'));

    await _dangNhap(1);
    expect((await store.getAllPoints()).map((p) => p.clientUuid), ['a1']);
  });

  test('đăng xuất xoá bản sao thông báo + danh sách đã đọc + bộ đệm Quãng đường của tôi', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyUserData: jsonEncode({'id': 1}),
      'local_notifications_store_v1': '{"items":[]}',
      'local_notifications_read_ids_v1': <String>['x'],
      'dms_travel_mine_cache_v1': '[]',
      'dms_travel_legs_cache_v1_1_2026-11-24': '[]',
      'giu_lai': 'x',
    });
    await AuthRepositoryImpl(_Api()).logout();
    final keys = (await SharedPreferences.getInstance()).getKeys();
    expect(keys.where((k) => k.startsWith('local_notifications_') || k.startsWith('dms_travel_')), isEmpty);
    expect(keys, contains('giu_lai'));
  });
}
