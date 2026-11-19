import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/core/utils/system_clock.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';
import 'package:vthm_dms/features/visit/domain/usecases/visit_usecases.dart';

import '../route_filter_day_of_week_test.dart' show MockCustomerRepository, FakeGetRouteDetailUseCase;

/// Rà soát 19/11/2026: lượt check-in NGOẠI TUYẾN (id âm) đã check-out trong máy; dòng tạo lượt lên server (id 901) nhưng
/// check-out còn chờ (mang `visit_id` âm). Danh sách lượt của server KHÔNG có `client_uuid` ⇒ chỉ khớp được qua id server
/// của dòng tạo cha — trước đây lượt 901 hiện lại là "đang mở", chặn check-in điểm kế tiếp.
class _ServerVisits implements GetTodayVisitsUseCase {
  @override
  Future<List<VisitEntity>> call() async =>
      [VisitEntity(id: 901, customerId: 1, checkinAt: DateTime.now().subtract(const Duration(hours: 1)))];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<RouteViewModel> load(String op) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory(), 1);
    addTearDown(db.close);
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.enqueue(SyncQueueEntriesCompanion.insert(
      entity: 'visit',
      op: 'create',
      clientUuid: 'visit-uuid',
      payload: '{}',
      state: const Value('done'),
      serverId: const Value(901),
      createdAt: now,
      createdElapsed: SystemClock.nowMonotonicMs,
      bootId: SystemClock.bootId,
    ));
    await db.enqueue(SyncQueueEntriesCompanion.insert(
      entity: 'visit',
      op: op,
      clientUuid: 'close-1',
      parentUuid: const Value('visit-uuid'),
      payload: '{"visit_id":-3}',
      createdAt: now,
      createdElapsed: SystemClock.nowMonotonicMs,
      bootId: SystemClock.bootId,
    ));
    final provider = Provider<RouteViewModel>((ref) => RouteViewModel(
          customerRepository: MockCustomerRepository(),
          getRouteDetailUseCase: FakeGetRouteDetailUseCase(),
          getTodayVisitsUseCase: _ServerVisits(),
          ref: ref,
        ));
    final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(container.dispose);
    final vm = container.read(provider);
    await vm.loadRouteDetail();
    return vm;
  }

  test('check-out chờ gửi mang id âm ⇒ lượt server (id thật, không uuid) hiện đã check-out', () async {
    final vm = await load('checkout');
    expect(vm.state.activeVisit, isNull, reason: 'lỗi cũ: lượt 901 được chọn làm lượt đang mở');
    expect(vm.state.todayVisits.single.isOpen, isFalse);
  });

  test('huỷ chờ gửi mang id âm ⇒ lượt server không được chọn làm lượt đang mở', () async {
    final vm = await load('cancel');
    expect(vm.state.activeVisit, isNull);
  });
}
