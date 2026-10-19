import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:vthm_dms/features/attendance/domain/entities/attendance_entity.dart';
import 'package:vthm_dms/features/attendance/presentation/widgets/attendance_history_card.dart';

void main() {
  testWidgets('AttendanceHistoryCard renders calendar grid, status dots, and toggles list view', (tester) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    final mockPunch1 = AttendancePunchEntity(
      id: 101,
      punchAt: '$todayStr 08:00:00',
      clientUuid: 'uuid-1',
      lat: 21.0285,
      lng: 105.8542,
      direction: 'in',
      directionLabel: 'Vào',
      geofenceName: 'Trụ sở chính',
      requirements: const AttendanceRequirementsEntity(
        satisfied: true,
        photoCount: 2,
        minPhotos: 2,
        needFront: false,
        needBack: false,
      ),
    );

    final mockPunch2 = AttendancePunchEntity(
      id: 102,
      punchAt: '$todayStr 17:30:00',
      clientUuid: 'uuid-2',
      lat: 21.0285,
      lng: 105.8542,
      direction: 'out',
      directionLabel: 'Ra',
      geofenceName: 'Trụ sở chính',
      requirements: const AttendanceRequirementsEntity(
        satisfied: true,
        photoCount: 2,
        minPhotos: 2,
        needFront: false,
        needBack: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AttendanceHistoryCard(
                history: [mockPunch1, mockPunch2],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Kiểm tra tiêu đề hiển thị Bảng lịch chấm công
    expect(find.text('Bảng lịch chấm công'), findsOneWidget);

    // 2. Kiểm tra các thứ trong tuần
    expect(find.text('T2'), findsOneWidget);
    expect(find.text('CN'), findsOneWidget);

    // 3. Kiểm tra thanh chú thích (đã loại bỏ 'Vi phạm')
    expect(find.text('Đủ công'), findsOneWidget);
    expect(find.text('Thiếu ảnh/ca'), findsOneWidget);
    expect(find.text('Vi phạm'), findsNothing);
    expect(find.text('Không chấm'), findsOneWidget);

    // 4. Kiểm tra lượt chấm của ngày hôm nay được liệt kê
    expect(find.textContaining('08:00'), findsOneWidget);
    expect(find.textContaining('17:30'), findsOneWidget);
    expect(find.text('Trụ sở chính'), findsNWidgets(2));
    expect(find.text('2 lượt'), findsOneWidget);

    // 5. Kiểm tra nút chuyển đổi sang Danh sách
    await tester.tap(find.text('Danh sách'));
    await tester.pumpAndSettle();

    expect(find.text('Lịch sử chấm công'), findsOneWidget);
    expect(find.text('30 ngày'), findsOneWidget);

    // 6. Chuyển lại về Lịch
    await tester.tap(find.text('Lịch'));
    await tester.pumpAndSettle();

    expect(find.text('Bảng lịch chấm công'), findsOneWidget);
  });
}
