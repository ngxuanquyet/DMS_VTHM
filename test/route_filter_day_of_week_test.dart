import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_dynamic_column.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_meta_entity.dart';
import 'package:vthm_dms/features/customer/domain/repositories/customer_repository.dart';
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
  Future<Map<String, dynamic>> uploadCustomerPhoto(
    String filePath, {
    String? locationName,
    double? lat,
    double? lng,
  }) async => {};

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

  late MockCustomerRepository mockCustomerRepo;
  late FakeGetRouteDetailUseCase fakeGetRouteDetail;
  late FakeGetTodayVisitsUseCase fakeGetTodayVisits;

  final mondayCustomer = CustomerEntity(
    id: 1,
    code: 'KH-T2',
    name: 'Đại lý Thứ 2',
    contactPerson: 'Nguyễn Văn Hai',
    phone: '0901111111',
    address: '123 Đường T2',
    route: 'Tuyến Thứ 2',
    routes: ['Tuyến Thứ 2'],
    routeIds: [20],
    type: 'Đại lý',
    status: 'active',
  );

  final saturdayCustomer = CustomerEntity(
    id: 2,
    code: 'KH-T7',
    name: 'Điểm bán Thứ 7 Vừa Tạo',
    contactPerson: 'Trần Văn Bảy',
    phone: '0907777777',
    address: '789 Đường T7',
    route: 'Tuyến Thứ 7',
    routes: ['Tuyến Thứ 7'],
    routeIds: [70],
    type: 'Tạp hóa',
    status: 'active',
  );

  setUp(() {
    mockCustomerRepo = MockCustomerRepository()
      ..customers = [mondayCustomer, saturdayCustomer];
    fakeGetRouteDetail = FakeGetRouteDetailUseCase();
    fakeGetTodayVisits = FakeGetTodayVisitsUseCase();
  });

  group('Route Day of Week Filtering Tests', () {
    test('Filtering Monday (day: 1) only shows Monday customer, NOT Saturday customer', () async {
      final vm = RouteViewModel(
        customerRepository: mockCustomerRepo,
        getRouteDetailUseCase: fakeGetRouteDetail,
        getTodayVisitsUseCase: fakeGetTodayVisits,
      );

      await vm.loadRouteDetail();

      // Trước khi lọc ngày: Cả 2 điểm bán đều xuất hiện
      expect(vm.state.routeDetail?.dealers.length, 2);

      // Lọc tuyến Thứ 2 (day = 1)
      vm.selectDayOfWeek(1);

      expect(vm.state.selectedDayOfWeek, 1);
      final dealers = vm.state.routeDetail?.dealers ?? [];
      expect(dealers.length, 1);
      expect(dealers.first.name, 'Đại lý Thứ 2');
      expect(dealers.any((d) => d.name == 'Điểm bán Thứ 7 Vừa Tạo'), isFalse);
    });

    test('Filtering Saturday (day: 6) only shows Saturday customer', () async {
      final vm = RouteViewModel(
        customerRepository: mockCustomerRepo,
        getRouteDetailUseCase: fakeGetRouteDetail,
        getTodayVisitsUseCase: fakeGetTodayVisits,
      );

      await vm.loadRouteDetail();

      // Lọc tuyến Thứ 7 (day = 6)
      vm.selectDayOfWeek(6);

      expect(vm.state.selectedDayOfWeek, 6);
      final dealers = vm.state.routeDetail?.dealers ?? [];
      expect(dealers.length, 1);
      expect(dealers.first.name, 'Điểm bán Thứ 7 Vừa Tạo');
      expect(dealers.any((d) => d.name == 'Đại lý Thứ 2'), isFalse);
    });

    test('getDealerCountForDay counts accurately per day of week', () async {
      final vm = RouteViewModel(
        customerRepository: mockCustomerRepo,
        getRouteDetailUseCase: fakeGetRouteDetail,
        getTodayVisitsUseCase: fakeGetTodayVisits,
      );

      await vm.loadRouteDetail();

      expect(vm.getDealerCountForDay(null), 2); // Tất cả
      expect(vm.getDealerCountForDay(1), 1);    // Thứ 2
      expect(vm.getDealerCountForDay(2), 0);    // Thứ 3
      expect(vm.getDealerCountForDay(3), 0);    // Thứ 4
      expect(vm.getDealerCountForDay(4), 0);    // Thứ 5
      expect(vm.getDealerCountForDay(5), 0);    // Thứ 6
      expect(vm.getDealerCountForDay(6), 1);    // Thứ 7
      expect(vm.getDealerCountForDay(7), 0);    // Chủ nhật
    });

    test('CustomerEntity.extractDayOfWeekFromName parses various Vietnamese formats', () {
      expect(CustomerEntity.extractDayOfWeekFromName('Tuyến Thứ 2'), 1);
      expect(CustomerEntity.extractDayOfWeekFromName('T2'), 1);
      expect(CustomerEntity.extractDayOfWeekFromName('T-2'), 1);
      expect(CustomerEntity.extractDayOfWeekFromName('tuyen_t2'), 1);
      expect(CustomerEntity.extractDayOfWeekFromName('Thứ Hai'), 1);

      expect(CustomerEntity.extractDayOfWeekFromName('Tuyến Thứ 3'), 2);
      expect(CustomerEntity.extractDayOfWeekFromName('T3'), 2);

      expect(CustomerEntity.extractDayOfWeekFromName('T4'), 3);
      expect(CustomerEntity.extractDayOfWeekFromName('Thứ Tư'), 3);

      expect(CustomerEntity.extractDayOfWeekFromName('T5'), 4);
      expect(CustomerEntity.extractDayOfWeekFromName('Thứ Năm'), 4);

      expect(CustomerEntity.extractDayOfWeekFromName('T6'), 5);
      expect(CustomerEntity.extractDayOfWeekFromName('Thứ Sáu'), 5);

      expect(CustomerEntity.extractDayOfWeekFromName('Tuyến Thứ 7'), 6);
      expect(CustomerEntity.extractDayOfWeekFromName('T7'), 6);
      expect(CustomerEntity.extractDayOfWeekFromName('tuyen_t7'), 6);
      expect(CustomerEntity.extractDayOfWeekFromName('Thứ Bảy'), 6);

      expect(CustomerEntity.extractDayOfWeekFromName('Chủ Nhật'), 7);
      expect(CustomerEntity.extractDayOfWeekFromName('CN'), 7);
    });

    test('CustomerEntity.matchesDayOfWeek works with UserRouteEntity visitDayOfWeek', () {
      const saturdayUserRoute = UserRouteEntity(
        id: 70,
        name: 'Vũ Tùng Dương - Thứ 7',
        code: 'VTD-T7',
        visitDayOfWeek: 6,
      );

      expect(saturdayCustomer.matchesDayOfWeek(1, userRoutes: [saturdayUserRoute]), isFalse);
      expect(saturdayCustomer.matchesDayOfWeek(6, userRoutes: [saturdayUserRoute]), isTrue);
    });
  });
}
