import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/daily_report/domain/entities/daily_activity_entity.dart';
import 'package:vthm_dms/features/daily_report/presentation/screens/daily_report_screen.dart';
import 'package:vthm_dms/features/daily_report/presentation/widgets/daily_activity_timeline_card.dart';
import 'package:vthm_dms/features/daily_report/presentation/widgets/visit_report_card.dart';
import 'package:vthm_dms/features/visit/data/models/checkin_request_model.dart';
import 'package:vthm_dms/features/visit/data/models/checkout_request_model.dart';
import 'package:vthm_dms/features/visit/data/repositories/visit_repository_impl.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_photo_entity.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_requirements_entity.dart';
import 'package:vthm_dms/features/visit/domain/repositories/visit_repository.dart';

class FakeVisitRepository implements VisitRepository {
  List<VisitEntity> localVisits;

  FakeVisitRepository({this.localVisits = const []});

  @override
  Future<List<VisitEntity>> getTodayVisits() async => localVisits;

  @override
  Future<List<VisitEntity>> getVisitsByDate(DateTime date,
          {bool forceRefresh = false}) async =>
      localVisits;

  @override
  Future<List<VisitEntity>> getAllLocalVisits() async => localVisits;

  @override
  Future<void> saveLocalVisit(VisitEntity visit) async {}

  @override
  Future<void> saveLocalVisits(List<VisitEntity> visits) async {}

  @override
  Future<VisitEntity> checkin(CheckinRequestModel request) async =>
      throw UnimplementedError();

  @override
  Future<VisitEntity> checkout(
          {required int visitId, required CheckoutRequestModel request}) async =>
      throw UnimplementedError();

  @override
  Future<void> cancelVisit(int visitId, {String? clientUuid}) async {}

  @override
  Future<void> removeLocalVisit(int visitId, {String? clientUuid}) async {}

  @override
  Future<void> clearActiveVisit() async {}

  @override
  Future<VisitRequirementsEntity> deletePhoto(
          {required int visitId, required int photoId}) async =>
      throw UnimplementedError();

  @override
  Future<VisitEntity?> getActiveVisit() async => null;

  @override
  Future<VisitRequirementsEntity> getRequirements(int visitId,
          {String? visitResult}) async =>
      const VisitRequirementsEntity();

  @override
  Future<void> saveActiveVisit(VisitEntity visit) async {}

  @override
  Future<VisitPhotoEntity> uploadPhoto({
    required int visitId,
    required File file,
    String photoType = 'other',
    DateTime? takenAt,
    double? lat,
    double? lng,
  }) async =>
      throw UnimplementedError();
}

