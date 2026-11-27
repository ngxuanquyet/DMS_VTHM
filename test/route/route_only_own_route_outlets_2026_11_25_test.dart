import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/customer/data/models/customer_dto.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/route/data/services/route_api_service.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';
import 'package:vthm_dms/features/route/presentation/states/route_state.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';

import '../customer_filter_test.dart' show FakeRouteApiService;
import '../route_filter_day_of_week_test.dart'
    show MockCustomerRepository, FakeGetRouteDetailUseCase, FakeGetTodayVisitsUseCase;

/// Màn Tuyến của nhân viên CÓ tuyến riêng chỉ hiện điểm bán thuộc tuyến của mình (chủ hệ thống chốt 25/11/2026).
///
/// Prod 23–25/11/2026: 6 nhân viên bấm check-in 69 lần vào điểm bán MobiWork GIAO cho họ nhưng nằm trong tuyến người khác
/// (hoặc không tuyến nào) ⇒ server 422 "Điểm bán này không thuộc tuyến nào được giao cho bạn". `/crm/customers/mine` trả
/// điểm được giao ∪ tự tạo ∪ trong tuyến; mảng `routes` của mỗi điểm chỉ gồm tuyến đang hoạt động CỦA người gọi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CustomerEntity c(int id, List<int> routeIds, {bool area = false, bool dept = false}) => CustomerEntity(
        id: id,
        code: 'KH$id',
        name: 'Điểm $id',
        address: 'A',
        route: '',
        routeIds: routeIds,
        inCareArea: area,
        inDepartment: dept,
        type: 'Tạp hóa',
        contactPerson: 'X',
        phone: '0900000000',
        status: 'active',
        clientUuid: 'u$id',
      );

  Future<RouteViewModel> build(List<UserRouteEntity> myRoutes, List<CustomerEntity> customers) async {
    final repo = MockCustomerRepository()..customers = customers;
    final vm = RouteViewModel(
      customerRepository: repo,
      getRouteDetailUseCase: FakeGetRouteDetailUseCase(),
      getTodayVisitsUseCase: FakeGetTodayVisitsUseCase(),
      routeApiService: FakeRouteApiService(myRoutes) as RouteApiService,
    );
    await vm.loadRouteDetail();
    return vm;
  }

  test('NV có tuyến riêng: điểm được giao nhưng ngoài tuyến của mình không hiện ở màn Tuyến', () async {
    final vm = await build(
      const [UserRouteEntity(id: 10, name: 'Tuyến Thứ 2'), UserRouteEntity(id: 11, name: 'Tuyến Thứ 3')],
      [c(1, [10]), c(2, [11]), c(3, const []), c(4, const [])],
    );

    expect(vm.getDealerCountForDay(null), 2);
    vm.dispose();
  });

  test('NV không có tuyến riêng: giữ cả danh sách (điểm bán theo phòng, #25830)', () async {
    final vm = await build(const [], [c(1, const []), c(2, const []), c(3, const [])]);

    expect(vm.getDealerCountForDay(null), 3);
    vm.dispose();
  });

  test('Khu vực chăm sóc (One #25938): NV có tuyến riêng vẫn thấy điểm bán khu vực; ba nguồn lọc đúng', () async {
    final vm = await build(
      const [UserRouteEntity(id: 10, name: 'Tuyến Thứ 2')],
      // 1 trên tuyến · 2 trên tuyến + khu vực · 3,4 chỉ khu vực · 5 được giao ngoài tuyến, ngoài khu vực (bị bỏ như cũ)
      [c(1, [10]), c(2, [10], area: true), c(3, const [], area: true), c(4, const [], area: true), c(5, const [])],
    );

    expect(vm.getDealerCountForDay(null), 4);
    expect(vm.getDealerCountForCareScope(CareScope.all), 4);
    expect(vm.getDealerCountForCareScope(CareScope.area), 3);
    expect(vm.getDealerCountForCareScope(CareScope.plan), 2);

    vm.selectCareScope(CareScope.area);
    expect(vm.state.routeDetail!.dealers.map((d) => d.name).toSet(), {'Điểm 2', 'Điểm 3', 'Điểm 4'});
    vm.selectCareScope(CareScope.plan);
    expect(vm.state.routeDetail!.dealers.map((d) => d.name).toSet(), {'Điểm 1', 'Điểm 2'});
    vm.resetFilters();
    expect(vm.state.careScope, CareScope.all);
    vm.dispose();
  });

  test('Khu vực chăm sóc: NV không có tuyến riêng — «Kế hoạch chăm sóc» = điểm bán không đến từ khu vực', () async {
    final vm = await build(const [], [c(1, const []), c(2, const [], area: true), c(3, const [], area: true)]);

    expect(vm.getDealerCountForCareScope(CareScope.all), 3);
    expect(vm.getDealerCountForCareScope(CareScope.area), 2);
    expect(vm.getDealerCountForCareScope(CareScope.plan), 1);
    vm.dispose();
  });

  test('Trưởng phòng có tuyến riêng: điểm bán của phòng (cờ in_department) giữ lại, CHỈ nằm trong «Tất cả» (chốt 27/11/2026)', () async {
    final vm = await build(
      const [UserRouteEntity(id: 10, name: 'Tuyến Thứ 2')],
      // 1 trên tuyến · 2 của phòng · 3 của phòng + khu vực · 4 được giao ngoài tuyến / phòng (bỏ như cũ)
      [c(1, [10]), c(2, const [], dept: true), c(3, const [], dept: true, area: true), c(4, const [])],
    );

    expect(vm.getDealerCountForCareScope(CareScope.all), 3);
    expect(vm.getDealerCountForCareScope(CareScope.plan), 1, reason: 'điểm bán của phòng không vào Kế hoạch chăm sóc');
    expect(vm.getDealerCountForCareScope(CareScope.area), 1);
    vm.dispose();
  });

  test('CustomerDto bỏ «tuyến ảo» id âm của server, đọc cờ in_department', () {
    final e = CustomerDto.fromJson({
      'id': 9,
      'code': 'X9',
      'name': 'Điểm 9',
      'routes': [
        {'id': 10, 'name': 'Tuyến Thứ 2'},
        {'id': -1, 'name': 'Điểm bán của phòng'},
      ],
      'in_department': true,
    }).toEntity();
    expect(e.routeIds, [10]);
    expect(e.routes, isNot(contains('Điểm bán của phòng')));
    expect(e.inDepartment, isTrue);
  });
}
