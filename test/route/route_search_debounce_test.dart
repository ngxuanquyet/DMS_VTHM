import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';

import '../route_filter_day_of_week_test.dart'
    show MockCustomerRepository, FakeGetRouteDetailUseCase, FakeGetTodayVisitsUseCase;

/// Tìm kiếm màn Tuyến lọc sau khi NGỪNG gõ 250ms; đặt lại bộ lọc (ngăn bộ lọc, màn trống) phải huỷ lượt gõ đang chờ —
/// không thì từ khoá cũ bị áp lại sau khi người dùng đã đặt lại.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<RouteViewModel> buildVm() async {
    final repo = MockCustomerRepository()
      ..customers = [
        CustomerEntity(id: 1, code: 'KH1', name: 'Đại lý Hoàng Mai', address: 'A', route: 'T1', type: 'Đại lý', contactPerson: 'X', phone: '0900000000', status: 'active'),
        CustomerEntity(id: 2, code: 'KH2', name: 'Tạp hoá Cầu Giấy', address: 'B', route: 'T1', type: 'Tạp hóa', contactPerson: 'X', phone: '0900000000', status: 'active'),
      ];
    final vm = RouteViewModel(
      customerRepository: repo,
      getRouteDetailUseCase: FakeGetRouteDetailUseCase(),
      getTodayVisitsUseCase: FakeGetTodayVisitsUseCase(),
    );
    await vm.loadRouteDetail();
    return vm;
  }

  test('gõ xong 250ms mới lọc', () async {
    final vm = await buildVm();
    vm.setSearchQueryDebounced('hoang mai');
    expect(vm.debugState.searchQuery, '');
    expect(vm.debugState.routeDetail!.dealers.length, 2);

    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(vm.debugState.searchQuery, 'hoang mai');
    expect(vm.debugState.routeDetail!.dealers.map((d) => d.code), ['KH1']);
    vm.dispose();
  });

  test('đặt lại bộ lọc trong lúc lượt gõ còn chờ ⇒ từ khoá cũ KHÔNG bị áp lại', () async {
    final vm = await buildVm();
    vm.setSearchQueryDebounced('hoang mai');
    vm.resetFilters();

    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(vm.debugState.searchQuery, '');
    expect(vm.debugState.routeDetail!.dealers.length, 2);
    vm.dispose();
  });
}