void main() {
  group('Daily Report & Visit Report Tests', () {
    testWidgets('DailyActivityTimelineCard renders activities and opens detail sheet',
        (tester) async {
      final sampleActivities = [
        const DailyActivityEntity(
          id: 'test-1',
          time: '08:00',
          title: 'Chấm công vào thành công',
          subtitle: 'Văn phòng VTHM',
          type: DailyActivityType.attendanceIn,
        ),
        const DailyActivityEntity(
          id: 'test-2',
          time: '09:30',
          title: 'Check-in: Quầy thuốc An Khang',
          subtitle: 'Trong bán kính 45m',
          type: DailyActivityType.checkIn,
          customerName: 'Quầy thuốc An Khang',
          customerAddress: '195 Trần Hưng Đạo',
          lat: 10.380123,
          lng: 105.432109,
          notes: 'Khảo sát quầy kệ tốt',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyActivityTimelineCard(activities: sampleActivities),
            ),
          ),
        ),
      );

      // Verify list items render
      expect(find.text('Chấm công vào thành công'), findsOneWidget);
      expect(find.text('Check-in: Quầy thuốc An Khang'), findsOneWidget);
      expect(find.text('2 hoạt động'), findsOneWidget);

      // Tap on second item to open detail sheet
      await tester.tap(find.text('Check-in: Quầy thuốc An Khang'));
      await tester.pumpAndSettle();

      // Verify detail sheet content
      expect(find.text('195 Trần Hưng Đạo'), findsOneWidget);
      expect(find.text('Khảo sát quầy kệ tốt'), findsOneWidget);
      expect(find.text('Đóng'), findsOneWidget);
    });

    testWidgets('DailyReportScreen renders metrics, empty state and visits correctly',
        (tester) async {
      final visits = [
        VisitEntity(
          id: 1,
          customerId: 101,
          customerName: 'Nhà thuốc An Khang',
          customerCode: 'AK001',
          customerAddress: '195 Trần Hưng Đạo',
          checkinAt: DateTime.now().subtract(const Duration(minutes: 45)),
          checkoutAt: DateTime.now().subtract(const Duration(minutes: 15)),
          durationSeconds: 1800,
          visitResult: 'visited',
          photoCount: 3,
          formCount: 1,
          isOnRoute: true,
        ),
        VisitEntity(
          id: 2,
          customerId: 102,
          customerName: 'Đại lý Dược Minh Châu',
          customerCode: 'MC002',
          customerAddress: '45 Lê Duẩn',
          checkinAt: DateTime.now().subtract(const Duration(hours: 2)),
          checkoutAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 55)),
          durationSeconds: 300,
          visitResult: 'closed',
          closedNote: 'Chủ đi vắng',
          photoCount: 1,
          formCount: 0,
          isOnRoute: false,
        ),
      ];

      final fakeRepo = FakeVisitRepository(localVisits: visits);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visitRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: DailyReportScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check title and metrics headers
      expect(find.text('Báo cáo viếng thăm'), findsOneWidget);
      expect(find.text('Điểm viếng thăm'), findsOneWidget);
      expect(find.text('Ảnh đóng dấu'), findsOneWidget);
      expect(find.text('Biểu mẫu nộp'), findsOneWidget);
      expect(find.text('Giờ làm việc'), findsOneWidget);

      // Verify metric values calculated dynamically:
      // Total 2 visits, 1 visited -> '1 / 2 điểm'
      expect(find.text('1 / 2 điểm'), findsOneWidget);
      // Photos: 3 + 1 = 4 ảnh
      expect(find.text('4 ảnh'), findsOneWidget);
      // Forms: 1 + 0 = 1 phiếu
      expect(find.text('1 phiếu'), findsOneWidget);
      // Duration: 1800 + 300 = 2100s = 35 phút
      expect(find.text('35 phút'), findsOneWidget);

      // Verify visit cards
      expect(find.text('Nhà thuốc An Khang'), findsWidgets);
      expect(find.text('Đại lý Dược Minh Châu'), findsWidgets);
      expect(find.text('Lý do: Chủ đi vắng'), findsOneWidget);

      // Verify timeline section
      expect(find.text('Dòng thời gian hoạt động'), findsOneWidget);
    });

    testWidgets('VisitReportCard renders and opens VisitDetailBottomSheet',
        (tester) async {
      final visit = VisitEntity(
        id: 99,
        customerId: 555,
        customerName: 'Tiệm thuốc Hạnh Phúc',
        customerCode: 'HP999',
        customerAddress: '88 Nguyễn Trãi, Q5',
        checkinAt: DateTime(2026, 10, 3, 9, 0),
        checkoutAt: DateTime(2026, 10, 3, 9, 25),
        durationSeconds: 1500,
        visitResult: 'visited',
        photoCount: 2,
        formCount: 1,
        isOnRoute: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VisitReportCard(visit: visit),
          ),
        ),
      );

      expect(find.text('Tiệm thuốc Hạnh Phúc'), findsOneWidget);
      expect(find.text('HP999'), findsOneWidget);
      expect(find.text('88 Nguyễn Trãi, Q5'), findsOneWidget);
      expect(find.text('Mở cửa'), findsOneWidget);

      // Tap card to open detail bottom sheet
      await tester.tap(find.text('Tiệm thuốc Hạnh Phúc'));
      await tester.pumpAndSettle();

      expect(find.text('Mã lượt viếng thăm'), findsOneWidget);
      expect(find.text('#99'), findsOneWidget);
      expect(find.text('2 ảnh'), findsOneWidget);
      expect(find.text('1 phiếu'), findsOneWidget);
    });
  });
}
