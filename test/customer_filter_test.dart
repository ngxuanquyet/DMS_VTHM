import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_dynamic_column.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_meta_entity.dart';
import 'package:vthm_dms/features/customer/domain/repositories/customer_repository.dart';
import 'package:vthm_dms/features/customer/presentation/viewmodels/customer_view_model.dart';
import 'package:vthm_dms/features/customer/presentation/widgets/customer_card.dart';
import 'package:vthm_dms/features/customer/presentation/widgets/customer_filter_bottom_sheet.dart';
import 'package:vthm_dms/features/customer/presentation/widgets/customer_filter_drawer.dart';
import 'package:vthm_dms/features/customer/presentation/screens/customer_screen.dart';
import 'package:vthm_dms/features/customer/data/repositories/customer_repository_impl.dart';
import 'package:vthm_dms/features/route/data/services/route_api_service.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';

class FakeRouteApiService extends Fake implements RouteApiService {
  final List<UserRouteEntity> mockRoutes;
  FakeRouteApiService(this.mockRoutes);

  @override
  Future<List<UserRouteEntity>> getMyRoutes() async => mockRoutes;
}

class FakeCustomerRepository implements CustomerRepository {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Customer Filter & Multi-Criteria Filtering Tests', () {
    late FakeCustomerRepository fakeRepo;
    late CustomerViewModel vm;

    final customer1 = CustomerEntity(
      id: 1,
      name: 'Đại lý An Nhiên',
      code: 'KH001',
      address: 'Hà Nội',
      phone: '0901111111',
      contactPerson: 'Nguyễn Văn A',
      route: 'Tuyến T2',
      type: 'Đại lý Cấp 1',
      channelName: 'GT',
      syncStatus: 'synced',
      status: 'active',
      isToday: true,
      visitStatus: CustomerVisitStatus.visited,
    );

    final customer2 = CustomerEntity(
      id: 2,
      name: 'Tạp hóa Bình Minh',
      code: 'KH002',
      address: 'Hải Phòng',
      phone: '0902222222',
      contactPerson: 'Trần Thị B',
      route: 'Tuyến T3',
      type: 'Tạp hóa',
      channelName: 'MT',
      syncStatus: 'synced',
      status: 'active',
      isToday: false,
      visitStatus: CustomerVisitStatus.pending,
    );

    final customer3Pending = CustomerEntity(
      id: 0,
      clientUuid: 'pending-uuid-333',
      name: 'Siêu thị Mini Chờ Đồng Bộ',
      code: 'PENDING_333',
      address: 'Đà Nẵng',
      phone: '0903333333',
      contactPerson: 'Lê Văn C',
      route: 'Tuyến T2',
      type: 'Siêu thị',
      channelName: 'GT',
      syncStatus: 'pending',
      status: 'active',
      isToday: true,
      visitStatus: CustomerVisitStatus.pending,
    );

    setUp(() {
      fakeRepo = FakeCustomerRepository()
        ..customers = [customer1, customer2, customer3Pending];
      vm = CustomerViewModel(fakeRepo);
    });

    test('Initial counts and metadata are computed correctly', () async {
      await vm.loadCustomers();

      expect(vm.state.totalCount, 3);
      expect(vm.state.pendingSyncCount, 1);
      expect(vm.state.todayCount, 2);
      expect(vm.state.visitedCount, 1);
      expect(vm.state.pendingCount, 2);

      expect(vm.state.availableRoutes, containsAll(['Tất cả tuyến', 'Tuyến T2', 'Tuyến T3']));
      expect(vm.state.availableCustomerTypes, containsAll(['Tất cả loại', 'Đại lý Cấp 1', 'Tạp hóa', 'Siêu thị']));
      expect(vm.state.availableChannels, containsAll(['Tất cả kênh', 'GT', 'MT']));
    });

    test('Filtering by tab: pendingSync tab only returns pending customers', () async {
      await vm.loadCustomers();

      final container = ProviderContainer(
        overrides: [
          customerViewModelProvider.overrideWith((ref) => vm),
        ],
      );

      // Default: all
      var list = container.read(filteredCustomersProvider);
      expect(list.length, 3);

      // Select pendingSync
      vm.selectTab(CustomerFilterTab.pendingSync);
      list = container.read(filteredCustomersProvider);
      expect(list.length, 1);
      expect(list.first.customer.name, 'Siêu thị Mini Chờ Đồng Bộ');
      expect(list.first.customer.syncStatus, 'pending');

      // Select today
      vm.selectTab(CustomerFilterTab.today);
      list = container.read(filteredCustomersProvider);
      expect(list.length, 2);

      // Select visited
      vm.selectTab(CustomerFilterTab.visited);
      list = container.read(filteredCustomersProvider);
      expect(list.length, 1);
      expect(list.first.customer.id, 1);
    });

