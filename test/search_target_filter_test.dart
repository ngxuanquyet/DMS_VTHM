import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/core/constants/search_target.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_dynamic_column.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_meta_entity.dart';
import 'package:vthm_dms/features/customer/domain/repositories/customer_repository.dart';
import 'package:vthm_dms/features/customer/presentation/viewmodels/customer_view_model.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';
import 'package:vthm_dms/features/route/domain/usecases/route_usecases.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';
import 'package:vthm_dms/features/visit/domain/usecases/visit_usecases.dart';

class MockCustomerRepository implements CustomerRepository {
  List<CustomerEntity> customers = [];

  @override
  Future<List<CustomerEntity>> getCustomers({
    int page = 1,
    int perPage = 200,
    String? query,
    bool forceRefresh = false,
  }) async =>
      customers;

  @override
  Future<List<CustomerDynamicColumn>> getDynamicColumns({bool forceRefresh = false}) async => [];

  @override
  Future<CustomerMetaData> getCustomerMeta({bool forceRefresh = false}) async =>
      const CustomerMetaData();

  @override
  Future<CustomerEntity> updateCustomer({
    required int id,
    required Map<String, dynamic> changes,
    String? clientUuid,
  }) async =>
      customers.first;

  @override
  Future<CustomerEntity> createCustomer(Map<String, dynamic> data) async => customers.first;

  @override
  Future<CustomerEntity> getCustomerDetail(int id) async =>
      customers.firstWhere((c) => c.id == id, orElse: () => customers.first);

  @override
  Future<Map<String, dynamic>> getCustomerFormSchema({bool forceRefresh = false}) async => {};

  @override
  Future<Map<String, dynamic>> uploadCustomerPhoto(String filePath) async => {};

  @override
  Future<bool> deleteCustomer(int id) async => true;

  @override
  Future<bool> deletePendingCustomer(String clientUuid) async => true;
}

class FakeGetRouteDetailUseCase implements GetRouteDetailUseCase {
  @override
  Future<RouteDetailEntity> call({bool forceRefresh = false}) async {
    return const RouteDetailEntity(
      id: 'active_route',
      title: 'Tất cả tuyến',
      totalDealers: 0,
      completedDealers: 0,
      pendingDealers: 0,
      progressPercent: 0.0,
      dealers: [],
    );
  }
}

class FakeGetTodayVisitsUseCase implements GetTodayVisitsUseCase {
  @override
  Future<List<VisitEntity>> call() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleCustomerA = CustomerEntity(
    id: 1,
    code: 'KH-ALPHA',
    name: 'Tạp Hóa Hương Sen',
    contactPerson: 'Nguyễn Văn Sen',
    phone: '0901234567',
    address: '123 Đường Cầu Giấy',
    wardName: 'Dịch Vọng',
    provinceName: 'Hà Nội',
    route: 'Tuyến Thứ 2 - Cầu Giấy',
    routes: ['Tuyến Thứ 2 - Cầu Giấy', 'Tuyến Thứ 4 - Mỹ Đình'],
    type: 'Tạp hóa',
    status: 'active',
  );

  final sampleCustomerB = CustomerEntity(
    id: 2,
    code: 'KH-BETA',
    name: 'Đại Lý Bia Minh Phát',
    contactPerson: 'Trần Minh Phát',
    phone: '0988776655',
    address: '456 Phố Huế',
    wardName: 'Hàng Bài',
    provinceName: 'Hà Nội',
    route: 'Tuyến Thứ 3 - Hai Bà Trưng',
    routes: ['Tuyến Thứ 3 - Hai Bà Trưng'],
    type: 'Đại lý Cấp 1',
    status: 'active',
  );

  final sampleCustomerC = CustomerEntity(
    id: 3,
    code: 'KH-GAMMA',
    name: 'Cửa Hàng Tự Do',
    contactPerson: 'Lê Hương',
    phone: '0912345678',
    address: '789 Đường Lê Lợi',
    wardName: 'Bến Thành',
    provinceName: 'Hồ Chí Minh',
    route: 'Tuyến Thứ 5 - Quận 1',
    routes: ['Tuyến Thứ 5 - Quận 1'],
    type: 'Cửa hàng',
    status: 'active',
  );

