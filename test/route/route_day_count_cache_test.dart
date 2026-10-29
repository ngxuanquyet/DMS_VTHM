import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';

import '../route_filter_day_of_week_test.dart'
    show MockCustomerRepository, FakeGetRouteDetailUseCase, FakeGetTodayVisitsUseCase;

/// Hàng chip ngày ở màn Tuyến gọi getDealerCountForDay mỗi lần dựng (29/10/2026: tuyến 1.090 điểm của anv lướt giật —
/// chip ngày nằm trong AnimatedBuilder theo cuộn, mỗi khung hình đếm lại 7 ngày × 1.090 điểm).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const days = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
  CustomerEntity c(int i) => CustomerEntity(
        id: i + 1,
        code: 'KH${i + 1}',
        name: 'Điểm ${i + 1}',
        address: 'A',
        route: 'Tuyến ${days[i % 7]}',
        routes: ['Tuyến ${days[i % 7]}'],
        type: 'Tạp hóa',
        contactPerson: 'X',
        phone: '0900000000',
        status: 'active',
        clientUuid: 'u$i',
      );

  Future<(RouteViewModel, MockCustomerRepository)> build() async {
    final repo = MockCustomerRepository()..customers = List.generate(1090, c);
    final vm = RouteViewModel(
      customerRepository: repo,
      getRouteDetailUseCase: FakeGetRouteDetailUseCase(),
      getTodayVisitsUseCase: FakeGetTodayVisitsUseCase(),
    );
    await vm.loadRouteDetail();
    return (vm, repo);
  }

  test('đếm theo ngày đúng, và 60 khung hình (1 giây lướt) đọc lại số đã nhớ — không đếm lại', () async {
    final (vm, _) = await build();

    expect(vm.getDealerCountForDay(null), 1090);
    expect(vm.getDealerCountForDay(1), 156); // 1090 = 7×155 + 5 ⇒ 5 ngày đầu 156
    expect(vm.getDealerCountForDay(7), 155);

    final sw = Stopwatch()..start();
    for (var frame = 0; frame < 60; frame++) {
      for (final d in [null, 1, 2, 3, 4, 5, 6, 7]) {
        vm.getDealerCountForDay(d);
      }
    }
    sw.stop();
    debugPrint('60 khung hình chip ngày: ${sw.elapsedMilliseconds} ms');
    expect(sw.elapsedMilliseconds, lessThan(500)); // bản đếm lại mỗi khung hình: ~1.400 ms trên máy chủ
    vm.dispose();
  });

  test('xoá điểm chờ đồng bộ (sửa danh sách tại chỗ) ⇒ số đếm cập nhật', () async {
    final (vm, _) = await build();
    expect(vm.getDealerCountForDay(1), 156);

    await vm.deletePendingCustomer('u0'); // điểm 1 — Thứ 2

    expect(vm.getDealerCountForDay(1), 155);
    expect(vm.getDealerCountForDay(null), 1089);
    vm.dispose();
  });
}
