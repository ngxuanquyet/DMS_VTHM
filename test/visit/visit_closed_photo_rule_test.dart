import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/rules/mobile_rules_model.dart';
import 'package:vthm_dms/core/rules/mobile_rules_service.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';
import 'package:vthm_dms/features/route/domain/repositories/route_repository.dart';
import 'package:vthm_dms/features/route/domain/usecases/route_usecases.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_photo_entity.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_requirements_entity.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_history_entity.dart';
import 'package:vthm_dms/features/visit/domain/repositories/visit_repository.dart';
import 'package:vthm_dms/features/visit/domain/usecases/visit_usecases.dart';
import 'package:vthm_dms/features/forms/domain/repositories/forms_repository.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/data/models/market_form_submission_model.dart';
import 'package:vthm_dms/features/forms/domain/usecases/get_available_forms_usecase.dart';
import 'package:vthm_dms/features/visit/data/models/checkin_request_model.dart';
import 'package:vthm_dms/features/visit/data/models/checkout_request_model.dart';

class FakeRouteRepository implements RouteRepository {
  @override
  Future<RouteDetailEntity> getRouteDetail() async => const RouteDetailEntity(
    id: 'r1',
    title: 'Tất cả tuyến',
    totalDealers: 0,
    completedDealers: 0,
    pendingDealers: 0,
    progressPercent: 0,
    dealers: [],
  );

  @override
  Future<DealerCheckinDataEntity> getDealerCheckinData() async => throw UnimplementedError();
  @override
  Future<bool> checkoutDealer(String dealerId) async => true;
}

class FakeFormsRepository implements FormsRepository {
  @override
  Future<List<MarketFormConfigEntity>> getAvailableForms({required String kind, int? customerId}) async => [];
  @override
  Future<MarketFormSubmitResult> submitForm(MarketFormSubmissionModel submission, {bool isOffline = false}) => throw UnimplementedError();
  @override
  Future<dynamic> uploadPhoto(dynamic file) => throw UnimplementedError();
}

class FakeVisitRepository implements VisitRepository {
  final List<VisitEntity> todayVisits;
  VisitEntity? activeVisit;
  FakeVisitRepository(this.todayVisits, {this.activeVisit});

  @override
  Future<CustomerVisitHistoryResponse> getCustomerVisitHistory(int customerId, {int page = 1, int perPage = 20}) async =>
      const CustomerVisitHistoryResponse();

  @override
  Future<VisitHistoryDetailEntity> getCustomerVisitHistoryDetail(int customerId, int visitId) async =>
      throw UnimplementedError();

  @override
  Future<List<VisitEntity>> getTodayVisits() async => todayVisits;
  @override
  Future<List<VisitEntity>> getVisitsByDate(DateTime date, {bool forceRefresh = false}) async => todayVisits;

  @override
  Future<VisitEntity> checkin(CheckinRequestModel request) async {
    final v = VisitEntity(
      id: 999,
      customerId: request.customerId,
      customerName: 'Customer ${request.customerId}',
      checkinAt: DateTime.now(),
    );
    activeVisit = v;
    return v;
  }

  @override
  Future<VisitRequirementsEntity> getRequirements(int visitId, {String? visitResult}) async =>
      const VisitRequirementsEntity();

  @override
  Future<VisitPhotoEntity> uploadPhoto({
    required int visitId,
    required dynamic file,
    String photoType = 'other',
    DateTime? takenAt,
    double? lat,
    double? lng,
  }) =>
      throw UnimplementedError();

  @override
  Future<VisitRequirementsEntity> deletePhoto({required int visitId, required int photoId}) =>
      throw UnimplementedError();

  @override
  Future<VisitEntity> checkout({required int visitId, required CheckoutRequestModel request}) async {
    final v = VisitEntity(
      id: visitId,
      customerId: 101,
      customerName: 'Customer 101',
      checkoutAt: DateTime.now(),
      checkoutLat: request.lat,
      checkoutLng: request.lng,
    );
    activeVisit = null;
    return v;
  }

  @override
  Future<void> cancelVisit(int visitId, {String? clientUuid}) async {
    activeVisit = null;
  }

  @override
  Future<void> removeLocalVisit(int visitId, {String? clientUuid}) async {}

  @override
  Future<VisitEntity?> getActiveVisit() async => activeVisit;

  @override
  Future<void> saveActiveVisit(VisitEntity visit) async {
    activeVisit = visit;
  }

  @override
  Future<void> clearActiveVisit() async {
    activeVisit = null;
  }

  @override
  Future<void> saveLocalVisit(VisitEntity visit) async {}

  @override
  Future<void> saveLocalVisits(List<VisitEntity> visits) async {}

