import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/map/goong_models.dart';
import 'package:vthm_dms/core/map/goong_providers.dart';
import 'package:vthm_dms/features/forms/data/models/route_customer_model.dart';
import 'package:vthm_dms/features/forms/data/services/route_customers_service.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RouteCustomer Model Tests (§1b Spec 24/09/2026)', () {
    test('RouteCustomerItem serializes to JSON and deserializes correctly with coordinates', () {
      final item = const RouteCustomerItem(
        id: 2036,
        code: '08170152',
        name: 'Dịu Khoản',
        address: '38/6 Phan Đình Phùng, Cam Ranh',
        lat: 11.9082,
        lng: 109.1523,
      );

      expect(item.hasCoordinates, isTrue);

      final json = item.toJson();
      expect(json['id'], 2036);
      expect(json['code'], '08170152');
      expect(json['name'], 'Dịu Khoản');
      expect(json['address'], '38/6 Phan Đình Phùng, Cam Ranh');
      expect(json['lat'], 11.9082);
      expect(json['lng'], 109.1523);

      final fromJson = RouteCustomerItem.fromJson(json);
      expect(fromJson.id, 2036);
      expect(fromJson.code, '08170152');
      expect(fromJson.name, 'Dịu Khoản');
      expect(fromJson.address, '38/6 Phan Đình Phùng, Cam Ranh');
      expect(fromJson.lat, 11.9082);
      expect(fromJson.lng, 109.1523);
      expect(fromJson.hasCoordinates, isTrue);

      // Deserializes with latitude / longitude keys as well
      final altJson = {
        'id': 5000,
        'code': 'KH01',
        'name': 'Đại lý ABC',
        'latitude': '21.0285',
        'longitude': '105.8544',
      };
      final fromAltJson = RouteCustomerItem.fromJson(altJson);
      expect(fromAltJson.lat, closeTo(21.0285, 0.0001));
      expect(fromAltJson.lng, closeTo(105.8544, 0.0001));
      expect(fromAltJson.hasCoordinates, isTrue);
    });

    test('RouteCustomersData serializes and deserializes with truncated flag', () {
      final data = const RouteCustomersData(
        items: [
          RouteCustomerItem(
            id: 2036,
            code: '08170152',
            name: 'Dịu Khoản',
            address: '38/6 Phan Đình Phùng, Cam Ranh',
          ),
          RouteCustomerItem(
            id: 5378,
            code: '08120001',
            name: 'VLXD Hoàng Hương',
            address: null,
          ),
        ],
        truncated: true,
      );

      final json = data.toJson();
      expect(json['truncated'], isTrue);
      expect((json['items'] as List).length, 2);

      final fromJson = RouteCustomersData.fromJson(json);
      expect(fromJson.truncated, isTrue);
      expect(fromJson.items.length, 2);
      expect(fromJson.items.first.id, 2036);
      expect(fromJson.items.last.address, isNull);
    });
  });

  group('RefCustomerFieldWidget & MarketFormRenderer Widget Tests', () {
    const sampleCustomer1 = RouteCustomerItem(
      id: 2036,
      code: '08170152',
      name: 'Dịu Khoản',
      address: '38/6 Phan Đình Phùng, Cam Ranh',
    );
    const sampleCustomer2 = RouteCustomerItem(
      id: 5378,
      code: '08120001',
      name: 'VLXD Hoàng Hương',
      address: '123 Đường 2/4, Nha Trang',
    );
    const sampleCustomer3 = RouteCustomerItem(
      id: 8338,
      code: '08150022',
      name: 'Cửa hàng Tạp hóa Lan',
      address: 'Phúc Yên, Vĩnh Phúc',
    );

    const testBlock = MarketFormBlockEntity(
      ref: 'diem_ban_khao_sat',
      type: 'field',
      required: true,
      colSpan: 12,
      resolved: MarketFormResolvedEntity(
        code: 'diem_ban_khao_sat',
        label: 'Điểm bán khảo sát',
        inputType: 'ref_customer',
      ),
    );

    testWidgets('Renders empty selection with required asterisk and opens picker sheet',
        (tester) async {
      final key = GlobalKey<MarketFormRendererState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routeCustomersListProvider.overrideWith(
              (ref) => Future.value(
                const RouteCustomersData(
                  items: [sampleCustomer1, sampleCustomer2, sampleCustomer3],
                  truncated: false,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MarketFormRenderer(
                key: key,
                blocks: const [testBlock],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Hiển thị nhãn và dấu * bắt buộc
      expect(find.textContaining('Điểm bán khảo sát'), findsOneWidget);
      expect(find.text('Chạm để chọn điểm bán / khách hàng...'), findsOneWidget);

      // Chạm để mở bottom sheet chọn điểm bán
      await tester.tap(find.text('Chạm để chọn điểm bán / khách hàng...'));
      await tester.pumpAndSettle();

      // Bottom sheet hiển thị tiêu đề và danh sách điểm bán
      expect(find.text('Dịu Khoản'), findsOneWidget);
      expect(find.text('VLXD Hoàng Hương'), findsOneWidget);
      expect(find.text('Cửa hàng Tạp hóa Lan'), findsOneWidget);

      // Tìm kiếm theo mã điểm bán
      await tester.enterText(find.byType(TextField), '08120001');
      await tester.pumpAndSettle();

      // Chỉ còn điểm bán VLXD Hoàng Hương
      expect(find.text('VLXD Hoàng Hương'), findsOneWidget);
      expect(find.text('Dịu Khoản'), findsNothing);

      // Chọn điểm bán VLXD Hoàng Hương
      await tester.tap(find.text('VLXD Hoàng Hương'));
      await tester.pumpAndSettle();

      // Bottom sheet đóng lại, ô hiển thị tên và mã đã chọn
      expect(find.text('VLXD Hoàng Hương'), findsOneWidget);
      expect(find.text('08120001'), findsOneWidget);

      // Giá trị answers lưu id số nguyên 5378
      expect(key.currentState?.currentAnswers['diem_ban_khao_sat'], 5378);

      // Validate thành công
      final answers = key.currentState?.validateAndGetAnswers();
      expect(answers, isNotNull);
      expect(answers!['diem_ban_khao_sat'], 5378);
    });

    testWidgets('Displays truncated warning notice when truncated is true',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routeCustomersListProvider.overrideWith(
              (ref) => Future.value(
                const RouteCustomersData(
                  items: [sampleCustomer1],
                  truncated: true,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MarketFormRenderer(
                blocks: [testBlock],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Chạm để chọn điểm bán / khách hàng...'));
      await tester.pumpAndSettle();

      // Cảnh báo danh sách chạm trần 2.000 dòng
      expect(
        find.textContaining('Danh sách điểm bán đã đạt giới hạn 2.000'),
        findsOneWidget,
      );
    });

    testWidgets('Displays friendly message when user has no assigned routes',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routeCustomersListProvider.overrideWith(
              (ref) => Future.value(
                const RouteCustomersData(
                  items: [],
                  truncated: false,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MarketFormRenderer(
                blocks: [testBlock],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Chạm để chọn điểm bán / khách hàng...'));
      await tester.pumpAndSettle();

      // Thông báo chưa được giao tuyến nào (§1b)
      expect(find.text('Bạn chưa được giao tuyến nào.'), findsOneWidget);
    });

    testWidgets('Auto pre-fills defaultCustomerId from check-in session',
        (tester) async {
      final key = GlobalKey<MarketFormRendererState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routeCustomersListProvider.overrideWith(
              (ref) => Future.value(
                const RouteCustomersData(
                  items: [sampleCustomer1, sampleCustomer2, sampleCustomer3],
                  truncated: false,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MarketFormRenderer(
                key: key,
                blocks: const [testBlock],
                defaultCustomerId: 8338,
                defaultCustomerName: 'Cửa hàng Tạp hóa Lan',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tự động chọn Cửa hàng Tạp hóa Lan và lưu id 8338
      expect(find.text('Cửa hàng Tạp hóa Lan'), findsOneWidget);
      expect(key.currentState?.currentAnswers['diem_ban_khao_sat'], 8338);

      final answers = key.currentState?.validateAndGetAnswers();
      expect(answers, isNotNull);
      expect(answers!['diem_ban_khao_sat'], 8338);
    });

    testWidgets('Fails validation when required ref_customer field is unselected',
        (tester) async {
      final key = GlobalKey<MarketFormRendererState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routeCustomersListProvider.overrideWith(
              (ref) => Future.value(
                const RouteCustomersData(
                  items: [sampleCustomer1],
                  truncated: false,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MarketFormRenderer(
                key: key,
                blocks: const [testBlock],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Validate khi chưa chọn điểm bán
      final answers = key.currentState?.validateAndGetAnswers();
      expect(answers, isNull);

      await tester.pumpAndSettle();

      // Báo lỗi đúng tên ô (§2)
      expect(find.text('Điểm bán khảo sát không được để trống.'), findsOneWidget);
    });

    testWidgets(
        'Sorts customers by distance ascending from current location and displays distance labels',
        (tester) async {
      // User location at Cam Ranh
      const userPoint = GoongLatLng(11.9080, 109.1520);

      const customerFar = RouteCustomerItem(
        id: 100,
        code: 'KH_FAR',
        name: 'Đại lý Nha Trang (Xa)',
        address: '123 Đường 2/4, Nha Trang',
        lat: 12.2388,
        lng: 109.1967, // ~37 km
      );

      const customerNear = RouteCustomerItem(
        id: 200,
        code: 'KH_NEAR',
        name: 'Tạp hóa Gần (Cam Ranh)',
        address: 'Gần chợ Cam Ranh',
        lat: 11.9085,
        lng: 109.1525, // ~77 m
      );

      const customerNoGps = RouteCustomerItem(
        id: 300,
        code: 'KH_NOGPS',
        name: 'Cửa hàng Chưa GPS',
        address: 'Không rõ toạ độ',
        lat: null,
        lng: null,
      );

      // Given original list has Far first, then NoGps, then Near
      final originalList = [customerFar, customerNoGps, customerNear];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentPointProvider.overrideWith((ref) => Future.value(userPoint)),
            routeCustomersListProvider.overrideWith(
              (ref) => Future.value(
                RouteCustomersData(
                  items: originalList,
                  truncated: false,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MarketFormRenderer(
                blocks: [testBlock],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open customer picker sheet
      await tester.tap(find.text('Chạm để chọn điểm bán / khách hàng...'));
      await tester.pumpAndSettle();

      // Notice about distance sorting should be visible
      expect(find.text('Sắp xếp theo vị trí gần bạn nhất'), findsOneWidget);

      // Verify badges:
      // customerNear (~78 m)
      expect(find.text('78 m'), findsOneWidget);
      // customerFar (distance in km)
      expect(find.textContaining(' km'), findsOneWidget);
      // customerNoGps
      expect(find.text('Chưa có GPS'), findsOneWidget);

      // Verify sorted order: KH_NEAR should appear before KH_FAR in the render tree
      final nearTopLeft = tester.getTopLeft(find.text('Tạp hóa Gần (Cam Ranh)'));
      final farTopLeft = tester.getTopLeft(find.text('Đại lý Nha Trang (Xa)'));
      final noGpsTopLeft = tester.getTopLeft(find.text('Cửa hàng Chưa GPS'));

      expect(nearTopLeft.dy < farTopLeft.dy, isTrue,
          reason: 'Nearest customer should be displayed first');
      expect(farTopLeft.dy < noGpsTopLeft.dy, isTrue,
          reason: 'Customer with GPS should appear before customer without GPS');

      // Select nearest customer
      await tester.tap(find.text('Tạp hóa Gần (Cam Ranh)'));
      await tester.pumpAndSettle();

      // Sheet closed, form displays selected customer and its distance label
      expect(find.text('Tạp hóa Gần (Cam Ranh)'), findsOneWidget);
      expect(find.text('78 m'), findsOneWidget);
    });
  });
}
