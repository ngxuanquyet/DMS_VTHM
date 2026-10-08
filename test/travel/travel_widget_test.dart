import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/travel/domain/entities/travel_day_entity.dart';
import 'package:vthm_dms/features/travel/domain/entities/travel_leg_entity.dart';
import 'package:vthm_dms/features/travel/presentation/states/travel_state.dart';
import 'package:vthm_dms/features/travel/presentation/widgets/travel_day_card.dart';
import 'package:vthm_dms/features/travel/presentation/widgets/travel_leg_item_card.dart';
import 'package:vthm_dms/features/travel/presentation/widgets/travel_summary_card.dart';

void main() {
  group('TravelSummaryCard Widget Tests', () {
    testWidgets('Displays finalized and pending totals, and separated metrics',
        (tester) async {
      final state = const TravelState(
        days: [
          TravelDayEntity(
            id: 1,
            userId: 100,
            workDate: '2026-09-01',
            roadKm: 15.2,
            isComplete: true,
            legCount: 5,
            legMissingCount: 0,
            legErrorCount: 0,
          ),
          TravelDayEntity(
            id: 2,
            userId: 100,
            workDate: '2026-09-02',
            roadKm: 8.5,
            isComplete: false,
            legCount: 4,
            legMissingCount: 1,
            legErrorCount: 2,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TravelSummaryCard(state: state),
          ),
        ),
      );

      // Con số đã chốt
      expect(find.text('15.2'), findsOneWidget);
      expect(find.text('km'), findsOneWidget);

      // Con số tạm tính
      expect(find.text('+8.5 km tạm tính'), findsOneWidget);

      // Các chỉ số phụ
      expect(find.text('1/2 ngày đã chốt'), findsOneWidget);
      expect(find.text('1 chặng'), findsOneWidget); // Thiếu mốc
      expect(find.text('2 chặng'), findsOneWidget); // Chờ tính đêm
    });
  });

  group('TravelDayCard Widget Tests', () {
    testWidgets('Renders finalized day correctly with Đã chốt badge',
        (tester) async {
      final day = const TravelDayEntity(
        id: 10,
        userId: 100,
        workDate: '2026-09-04',
        roadKm: 12.4,
        isComplete: true,
        legCount: 4,
        legMissingCount: 0,
        legErrorCount: 0,
      );

      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TravelDayCard(
              day: day,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Đã chốt'), findsOneWidget);
      expect(find.text('12.4 km'), findsOneWidget);
      expect(find.text('4 chặng'), findsOneWidget);

      await tester.tap(find.byType(TravelDayCard));
      expect(tapped, true);
    });

    testWidgets('Renders incomplete day with warning badge and (tạm tính)',
        (tester) async {
      final day = const TravelDayEntity(
        id: 11,
        userId: 100,
        workDate: '2026-09-04',
        roadKm: 5.6,
        isComplete: false,
        legCount: 6,
        legMissingCount: 1,
        legErrorCount: 3,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TravelDayCard(
              day: day,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Chưa chốt (3 chặng chờ)'), findsOneWidget);
      expect(find.text('5.6 km'), findsOneWidget);
      expect(find.text('(tạm tính)'), findsOneWidget);
      expect(find.text('1 chặng thiếu mốc (0 km)'), findsOneWidget);
      expect(find.text('Còn 3 chặng chưa tính'), findsOneWidget);
    });
  });

  group('TravelLegItemCard Widget Tests', () {
    testWidgets('Renders calculated leg with km and status from server',
        (tester) async {
      final leg = const TravelLegEntity(
        id: 1,
        seq: 1,
        legKind: 'start',
        legKindLabel: 'Chấm công vào → điểm bán đầu tiên',
        status: 'ok',
        statusLabel: 'Đã tính',
        statusColor: 'success',
        roadM: '8900.00',
        haversineM: '7200.00',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TravelLegItemCard(leg: leg),
          ),
        ),
      );

      expect(find.text('#1'), findsOneWidget);
      expect(find.text('Chấm công vào → điểm bán đầu tiên'), findsOneWidget);
      expect(find.text('Đã tính'), findsOneWidget);
      expect(find.text('8.9 km'), findsOneWidget);
      expect(find.text('7.2 km'), findsOneWidget); // chim bay
    });

    testWidgets('Renders missing_anchor leg with 0 km and danger badge',
        (tester) async {
      final leg = const TravelLegEntity(
        id: 2,
        seq: 2,
        legKind: 'between',
        legKindLabel: 'Giữa hai điểm bán',
        status: 'missing_anchor',
        statusLabel: 'Thiếu mốc để đo',
        statusColor: 'danger',
        roadM: '0.00',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TravelLegItemCard(leg: leg),
          ),
        ),
      );

      expect(find.text('Thiếu mốc để đo'), findsOneWidget);
      expect(find.text('0 km'), findsOneWidget);
      expect(find.text('Thiếu mốc'), findsOneWidget);
    });

    testWidgets('Renders pending leg with "—" and hides error_note (§4.2)',
        (tester) async {
      final leg = const TravelLegEntity(
        id: 3,
        seq: 3,
        legKind: 'between',
        legKindLabel: 'Giữa hai điểm bán',
        status: 'provider_error',
        statusLabel: 'Lỗi dịch vụ',
        statusColor: 'danger',
        roadM: null,
        errorNote: 'SECRET_BACKEND_ERROR_NOTE_INTERNAL',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TravelLegItemCard(leg: leg),
          ),
        ),
      );

      expect(find.text('—'), findsOneWidget);
      expect(find.text('Lỗi dịch vụ'), findsOneWidget);
      // Bảo đảm error_note bí mật của hệ thống KHÔNG hiển thị cho nhân viên (§4.2)
      expect(find.text('SECRET_BACKEND_ERROR_NOTE_INTERNAL'), findsNothing);
    });
  });
}
