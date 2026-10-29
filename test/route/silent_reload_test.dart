import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/customer/presentation/viewmodels/customer_view_model.dart';
import 'package:vthm_dms/features/route/presentation/states/route_state.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';

import '../route_filter_day_of_week_test.dart'
    show MockCustomerRepository, FakeGetRouteDetailUseCase, FakeGetTodayVisitsUseCase;

/// Tải ngầm danh sách điểm bán xong ⇒ màn nạp lại NGẦM (29/10/2026, tuyến 1.090 điểm của anv hiện 199).
/// Nạp ngầm chỉ thay danh sách điểm bán — không đối chiếu lại lượt viếng thăm (có thể huỷ nhầm lượt vừa check-in),
/// không lấy tập con theo từ khoá đang gõ.

class _CountingTodayVisits extends FakeGetTodayVisitsUseCase {
  int calls = 0;
  @override
  Future<List<VisitEntity>> call() async {
    calls++;
    return [];
  }
}

class _GatedTodayVisits extends FakeGetTodayVisitsUseCase {
  Completer<void> gate;
  List<VisitEntity> result;
  _GatedTodayVisits(this.gate, this.result);
  @override
  Future<List<VisitEntity>> call() async {
    await gate.future;
    return result;
  }
}

class _QueryRecordingRepository extends MockCustomerRepository {
  final List<String?> queries = [];
  @override
  Future<List<CustomerEntity>> getCustomers({
    int page = 1,
    int perPage = 100,
    String? query,
    bool forceRefresh = false,
  }) async {
    queries.add(query);
    return query == null ? customers : customers.where((c) => c.name.contains(query)).toList();
  }
}

CustomerEntity _c(int id, String name) => CustomerEntity(
      id: id,
      code: 'KH$id',
      name: name,
      address: 'A',
      route: 'T1',
      type: 'Tạp hóa',
      contactPerson: 'X',
      phone: '0900000000',
      status: 'active',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('màn Tuyến nạp ngầm: có điểm bán mới, KHÔNG gọi lại lượt viếng thăm, giữ lượt đang mở', () async {
    final repo = MockCustomerRepository()..customers = [_c(1, 'A')];
    final visits = _CountingTodayVisits();
    final vm = RouteViewModel(
      customerRepository: repo,
      getRouteDetailUseCase: FakeGetRouteDetailUseCase(),
      getTodayVisitsUseCase: visits,
    );
    await vm.loadRouteDetail();
    final callsBefore = visits.calls;

    final open = VisitEntity(id: 77, customerId: 1, customerName: 'A', checkinAt: DateTime.now());
    vm.setActiveVisit(open); // vừa check-in

    repo.customers = [_c(1, 'A'), _c(2, 'B'), _c(3, 'C')];
    await vm.loadRouteDetail(silent: true);

    expect(visits.calls, callsBefore);
    expect(vm.debugState.activeVisit?.id, 77);
    expect(vm.debugState.routeDetail!.dealers.length, 3);
    vm.dispose();
  });

  test('lượt nạp ngầm chen vào lúc lượt THƯỜNG đang chạy: bị bỏ, lượt thường vẫn áp lượt viếng thăm mới, không kẹt tải', () async {
    final repo = MockCustomerRepository()..customers = [_c(1, 'A')];
    final gate = Completer<void>();
    final visits = _GatedTodayVisits(gate, []);
    final vm = RouteViewModel(
      customerRepository: repo,
      getRouteDetailUseCase: FakeGetRouteDetailUseCase(),
      getTodayVisitsUseCase: visits,
    );
    await Future<void>.delayed(Duration.zero);
    gate.complete(); // lượt nạp lúc dựng VM xong
    await vm.loadRouteDetail();

    final gate2 = Completer<void>();
    visits
      ..gate = gate2
      ..result = [VisitEntity(id: 88, customerId: 1, customerName: 'A', checkinAt: DateTime.now())]; // vừa check-in
    final normal = vm.loadRouteDetail(isRefresh: true); // vd sau check-in
    await vm.loadRouteDetail(silent: true); // tải ngầm xong chen vào
    gate2.complete();
    await normal;

    expect(vm.debugState.status, RouteStatus.loaded);
    expect(vm.debugState.activeVisit?.id, 88);
    vm.dispose();
  });

  test('lượt thường đã đọc bản CŨ (199) thì tải ngầm xong giữa chừng ⇒ khi lượt thường xong, màn vẫn lên bản MỚI', () async {
    final repo = MockCustomerRepository()..customers = List.generate(199, (i) => _c(i + 1, 'Điểm ${i + 1}'));
    final gate = Completer<void>()..complete();
    final visits = _GatedTodayVisits(gate, []);
    final vm = RouteViewModel(
      customerRepository: repo,
      getRouteDetailUseCase: FakeGetRouteDetailUseCase(),
      getTodayVisitsUseCase: visits,
    );
    await vm.loadRouteDetail();

    final gate2 = Completer<void>();
    visits.gate = gate2;
    final normal = vm.loadRouteDetail(); // đọc 199 rồi chờ mạng (lượt viếng thăm)
    await Future<void>.delayed(Duration.zero);
    repo.customers = List.generate(1090, (i) => _c(i + 1, 'Điểm ${i + 1}')); // tải ngầm ghi xong
    await vm.loadRouteDetail(silent: true); // báo tới lúc lượt thường còn chạy
    gate2.complete();
    await normal;
    await Future<void>.delayed(const Duration(milliseconds: 20)); // lượt ngầm chờ được chạy lại

    expect(vm.debugState.routeDetail!.dealers.length, 1090);
    vm.dispose();
  });

  test('màn Danh sách nạp ngầm khi đang gõ từ khoá vẫn lấy ĐỦ danh sách', () async {
    final repo = _QueryRecordingRepository()..customers = [_c(1, 'Hoàng Mai'), _c(2, 'Cầu Giấy')];
    final vm = CustomerViewModel(repo);
    await vm.loadCustomers();
    vm.setSearchQuery('Hoàng');

    await vm.loadCustomers(silent: true);

    expect(repo.queries.last, isNull);
    expect(vm.debugState.allCustomers.length, 2);
    vm.dispose();
  });
}
