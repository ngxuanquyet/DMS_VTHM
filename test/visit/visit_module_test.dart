import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_entity.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_dynamic_column.dart';
import 'package:vthm_dms/features/customer/domain/entities/customer_meta_entity.dart';
import 'package:vthm_dms/features/customer/domain/repositories/customer_repository.dart';
import 'package:vthm_dms/features/route/domain/entities/route_entity.dart';
import 'package:vthm_dms/features/route/domain/repositories/route_repository.dart';
import 'package:vthm_dms/features/route/domain/usecases/route_usecases.dart';
import 'package:vthm_dms/features/route/presentation/viewmodels/route_view_model.dart';
import 'package:vthm_dms/features/visit/data/models/checkin_request_model.dart';
import 'package:vthm_dms/features/visit/data/models/checkout_request_model.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_photo_entity.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_requirements_entity.dart';
import 'package:vthm_dms/features/visit/domain/usecases/visit_usecases.dart';
import 'package:vthm_dms/features/visit/domain/repositories/visit_repository.dart';

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
  Future<CustomerEntity> updateCustomer({required int id, required Map<String, dynamic> changes}) => throw UnimplementedError();
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
  FakeVisitRepository(this.todayVisits);

  @override
  Future<List<VisitEntity>> getTodayVisits() async => todayVisits;
  @override
  Future<VisitEntity> checkin(CheckinRequestModel request) => throw UnimplementedError();
  @override
  Future<VisitRequirementsEntity> getRequirements(int visitId, {String? visitResult}) => throw UnimplementedError();
  @override
  Future<VisitPhotoEntity> uploadPhoto({required int visitId, required dynamic file, String photoType = 'other', DateTime? takenAt, double? lat, double? lng}) => throw UnimplementedError();
  @override
  Future<VisitRequirementsEntity> deletePhoto({required int visitId, required int photoId}) => throw UnimplementedError();
  @override
  Future<VisitEntity> checkout({required int visitId, required CheckoutRequestModel request}) => throw UnimplementedError();
  @override
  Future<void> cancelVisit(int visitId) async {}
  @override
  Future<void> saveActiveVisit(VisitEntity visit) async {}
  @override
  Future<VisitEntity?> getActiveVisit() async => null;
  @override
  Future<void> clearActiveVisit() async {}
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

      final dealer2 = dealers.firstWhere((d) => d.id == '102');
      expect(dealer2.status, DealerVisitStatus.inProgress);
      expect(dealer2.statusLabel, 'Đang ghé');

      final dealer3 = dealers.firstWhere((d) => d.id == '103');
      expect(dealer3.status, DealerVisitStatus.pending);
      expect(dealer3.statusLabel, 'Chưa ghé');
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
}
