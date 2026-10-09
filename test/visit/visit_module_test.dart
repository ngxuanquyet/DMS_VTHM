import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_dynamic_column.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_meta_entity.dart';
import 'package:vthm_dms/features/customer/domain/repositories/customer_repository.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';
import 'package:vthm_dms/features/route/domain/repositories/route_repository.dart';
import 'package:vthm_dms/features/route/domain/usecases/route_usecases.dart';
import 'package:vthm_dms/features/route/presentation/states/route_state.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';
import 'package:vthm_dms/features/visit/data/models/checkin_request_model.dart';
import 'package:vthm_dms/features/visit/data/models/checkout_request_model.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_photo_entity.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_requirements_entity.dart';
import 'package:vthm_dms/features/visit/domain/usecases/visit_usecases.dart';
import 'package:vthm_dms/features/visit/domain/repositories/visit_repository.dart';
import 'package:vthm_dms/features/forms/domain/repositories/forms_repository.dart';
import 'package:vthm_dms/features/forms/domain/entities/market_form_entity.dart';
import 'package:vthm_dms/features/forms/data/models/market_form_submission_model.dart';
import 'package:vthm_dms/features/forms/domain/usecases/get_available_forms_usecase.dart';

class FakeCustomerRepository implements CustomerRepository {
  final List<CustomerEntity> customers;
  FakeCustomerRepository(this.customers);

  @override
  Future<List<CustomerEntity>> getCustomers({int page = 1, int perPage = 200, String? query, bool forceRefresh = false}) async {
    return customers;
  }

  @override
  Future<CustomerEntity> createCustomer(Map<String, dynamic> data) => throw UnimplementedError();
  @override
  Future<bool> deleteCustomer(int id) => throw UnimplementedError();
  @override
  Future<bool> deletePendingCustomer(String clientUuid) async => true;
  @override
  Future<CustomerEntity> getCustomerDetail(int id) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> getCustomerFormSchema({bool forceRefresh = false}) => throw UnimplementedError();
  @override
  Future<CustomerMetaData> getCustomerMeta({bool forceRefresh = false}) => throw UnimplementedError();
  @override
  Future<List<CustomerDynamicColumn>> getDynamicColumns({bool forceRefresh = false}) => throw UnimplementedError();
  @override
  Future<CustomerEntity> updateCustomer({required int id, required Map<String, dynamic> changes, String? clientUuid}) => throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> uploadCustomerPhoto(String filePath) => throw UnimplementedError();
}

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
  Future<DealerCheckinDataEntity> getDealerCheckinData() => throw UnimplementedError();
  @override
  Future<bool> checkoutDealer(String dealerId) async => true;
}

class FakeVisitRepository implements VisitRepository {
  final List<VisitEntity> todayVisits;
  VisitEntity? activeVisit;
  FakeVisitRepository(this.todayVisits, {this.activeVisit});

  @override
  Future<List<VisitEntity>> getTodayVisits() async => todayVisits;
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
  Future<VisitRequirementsEntity> getRequirements(int visitId, {String? visitResult}) => throw UnimplementedError();
  @override
  Future<VisitPhotoEntity> uploadPhoto({required int visitId, required dynamic file, String photoType = 'other', DateTime? takenAt, double? lat, double? lng}) => throw UnimplementedError();
  @override
  Future<VisitRequirementsEntity> deletePhoto({required int visitId, required int photoId}) => throw UnimplementedError();
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

  Exception? throwOnCancel;

