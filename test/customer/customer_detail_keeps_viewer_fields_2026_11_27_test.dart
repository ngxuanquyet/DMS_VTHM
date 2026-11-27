import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/network/connectivity_provider.dart';
import 'package:vthm_dms/core/sync/sync_service.dart';
import 'package:vthm_dms/features/customer/data/datasources/customer_local_data_source.dart';
import 'package:vthm_dms/features/customer/data/repositories/customer_repository_impl.dart';
import 'package:vthm_dms/features/customer/data/services/customer_api_service.dart';
import 'package:vthm_dms/features/customer/data/utils/customer_payload_helper.dart';

/// Danh sách `/dms/outlets/mine` gắn phần "theo người xem" (tuyến của tôi, cờ `in_care_area` — One #25938); cửa chi tiết
/// `/dms/outlets/{id}` KHÔNG gắn (đo app_test 27/11/2026: `routes: []`, `in_care_area: null`). Mở chi tiết mà ghi đè bản
/// trong máy bằng bản chi tiết ⇒ điểm bán rơi khỏi màn Tuyến (lọc tuyến ∪ khu vực) tới lần tải lại.
/// Tên tuyến mang thứ của HÔM NAY — để `isToday` của bản danh sách là `true` mà kiểm được việc giữ nó.
String _todayRouteName() {
  final w = DateTime.now().weekday;
  return w == DateTime.sunday ? 'Tuyến Chủ nhật' : 'Tuyến Thứ ${w + 1}';
}

class _Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    Map<String, dynamic> body = {'success': true};
    if (options.path.contains('outlets/mine')) {
      body = {
        'success': true,
        'data': [
          {
            'id': 77,
            'code': 'DMS77',
            'name': 'Điểm khu vực',
            'address': 'Vĩnh Phúc',
            'phone': '0900000000',
            'status': 'active',
            'routes': [
              {'id': 10, 'name': _todayRouteName()},
            ],
            'in_care_area': true,
          },
        ],
        'meta': {'total': 1, 'currentPage': 1, 'pageCount': 1},
      };
    } else if (options.path == '/dms/outlets/77') {
      body = {
        'success': true,
        'data': {
          'id': 77,
          'code': 'DMS77',
          'name': 'Điểm khu vực (sửa tên)',
          'address': 'Vĩnh Phúc',
          'phone': '0900000000',
          'status': 'active',
          'routes': <dynamic>[],
          'in_care_area': null,
        },
      };
    }
    return ResponseBody.fromString(jsonEncode(body), 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mở chi tiết điểm bán giữ tuyến của tôi + cờ khu vực chăm sóc (RAM và SQLite), nhận phần còn lại từ server', () async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory(), 1);
    final dio = Dio(BaseOptions(baseUrl: 'https://api-app.vthmgroup.vn'))..httpClientAdapter = _Adapter();
    final apiClient = ApiClient(dio);
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      apiClientProvider.overrideWithValue(apiClient),
      connectivityProvider.overrideWith((ref) => ConnectivityNotifier()),
    ]);
    addTearDown(() async {
      await db.close();
      container.dispose();
    });
    final local = CustomerLocalDataSource(db);
    final repo = CustomerRepositoryImpl(
        CustomerApiService(apiClient), local, container.read(syncServiceProvider), null, () => true);

    final list = await repo.getCustomers(forceRefresh: true);
    expect(list.single.inCareArea, isTrue);
    expect(list.single.routeIds, [10]);
    final wasToday = list.single.isToday;
    expect(wasToday, isTrue);

    final detail = await repo.getCustomerDetail(77);
    expect(detail.name, 'Điểm khu vực (sửa tên)');
    expect(detail.inCareArea, isTrue);
    expect(detail.routeIds, [10]);
    expect(detail.isToday, wasToday, reason: 'lọc "Hôm nay" không được đổi vì mở chi tiết');

    // RAM trống (mở lại app, mở chi tiết từ thông báo) ⇒ tra bản máy SQLite.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final coldRepo = CustomerRepositoryImpl(
        CustomerApiService(apiClient), local, container.read(syncServiceProvider), null, () => true);
    final coldDetail = await coldRepo.getCustomerDetail(77);
    expect(coldDetail.inCareArea, isTrue);
    expect(coldDetail.routeIds, [10]);

    // Ghi SQLite chạy nền (`unawaited`) — chờ một nhịp rồi đọc lại bản máy.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final saved = (await local.getLocalCustomers()).single;
    expect(saved.inCareArea, isTrue);
    expect(saved.routeIds, [10]);
  });

  test('cờ in_care_area không bao giờ gửi lên server (khoá cấm, kể cả trong data)', () {
    expect(kForbiddenCustomerKeys, contains('in_care_area'));
    expect(kCustomerFixedKeys, isNot(contains('in_care_area')));
  });
}