  @override
  Future<List<VisitEntity>> getAllLocalVisits() async => [];

}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MobileRules Cache & Closed Store Rule Tests', () {
    test('MobileRules correctly parses closed_min_photos and saves to cache', () async {
      SharedPreferences.setMockInitialValues({});

      final jsonRules = {
        'visit': {
          'require_geofence': true,
          'default_radius_m': 100,
          'min_duration_minutes': 5,
          'min_photos': 3,
          'closed_min_photos': 1,
        },
        'position': {'min_photos': 1},
        'clock': {'skew_tolerance_minutes': 15},
      };

      final rules = MobileRules.fromJson(jsonRules);
      expect(rules.visit.minPhotos, 3);
      expect(rules.visit.closedMinPhotos, 1);

      // Verify saving to and reading from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(MobileRulesNotifier.cacheKey, jsonEncode(rules.toJson()));

      final cached = await MobileRulesNotifier.getCachedRules();
      expect(cached, isNotNull);
      expect(cached!.visit.minPhotos, 3);
      expect(cached.visit.closedMinPhotos, 1);
    });

    test('CheckInViewModel correctly calculates requirements when switching to closed store offline', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Configure rules: 3 photos for open visit, 1 photo for closed visit
      const configuredRules = MobileRules(
        visit: VisitRules(
          minDurationMinutes: 5,
          minPhotos: 3,
          closedMinPhotos: 1,
        ),
      );
      await prefs.setString(MobileRulesNotifier.cacheKey, jsonEncode(configuredRules.toJson()));

      final container = ProviderContainer();
      container.read(mobileRulesProvider.notifier).setRules(configuredRules);

      late Ref testRef;
      final testRefProvider = Provider((ref) {
        testRef = ref;
      });
      container.read(testRefProvider);

      final fakeVisitRepo = FakeVisitRepository([]);
      final fakeRouteRepo = FakeRouteRepository();
      final fakeFormsRepo = FakeFormsRepository();

      final vm = CheckInViewModel(
        getDealerCheckinUseCase: GetDealerCheckinUseCase(fakeRouteRepo),
        checkoutDealerUseCase: CheckoutDealerUseCase(fakeRouteRepo),
        getAvailableFormsUseCase: GetAvailableFormsUseCase(fakeFormsRepo),
        checkinUseCase: CheckinUseCase(fakeVisitRepo),
        checkoutUseCase: CheckoutUseCase(fakeVisitRepo),
        getVisitRequirementsUseCase: GetVisitRequirementsUseCase(fakeVisitRepo),
        uploadVisitPhotoUseCase: UploadVisitPhotoUseCase(fakeVisitRepo),
        deleteVisitPhotoUseCase: DeleteVisitPhotoUseCase(fakeVisitRepo),
        cancelVisitUseCase: CancelVisitUseCase(fakeVisitRepo),
        visitRepository: fakeVisitRepo,
        ref: testRef,
      );

      // 1. Initial state (Mở cửa)
      vm.setVisitResult('visited');
      expect(vm.state.visitResult, 'visited');
      expect(vm.state.requirements?.photosMissing, 3);
      expect(vm.state.requirements?.satisfied, false);

      // 2. User chooses Đóng cửa ('closed')
      // Rule requires closedMinPhotos = 1
      vm.setVisitResult('closed');
      expect(vm.state.visitResult, 'closed');
      expect(vm.state.requirements?.photosMissing, 1,
          reason: 'Closed store must require closedMinPhotos (1 photo), not minPhotos (3 photos)');
      expect(vm.state.requirements?.secondsRemaining, 0,
          reason: 'Time requirement must be waived for closed store');
      expect(vm.state.requirements?.satisfied, false,
          reason: '0 photos taken out of 1 required -> not yet satisfied');
      expect(vm.state.requirements?.blockers.any((b) => b.contains('đóng cửa')), true);

      // 3. User switches back to Mở cửa ('visited')
      vm.setVisitResult('visited');
      expect(vm.state.visitResult, 'visited');
      expect(vm.state.requirements?.photosMissing, 3,
          reason: 'Open store requires minPhotos (3 photos)');

      // 4. User switches back to Đóng cửa
      vm.setVisitResult('closed');
      expect(vm.state.requirements?.photosMissing, 1);

      // 5. When 1 photo is taken for closed store
      vm.state = vm.state.copyWith(photos: const [
        VisitPhotoEntity(
          id: -1234,
          token: '',
          url: 'local_path.jpg',
          photoType: 'closed_store',
        ),
      ]);
      await vm.refreshRequirements();
      expect(vm.state.requirements?.photosMissing, 0,
          reason: '1 photo taken satisfies closedMinPhotos (1 photo)');
      expect(vm.state.requirements?.satisfied, true,
          reason: 'When 1 photo is taken and store is closed, visit is satisfied and can check-out');
      expect(vm.state.requirements?.blockers, isEmpty);
    });
  });
}
