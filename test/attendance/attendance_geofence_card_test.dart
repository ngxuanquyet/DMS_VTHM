import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/attendance/domain/entities/attendance_entity.dart';
import 'package:vthm_dms/features/attendance/presentation/states/attendance_state.dart';
import 'package:vthm_dms/features/attendance/presentation/viewmodels/attendance_view_model.dart';
import 'package:vthm_dms/features/attendance/presentation/widgets/attendance_geofence_card.dart';

void main() {
  testWidgets('AttendanceGeofenceCard renders compact card and opens distance-sorted bottom sheet', (tester) async {
    final loc1 = const AttendanceLocationItemEntity(
      id: 1,
      code: 'VP-01',
      name: 'Văn phòng Xa (2000m)',
      radiusM: 100,
      distanceM: 2000,
    );
    final loc2 = const AttendanceLocationItemEntity(
      id: 2,
      code: 'VP-02',
      name: 'Văn phòng Gần Nhất (25m)',
      radiusM: 100,
      distanceM: 25,
    );
    final loc3 = const AttendanceLocationItemEntity(
      id: 3,
      code: 'VP-03',
      name: 'Văn phòng Trung Bình (150m)',
      radiusM: 100,
      distanceM: 150,
    );

    final mockConfig = AttendanceConfigEntity(
      canPunch: true,
      group: const AttendanceGroupEntity(
        code: 'GRP-1',
        name: 'Khối Kinh Doanh',
        enforceGeofence: true,
      ),
      photo: const AttendancePhotoConfigEntity(),
      locations: [loc1, loc2, loc3],
    );

    final container = ProviderContainer();
    final vm = container.read(attendanceViewModelProvider.notifier);
    vm.state = AttendanceState(
      status: AttendanceStatus.loaded,
      config: mockConfig,
      selectedLocation: loc2,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AttendanceGeofenceCard(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Kiểm tra tiêu đề và nút Đổi địa điểm
    expect(find.text('Địa điểm chấm công'), findsOneWidget);
    expect(find.text('Đổi địa điểm'), findsOneWidget);
    expect(find.text('Văn phòng Gần Nhất (25m)'), findsOneWidget);
    expect(find.text('Gần nhất'), findsOneWidget);

    // 2. Nhấn vào nút "Đổi địa điểm" để mở Bottom Sheet
    await tester.tap(find.text('Đổi địa điểm'));
    await tester.pumpAndSettle();

    // 3. Kiểm tra Bottom Sheet hiển thị danh sách đã sắp xếp theo khoảng cách
    expect(find.text('Chọn địa điểm chấm công'), findsOneWidget);
    expect(find.textContaining('Đã sắp xếp theo khoảng cách gần nhất'), findsOneWidget);

    // Kiểm tra thứ tự xuất hiện: loc2 (25m) xuất hiện trước loc3 (150m) và loc1 (2000m)
    final loc2Finder = find.text('Văn phòng Gần Nhất (25m)');
    final loc3Finder = find.text('Văn phòng Trung Bình (150m)');
    final loc1Finder = find.text('Văn phòng Xa (2000m)');

    expect(loc2Finder, findsWidgets);
    expect(loc3Finder, findsOneWidget);
    expect(loc1Finder, findsOneWidget);

    final loc2Top = tester.getTopLeft(loc2Finder.last).dy;
    final loc3Top = tester.getTopLeft(loc3Finder).dy;
    final loc1Top = tester.getTopLeft(loc1Finder).dy;

    // loc2 (25m) phải nằm trên loc3 (150m), và loc3 phải nằm trên loc1 (2000m)
    expect(loc2Top < loc3Top, isTrue);
    expect(loc3Top < loc1Top, isTrue);

    // 4. Chọn loc3
    await tester.tap(loc3Finder);
    await tester.pumpAndSettle();

    // Bottom sheet đã đóng và màn hình đã chọn loc3
    expect(find.text('Chọn địa điểm chấm công'), findsNothing);
    expect(find.text('Văn phòng Trung Bình (150m)'), findsOneWidget);

    vm.dispose();
  });
}