  @override
  Future<void> cancelVisit(int visitId, {String? clientUuid}) async {
    if (throwOnCancel != null) throw throwOnCancel!;
    activeVisit = null;
  }
  @override
  Future<void> removeLocalVisit(int visitId, {String? clientUuid}) async {
    todayVisits.removeWhere((v) => v.id == visitId || (clientUuid != null && v.clientUuid == clientUuid));
    if (activeVisit?.id == visitId || (clientUuid != null && activeVisit?.clientUuid == clientUuid)) {
      activeVisit = null;
    }
  }
  @override
  Future<void> saveActiveVisit(VisitEntity visit) async {
    activeVisit = visit;
  }
  @override
  Future<VisitEntity?> getActiveVisit() async => activeVisit;
  @override
  Future<void> clearActiveVisit() async {
    activeVisit = null;
  }
  @override
  Future<List<VisitEntity>> getVisitsByDate(DateTime date, {bool forceRefresh = false}) async => todayVisits;
  @override
  Future<List<VisitEntity>> getAllLocalVisits() async => todayVisits;
  @override
  Future<void> saveLocalVisit(VisitEntity visit) async {}
  @override
  Future<void> saveLocalVisits(List<VisitEntity> visits) async {}
}

class FakeFormsRepository implements FormsRepository {
  @override
  Future<List<MarketFormConfigEntity>> getAvailableForms({required String kind, int? customerId}) async => [];
  @override
  Future<MarketFormSubmitResult> submitForm(MarketFormSubmissionModel submission, {bool isOffline = false}) => throw UnimplementedError();
  @override
  Future<dynamic> uploadPhoto(dynamic file) => throw UnimplementedError();
}

