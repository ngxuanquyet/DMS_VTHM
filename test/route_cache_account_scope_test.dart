import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:vthm_dms/core/constants/app_constants.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/features/route/data/services/route_api_service.dart';

class FakeApiClient implements ApiClient {
  dynamic response;
  bool shouldThrow = false;
  String? lastPath;

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    lastPath = path;
    if (shouldThrow) throw Exception('Network error or offline');
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeApiClient fakeApiClient;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory(), 1);
    fakeApiClient = FakeApiClient();
  });

  tearDown(() async {
    await db.close();
  });

  test('RouteApiService scopes cache strictly to active logged-in user', () async {
    final prefs = await SharedPreferences.getInstance();

    // 1. User 1 logs in
    await prefs.setString(
      AppConstants.keyUserData,
      jsonEncode({
        'id': 'user_001',
        'username': 'quyetnx',
        'display_name': 'Nguyễn Xuân Quyết',
      }),
    );

    fakeApiClient.response = {
      'success': true,
      'data': [
        {'id': 10, 'name': 'Tuyến Hà Đông - Thanh Xuân', 'code': 'HD-TX'},
        {'id': 11, 'name': 'Tuyến Cầu Giấy - Ba Đình', 'code': 'CG-BD'},
      ],
    };

    final routeService = RouteApiService(fakeApiClient);
    final user1Routes = await routeService.getMyRoutes();

    expect(user1Routes.length, 2);
    expect(user1Routes[0].name, 'Tuyến Hà Đông - Thanh Xuân');
    expect(user1Routes[1].name, 'Tuyến Cầu Giấy - Ba Đình');

    // Verify cache key exists for user_001
    expect(prefs.containsKey('dms_user_routes_user_001_v3'), isTrue);

    // 2. User 2 logs in
    await prefs.setString(
      AppConstants.keyUserData,
      jsonEncode({
        'id': 'user_002',
        'username': 'tranvanb',
        'display_name': 'Trần Văn B',
      }),
    );

    // Turn offline for User 2
    fakeApiClient.shouldThrow = true;

    // User 2 should NOT see User 1's cached routes
    final user2RoutesOffline = await routeService.getMyRoutes();
    expect(user2RoutesOffline, isEmpty);

    // 3. User 1 goes offline and re-opens app
    await prefs.setString(
      AppConstants.keyUserData,
      jsonEncode({
        'id': 'user_001',
        'username': 'quyetnx',
        'display_name': 'Nguyễn Xuân Quyết',
      }),
    );

    // User 1 gets their cached routes even when offline
    final user1RoutesOffline = await routeService.getMyRoutes();
    expect(user1RoutesOffline.length, 2);
    expect(user1RoutesOffline[0].name, 'Tuyến Hà Đông - Thanh Xuân');
  });

  test('RouteApiService automatically purges stale mock data for non-mock user', () async {
    final prefs = await SharedPreferences.getInstance();

    // Simulate old legacy cache or poisoned cache containing "Vũ Tùng Dương"
    await prefs.setString(
      'dms_user_routes_cache_v1',
      jsonEncode([
        {'id': 5, 'name': 'Vũ Tùng Dương - T2', 'code': 'T2'},
      ]),
    );
    await prefs.setString(
      'dms_user_routes_user_123_v3',
      jsonEncode([
        {'id': 5, 'name': 'Vũ Tùng Dương - T2', 'code': 'T2'},
      ]),
    );

    // User logged in is Nguyễn Xuân Quyết
    await prefs.setString(
      AppConstants.keyUserData,
      jsonEncode({
        'id': 'user_123',
        'username': 'quyetnx',
        'display_name': 'Nguyễn Xuân Quyết',
      }),
    );

    fakeApiClient.shouldThrow = true; // Offline

    final routeService = RouteApiService(fakeApiClient);
    final routes = await routeService.getMyRoutes();

    // Should purge mock data and not return Vũ Tùng Dương
    expect(routes.any((r) => r.name.contains('Vũ Tùng Dương')), isFalse);
    expect(prefs.containsKey('dms_user_routes_cache_v1'), isFalse);
    expect(prefs.containsKey('dms_user_routes_user_123_v3'), isFalse);
  });

  test('RouteApiService KHÔNG dựng tuyến từ điểm bán trong máy khi mất mạng và chưa có bộ đệm (#24698 vòng 3)', () async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      AppConstants.keyUserData,
      jsonEncode({
        'id': 'user_999',
        'username': 'hoang_market',
        'display_name': 'Lê Hoàng',
      }),
    );

    // Insert customers into SQLite for user
    await db.insertOrUpdateCustomer(
      LocalCustomersCompanion(
        id: const Value(1),
        clientUuid: const Value('cust-1'),
        name: const Value('Tạp hóa Minh Khai'),
        code: const Value('KH001'),
        nameUnaccent: const Value('tap hoa minh khai'),
        address: const Value('123 Minh Khai'),
        contactPerson: const Value('Anh Tuấn'),
        phone: const Value('0912345678'),
        route: const Value('Tuyến Minh Khai - Bạch Mai'),
        dynamicFieldsJson: Value(jsonEncode({
          'routes': ['Tuyến Minh Khai - Bạch Mai', 'Tuyến Đại La'],
          'route_ids': [101, 102],
        })),
      ),
    );

    fakeApiClient.shouldThrow = true; // Offline

    final routeService = RouteApiService(fakeApiClient);
    final routes = await routeService.getMyRoutes();

    // id tuyến lưu ở điểm bán có thể là id giả của bản app cũ ⇒ chỉ tin /dms/routes/mine.
    expect(routes, isEmpty);
    expect(prefs.containsKey('dms_user_routes_user_999_v3'), isFalse);
  });

  group('#24698 vòng 3: không dựng / không nhận id tuyến giả', () {
    Future<void> seed(String uuid, {required List<String> names, required List<int> ids}) =>
        db.insertOrUpdateCustomer(LocalCustomersCompanion(
          id: Value(uuid.hashCode.abs() % 100000 + 1),
          clientUuid: Value(uuid),
          name: const Value('Điểm'),
          code: Value('KH-$uuid'),
          nameUnaccent: const Value('diem'),
          address: const Value('HN'),
          contactPerson: const Value('A'),
          phone: const Value('0900000000'),
          route: Value(names.join(', ')),
          dynamicFieldsJson: Value(jsonEncode({'routes': names, 'route_ids': ids})),
        ));

    setUp(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyUserData, jsonEncode({'id': 'user_777', 'username': 'u'}));
    });

    test('API trả RỖNG ⇒ xoá bộ đệm tuyến cũ', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dms_user_routes_user_777_v3', jsonEncode([{'id': 9, 'name': 'Cũ', 'code': 'C'}]));
      fakeApiClient.response = {'success': true, 'data': <dynamic>[]};
      expect(await RouteApiService(fakeApiClient).getMyRoutes(forceRefresh: true), isEmpty);
      expect(prefs.containsKey('dms_user_routes_user_777_v3'), isFalse);
    });

    test('API trả RỖNG ⇒ rỗng, không lấy tuyến trích từ điểm bán trong máy', () async {
      await seed('c-ok', names: ['Tuyến A'], ids: [501]);
      fakeApiClient.response = {'success': true, 'data': <dynamic>[]};
      final routes = await RouteApiService(fakeApiClient).getMyRoutes(forceRefresh: true);
      expect(routes, isEmpty);
    });

  });
}
