import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/travel/data/models/travel_day_model.dart';
import 'package:vthm_dms/features/travel/data/models/travel_leg_model.dart';
import 'package:vthm_dms/features/travel/domain/entities/travel_day_entity.dart';
import 'package:vthm_dms/features/visit/data/models/checkin_request_model.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';

void main() {
  group('TravelDayModel & TravelDayEntity Tests (§4.1)', () {
    test('Parses exact sample JSON from spec §4.1', () {
      final json = {
        "id": 33,
        "user_id": 1193,
        "work_date": "2026-09-04",
        "road_m_total": "0.00",
        "road_km": 0,
        "haversine_m_total": "0.00",
        "leg_count": 6,
        "leg_missing_count": 1,
        "leg_error_count": 5,
        "is_complete": false,
        "calculated_at": "2026-10-08 09:14:23.920189+07"
      };

      final model = TravelDayModel.fromJson(json);

      expect(model.id, 33);
      expect(model.userId, 1193);
      expect(model.workDate, "2026-09-04");
      expect(model.roadMTotal, "0.00");
      expect(model.roadKm, 0);
      expect(model.haversineMTotal, "0.00");
      expect(model.legCount, 6);
      expect(model.legMissingCount, 1);
      expect(model.legErrorCount, 5);
      expect(model.isComplete, false);
      expect(model.hasPendingErrors, true);
      expect(model.hasMissingAnchors, true);
    });

    test('is_complete = false does NOT display road_km as finalized (§4.1)', () {
      final dayIncomplete = const TravelDayEntity(
        id: 33,
        userId: 1193,
        workDate: "2026-09-04",
        roadKm: 8.5,
        legCount: 5,
        legErrorCount: 2,
        isComplete: false,
      );

      expect(dayIncomplete.displayKmText, "8.5 km (tạm tính)");
      expect(dayIncomplete.statusBadgeLabel, "Còn 2 chặng chưa tính");

      final dayComplete = const TravelDayEntity(
        id: 34,
        userId: 1193,
        workDate: "2026-09-05",
        roadKm: 12.8,
        legCount: 4,
        legErrorCount: 0,
        isComplete: true,
      );

      expect(dayComplete.displayKmText, "12.8 km");
      expect(dayComplete.statusBadgeLabel, "Đã chốt");
    });

    test('leg_missing_count and leg_error_count are kept strictly separate (§4.1)', () {
      final day = const TravelDayEntity(
        id: 1,
        userId: 1193,
        workDate: "2026-09-04",
        legCount: 6,
        legMissingCount: 2, // 2 chặng = 0 vì thiếu mốc
        legErrorCount: 3, // 3 chặng chưa tính
        isComplete: false,
      );

      expect(day.legMissingCount, 2);
      expect(day.legErrorCount, 3);
      expect(day.legMissingCount != day.legErrorCount, true);
    });
  });

  group('TravelLegModel & 3 Distance States Tests (§3 & §4.2)', () {
    test('State 1 - number (ok / skipped_short): displays km value', () {
      final legOk = TravelLegModel.fromJson({
        "id": 1,
        "seq": 1,
        "leg_kind": "start",
        "leg_kind_label": "Chấm công vào → điểm bán đầu tiên",
        "status": "ok",
        "status_label": "Đã tính",
        "status_color": "success",
        "road_m": "8900.00",
      });

      expect(legOk.displayDistance, "8.9 km");
      expect(legOk.isFinalized, true);
      expect(legOk.isOk, true);

      final legShort = TravelLegModel.fromJson({
        "id": 2,
        "seq": 2,
        "leg_kind": "between",
        "leg_kind_label": "Giữa hai điểm bán",
        "status": "skipped_short",
        "status_label": "Quá ngắn",
        "status_color": "info",
        "road_m": "40.00",
      });

      expect(legShort.displayDistance, "0.0 km");
      expect(legShort.isFinalized, true);
      expect(legShort.isSkippedShort, true);
    });

    test('State 2 - 0 (missing_anchor): displays 0 km with warning (§3)', () {
      final legMissing = TravelLegModel.fromJson({
        "id": 683,
        "seq": 1,
        "leg_kind": "start",
        "leg_kind_label": "Chấm công vào → điểm bán đầu tiên",
        "status": "missing_anchor",
        "status_label": "Thiếu mốc để đo",
        "status_color": "danger",
        "road_m": "0.00",
      });

      expect(legMissing.displayDistance, "0 km");
      expect(legMissing.isFinalized, true); // Đã chốt chi tiền được
      expect(legMissing.isMissingAnchor, true);
    });

    test('State 3 - null (pending / provider_error): displays "—", never 0 (§3)', () {
      final legPending = TravelLegModel.fromJson({
        "id": 684,
        "seq": 2,
        "leg_kind": "between",
        "leg_kind_label": "Giữa hai điểm bán",
        "status": "pending",
        "status_label": "Chờ tính",
        "status_color": "secondary",
        "road_m": null,
      });

      expect(legPending.displayDistance, "—");
      expect(legPending.isFinalized, false); // Chưa chốt
      expect(legPending.isPending, true);

      final legError = TravelLegModel.fromJson({
        "id": 685,
        "seq": 3,
        "leg_kind": "between",
        "leg_kind_label": "Giữa hai điểm bán",
        "status": "provider_error",
        "status_label": "Lỗi gọi dịch vụ",
        "status_color": "danger",
        "road_m": null,
        "error_note": "Goong 500 internal server error",
      });

      // 🔴 Ép null thành 0 là biến 'chưa biết' thành 'không đi', CẤM gộp (§3)
      expect(legError.displayDistance, "—");
      expect(legError.isFinalized, false);
      expect(legError.isProviderError, true);
      // error_note dành cho quản trị viên, không hiện trên UI nhân viên
      expect(legError.errorNote, isNotNull);
    });

    test('leg_kind only supports start and between (§4.2)', () {
      final legStart = TravelLegModel.fromJson({
        "id": 1,
        "seq": 1,
        "leg_kind": "start",
        "leg_kind_label": "Chấm công vào → điểm bán đầu tiên",
        "status": "ok",
        "status_label": "Đã tính",
        "status_color": "success",
      });
      expect(legStart.legKind, "start");

      final legBetween = TravelLegModel.fromJson({
        "id": 2,
        "seq": 2,
        "leg_kind": "between",
        "leg_kind_label": "Giữa hai điểm bán",
        "status": "ok",
        "status_label": "Đã tính",
        "status_color": "success",
      });
      expect(legBetween.legKind, "between");
    });
  });

  group('VisitEntity & CheckinRequestModel Integration Tests (§2.3 & §4.4)', () {
    test('VisitEntity parses travel_m from GET /dms/visits/{id} accurately', () {
      final visitCalculated = VisitEntity.fromJson({
        "id": 42141,
        "customer_id": 100,
        "visit_date": "2026-09-04",
        "travel_m": 8900,
      });
      expect(visitCalculated.travelM, 8900);
      expect(visitCalculated.travelKmFormatted, "8.9 km");
      expect(visitCalculated.hasTravelCalculated, true);

      final visitMissing = VisitEntity.fromJson({
        "id": 42142,
        "customer_id": 101,
        "visit_date": "2026-09-04",
        "travel_m": 0,
      });
      expect(visitMissing.travelM, 0);
      expect(visitMissing.travelKmFormatted, "0 km");
      expect(visitMissing.isTravelMissingAnchor, true);

      final visitPending = VisitEntity.fromJson({
        "id": 42143,
        "customer_id": 102,
        "visit_date": "2026-09-04",
        "travel_m": null,
      });
      expect(visitPending.travelM, isNull);
      expect(visitPending.travelKmFormatted, "—");
      expect(visitPending.isTravelPending, true);
    });

    test('CheckinRequestModel NEVER sends km_declared field (§2.3)', () {
      final req = const CheckinRequestModel(
        customerId: 123,
        clientUuid: 'uuid-test',
        kmDeclared: 15.5, // Thậm chí nếu có truyền giá trị, toJson không bao giờ gửi
      );

      final json = req.toJson();
      expect(json.containsKey('km_declared'), false);
    });
  });
}