CheckInViewModel createCheckInViewModel(VisitRepository visitRepo) {
  final routeRepo = FakeRouteRepository();
  final formsRepo = FakeFormsRepository();
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

void main() {
  group('Visit Entities and Models Spec Tests', () {
    test('VisitRequirementsEntity parses JSON accurately from §6', () {
      final json = {
        "satisfied": false,
        "seconds_remaining": 300,
        "photos_missing": 2,
        "missing_forms": [
          {"form_id": 9809, "name": "Khảo sát giá tháng 9"}
        ],
        "blockers": [
          "Bạn cần ở lại thêm 5 phút nữa mới check-out được.",
          "Bạn cần chụp thêm 2 ảnh nữa."
        ]
      };

      final req = VisitRequirementsEntity.fromJson(json);

      expect(req.satisfied, false);
      expect(req.secondsRemaining, 300);
      expect(req.photosMissing, 2);
      expect(req.missingForms.length, 1);
      expect(req.missingForms.first.formId, 9809);
      expect(req.missingForms.first.name, "Khảo sát giá tháng 9");
      expect(req.blockers.length, 2);
      expect(req.blockers.first, "Bạn cần ở lại thêm 5 phút nữa mới check-out được.");
    });

    test('VisitEntity parses real backend JSON from §2.3 and §3', () {
      final json = {
        "id": 127954,
        "visit_date": "2026-09-29",
        "checkin_at": "2026-09-29 16:17:05+07",
        "checkout_at": "2026-09-29 16:24:18+07",
        "duration_seconds": 420,
        "customer_id": 3315,
        "customer_name": "Đại lý Thành Công",
        "visit_result": "visited",
        "photo_count": 2,
        "form_count": 1,
        "checkout_lat": "10.7769123",
        "checkout_lng": "106.7009456"
      };

      final visit = VisitEntity.fromJson(json);

      expect(visit.id, 127954);
      expect(visit.visitDate, "2026-09-29");
      expect(visit.customerId, 3315);
      expect(visit.customerName, "Đại lý Thành Công");
      expect(visit.durationSeconds, 420);
      expect(visit.photoCount, 2);
      expect(visit.formCount, 1);
      expect(visit.isCompleted, true);
      expect(visit.isOpen, false);
      expect(visit.checkoutLat, 10.7769123);
      expect(visit.checkoutLng, 106.7009456);
    });

    test('VisitPhotoEntity parses public URL, token, and duplicate flag from §4.1', () {
      final json = {
        "id": 191,
        "file_id": 11917,
        "token": "fb3214388b3b66970baf3296de3e0da0",
        "url": "/dms/visit-photos/public/fb3214388b3b66970baf3296de3e0da0",
        "photo_type": "display",
        "photo_type_label": "Ảnh trưng bày",
        "photo_type_color": "primary",
        "taken_at": "2026-09-29 15:40:00+07",
        "sort_order": 0,
        "duplicate": true
      };

      final photo = VisitPhotoEntity.fromJson(json);

      expect(photo.id, 191);
      expect(photo.fileId, 11917);
      expect(photo.token, "fb3214388b3b66970baf3296de3e0da0");
      expect(photo.photoType, "display");
      expect(photo.photoTypeLabel, "Ảnh trưng bày");
      expect(photo.duplicate, true);
      expect(photo.fullPublicUrl, contains("fb3214388b3b66970baf3296de3e0da0"));
    });

    test('CheckinRequestModel generates correct payload according to §3', () {
      const model = CheckinRequestModel(
        customerId: 3315,
        lat: 10.776889,
        lng: 106.700897,
        accuracyM: 12.5,
        address: "Quận 1, TP HCM",
        isMockLocation: false,
        clientUuid: "f09d273a-4467-4a7b-a0d3-34e8574d2cb9",
        note: "Ghé chào hàng",
      );

      final json = model.toJson();

      expect(json['customer_id'], 3315);
      expect(json['lat'], 10.776889);
      expect(json['lng'], 106.700897);
      expect(json['accuracy_m'], 12.5);
      expect(json['client_uuid'], "f09d273a-4467-4a7b-a0d3-34e8574d2cb9");
      expect(json['note'], "Ghé chào hàng");
    });

    test('CheckoutRequestModel conditionally includes closed_note only when closed (§7)', () {
      const openModel = CheckoutRequestModel(
        visitResult: 'visited',
        closedNote: 'Không nên gửi',
        lat: 10.77,
        lng: 106.70,
      );
      expect(openModel.toJson().containsKey('closed_note'), false);

      const closedModel = CheckoutRequestModel(
        visitResult: 'closed',
        closedNote: 'Cửa hàng nghỉ lễ',
        lat: 10.77,
        lng: 106.70,
      );
      expect(closedModel.toJson()['closed_note'], 'Cửa hàng nghỉ lễ');
      expect(closedModel.toJson()['visit_result'], 'closed');
    });
  });

  group('RouteViewModel Visit Mapping Integration', () {
    test('Correctly maps today visits to Completed, InProgress, and Pending statuses', () async {
      final fakeCustomers = [
        const CustomerEntity(
          id: 101,
          code: 'C101',
          name: 'Điểm bán 1 - Đã ghé',
          address: 'Địa chỉ 1',
          contactPerson: 'Anh A',
          phone: '0901234567',
          route: 'Tất cả tuyến',
          status: 'active',
          approvalStatus: 'approved',
          syncStatus: 'synced',
          type: 'Đại lý',
        ),
        const CustomerEntity(
          id: 102,
          code: 'C102',
          name: 'Điểm bán 2 - Đang ghé',
          address: 'Địa chỉ 2',
          contactPerson: 'Chị B',
          phone: '0901234568',
          route: 'Tất cả tuyến',
          status: 'active',
          approvalStatus: 'approved',
          syncStatus: 'synced',
          type: 'Đại lý',
        ),
        const CustomerEntity(
          id: 103,
          code: 'C103',
          name: 'Điểm bán 3 - Chưa ghé',
          address: 'Địa chỉ 3',
          contactPerson: 'Anh C',
          phone: '0901234569',
          route: 'Tất cả tuyến',
          status: 'active',
          approvalStatus: 'approved',
          syncStatus: 'synced',
          type: 'Đại lý',
        ),
      ];

      final todayVisits = [
        VisitEntity(
          id: 901,
          customerId: 101,
          customerName: 'Điểm bán 1 - Đã ghé',
          checkinAt: DateTime(2026, 9, 30, 8, 30),
          checkoutAt: DateTime(2026, 9, 30, 8, 45),
          durationSeconds: 900,
          visitResult: 'visited',
        ),
        VisitEntity(
          id: 902,
          customerId: 102,
          customerName: 'Điểm bán 2 - Đang ghé',
          checkinAt: DateTime(2026, 9, 30, 9, 0),
          checkoutAt: null, // Chưa check-out -> Đang mở
        ),
      ];

      final custRepo = FakeCustomerRepository(fakeCustomers);
      final routeRepo = FakeRouteRepository();
      final visitRepo = FakeVisitRepository(todayVisits);

      final vm = RouteViewModel(
        customerRepository: custRepo,
        getRouteDetailUseCase: GetRouteDetailUseCase(routeRepo),
        getTodayVisitsUseCase: GetTodayVisitsUseCase(visitRepo),
      );

      await vm.loadRouteDetail();

      final state = vm.state;
      expect(state.todayVisits.length, 2);
      expect(state.activeVisit?.id, 902);
      expect(state.activeVisit?.customerId, 102);

      final dealers = state.routeDetail!.dealers;
      expect(dealers.length, 3);

      final dealer1 = dealers.firstWhere((d) => d.id == '101');
      expect(dealer1.status, DealerVisitStatus.completed);
      expect(dealer1.statusLabel, 'Đã ghé');
      expect(dealer1.visitedTime, '08:30 - 08:45');

      final dealer2 = dealers.firstWhere((d) => d.id == '102');
      expect(dealer2.status, DealerVisitStatus.inProgress);
      expect(dealer2.statusLabel, 'Đang ghé');
      expect(dealer2.visitedTime, '09:00');

      final dealer3 = dealers.firstWhere((d) => d.id == '103');
      expect(dealer3.status, DealerVisitStatus.pending);
      expect(dealer3.statusLabel, 'Chưa ghé');
    });

    test('RouteViewModel does NOT count cancelled visits as visited/completed (§3 HUY-LUOT-VIENG-THAM)', () async {
      final fakeCustomers = [
        const CustomerEntity(
          id: 101,
          code: 'DB01',
          name: 'Điểm bán 1',
          address: 'Hà Nội',
          contactPerson: 'Anh A',
          phone: '0901234567',
          route: 'Tất cả tuyến',
          status: 'active',
          approvalStatus: 'approved',
          syncStatus: 'synced',
          type: 'Đại lý',
        ),
      ];

      final todayVisits = [
        VisitEntity(
          id: 901,
          customerId: 101,
          customerName: 'Điểm bán 1 - Đã huỷ',
          checkinAt: DateTime(2026, 9, 30, 8, 30),
          cancelledAt: DateTime(2026, 9, 30, 8, 40),
          cancelledAtRaw: '2026-09-30 08:40:00+07',
        ),
      ];

      final custRepo = FakeCustomerRepository(fakeCustomers);
      final routeRepo = FakeRouteRepository();
      final visitRepo = FakeVisitRepository(todayVisits);

      final vm = RouteViewModel(
        customerRepository: custRepo,
        getRouteDetailUseCase: GetRouteDetailUseCase(routeRepo),
        getTodayVisitsUseCase: GetTodayVisitsUseCase(visitRepo),
      );

      await vm.loadRouteDetail();

      final state = vm.state;
      expect(state.activeVisit, isNull);

      final dealers = state.routeDetail!.dealers;
      expect(dealers.length, 1);

      final dealer1 = dealers.firstWhere((d) => d.id == '101');
      // Lượt đã huỷ checkin tuyệt đối không được tính là đã viếng thăm
      expect(dealer1.status, DealerVisitStatus.pending);
      expect(dealer1.statusLabel, 'Chưa ghé');
      expect(dealer1.visitedTime, isNull);
      expect(state.routeDetail!.completedDealers, 0);
      expect(state.routeDetail!.pendingDealers, 1);
    });

    test('VisitEntity converts server checkin_at with timezone +07 to local DateTime without hour loss', () {
      final json = {
        "id": 127954,
        "visit_date": "2026-09-29",
        "checkin_at": "2026-09-29 16:17:05+07",
        "checkout_at": "2026-09-29 16:24:18+07",
      };

      final visit = VisitEntity.fromJson(json);

      expect(visit.checkinAt, isNotNull);
      expect(visit.checkinAt!.isUtc, false);
      expect(visit.checkoutAt, isNotNull);
      expect(visit.checkoutAt!.isUtc, false);
      expect(visit.checkoutAt!.difference(visit.checkinAt!).inSeconds, 433);
    });

    test('VisitEntity handles cancelled_at and isCancelled correctly (§3 & §4 HUY-LUOT-VIENG-THAM)', () {
      final json = {
        "id": 888,
        "customer_id": 105,
        "customer_name": "Tạp hoá Bình Minh",
        "checkin_at": "2026-09-30 09:15:00",
        "checkout_at": null,
        "cancelled_at": "2026-09-30 09:20:00",
        "visit_result": "visited"
      };

      final visit = VisitEntity.fromJson(json);

      expect(visit.id, 888);
      expect(visit.cancelledAt, isNotNull);
      expect(visit.isCancelled, isTrue);
      expect(visit.isOpen, isFalse);
      expect(visit.isCompleted, isFalse);
    });
  });

  group('Active Visit & Offline Blocking Tests (§3 Luật 3)', () {
    test('RouteViewModel recovers activeVisit from local storage when offline (todayVisits is empty)', () async {
      final custRepo = FakeCustomerRepository([
        const CustomerEntity(id: 101, code: 'C101', name: 'Đại lý A', address: '123 Đường 1', contactPerson: 'Người liên hệ', phone: '0901', route: 'Tuyến 1', type: 'Đại lý'),
        const CustomerEntity(id: 102, code: 'C102', name: 'Đại lý B', address: '456 Đường 2', contactPerson: 'Người liên hệ', phone: '0902', route: 'Tuyến 1', type: 'Đại lý'),
      ]);
      final savedVisit = VisitEntity(
        id: 777,
        customerId: 101,
        customerName: 'Đại lý A',
        checkinAt: DateTime.now(),
      );
      final visitRepo = FakeVisitRepository([], activeVisit: savedVisit);

      final vm = RouteViewModel(
        customerRepository: custRepo,
        getRouteDetailUseCase: GetRouteDetailUseCase(FakeRouteRepository()),
        getTodayVisitsUseCase: GetTodayVisitsUseCase(visitRepo),
        visitRepository: visitRepo,
      );

      await vm.loadRouteDetail();

      expect(vm.state.activeVisit, isNotNull);
      expect(vm.state.activeVisit?.id, 777);
      expect(vm.state.activeVisit?.customerId, 101);

      final dealers = vm.state.routeDetail!.dealers;
      final dealerA = dealers.firstWhere((d) => d.id == '101');
      expect(dealerA.status, DealerVisitStatus.inProgress);
      expect(dealerA.statusLabel, 'Đang ghé');
    });

    test('RouteViewModel.setActiveVisit immediately updates activeVisit and recomputes dealer status', () async {
      final custRepo = FakeCustomerRepository([
        const CustomerEntity(id: 101, code: 'C101', name: 'Đại lý A', address: '123 Đường 1', contactPerson: 'Người liên hệ', phone: '0901', route: 'Tuyến 1', type: 'Đại lý'),
      ]);
      final visitRepo = FakeVisitRepository([]);
      final vm = RouteViewModel(
        customerRepository: custRepo,
        getRouteDetailUseCase: GetRouteDetailUseCase(FakeRouteRepository()),
        getTodayVisitsUseCase: GetTodayVisitsUseCase(visitRepo),
        visitRepository: visitRepo,
      );

      await vm.loadRouteDetail();
      expect(vm.state.activeVisit, isNull);

      final newVisit = VisitEntity(
        id: 555,
        customerId: 101,
        customerName: 'Đại lý A',
        checkinAt: DateTime.now(),
      );
      vm.setActiveVisit(newVisit);

      expect(vm.state.activeVisit?.id, 555);
      final dealerA = vm.state.routeDetail!.dealers.firstWhere((d) => d.id == '101');
      expect(dealerA.status, DealerVisitStatus.inProgress);

      vm.setActiveVisit(null);
      expect(vm.state.activeVisit, isNull);
    });

    test('CheckInViewModel blocks check-in to a different dealer when an active visit is open in memory', () async {
      final visitRepo = FakeVisitRepository([]);
      final vm = createCheckInViewModel(visitRepo);

      // Check-in đại lý 101
      final err1 = await vm.performCheckin(customerId: 101);
      expect(err1, isNull);
      expect(vm.state.visitId, 999);

      // Thử check-in đại lý 102 khi đại lý 101 chưa check-out
      final err2 = await vm.performCheckin(customerId: 102);
      expect(err2, contains('Bạn còn một lượt viếng thăm tại điểm bán khác chưa check-out'));
    });

    test('CheckInViewModel blocks check-in to another dealer when active visit is stored in repository (offline check)', () async {
      final savedVisit = VisitEntity(
        id: 888,
        customerId: 101,
        customerName: 'Đại lý A',
        checkinAt: DateTime.now(),
      );
      final visitRepo = FakeVisitRepository([], activeVisit: savedVisit);
      final vm = createCheckInViewModel(visitRepo);

      // Thử check-in đại lý 102 trong khi repo đang lưu active visit của 101
      final err = await vm.performCheckin(customerId: 102);
      expect(err, contains('Bạn còn một lượt viếng thăm tại điểm bán khác chưa check-out'));
    });

    test('CheckInViewModel.initCheckinWithDealer does not overwrite in-progress session if different dealer is passed', () async {
      final visitRepo = FakeVisitRepository([]);
      final vm = createCheckInViewModel(visitRepo);

      await vm.performCheckin(customerId: 101);
      expect(vm.state.visitId, 999);

      const otherDealer = DealerEntity(
        id: '102',
        order: '02',
        name: 'Đại lý B',
        address: '456 Đường 2',
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
      );

      vm.initCheckinWithDealer(otherDealer);
      // Phiên vẫn giữ nguyên id 999 của đại lý 101, không bị ghi đè thành 102
      expect(vm.state.visitId, 999);
    });

    test('CheckInViewModel.checkout blocks checkout if distance to dealer > 100m', () async {
      final visitRepo = FakeVisitRepository([]);
      final vm = createCheckInViewModel(visitRepo);

      // Điểm bán có tọa độ tại (10.7725, 106.6980)
      const dealer = DealerEntity(
        id: '101',
        order: '01',
        name: 'Đại lý Bến Thành',
        address: 'Quận 1',
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
        lat: 10.7725,
        lng: 106.6980,
      );

      vm.initCheckinWithDealer(dealer);
      await vm.performCheckin(customerId: 101);
      expect(vm.state.visitId, 999);

      // Vị trí người dùng ở xa (~3km, Landmark 81: 10.7950, 106.7218)
      final (success, errorMsg) = await vm.checkout(
        lat: 10.7950,
        lng: 106.7218,
      );

      expect(success, isFalse);
      expect(errorMsg, contains('vượt quá phạm vi cho phép (tối đa 100m)'));
      expect(vm.state.status, isNot(CheckInStatus.checkedOut));
    });

    test('CheckInViewModel.checkout succeeds if distance to dealer <= 100m', () async {
      final visitRepo = FakeVisitRepository([]);
      final vm = createCheckInViewModel(visitRepo);

      // Điểm bán có tọa độ tại (10.77250, 106.69800)
      const dealer = DealerEntity(
        id: '101',
        order: '01',
        name: 'Đại lý Bến Thành',
        address: 'Quận 1',
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
        lat: 10.77250,
        lng: 106.69800,
      );

      vm.initCheckinWithDealer(dealer);
      await vm.performCheckin(customerId: 101);
      expect(vm.state.visitId, 999);

      // Vị trí người dùng cách 11m (10.77260, 106.69800)
      final (success, errorMsg) = await vm.checkout(
        lat: 10.77260,
        lng: 106.69800,
      );

      expect(success, isTrue);
      expect(errorMsg, isNull);
      expect(vm.state.status, CheckInStatus.checkedOut);
    });

    test('CheckInViewModel.checkout allows checkout if dealer has no coordinates (Luật 4)', () async {
      final visitRepo = FakeVisitRepository([]);
      final vm = createCheckInViewModel(visitRepo);

      // Điểm bán không có tọa độ (lat: null, lng: null)
      const dealer = DealerEntity(
        id: '101',
        order: '01',
        name: 'Đại lý Chưa có GPS',
        address: 'Hẻm sâu',
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
        lat: null,
        lng: null,
      );

      vm.initCheckinWithDealer(dealer);
      await vm.performCheckin(customerId: 101);
      expect(vm.state.visitId, 999);

      // Bất kể vị trí check-out ở đâu, đều được thông qua theo Luật 4
      final (success, errorMsg) = await vm.checkout(
        lat: 10.7950,
        lng: 106.7218,
      );

      expect(success, isTrue);
      expect(errorMsg, isNull);
      expect(vm.state.status, CheckInStatus.checkedOut);
    });

    test('CheckInViewModel.checkout respects allowedRadiusMeters > 100m', () async {
      final visitRepo = FakeVisitRepository([]);
      final vm = createCheckInViewModel(visitRepo);

      const dealer = DealerEntity(
        id: '101',
        order: '01',
        name: 'Đại lý Bến Thành',
        address: 'Quận 1',
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
        lat: 10.77250,
        lng: 106.69800,
      );

      vm.initCheckinWithDealer(dealer);
      await vm.performCheckin(customerId: 101);
      expect(vm.state.visitId, 999);

      // Cách điểm bán ~150m (10.77385, 106.69800)
      // Khi cấu hình allowedRadiusMeters = 200m -> Cho phép check-out thành công
      final (success, errorMsg) = await vm.checkout(
        lat: 10.77385,
        lng: 106.69800,
        allowedRadiusMeters: 200,
      );

      expect(success, isTrue);
      expect(errorMsg, isNull);
      expect(vm.state.status, CheckInStatus.checkedOut);
    });

    test('CheckInViewModel.checkout respects dealer.geofenceRadiusM when allowedRadiusMeters is not passed', () async {
      final visitRepo = FakeVisitRepository([]);
      final vm = createCheckInViewModel(visitRepo);

      const dealer = DealerEntity(
        id: '102',
        order: '02',
        name: 'Đại lý Bán kính rộng',
        address: 'Quận 3',
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
        lat: 10.77250,
        lng: 106.69800,
        geofenceRadiusM: 300,
      );

      vm.initCheckinWithDealer(dealer);
      await vm.performCheckin(customerId: 102);
      expect(vm.state.visitId, 999);

      // Vị trí cách 250m
      // Khi check-out, tự động lấy 300m từ dealer -> Thành công
      final (success, errorMsg) = await vm.checkout(
        lat: 10.77475,
        lng: 106.69800,
      );

      expect(success, isTrue);
      expect(errorMsg, isNull);
      expect(vm.state.status, CheckInStatus.checkedOut);
    });

    test('CheckInViewModel.checkout allows checkout when requireGeofence is false regardless of distance', () async {
      final visitRepo = FakeVisitRepository([]);
      final vm = createCheckInViewModel(visitRepo);

      const dealer = DealerEntity(
        id: '103',
        order: '03',
        name: 'Đại lý Không bắt buộc Geofence',
        address: 'Quận 1',
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
        lat: 10.77250,
        lng: 106.69800,
      );

      vm.initCheckinWithDealer(dealer);
      await vm.performCheckin(customerId: 103);
      expect(vm.state.visitId, 999);

      // Vị trí ở xa 3km nhưng requireGeofence: false -> Cho phép check-out
      final (success, errorMsg) = await vm.checkout(
        lat: 10.7950,
        lng: 106.7218,
        requireGeofence: false,
      );

      expect(success, isTrue);
      expect(errorMsg, isNull);
      expect(vm.state.status, CheckInStatus.checkedOut);
    });

    test('CheckInViewModel.initCheckinWithDealer retains existing active visit and does not reset visitId', () async {
      final activeVisit = VisitEntity(
        id: 777,
        customerId: 104,
        customerName: 'Đại lý 104',
        checkinAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      final visitRepo = FakeVisitRepository([], activeVisit: activeVisit);
      final vm = createCheckInViewModel(visitRepo);

      final dealer = DealerEntity(
        id: '104',
        order: '04',
        name: 'Đại lý 104',
        address: 'Quận 1',
        status: DealerVisitStatus.inProgress,
        statusLabel: 'Đang ghé',
        isVip: false,
        visit: activeVisit,
      );

      // 1. Khởi tạo phiên với dealer đang có lượt
      vm.initCheckinWithDealer(dealer);
      expect(vm.state.visitId, 777);
      expect(vm.state.visitEntity?.customerId, 104);

      // 2. Giả lập tạm rời và quay lại: gọi lại initCheckinWithDealer với dealer từ danh sách tuyến
      const dealerWithoutVisit = DealerEntity(
        id: '104',
        order: '04',
        name: 'Đại lý 104',
        address: 'Quận 1',
        status: DealerVisitStatus.inProgress,
        statusLabel: 'Đang ghé',
        isVip: false,
      );
      vm.initCheckinWithDealer(dealerWithoutVisit);

      // Phiên không bị reset về 0
      expect(vm.state.visitId, 777);
      expect(vm.state.visitEntity?.id, 777);

      // 3. Gọi performCheckin không tạo duplicate visit
      final error = await vm.performCheckin(customerId: 104);
      expect(error, isNull);
      expect(vm.state.visitId, 777);
    });

    test('CheckInViewModel.performCheckin restores active visit from storage without creating duplicate', () async {
      final savedVisit = VisitEntity(
        id: 888,
        customerId: 105,
        customerName: 'Đại lý 105',
        checkinAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );
      final visitRepo = FakeVisitRepository([], activeVisit: savedVisit);
      final vm = createCheckInViewModel(visitRepo);

      const dealer = DealerEntity(
        id: '105',
        order: '05',
        name: 'Đại lý 105',
        address: 'Quận 1',
        status: DealerVisitStatus.pending,
        statusLabel: 'Chưa ghé',
        isVip: false,
      );

      // Khởi tạo phiên mới khi state chưa có
      vm.initCheckinWithDealer(dealer);
      // Gọi performCheckin cho customerId 105: tự động phát hiện storage có active visit và phục hồi
      final error = await vm.performCheckin(customerId: 105);
      expect(error, isNull);
      expect(vm.state.visitId, 888);
      expect(vm.state.visitEntity?.customerId, 105);
    });

    test('CheckInViewModel.cancelVisit handles 422 "lượt viếng thăm này đã check out rồi, không hủy được nữa" gracefully', () async {
      final activeVisit = VisitEntity(
        id: 999,
        customerId: 106,
        customerName: 'Đại lý 106',
        checkinAt: DateTime.now().subtract(const Duration(minutes: 15)),
      );
      final visitRepo = FakeVisitRepository([], activeVisit: activeVisit);
      visitRepo.throwOnCancel = Exception('AppException: lượt viếng thăm này đã check out rồi, không hủy được nữa (code: 422)');
      final vm = createCheckInViewModel(visitRepo);

      final dealer = DealerEntity(
        id: '106',
        order: '06',
        name: 'Đại lý 106',
        address: 'Quận 1',
        status: DealerVisitStatus.inProgress,
        statusLabel: 'Đang ghé',
        isVip: false,
        visit: activeVisit,
      );

      vm.initCheckinWithDealer(dealer);
      expect(vm.state.visitId, 999);

      final (success, infoMsg) = await vm.cancelVisit();
      expect(success, isTrue);
      expect(infoMsg, contains('đã check-out trước đó trên hệ thống'));
      expect(vm.state.visitId, 0);
      expect(visitRepo.activeVisit, isNull);
    });
  });
}
