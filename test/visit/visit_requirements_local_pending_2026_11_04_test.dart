// ignore_for_file: invalid_use_of_protected_member
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/database/app_database.dart';
import 'package:vthm_dms/core/database/database_provider.dart';
import 'package:vthm_dms/core/utils/system_clock.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/domain/usecases/get_available_forms_usecase.dart';
import 'package:vthm_dms/features/route/domain/usecases/route_usecases.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_photo_entity.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_requirements_entity.dart';
import 'package:vthm_dms/features/visit/domain/usecases/visit_usecases.dart';

import 'visit_closed_photo_rule_test.dart' show FakeFormsRepository, FakeRouteRepository, FakeVisitRepository;

/// #24698 vòng 4, V1: điều kiện check-out tải lại từ server chưa thấy ảnh / phiếu còn chờ gửi trên máy ⇒ nút Check-out
/// chặn ngay trên màn, không tới bước đẩy hàng đợi. Nay cộng phần chờ gửi vào điều kiện của server.
class _ServerReq extends FakeVisitRepository {
  _ServerReq() : super([]);

  @override
  Future<VisitRequirementsEntity> getRequirements(int visitId, {String? visitResult}) async =>
      const VisitRequirementsEntity(
        satisfied: false,
        photosMissing: 1,
        missingForms: [MissingFormEntity(formId: 7, name: 'Khảo sát giá')],
        blockers: ['Bạn cần hoàn thành 1 biểu mẫu bắt buộc.', 'Bạn cần chụp thêm 1 ảnh nữa.'],
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CheckInViewModel vm({Ref? ref}) {
    final visitRepo = _ServerReq();
    return CheckInViewModel(
      getDealerCheckinUseCase: GetDealerCheckinUseCase(FakeRouteRepository()),
      checkoutDealerUseCase: CheckoutDealerUseCase(FakeRouteRepository()),
      getAvailableFormsUseCase: GetAvailableFormsUseCase(FakeFormsRepository()),
      checkinUseCase: CheckinUseCase(visitRepo),
      checkoutUseCase: CheckoutUseCase(visitRepo),
      getVisitRequirementsUseCase: GetVisitRequirementsUseCase(visitRepo),
      uploadVisitPhotoUseCase: UploadVisitPhotoUseCase(visitRepo),
      deleteVisitPhotoUseCase: DeleteVisitPhotoUseCase(visitRepo),
      cancelVisitUseCase: CancelVisitUseCase(visitRepo),
      visitRepository: visitRepo,
      ref: ref,
    );
  }

  const survey = MarketFormConfigEntity(
    configId: 2,
    formId: 7,
    code: 'ks_gia',
    name: 'Khảo sát giá',
    kind: 'survey',
    isRequired: true,
    sortOrder: 1,
    schema: MarketFormSchemaEntity(blocks: []),
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  late AppDatabase db;
  late Ref testRef;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory(), 1);
    final container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    container.read(Provider((ref) => testRef = ref));
  });

  Future<int> enqueue(String entity, String state, {String? parent, String payload = '{}'}) =>
      db.enqueue(SyncQueueEntriesCompanion.insert(
        entity: entity,
        op: 'create',
        clientUuid: '$entity-$state-${DateTime.now().microsecondsSinceEpoch}',
        parentUuid: Value(parent),
        payload: payload,
        state: Value(state),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        createdElapsed: SystemClock.nowMonotonicMs,
        bootId: SystemClock.bootId,
      ));

  VisitPhotoEntity anh(int id) => VisitPhotoEntity(id: id, token: '', url: '/x.jpg', localPath: '/x.jpg');

  test('ảnh chờ gửi + phiếu đã nộp vào hàng đợi ⇒ đủ điều kiện', () async {
    final m = vm(ref: testRef);
    final photo = await enqueue('visit_photo', 'pending', parent: m.sessionClientUuid);
    await enqueue('form_submission', 'pending', parent: m.sessionClientUuid, payload: '{"config_id":2}');
    m.state = m.state.copyWith(
      visitId: 5,
      surveyForms: [survey],
      submittedSurveyConfigIds: {2},
      photos: [anh(-photo)],
    );

    await m.refreshRequirements();

    final req = m.state.requirements!;
    expect(req.photosMissing, 0, reason: 'lỗi cũ: server báo thiếu 1 ảnh dù ảnh đang chờ gửi trên máy');
    expect(req.missingForms, isEmpty);
    expect(req.blockers, isEmpty);
    expect(req.satisfied, isTrue);
  });

  test('ảnh đang tải trực tuyến (mã tạm) cũng tính', () async {
    final m = vm(ref: testRef);
    m.state = m.state.copyWith(visitId: 5, photos: [anh(-DateTime.now().millisecondsSinceEpoch)]);
    await m.refreshRequirements();
    expect(m.state.requirements!.photosMissing, 0);
  });

  test('không có gì chờ gửi ⇒ giữ nguyên điều kiện server', () async {
    final m = vm(ref: testRef);
    m.state = m.state.copyWith(visitId: 5, surveyForms: [survey]);

    await m.refreshRequirements();

    final req = m.state.requirements!;
    expect(req.photosMissing, 1);
    expect(req.missingForms.single.formId, 7);
    expect(req.satisfied, isFalse);
  });

  test('ảnh / phiếu có dòng hàng đợi đã chết hoặc đã bị xoá không tính là chờ gửi', () async {
    final m = vm(ref: testRef);
    final dead = await enqueue('visit_photo', 'dead', parent: m.sessionClientUuid);
    await enqueue('form_submission', 'dead', parent: m.sessionClientUuid, payload: '{"config_id":2}');
    m.state = m.state.copyWith(
      visitId: 5,
      surveyForms: [survey],
      submittedSurveyConfigIds: {2},
      photos: [anh(-dead), anh(-9999)], // -9999: dòng hàng đợi đã bị xoá
    );

    await m.refreshRequirements();

    final req = m.state.requirements!;
    expect(req.photosMissing, 1, reason: 'ảnh chết / đã xoá ở hàng đợi sẽ không bao giờ lên server');
    expect(req.missingForms.single.formId, 7);
    expect(req.satisfied, isFalse);
  });
}
