// ignore_for_file: invalid_use_of_protected_member
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/errors/app_exceptions.dart';
import 'package:vthm_dms/features/forms/data/models/market_form_submission_model.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/domain/repositories/forms_repository.dart';
import 'package:vthm_dms/features/forms/domain/usecases/get_available_forms_usecase.dart';
import 'package:vthm_dms/features/route/domain/usecases/route_usecases.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';
import 'package:vthm_dms/features/visit/data/models/checkout_request_model.dart';
import 'package:vthm_dms/features/visit/data/repositories/visit_material_repository.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_requirements_entity.dart';
import 'package:vthm_dms/features/visit/domain/repositories/visit_repository.dart';
import 'package:vthm_dms/features/visit/domain/usecases/visit_usecases.dart';

import 'visit_module_test.dart' show FakeRouteRepository, FakeVisitRepository;

/// Rà soát 24/11/2026 (#25868, nhóm B — lượt viếng thăm / vật tư).
class _FormsRepo implements FormsRepository {
  Object? error;
  List<MarketFormConfigEntity> forms = const [];
  @override
  Future<List<MarketFormConfigEntity>> getAvailableForms({required String kind, int? customerId}) async {
    if (error != null) throw error!;
    return forms;
  }

  @override
  Future<MarketFormSubmitResult> submitForm(MarketFormSubmissionModel submission, {bool isOffline = false}) =>
      throw UnimplementedError();
  @override
  Future<dynamic> uploadPhoto(dynamic file) => throw UnimplementedError();
}

class _VisitRepo extends FakeVisitRepository {
  _VisitRepo({super.activeVisit}) : super([]);
  Object? checkoutError;
  @override
  Future<VisitEntity> checkout({required int visitId, required CheckoutRequestModel request}) async {
    if (checkoutError != null) throw checkoutError!;
    return super.checkout(visitId: visitId, request: request);
  }
}

CheckInViewModel _vm(VisitRepository visitRepo, FormsRepository formsRepo) {
  final routeRepo = FakeRouteRepository();
  return CheckInViewModel(
    getDealerCheckinUseCase: GetDealerCheckinUseCase(routeRepo),
    checkoutDealerUseCase: CheckoutDealerUseCase(routeRepo),
    getAvailableFormsUseCase: GetAvailableFormsUseCase(formsRepo),
    checkinUseCase: CheckinUseCase(visitRepo),
    checkoutUseCase: CheckoutUseCase(visitRepo),
    getVisitRequirementsUseCase: GetVisitRequirementsUseCase(visitRepo),
    uploadVisitPhotoUseCase: UploadVisitPhotoUseCase(visitRepo),
    deleteVisitPhotoUseCase: DeleteVisitPhotoUseCase(visitRepo),
    cancelVisitUseCase: CancelVisitUseCase(visitRepo),
    visitRepository: visitRepo,
  );
}

VisitEntity _offlineVisit({required DateTime checkinAt, required int secondsRemaining}) => VisitEntity(
      id: -1000,
      customerId: 101,
      customerName: 'Đại lý A',
      checkinAt: checkinAt,
      clientUuid: 'uuid-offline-1',
      visitResult: 'visited',
      requirements: VisitRequirementsEntity(
        secondsRemaining: secondsRemaining,
        blockers: secondsRemaining > 0 ? ['Bạn cần ở lại thêm 5 phút nữa mới check-out được.'] : const [],
      ),
    );

