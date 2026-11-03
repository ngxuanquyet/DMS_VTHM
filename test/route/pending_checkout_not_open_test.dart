import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/core/network/api_client.dart';
import 'package:vthm_dms/core/utils/system_clock.dart';
import 'package:vthm_dms/features/visit/data/repositories/visit_repository_impl.dart';
import 'package:vthm_dms/features/visit/data/services/visit_api_service.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';
import 'package:vthm_dms/features/visit/domain/usecases/visit_usecases.dart';

import '../route_filter_day_of_week_test.dart' show MockCustomerRepository, FakeGetRouteDetailUseCase;

/// Rà soát offline vòng 2 (#24698), nhóm 4: lượt đã check-out ngoại tuyến (lệnh còn chờ gửi) mà server vẫn trả là "mở" —
/// tuyến KHÔNG được hiện lượt là đang mở (nhân viên vào check-out lần hai, đua với lệnh trong hàng đợi).
class _TodayVisits implements GetTodayVisitsUseCase {
  @override
  Future<List<VisitEntity>> call() async =>
      [VisitEntity(id: 901, customerId: 1, checkinAt: DateTime.now().subtract(const Duration(hours: 1)))];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<RouteViewModel> load(String checkoutState) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory(), 1);
    addTearDown(db.close);
    await db.enqueue(SyncQueueEntriesCompanion.insert(
      entity: 'visit',
      op: 'checkout',
      clientUuid: 'co-1',
      parentUuid: const Value('visit-uuid'),
      payload: '{"visit_id":901}',
      state: Value(checkoutState),
      createdAt: DateTime.now().millisecondsSinceEpoch,
      createdElapsed: SystemClock.nowMonotonicMs,
      bootId: SystemClock.bootId,
    ));
    final provider = Provider<RouteViewModel>((ref) => RouteViewModel(
          customerRepository: MockCustomerRepository(),
          getRouteDetailUseCase: FakeGetRouteDetailUseCase(),
          getTodayVisitsUseCase: _TodayVisits(),
          ref: ref,
        ));
    final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    final vm = container.read(provider);
    await vm.loadRouteDetail();
    return vm;
  }

  test('check-out chờ gửi ⇒ lượt hiện đã check-out, không phải lượt đang mở', () async {
    final vm = await load('pending');
    expect(vm.state.activeVisit, isNull, reason: 'lỗi cũ: lượt server còn "mở" được chọn làm lượt đang mở');
    expect(vm.state.todayVisits.single.isOpen, isFalse);
  });

  test('check-out bị từ chối hẳn (dead) ⇒ lượt hiện lại là đang mở để đóng lại', () async {
    final vm = await load('dead');
    expect(vm.state.activeVisit?.id, 901);
  });

  test('check-out lượt A ngoại tuyến rồi ghé lại CÙNG điểm bán ⇒ lượt mới (bản lưu) KHÔNG bị xoá', () async {
    SharedPreferences.setMockInitialValues({
      'vthm_user_data': '{"id":1}',
    });
    final db = AppDatabase(NativeDatabase.memory(), 1);
    addTearDown(db.close);
    await db.enqueue(SyncQueueEntriesCompanion.insert(
      entity: 'visit',
      op: 'checkout',
      clientUuid: 'co-1',
      parentUuid: const Value('visit-uuid'),
      payload: '{"visit_id":901}',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      createdElapsed: SystemClock.nowMonotonicMs,
      bootId: SystemClock.bootId,
    ));
    final repo = VisitRepositoryImpl(VisitApiService(ApiClient(Dio())));
    await repo.saveActiveVisit(VisitEntity(
        id: -5, customerId: 1, checkinAt: DateTime.now(), checkinAtRaw: DateTime.now().toIso8601String(), clientUuid: 'visit-new'));
    final provider = Provider<RouteViewModel>((ref) => RouteViewModel(
          customerRepository: MockCustomerRepository(),
          getRouteDetailUseCase: FakeGetRouteDetailUseCase(),
          getTodayVisitsUseCase: _TodayVisits(),
          visitRepository: repo,
          ref: ref,
        ));
    final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    final vm = container.read(provider);
    await vm.loadRouteDetail();
    expect(vm.state.activeVisit?.id, -5);
    expect((await repo.getActiveVisit())?.id, -5, reason: 'lỗi: lượt cũ "đóng tạm" bị coi là server đã đóng ⇒ xoá bản lưu');
  });

  test('lượt cũ ở cùng điểm bán ĐÃ đóng trên server (check-in trước) không xoá lượt mới ghé lại (bản lưu)', () async {
    SharedPreferences.setMockInitialValues({'vthm_user_data': '{"id":1}'});
    final db = AppDatabase(NativeDatabase.memory(), 1);
    addTearDown(db.close);
    final repo = VisitRepositoryImpl(VisitApiService(ApiClient(Dio())));
    final now = DateTime.now();
    await repo.saveActiveVisit(VisitEntity(
        id: -6, customerId: 1, checkinAt: now, checkinAtRaw: now.toIso8601String(), clientUuid: 'visit-new2'));
    final provider = Provider<RouteViewModel>((ref) => RouteViewModel(
          customerRepository: MockCustomerRepository(),
          getRouteDetailUseCase: FakeGetRouteDetailUseCase(),
          getTodayVisitsUseCase: _ClosedEarlier(now),
          visitRepository: repo,
          ref: ref,
        ));
    final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    final vm = container.read(provider);
    await vm.loadRouteDetail();
    expect((await repo.getActiveVisit())?.id, -6);
  });
}

class _ClosedEarlier implements GetTodayVisitsUseCase {
  final DateTime now;
  _ClosedEarlier(this.now);
  @override
  Future<List<VisitEntity>> call() async => [
        VisitEntity(
          id: 900,
          customerId: 1,
          checkinAt: now.subtract(const Duration(hours: 1)),
          checkoutAt: now.subtract(const Duration(minutes: 30)),
        ),
      ];
}
