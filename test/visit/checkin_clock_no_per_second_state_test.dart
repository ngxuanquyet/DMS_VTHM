// ignore_for_file: invalid_use_of_protected_member
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_requirements_entity.dart';

import 'visit_module_test.dart' show FakeVisitRepository, createCheckInViewModel;

/// Màn check-in (29/10/2026): đồng hồ thăm chạy qua ValueNotifier (không ghi state mỗi giây — trước đây mỗi giây dựng
/// lại cả màn ~1.200 dòng suốt lượt thăm). Đếm ngược thời gian tối thiểu giữ nguyên logic: state luôn mang số giây thật,
/// chỉ thôi ghi khi không còn gì đổi (hết thời gian tối thiểu).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dealer = DealerEntity(
    id: '101',
    order: '01',
    name: 'Đại lý A',
    address: '1 Đường 1',
    status: DealerVisitStatus.pending,
    statusLabel: 'Chưa ghé',
    isVip: false,
  );

  test('đếm ngược: state mang số giây thật; về 0 ⇒ đủ thời gian; sau đó KHÔNG ghi state mỗi giây', () {
    fakeAsync((async) {
      final vm = createCheckInViewModel(FakeVisitRepository([]));
      vm.initCheckinWithDealer(dealer);
      vm.state = vm.state.copyWith(
        requirements: const VisitRequirementsEntity(secondsRemaining: 3, blockers: ['Cần ở lại thêm 3 giây']),
      );
      async.flushMicrotasks();

      var stateChanges = 0;
      final remove = vm.addListener((_) => stateChanges++, fireImmediately: false);

      async.elapse(const Duration(seconds: 2));
      expect(vm.liveDuration.value, '00:00:02');
      expect(vm.state.requirements!.secondsRemaining, 1);

      async.elapse(const Duration(seconds: 1));
      expect(vm.state.requirements!.secondsRemaining, 0);
      expect(vm.state.requirements!.satisfied, isTrue);
      expect(vm.state.requirements!.blockers, isEmpty);
      final changesAtZero = stateChanges;

      async.elapse(const Duration(seconds: 10)); // hết thời gian tối thiểu: đồng hồ vẫn chạy, state đứng yên
      expect(stateChanges, changesAtZero);
      expect(vm.liveDuration.value, '00:00:13');

      remove();
      vm.dispose();
    });
  });

  test('chép requirements (nộp khảo sát / chụp ảnh) ⇒ đếm ngược KHÔNG nhảy lùi', () {
    fakeAsync((async) {
      final vm = createCheckInViewModel(FakeVisitRepository([]));
      vm.initCheckinWithDealer(dealer);
      vm.state = vm.state.copyWith(
        requirements: const VisitRequirementsEntity(secondsRemaining: 600, photosMissing: 2),
      );
      async.elapse(const Duration(seconds: 570));
      expect(vm.state.requirements!.secondsRemaining, 30);

      vm.state = vm.state.copyWith(requirements: vm.state.requirements!.copyWith(photosMissing: 1));
      async.elapse(const Duration(seconds: 1));
      expect(vm.state.requirements!.secondsRemaining, 29);
      vm.dispose();
    });
  });
}