const _proxy404 = AppException('<html>404 page not found</html>', 404, nonApiResponseCode);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('① Khôi phục lượt: thời gian tối thiểu tính theo giờ check-in, không đếm lại từ số giây đã lưu', () {
    test('lượt ngoại tuyến check-in 3 phút trước, bản lưu còn 300 giây ⇒ còn ~120 giây', () async {
      final repo = _VisitRepo(
        activeVisit: _offlineVisit(
          checkinAt: DateTime.now().subtract(const Duration(minutes: 3)),
          secondsRemaining: 300,
        ),
      );
      final vm = _vm(repo, _FormsRepo());
      expect(await vm.restoreActiveVisitIfAvailable(), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final sec = vm.state.requirements!.secondsRemaining;
      expect(sec, inInclusiveRange(110, 120));
      vm.dispose();
    });

    test('check-in đã quá thời gian tối thiểu ⇒ về 0 ngay, không chặn vì thời gian', () async {
      final repo = _VisitRepo(
        activeVisit: _offlineVisit(
          checkinAt: DateTime.now().subtract(const Duration(minutes: 30)),
          secondsRemaining: 300,
        ),
      );
      final vm = _vm(repo, _FormsRepo());
      await vm.restoreActiveVisitIfAvailable();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.state.requirements!.secondsRemaining, 0);
      expect(vm.state.requirements!.blockers.where((b) => b.contains('ở lại thêm')), isEmpty);
      vm.dispose();
    });

    test('lượt miễn thời gian (lưu 0) ⇒ giữ 0', () async {
      final repo = _VisitRepo(
        activeVisit: _offlineVisit(checkinAt: DateTime.now(), secondsRemaining: 0),
      );
      final vm = _vm(repo, _FormsRepo());
      await vm.restoreActiveVisitIfAvailable();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.state.requirements!.secondsRemaining, 0);
      vm.dispose();
    });

    test('hàm thuần: không vượt số giây đã lưu (luật min cục bộ dài hơn của server)', () {
      final now = DateTime(2026, 11, 24, 10);
      final checkin = now.subtract(const Duration(minutes: 1));
      // Luật cục bộ 10 phút ⇒ còn 9 phút, nhưng bản lưu (của server) chỉ còn 60 giây ⇒ lấy 60.
      expect(
        CheckInViewModel.restoredMinDurationTarget(
          checkinAt: checkin,
          savedSecondsRemaining: 60,
          minDurationMinutes: 10,
          now: now,
        ),
        now.add(const Duration(seconds: 60)),
      );
      expect(
        CheckInViewModel.restoredMinDurationTarget(
          checkinAt: checkin,
          savedSecondsRemaining: 0,
          minDurationMinutes: 10,
          now: now,
        ),
        isNull,
      );
      expect(
        CheckInViewModel.restoredMinDurationTarget(
          checkinAt: null,
          savedSecondsRemaining: 120,
          minDurationMinutes: 10,
          now: now,
        ),
        now.add(const Duration(seconds: 120)),
      );
    });
  });

  group('② Danh sách biểu mẫu: "không đọc được" khác "rỗng"', () {
    test('tải hỏng (chưa có bản lưu) ⇒ cờ chưa tải được; lượt ngoại tuyến ⇒ cần cảnh báo khi check-out', () async {
      final forms = _FormsRepo()..error = const NetworkException();
      final repo = _VisitRepo(
        activeVisit: _offlineVisit(checkinAt: DateTime.now().subtract(const Duration(hours: 1)), secondsRemaining: 0),
      );
      final vm = _vm(repo, forms);
      await vm.restoreActiveVisitIfAvailable();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.state.surveyFormsLoaded, isFalse);
      expect(vm.state.shouldWarnUnknownRequiredForms, isTrue);

      // Đóng cửa: không có cổng biểu mẫu ⇒ không cảnh báo.
      vm.state = vm.state.copyWith(visitResult: 'closed');
      expect(vm.state.shouldWarnUnknownRequiredForms, isFalse);
      vm.dispose();
    });

    test('tải được danh sách RỖNG ⇒ không cảnh báo', () async {
      final repo = _VisitRepo(
        activeVisit: _offlineVisit(checkinAt: DateTime.now().subtract(const Duration(hours: 1)), secondsRemaining: 0),
      );
      final vm = _vm(repo, _FormsRepo());
      await vm.restoreActiveVisitIfAvailable();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.state.surveyFormsLoaded, isTrue);
      expect(vm.state.shouldWarnUnknownRequiredForms, isFalse);
      vm.dispose();
    });

    test('lượt đã lên server (id > 0) ⇒ cổng biểu mẫu do server giữ, không cảnh báo', () async {
      final forms = _FormsRepo()..error = const NetworkException();
      final repo = _VisitRepo(
        activeVisit: VisitEntity(id: 55, customerId: 101, customerName: 'A', checkinAt: DateTime.now()),
      );
      final vm = _vm(repo, forms);
      await vm.restoreActiveVisitIfAvailable();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(vm.state.surveyFormsLoaded, isFalse);
      expect(vm.state.shouldWarnUnknownRequiredForms, isFalse);
      vm.dispose();
    });
  });

  group('③ Câu lỗi check-out / huỷ lượt giữ nguyên chữ hoa của server', () {
    test('check-out bị từ chối 422 ⇒ câu báo đúng chữ gốc', () async {
      final repo = _VisitRepo(
        activeVisit: VisitEntity(id: 77, customerId: 101, customerName: 'A', checkinAt: DateTime.now()),
      )..checkoutError = const AppException('Bạn cần chụp thêm 2 ảnh POSM tại Đại lý A.', 422);
      final vm = _vm(repo, _FormsRepo());
      await vm.restoreActiveVisitIfAvailable();
      final (ok, msg) = await vm.checkout(forceCheckout: true);
      expect(ok, isFalse);
      expect(msg, startsWith('Bạn cần chụp thêm 2 ảnh POSM tại Đại lý A.'));
      vm.dispose();
    });

    test('huỷ lượt bị từ chối 422 ⇒ câu báo đúng chữ gốc', () async {
      final repo = _VisitRepo(
        activeVisit: VisitEntity(id: 78, customerId: 101, customerName: 'A', checkinAt: DateTime.now()),
      )..throwOnCancel = const AppException('Quản lý đã Khoá tuyến ngày 24/11.', 422);
      final vm = _vm(repo, _FormsRepo());
      await vm.restoreActiveVisitIfAvailable();
      final (ok, msg) = await vm.cancelVisit();
      expect(ok, isFalse);
      expect(msg, startsWith('Quản lý đã Khoá tuyến ngày 24/11.'));
      vm.dispose();
    });
  });

  group('⑤ Trang proxy (NON_API_RESPONSE) khi gửi trực tuyến ⇒ như mất mạng, không báo lỗi', () {
    test('huỷ lượt gặp 404 trang proxy ⇒ KHÔNG coi là "đã huỷ trên server" mà đi nhánh ngoại tuyến', () async {
      final repo = _VisitRepo(
        activeVisit: VisitEntity(id: 79, customerId: 101, customerName: 'A', checkinAt: DateTime.now()),
      )..throwOnCancel = _proxy404;
      final vm = _vm(repo, _FormsRepo());
      await vm.restoreActiveVisitIfAvailable();
      final (ok, msg) = await vm.cancelVisit();
      expect(ok, isTrue);
      expect(msg, isNull);
      vm.dispose();
    });

    test('check-out gặp 403 trang WAF ⇒ không báo lỗi (đi hàng đợi), vẫn ghi nhận check-out', () async {
      final repo = _VisitRepo(
        activeVisit: VisitEntity(id: 80, customerId: 101, customerName: 'A', checkinAt: DateTime.now()),
      )..checkoutError = const AppException('<html>Forbidden</html>', 403, nonApiResponseCode);
      final vm = _vm(repo, _FormsRepo());
      await vm.restoreActiveVisitIfAvailable();
      final (ok, _) = await vm.checkout(forceCheckout: true);
      expect(ok, isTrue);
      vm.dispose();
    });

    test('check-out bị server từ chối thật (422 JSON) vẫn báo lỗi', () async {
      final repo = _VisitRepo(
        activeVisit: VisitEntity(id: 81, customerId: 101, customerName: 'A', checkinAt: DateTime.now()),
      )..checkoutError = const AppException('Thiếu ảnh', 422);
      final vm = _vm(repo, _FormsRepo());
      await vm.restoreActiveVisitIfAvailable();
      final (ok, _) = await vm.checkout(forceCheckout: true);
      expect(ok, isFalse);
      vm.dispose();
    });
  });

  group('④ Vật tư: trang proxy là lỗi tạm', () {
    test('ảnh vật tư gặp trang proxy ⇒ ném để thử lại, KHÔNG bỏ ảnh', () async {
      final wrapped = skipRejectedMaterialPhotos((_) async => throw _proxy404);
      await expectLater(wrapped(File('khong-co.jpg')), throwsA(isA<AppException>()));
    });

    test('ảnh vật tư bị API từ chối thật (422 JSON) ⇒ vẫn bỏ ảnh như cũ', () async {
      final wrapped = skipRejectedMaterialPhotos((_) async => throw const AppException('Sai định dạng', 422));
      expect(await wrapped(File('khong-co.jpg')), isNull);
    });

    test('isRetryableMaterialError: trang proxy ⇒ tạm; 4xx của API ⇒ không', () {
      expect(isRetryableMaterialError(_proxy404), isTrue);
      expect(isRetryableMaterialError(const AppException('x', 403, nonApiResponseCode)), isTrue);
      expect(isRetryableMaterialError(const AppException('x', 404)), isFalse);
    });

    test('isMaterialViewRejected: 403/404/410 của API ⇒ bỏ bộ đệm; trang proxy ⇒ giữ', () {
      expect(isMaterialViewRejected(const AppException('x', 404)), isTrue);
      expect(isMaterialViewRejected(const AppException('x', 403)), isTrue);
      expect(isMaterialViewRejected(_proxy404), isFalse);
      expect(isMaterialViewRejected(const AppException('x', 403, nonApiResponseCode)), isFalse);
    });
  });
}