  group('SearchTarget Logic & Entity Matching', () {
    test('SearchTarget enum definitions and metadata', () {
      expect(SearchTarget.values.length, 6);
      expect(SearchTarget.all.label, 'Tất cả');
      expect(SearchTarget.name.label, 'Tên');
      expect(SearchTarget.code.label, 'Mã');
      expect(SearchTarget.route.label, 'Tuyến');
      expect(SearchTarget.address.label, 'Địa chỉ');
      expect(SearchTarget.phone.label, 'SĐT');

      for (final t in SearchTarget.values) {
        expect(t.hintText.isNotEmpty, true);
        expect(t.icon, isNotNull);
      }
    });

    test('SearchTarget.name matches store name and contact person with unaccented query', () {
      // "huong sen" should match "Tạp Hóa Hương Sen"
      expect(SearchTarget.name.matchesCustomer(sampleCustomerA, 'huong sen'), isTrue);
      // "nguyen van sen" should match contact person "Nguyễn Văn Sen"
      expect(SearchTarget.name.matchesCustomer(sampleCustomerA, 'nguyen van sen'), isTrue);
      // Should NOT match code or address when SearchTarget is name
      expect(SearchTarget.name.matchesCustomer(sampleCustomerA, 'kh-alpha'), isFalse);
      expect(SearchTarget.name.matchesCustomer(sampleCustomerA, 'cau giay'), isFalse);
      expect(SearchTarget.name.matchesCustomer(sampleCustomerA, '0901234567'), isFalse);
    });

    test('SearchTarget.code matches only customer code', () {
      expect(SearchTarget.code.matchesCustomer(sampleCustomerA, 'kh-alpha'), isTrue);
      expect(SearchTarget.code.matchesCustomer(sampleCustomerA, 'alpha'), isTrue);
      expect(SearchTarget.code.matchesCustomer(sampleCustomerA, 'kh-alpha'.toLowerCase()), isTrue);

      // Should NOT match name, address, or phone
      expect(SearchTarget.code.matchesCustomer(sampleCustomerA, 'huong sen'), isFalse);
      expect(SearchTarget.code.matchesCustomer(sampleCustomerA, 'cau giay'), isFalse);
    });

    test('SearchTarget.route matches single route and routes list', () {
      expect(SearchTarget.route.matchesCustomer(sampleCustomerA, 'cau giay'), isTrue);
      // Secondary route in routes array
      expect(SearchTarget.route.matchesCustomer(sampleCustomerA, 'my dinh'), isTrue);

      // Customer B should match Hai Ba Trung
      expect(SearchTarget.route.matchesCustomer(sampleCustomerB, 'hai ba trung'), isTrue);
      expect(SearchTarget.route.matchesCustomer(sampleCustomerB, 'cau giay'), isFalse);
    });

    test('SearchTarget.address matches address, ward, and province', () {
      expect(SearchTarget.address.matchesCustomer(sampleCustomerA, 'cau giay'), isTrue);
      expect(SearchTarget.address.matchesCustomer(sampleCustomerA, 'dich vong'), isTrue);
      expect(SearchTarget.address.matchesCustomer(sampleCustomerA, 'ha noi'), isTrue);

      expect(SearchTarget.address.matchesCustomer(sampleCustomerC, 'le loi'), isTrue);
      expect(SearchTarget.address.matchesCustomer(sampleCustomerC, 'ben thanh'), isTrue);
      expect(SearchTarget.address.matchesCustomer(sampleCustomerC, 'ho chi minh'), isTrue);

      // Address should not match name or code
      expect(SearchTarget.address.matchesCustomer(sampleCustomerC, 'kh-gamma'), isFalse);
      expect(SearchTarget.address.matchesCustomer(sampleCustomerC, 'tu do'), isFalse);
    });

    test('SearchTarget.phone matches phone number', () {
      expect(SearchTarget.phone.matchesCustomer(sampleCustomerA, '0901234567'), isTrue);
      expect(SearchTarget.phone.matchesCustomer(sampleCustomerA, '0901'), isTrue);
      expect(SearchTarget.phone.matchesCustomer(sampleCustomerB, '0988'), isTrue);

      // Should NOT match code or address
      expect(SearchTarget.phone.matchesCustomer(sampleCustomerA, 'alpha'), isFalse);
    });

    test('SearchTarget.all matches across all fields', () {
      // By name
      expect(SearchTarget.all.matchesCustomer(sampleCustomerA, 'huong sen'), isTrue);
      // By code
      expect(SearchTarget.all.matchesCustomer(sampleCustomerA, 'alpha'), isTrue);
      // By phone
      expect(SearchTarget.all.matchesCustomer(sampleCustomerA, '0901'), isTrue);
      // By address
      expect(SearchTarget.all.matchesCustomer(sampleCustomerA, 'dich vong'), isTrue);
      // By route
      expect(SearchTarget.all.matchesCustomer(sampleCustomerA, 'my dinh'), isTrue);
      // Non matching
      expect(SearchTarget.all.matchesCustomer(sampleCustomerA, 'non_existent_xyz'), isFalse);
    });
  });

