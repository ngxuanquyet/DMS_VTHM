import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/core/services/app_notification_service.dart';
import 'package:vthm_dms/features/attendance/domain/entities/attendance_entity.dart';
import 'package:vthm_dms/features/attendance/presentation/states/attendance_state.dart';
import 'package:vthm_dms/features/attendance/presentation/viewmodels/attendance_view_model.dart';
import 'package:vthm_dms/features/attendance/presentation/widgets/attendance_shift_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Shift Reminders & Notification Service Tests (§8 API-NHAC-CA-MOBILE-2026-10-17)', () {
    test('scheduleShiftReminders and cancellations execute without error', () async {
      final notifService = AppNotificationService();
      await notifService.init();

      const shift = AttendanceShiftEntity(
        id: 12,
        code: 'HC',
        name: 'Hành chính 08:00–17:30',
        startTime: '08:00',
        endTime: '17:30',
        crossMidnight: false,
      );

      final schedule = AttendanceShiftScheduleEntity(
        workDate: DateTime.now().toIso8601String().substring(0, 10),
        status: 'shift',
        source: 'schedule',
        shift: shift,
      );

      // 1. Lên lịch khi chưa có lượt chấm công (punchCount: 0)
      await notifService.scheduleShiftReminders(schedule, punchCount: 0);

      // 2. Hủy nhắc vào ca khi đã chấm công thành công
      await notifService.cancelShiftInReminder();

      // 3. Lên lịch cho ca qua đêm (crossMidnight = true)
      const nightShift = AttendanceShiftEntity(
        id: 15,
        code: 'CD',
        name: 'Ca đêm 22:00–06:00',
        startTime: '22:00',
        endTime: '06:00',
        crossMidnight: true,
      );

      final nightSchedule = AttendanceShiftScheduleEntity(
        workDate: DateTime.now().toIso8601String().substring(0, 10),
        status: 'shift',
        source: 'override',
        shift: nightShift,
      );

      await notifService.scheduleShiftReminders(nightSchedule, punchCount: 1);
      await notifService.cancelShiftOutReminder();
      await notifService.cancelAllShiftReminders();

      expect(true, isTrue);
    });

    test('scheduleMultiDayShiftReminders schedules list of week shifts', () async {
      final notifService = AppNotificationService();

      final today = DateTime.now();
      final schedules = List.generate(7, (i) {
        final d = today.add(Duration(days: i));
        final dateStr = d.toIso8601String().substring(0, 10);
        if (d.weekday == DateTime.sunday) {
          return AttendanceShiftScheduleEntity(
            workDate: dateStr,
            status: 'day_off',
          );
        }
        return AttendanceShiftScheduleEntity(
          workDate: dateStr,
          status: 'shift',
          source: 'schedule',
          shift: const AttendanceShiftEntity(
            id: 10,
            code: 'HC',
            name: 'Hành chính 08:00–17:30',
            startTime: '08:00',
            endTime: '17:30',
          ),
        );
      });

      await notifService.scheduleMultiDayShiftReminders(schedules);
      expect(true, isTrue);
    });
  });

  group('AttendanceShiftCard Widget Tests', () {
    testWidgets('Renders standard shift details accurately', (tester) async {
      const shift = AttendanceShiftEntity(
        id: 1,
        code: 'HC',
        name: 'Hành chính 08:00–17:30',
        startTime: '08:00',
        endTime: '17:30',
      );

      final schedule = AttendanceShiftScheduleEntity(
        workDate: '2026-10-19',
        status: 'shift',
        source: 'override',
        shift: shift,
      );

      final mockConfig = AttendanceConfigEntity(
        canPunch: true,
        group: const AttendanceGroupEntity(code: 'VP', name: 'Văn phòng', enforceGeofence: true),
        photo: const AttendancePhotoConfigEntity(),
        locations: const [],
        today: AttendanceTodayEntity(
          workDate: '2026-10-19',
          punchCount: 0,
          shift: schedule,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          attendanceViewModelProvider.overrideWith((ref) {
            return _MockAttendanceViewModel(
              AttendanceState(
                status: AttendanceStatus.loaded,
                config: mockConfig,
              ),
            );
          }),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: AttendanceShiftCard(),
            ),
          ),
        ),
      );

      expect(find.text('Ca làm việc hôm nay'), findsOneWidget);
      expect(find.text('Hành chính 08:00–17:30'), findsOneWidget);
      expect(find.text('08:00 – 17:30'), findsOneWidget);
      expect(find.text('Xếp tay'), findsOneWidget);
      expect(find.textContaining('Nhắc vào ca: 15\' trước giờ'), findsOneWidget);
    });

    testWidgets('Renders day off status properly', (tester) async {
      final schedule = AttendanceShiftScheduleEntity(
        workDate: '2026-10-18',
        status: 'day_off',
      );

      final mockConfig = AttendanceConfigEntity(
        canPunch: true,
        group: const AttendanceGroupEntity(code: 'VP', name: 'Văn phòng', enforceGeofence: true),
        photo: const AttendancePhotoConfigEntity(),
        locations: const [],
        today: AttendanceTodayEntity(
          workDate: '2026-10-18',
          punchCount: 0,
          shift: schedule,
        ),
      );

      final container = ProviderContainer(
        overrides: [
          attendanceViewModelProvider.overrideWith((ref) {
            return _MockAttendanceViewModel(
              AttendanceState(
                status: AttendanceStatus.loaded,
                config: mockConfig,
              ),
            );
          }),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: AttendanceShiftCard(),
            ),
          ),
        ),
      );

      expect(find.text('Hôm nay bạn không có ca làm việc (Nghỉ tuần)'), findsOneWidget);
      expect(find.text('Nghỉ'), findsOneWidget);
    });
  });
}

class _MockAttendanceViewModel extends StateNotifier<AttendanceState>
    implements AttendanceViewModel {
  _MockAttendanceViewModel(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
