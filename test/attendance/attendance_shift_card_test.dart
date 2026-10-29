import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vthm_dms/features/attendance/domain/entities/attendance_entity.dart';
import 'package:vthm_dms/features/attendance/presentation/states/attendance_state.dart';
import 'package:vthm_dms/features/attendance/presentation/viewmodels/attendance_view_model.dart';
import 'package:vthm_dms/features/attendance/presentation/widgets/attendance_shift_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Thẻ chỉ đọc khối `today` của ĐÚNG hôm nay (`currentToday`) — ngày cố định bị coi là bộ đệm cũ.
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
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
        workDate: today,
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
          workDate: today,
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
        workDate: today,
        status: 'day_off',
      );

      final mockConfig = AttendanceConfigEntity(
        canPunch: true,
        group: const AttendanceGroupEntity(code: 'VP', name: 'Văn phòng', enforceGeofence: true),
        photo: const AttendancePhotoConfigEntity(),
        locations: const [],
        today: AttendanceTodayEntity(
          workDate: today,
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
