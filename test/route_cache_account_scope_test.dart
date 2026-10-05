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
    db = AppDatabase(NativeDatabase.memory());
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

    final routeService = RouteApiService(fakeApiClient, db);
    final user1Routes = await routeService.getMyRoutes();

    expect(user1Routes.length, 2);
    expect(user1Routes[0].name, 'Tuyến Hà Đông - Thanh Xuân');
    expect(user1Routes[1].name, 'Tuyến Cầu Giấy - Ba Đình');

    // Verify cache key exists for user_001
    expect(prefs.containsKey('dms_user_routes_user_001_v2'), isTrue);

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
      'dms_user_routes_user_123_v2',
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

    final routeService = RouteApiService(fakeApiClient, db);
    final routes = await routeService.getMyRoutes();

    // Should purge mock data and not return Vũ Tùng Dương
    expect(routes.any((r) => r.name.contains('Vũ Tùng Dương')), isFalse);
    expect(prefs.containsKey('dms_user_routes_cache_v1'), isFalse);
    expect(prefs.containsKey('dms_user_routes_user_123_v2'), isFalse);
  });

  test('RouteApiService derives routes from local SQLite customers when offline without route cache', () async {
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

    final routeService = RouteApiService(fakeApiClient, db);
    final routes = await routeService.getMyRoutes();

    expect(routes.length, 2);
    expect(routes.map((r) => r.name), containsAll(['Tuyến Minh Khai - Bạch Mai', 'Tuyến Đại La']));

    // It should have written the derived routes into user_999's cache
    expect(prefs.containsKey('dms_user_routes_user_999_v2'), isTrue);
  });
}
