import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/route/data/services/route_api_service.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';
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

  CustomerEntity c(int id, List<int> routeIds) => CustomerEntity(
        id: id,
        code: 'KH$id',
        name: 'Điểm $id',
        address: 'A',
        route: '',
        routeIds: routeIds,
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
}