    test('Multi-criteria filtering by route and channel', () async {
      await vm.loadCustomers();

      final container = ProviderContainer(
        overrides: [
          customerViewModelProvider.overrideWith((ref) => vm),
        ],
      );

      // Filter by Route 'Tuyến T2'
      vm.selectRoute('Tuyến T2');
      var list = container.read(filteredCustomersProvider);
      expect(list.length, 2);

      // Filter by Channel 'GT'
      vm.selectChannel('GT');
      list = container.read(filteredCustomersProvider);
      expect(list.length, 2);

      // Filter by Channel 'MT' -> should be empty for Tuyến T2
      vm.selectChannel('MT');
      list = container.read(filteredCustomersProvider);
      expect(list.length, 0);

      // Reset filters
      vm.resetFilters();
      list = container.read(filteredCustomersProvider);
      expect(list.length, 3);
      expect(vm.state.activeFiltersCount, 0);
    });
  });

  group('CustomerCard Layout Overflow Verification Tests', () {
    testWidgets('Pending customer card renders code, status and directions without RenderFlex overflow', (tester) async {
      final pendingCustomer = CustomerEntity(
        id: 0,
        clientUuid: 'pending-uuid-test',
        name: 'Cửa Hàng Tạp Hóa Rất Dài Không Bị Tràn Chữ Ra Ngoài Thẻ Điểm Bán',
        code: 'PENDING_ABCDEF123456',
        address: 'Số 999 Đường Giải Phóng, Phường Giáp Bát, Quận Hoàng Mai, Hà Nội',
        phone: '0988776655',
        contactPerson: 'Trịnh Văn Long',
        route: 'Tuyến T2',
        type: 'Đại lý Cấp 1',
        syncStatus: 'pending',
        lat: 21.0,
        lng: 105.8,
      );

      // Constrain screen to a narrow mobile width (320px) to verify zero overflow
      tester.view.physicalSize = const Size(320 * 2, 600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FlutterErrorDetails? errorDetails;
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errorDetails = details;
      };

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CustomerCard.fromCustomer(
                  customer: pendingCustomer,
                  distance: 1250,
                  distanceText: '1.3 km',
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = previousOnError;
      }

      expect(errorDetails, isNull);
      expect(find.text('PENDING_ABCDEF123456'), findsOneWidget);
      expect(find.text('Chờ đồng bộ'), findsOneWidget);
      expect(find.text('1.3 km'), findsOneWidget);
      expect(find.text('Chỉ đường'), findsOneWidget);
    });

    testWidgets('CustomerFilterBottomSheet renders and triggers onApply / onReset', (tester) async {
      String? appliedRoute;
      String? appliedType;
      String? appliedChannel;
      bool resetCalled = false;

      final testState = CustomerState(
        allCustomers: [
          CustomerEntity(
            id: 1,
            code: 'KH01',
            name: 'Điểm 1',
            route: 'Tuyến Bắc',
            type: 'NPP',
            channelName: 'GT',
            address: 'Hà Nội',
            phone: '091',
            contactPerson: 'Anh Bình',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    CustomerFilterBottomSheet.show(
                      context,
                      state: testState,
                      onApply: (r, t, c) {
                        appliedRoute = r;
                        appliedType = t;
                        appliedChannel = c;
                      },
                      onReset: () {
                        resetCalled = true;
                      },
                    );
                  },
                  child: const Text('Open Filter'),
                );
              },
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Filter'));
      await tester.pumpAndSettle();

      expect(find.text('Bộ lọc nâng cao'), findsOneWidget);
      expect(find.text('Tuyến khách hàng'), findsOneWidget);
      expect(find.text('Loại khách hàng'), findsOneWidget);
      expect(find.text('Kênh bán hàng'), findsOneWidget);

      // Tap Apply
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();

      expect(appliedRoute, isNull); // default was 'Tất cả tuyến' -> null
      expect(appliedType, isNull);
      expect(appliedChannel, isNull);
      expect(resetCalled, isFalse);
    });

    testWidgets('CustomerFilterDrawer renders and applies filters correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final scaffoldKey = GlobalKey<ScaffoldState>();
      final vm = CustomerViewModel(FakeCustomerRepository());
      final testState = CustomerState(
        allCustomers: [
          CustomerEntity(
            id: 1,
            code: 'KH01',
            name: 'Điểm 1',
            route: 'Tuyến Bắc',
            type: 'NPP',
            channelName: 'GT',
            address: 'Hà Nội',
            phone: '091',
            contactPerson: 'Anh Bình',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: scaffoldKey,
            endDrawer: CustomerFilterDrawer(
              state: testState,
              vm: vm,
            ),
            body: Center(
              child: ElevatedButton(
                onPressed: () => scaffoldKey.currentState?.openEndDrawer(),
                child: const Text('Open Drawer'),
              ),
            ),
          ),
        ),
      );

      // Open drawer
      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();

      expect(find.text('Bộ lọc khách hàng'), findsOneWidget);
      expect(find.text('Trạng thái điểm bán'), findsOneWidget);
      expect(find.text('Tuyến khách hàng'), findsOneWidget);
      expect(find.text('Loại khách hàng'), findsOneWidget);
      expect(find.text('Kênh phân phối'), findsOneWidget);
      expect(find.text('Sắp xếp khoảng cách'), findsOneWidget);

      // Tap Apply
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();

      // Drawer closed
      expect(find.text('Bộ lọc khách hàng'), findsNothing);
    });

    test('Customer with multiple routes is included in availableRoutes and matched when filtering', () async {
      final multiRouteCustomer = CustomerEntity(
        id: 99,
        code: 'KH099',
        name: 'Đại lý Hai Tuyến',
        route: 'Tuyến T2, Tuyến T4',
        routes: const ['Tuyến T2', 'Tuyến T4'],
        routeIds: const [5, 9],
        type: 'Đại lý',
        channelName: 'GT',
        address: 'Hà Nội',
        phone: '0909999999',
        contactPerson: 'Anh Đa Tuyến',
      );

      final repo = FakeCustomerRepository()..customers = [multiRouteCustomer];
      final vm = CustomerViewModel(repo);
      await vm.loadCustomers();

      // availableRoutes should extract individual customer routes
      expect(vm.state.availableRoutes, containsAll(['Tất cả tuyến', 'Tuyến T2', 'Tuyến T4']));

      final container = ProviderContainer(
        overrides: [
          customerViewModelProvider.overrideWith((ref) => vm),
        ],
      );

      // Filter by Tuyến T2 -> should match
      vm.selectRoute('Tuyến T2');
      var list = container.read(filteredCustomersProvider);
      expect(list.length, 1);
      expect(list.first.customer.id, 99);

      // Filter by Tuyến T4 -> should also match
      vm.selectRoute('Tuyến T4');
      list = container.read(filteredCustomersProvider);
      expect(list.length, 1);
      expect(list.first.customer.id, 99);

      // Filter by Tuyến T3 -> should NOT match
      vm.selectRoute('Tuyến T3');
      list = container.read(filteredCustomersProvider);
      expect(list.length, 0);
    });

    test('CustomerEntity.isInvalidOrProvinceRoute correctly identifies provinces, region codes, and old mock locations', () {
      // 1. Tỉnh / Thành phố / Mã vùng
      expect(CustomerEntity.isInvalidOrProvinceRoute('Tỉnh Vĩnh Phúc'), isTrue);
      expect(CustomerEntity.isInvalidOrProvinceRoute('Thành phố Hà Nội'), isTrue);
      expect(CustomerEntity.isInvalidOrProvinceRoute('08 - Vĩnh Phúc'), isTrue);
      expect(CustomerEntity.isInvalidOrProvinceRoute('0865 - Thành phố Cần Thơ'), isTrue);
      expect(CustomerEntity.isInvalidOrProvinceRoute('Vĩnh Phúc'), isTrue);
      expect(CustomerEntity.isInvalidOrProvinceRoute('Hà Nội'), isTrue);
      expect(CustomerEntity.isInvalidOrProvinceRoute('Chưa phân tuyến'), isTrue);
      expect(CustomerEntity.isInvalidOrProvinceRoute('Tất cả tuyến'), isTrue);
      expect(CustomerEntity.isInvalidOrProvinceRoute('Tuyến mặc định'), isTrue);

      // 2. Mock data cũ có chứa địa danh quận/huyện
      expect(CustomerEntity.isInvalidOrProvinceRoute('Tuyến Phúc Yên – Tiền Châu'), isTrue);
      expect(CustomerEntity.isInvalidOrProvinceRoute('Tuyến Vĩnh Yên Trung tâm'), isTrue);
      expect(CustomerEntity.isInvalidOrProvinceRoute('Tuyến Bình Xuyên'), isTrue);
      expect(CustomerEntity.isInvalidOrProvinceRoute('Tuyến Sóc Sơn Giáp ranh'), isTrue);
      expect(CustomerEntity.isInvalidOrProvinceRoute('Showroom Xuân Hòa'), isTrue);

      // 3. Tuyến hợp lệ thực tế
      expect(CustomerEntity.isInvalidOrProvinceRoute('Tuyến Thứ 2 (T2)'), isFalse);
      expect(CustomerEntity.isInvalidOrProvinceRoute('Tuyến Thứ 3 (T3)'), isFalse);
      expect(CustomerEntity.isInvalidOrProvinceRoute('Vũ Tùng Dương - T2'), isFalse);
      expect(CustomerEntity.isInvalidOrProvinceRoute('Tuyến T2'), isFalse);
      expect(CustomerEntity.isInvalidOrProvinceRoute('Tuyến 01'), isFalse);
    });

    test('CustomerViewModel filters out any province or stale mock names and never displays them in availableRoutes', () async {
      final dirtyCustomers = [
        const CustomerEntity(
          id: 101,
          code: 'KH101',
          name: 'Đại lý Cũ 1',
          route: 'Tỉnh Vĩnh Phúc',
          routes: ['Tỉnh Vĩnh Phúc'],
          type: 'Đại lý',
          address: 'Vĩnh Phúc',
          phone: '0901010101',
          contactPerson: 'Anh Một',
        ),
        const CustomerEntity(
          id: 102,
          code: 'KH102',
          name: 'Đại lý Cũ 2',
          route: 'Tuyến Vĩnh Yên Trung tâm',
          routes: ['Tuyến Vĩnh Yên Trung tâm'],
          type: 'Đại lý',
          address: 'Vĩnh Yên',
          phone: '0902020202',
          contactPerson: 'Anh Hai',
        ),
        const CustomerEntity(
          id: 103,
          code: 'KH103',
          name: 'Đại lý Chuẩn',
          route: 'Tuyến Thứ 2 (T2)',
          routes: ['Tuyến Thứ 2 (T2)'],
          type: 'Đại lý',
          address: 'Hà Nội',
          phone: '0903030303',
          contactPerson: 'Anh Ba',
        ),
      ];

      final repo = FakeCustomerRepository()..customers = dirtyCustomers;
      final vm = CustomerViewModel(repo);
      await vm.loadCustomers();

      final routes = vm.state.availableRoutes;

      // Tuyến chuẩn phải có
      expect(routes, contains('Tất cả tuyến'));
      expect(routes, contains('Tuyến Thứ 2 (T2)'));

      // Tỉnh và mock cũ TUYỆT ĐỐI không được xuất hiện
      expect(routes.contains('Tỉnh Vĩnh Phúc'), isFalse);
      expect(routes.contains('Vĩnh Phúc'), isFalse);
      expect(routes.contains('Tuyến Vĩnh Yên Trung tâm'), isFalse);
      expect(routes.contains('Vĩnh Yên'), isFalse);
      expect(routes.contains('Chưa phân tuyến'), isFalse);
    });

    test('CustomerViewModel resolves routeIds via RouteApiService and excludes provinces', () async {
      final unmappedCustomer = const CustomerEntity(
        id: 201,
        code: 'KH201',
        name: 'Đại lý Theo Route IDs',
        route: '',
        routes: [],
        routeIds: [5, 7],
        type: 'Đại lý',
        address: 'Hà Nội',
        phone: '0905050505',
        contactPerson: 'Anh Năm',
      );

      final fakeRouteService = FakeRouteApiService([
        const UserRouteEntity(
          id: 5,
          code: 'T2',
          name: 'Vũ Tùng Dương - T2',
          visitDayOfWeek: 2,
        ),
        const UserRouteEntity(
          id: 7,
          code: 'T3',
          name: 'Vũ Tùng Dương - T3',
          visitDayOfWeek: 3,
        ),
      ]);

      final repo = FakeCustomerRepository()..customers = [unmappedCustomer];
      final vm = CustomerViewModel(repo, routeApiService: fakeRouteService);
      await vm.loadCustomers();

      final customer = vm.state.allCustomers.first;
      expect(customer.routes, ['Vũ Tùng Dương - T2', 'Vũ Tùng Dương - T3']);
      expect(customer.route, 'Vũ Tùng Dương - T2, Vũ Tùng Dương - T3');

      final routes = vm.state.availableRoutes;
      expect(routes, containsAll(['Tất cả tuyến', 'Vũ Tùng Dương - T2', 'Vũ Tùng Dương - T3']));
      expect(routes.any((r) => r.contains('Vĩnh Phúc') || r.contains('Tỉnh ')), isFalse);
    });

    testWidgets('CustomerScreen updates customer count badge next to title when filtered and when reset', (tester) async {
      final customer1 = CustomerEntity(
        id: 1,
        name: 'Đại lý An Nhiên',
        code: 'KH001',
        address: 'Hà Nội',
        phone: '0901111111',
        contactPerson: 'Nguyễn Văn A',
        route: 'Tuyến Thứ 2 (T2)',
        routes: const ['Tuyến Thứ 2 (T2)'],
        type: 'Đại lý Cấp 1',
        channelName: 'GT',
        status: 'active',
      );
      final customer2 = CustomerEntity(
        id: 2,
        name: 'Tạp hóa Bình Minh',
        code: 'KH002',
        address: 'Hà Nội',
        phone: '0902222222',
        contactPerson: 'Trần Văn B',
        route: 'Tuyến Thứ 2 (T2)',
        routes: const ['Tuyến Thứ 2 (T2)'],
        type: 'Đại lý',
        channelName: 'GT',
        status: 'active',
      );
      final customer3 = CustomerEntity(
        id: 3,
        name: 'NPP Toàn Thắng',
        code: 'KH003',
        address: 'Hà Nội',
        phone: '0903333333',
        contactPerson: 'Lê Văn C',
        route: 'Tuyến Thứ 3 (T3)',
        routes: const ['Tuyến Thứ 3 (T3)'],
        type: 'Nhà Phân Phối',
        channelName: 'KA',
        status: 'active',
      );

      final fakeRepo = FakeCustomerRepository()..customers = [customer1, customer2, customer3];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerRepositoryProvider.overrideWithValue(fakeRepo),
            routeApiServiceProvider.overrideWithValue(FakeRouteApiService([])),
          ],
          child: const MaterialApp(
            home: CustomerScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ban đầu chưa lọc: hiển thị tổng số '3 điểm'
      expect(find.text('3 điểm'), findsOneWidget);
      expect(find.text('Danh sách phụ trách & định vị'), findsOneWidget);

      // Mở bộ lọc và lọc theo Tuyến Thứ 2 (T2)
      final element = tester.element(find.byType(CustomerScreen));
      final container = ProviderScope.containerOf(element);
      container.read(customerViewModelProvider.notifier).selectRoute('Tuyến Thứ 2 (T2)');
      await tester.pumpAndSettle();

      // Đã lọc xong: badge cạnh tiêu đề cập nhật thành '2/3 điểm' và subtitle cập nhật
      expect(find.text('2/3 điểm'), findsOneWidget);
      expect(find.text('Đang hiển thị 2 trên tổng 3 điểm bán'), findsOneWidget);

      // Tiếp tục lọc sang Tuyến Thứ 3 (T3): cập nhật thành '1/3 điểm'
      container.read(customerViewModelProvider.notifier).selectRoute('Tuyến Thứ 3 (T3)');
      await tester.pumpAndSettle();
      expect(find.text('1/3 điểm'), findsOneWidget);
      expect(find.text('Đang hiển thị 1 trên tổng 3 điểm bán'), findsOneWidget);

      // Thiết lập lại bộ lọc: trở lại ban đầu '3 điểm'
      container.read(customerViewModelProvider.notifier).resetFilters();
      await tester.pumpAndSettle();
      expect(find.text('3 điểm'), findsOneWidget);
      expect(find.text('Danh sách phụ trách & định vị'), findsOneWidget);
    });
  });
}