  group('CustomerViewModel Multi-Target Search Integration', () {
    late MockCustomerRepository repo;

    setUp(() {
      repo = MockCustomerRepository()
        ..customers = [sampleCustomerA, sampleCustomerB, sampleCustomerC];
    });

    test('Filtering with different SearchTarget in CustomerViewModel', () async {
      final vm = CustomerViewModel(repo);
      await vm.loadCustomers();

      final container = ProviderContainer(
        overrides: [
          customerViewModelProvider.overrideWith((ref) => vm),
        ],
      );
      addTearDown(container.dispose);

      // Initial state: all customers
      var list = container.read(filteredCustomersProvider);
      expect(list.length, 3);

      // 1. Search for "huong" with SearchTarget.all -> matches Customer A ("Hương Sen") and C ("Lê Hương")
      vm.setSearchQuery('huong');
      vm.setSearchTarget(SearchTarget.all);
      list = container.read(filteredCustomersProvider);
      expect(list.length, 2);
      expect(list.map((c) => c.customer.code).toSet(), {'KH-ALPHA', 'KH-GAMMA'});

      // 2. Search for "huong" with SearchTarget.name -> matches Customer A (name) and C (contactPerson)
      vm.setSearchTarget(SearchTarget.name);
      list = container.read(filteredCustomersProvider);
      expect(list.length, 2);

      // 3. Search for "huong" with SearchTarget.code -> no customer matches
      vm.setSearchTarget(SearchTarget.code);
      list = container.read(filteredCustomersProvider);
      expect(list.length, 0);

      // 4. Search for "alpha" with SearchTarget.code -> matches only Customer A
      vm.setSearchQuery('alpha');
      list = container.read(filteredCustomersProvider);
      expect(list.length, 1);
      expect(list.first.customer.code, 'KH-ALPHA');

      // 5. Search for "alpha" with SearchTarget.address -> 0 results
      vm.setSearchTarget(SearchTarget.address);
      list = container.read(filteredCustomersProvider);
      expect(list.length, 0);

      // 6. Search for "cau giay" with SearchTarget.address -> matches Customer A
      vm.setSearchQuery('cau giay');
      list = container.read(filteredCustomersProvider);
      expect(list.length, 1);
      expect(list.first.customer.code, 'KH-ALPHA');

      // 7. Search for "cau giay" with SearchTarget.route -> matches Customer A
      vm.setSearchTarget(SearchTarget.route);
      list = container.read(filteredCustomersProvider);
      expect(list.length, 1);
      expect(list.first.customer.code, 'KH-ALPHA');

      // 8. Search for "0988" with SearchTarget.phone -> matches Customer B
      vm.setSearchQuery('0988');
      vm.setSearchTarget(SearchTarget.phone);
      list = container.read(filteredCustomersProvider);
      expect(list.length, 1);
      expect(list.first.customer.code, 'KH-BETA');
    });
  });

  group('RouteViewModel Multi-Target Search Integration', () {
    late MockCustomerRepository repo;

    setUp(() {
      repo = MockCustomerRepository()
        ..customers = [sampleCustomerA, sampleCustomerB, sampleCustomerC];
    });

    test('RouteViewModel applies SearchTarget to route dealers', () async {
      final routeVm = RouteViewModel(
        customerRepository: repo,
        getRouteDetailUseCase: FakeGetRouteDetailUseCase(),
        getTodayVisitsUseCase: FakeGetTodayVisitsUseCase(),
      );

      await routeVm.loadRouteDetail();
      expect(routeVm.state.routeDetail?.dealers.length, 3);

      // 1. Search by name
      routeVm.setSearchTarget(SearchTarget.name);
      routeVm.setSearchQuery('bia minh phat');
      expect(routeVm.state.routeDetail?.dealers.length, 1);
      expect(routeVm.state.routeDetail?.dealers.first.code, 'KH-BETA');

      // 2. Search by code
      routeVm.setSearchTarget(SearchTarget.code);
      routeVm.setSearchQuery('gamma');
      expect(routeVm.state.routeDetail?.dealers.length, 1);
      expect(routeVm.state.routeDetail?.dealers.first.code, 'KH-GAMMA');

      // 3. Search by route
      routeVm.setSearchTarget(SearchTarget.route);
      routeVm.setSearchQuery('quan 1');
      expect(routeVm.state.routeDetail?.dealers.length, 1);
      expect(routeVm.state.routeDetail?.dealers.first.code, 'KH-GAMMA');

      // 4. Search by address
      routeVm.setSearchTarget(SearchTarget.address);
      routeVm.setSearchQuery('pho hue');
      expect(routeVm.state.routeDetail?.dealers.length, 1);
      expect(routeVm.state.routeDetail?.dealers.first.code, 'KH-BETA');

      // 5. Search by phone
      routeVm.setSearchTarget(SearchTarget.phone);
      routeVm.setSearchQuery('0901234567');
      expect(routeVm.state.routeDetail?.dealers.length, 1);
      expect(routeVm.state.routeDetail?.dealers.first.code, 'KH-ALPHA');

      // 6. Search target all
      routeVm.setSearchTarget(SearchTarget.all);
      routeVm.setSearchQuery('ha noi');
      expect(routeVm.state.routeDetail?.dealers.length, 2);
    });
  });

  group('Search Bar Double Border Prevention Tests', () {
    testWidgets('Search TextField explicitly uses InputBorder.none on all states to prevent double borders', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            inputDecorationTheme: const InputDecorationTheme(
              enabledBorder: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(),
            ),
          ),
          home: Scaffold(
            body: Container(
              height: 42,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
              ),
              child: TextField(
                focusNode: focusNode,
                controller: controller,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: SearchTarget.all.hintText,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                  fillColor: Colors.transparent,
                ),
              ),
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.border, InputBorder.none);
      expect(textField.decoration?.enabledBorder, InputBorder.none);
      expect(textField.decoration?.focusedBorder, InputBorder.none);
      expect(textField.decoration?.filled, isFalse);
      expect(textField.decoration?.fillColor, Colors.transparent);
    });
  });
}
